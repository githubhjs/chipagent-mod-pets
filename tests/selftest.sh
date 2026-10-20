#!/bin/bash

# chip-pet self-test. No ChipAgents needed:  bash tests/selftest.sh
# Uses mktemp under $TMPDIR (default /tmp); set TMPDIR to move it.

set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PET=$here/plugins/chip-pet/bin/chip-pet
work=$(mktemp -d "${TMPDIR:-/tmp}/chip-pet-test.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
export CHIP_PET_HOME=$work/home LANG=C.UTF-8 NO_COLOR=1
unset LC_ALL CHIPAGENTS_HOOKS_INNER REVIEW_GATE_INNER CHIP_PET_OFF CHIP_PET_TMUX CHIP_PET_LANG
cd "$work" || exit 1

passed=0 failed=0
ok() {
  echo "PASS  $1"
  passed=$((passed + 1))
}
ng() {
  echo "FAIL  $1"
  [[ -n ${2:-} ]] && printf '      %s\n' "$2"
  failed=$((failed + 1))
}
get() { sed -n "s/^$1=//p" "$CHIP_PET_HOME/state" 2> /dev/null; }

# ev <event> <payload>: the hook contract is no output at all and exit 0.
SILENT_BAD=
ev() {
  local out rc
  out=$(printf '%s' "$2" | bash "$PET" event "$1" 2>&1)
  rc=$?
  if [[ $rc != 0 || -n $out ]]; then
    SILENT_BAD+="$1(rc=$rc out=${out:0:60}) "
  fi
}
bash_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

PY=
for c in python3 python; do
  if command -v "$c" > /dev/null 2>&1 && "$c" -I -c 'import tomllib' > /dev/null 2>&1; then
    PY=$c
    break
  fi
done

# --- startup ----------------------------------------------------------------
CHIPAGENTS_PLUGIN_ROOT=$here/plugins/chip-pet ev startup ''
[[ $(get last_event) == hello ]] && ok "startup: the pet says hello" || ng "startup: the pet says hello" "last_event=$(get last_event)"
[[ $(cat "$CHIP_PET_HOME/plugin_root" 2> /dev/null) == "$here/plugins/chip-pet" ]] &&
  ok "startup: records the plugin root for /pet" || ng "startup: records the plugin root for /pet"

# --- shell command classification -------------------------------------------
bad=
while IFS='|' read -r cmd want_kind want_prog; do
  ev pre_tool_use "$(bash_payload "$cmd")"
  k=$(get last_kind) p=$(get last_prog)
  [[ $k == "$want_kind" && ( -z $want_prog || $p == "$want_prog" ) ]] || bad+="[$cmd -> $k/$p, want $want_kind/$want_prog] "
done << 'EOF'
cd sim && xrun -f files.f +UVM_TESTNAME=smoke|sim|xrun
./simv +ntb_random_seed=7|sim|simv
vcs -full64 -sverilog top.sv|sim|vcs
make sim TEST=fifo_smoke|sim|sim
slang --lint-only rtl/top.sv|lint|slang
verilator --lint-only -Wall rtl/top.sv|lint|verilator
dc_shell -f scripts/syn.tcl|synth|dc_shell
yosys -p synth_ice40 top.v|synth|yosys
jg -batch -tcl prove.tcl|formal|jg
verdi -ssf waves.fsdb|wave|verdi
git-flock-commit -m fix|git|git-flock-commit
git status --short|git|git
pytest -q tests|test|pytest
make -j8|build|make
ls -la rtl|shell|ls
EOF
[[ -z $bad ]] && ok "pre_tool_use: shell commands classified (sim, lint, synth, formal, wave, git, test, build)" ||
  ng "pre_tool_use: shell commands classified" "$bad"

bad=
while IFS='|' read -r tool want_kind; do
  ev pre_tool_use "{\"tool_name\":\"$tool\",\"tool_input\":{\"path\":\"rtl/top.sv\"}}"
  [[ $(get last_kind) == "$want_kind" ]] || bad+="[$tool -> $(get last_kind), want $want_kind] "
done << 'EOF'
Edit|edit
Write|edit
Read|read
Grep|read
queryWaveform|wave
Task|sub
EOF
[[ -z $bad ]] && ok "pre_tool_use: non-shell tools classified (edit, read, wave, subagent)" ||
  ng "pre_tool_use: non-shell tools classified" "$bad"

tools=$(get tools) sims=$(get sims)
[[ $tools == 21 && $sims == 5 ]] && ok "counters: 21 tool calls, 5 of them sims/tests" || ng "counters: 21 tool calls, 5 of them sims/tests" "tools=$tools sims=$sims"

# --- pass / fail from tool output -------------------------------------------
xp0=$(get xp)
ev post_tool_use '{"tool_name":"Bash","tool_input":{"command":"xrun"},"tool_output":"--- UVM Report Summary ---\nUVM_INFO :   12\nUVM_WARNING :    0\nUVM_ERROR :    3\nUVM_FATAL :    0\n"}'
[[ $(get last_event) == fail && $(get fails) == 1 ]] && ok "post_tool_use: UVM_ERROR : 3 is a failure" || ng "post_tool_use: UVM_ERROR : 3 is a failure" "last_event=$(get last_event) fails=$(get fails)"

ev post_tool_use '{"tool_name":"Bash","tool_input":{"command":"xrun"},"tool_output":"--- UVM Report Summary ---\nUVM_ERROR :    0\nUVM_FATAL :    0\nTEST PASSED\n"}'
[[ $(get last_event) == pass && $(get passes) == 1 && $(get xp) == $((xp0 + 10)) ]] &&
  ok "post_tool_use: a clean UVM summary is a pass, +10 xp, and feeds the pet" ||
  ng "post_tool_use: a clean UVM summary is a pass" "last_event=$(get last_event) passes=$(get passes) xp=$(get xp) (was $xp0)"

bad=
for out in 'Error-[SE] Syntax error' '%Error: top.sv:3:1: syntax error' 'xmvlog: *E,EXPSMC (top.sv,3|4)' 'Segmentation fault (core dumped)' '2 tests failed'; do
  before=$(get fails)
  ev post_tool_use "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"run\"},\"tool_output\":\"$out\"}"
  [[ $(get fails) == $((before + 1)) ]] || bad+="[$out] "
done
[[ -z $bad ]] && ok "post_tool_use: VCS, Verilator, Xcelium, crash and test-count failures detected" || ng "post_tool_use: failure markers" "missed: $bad"

before=$(get fails)
ev post_tool_use '{"tool_name":"Read","tool_input":{"path":"log"},"tool_output":"UVM_ERROR :    3 FAILED"}'
[[ $(get fails) == "$before" && $(get last_event) == think ]] &&
  ok "post_tool_use: reading a failing log is not a failure (only commands count)" ||
  ng "post_tool_use: reading a failing log is not a failure" "fails=$(get fails) last_event=$(get last_event)"

# --- turns ------------------------------------------------------------------
ev pre_turn '{"user_message":"fix the fifo"}'
[[ $(get last_event) == think ]] && ok "pre_turn: thinking" || ng "pre_turn: thinking"
ev post_turn '{"user_message":"Last turn transcript:\nUser:\nfix\n---\n"}'
ev end_turn ''
[[ $(get turns) == 1 && $(get dones) == 1 && $(get last_event) == done ]] &&
  ok "post_turn and end_turn: counted, the pet celebrates" || ng "post_turn and end_turn" "turns=$(get turns) dones=$(get dones)"
ev post_compact ''
[[ $(get last_event) == compact ]] && ok "post_compact: dizzy" || ng "post_compact: dizzy"

# --- inner runs, off switch -------------------------------------------------
tools=$(get tools) dones=$(get dones)
CHIPAGENTS_HOOKS_INNER=1 ev pre_tool_use "$(bash_payload 'grep -n always rtl/top.sv')"
REVIEW_GATE_INNER=1 ev end_turn ''
[[ $(get last_event) == review && $(get tools) == "$tools" && $(get dones) == "$dones" ]] &&
  ok "inner runs (reviewers): shown as review, earn nothing, no celebration" ||
  ng "inner runs" "last_event=$(get last_event) tools=$(get tools)/$tools dones=$(get dones)/$dones"

sum=$(cksum < "$CHIP_PET_HOME/state")
CHIP_PET_OFF=1 ev pre_tool_use "$(bash_payload xrun)"
[[ $(cksum < "$CHIP_PET_HOME/state") == "$sum" ]] && ok "CHIP_PET_OFF=1: hooks do nothing" || ng "CHIP_PET_OFF=1: hooks do nothing"

# --- robustness -------------------------------------------------------------
big=$work/big.json
{
  printf '{"tool_name":"Bash","tool_input":{"command":"xrun"},"tool_output":"'
  head -c 6000000 /dev/zero | tr '\0' 'x'
  printf ' UVM_ERROR :    1"}'
} > "$big"
start=$SECONDS
out=$(bash "$PET" event post_tool_use < "$big" 2>&1)
rc=$?
elapsed=$((SECONDS - start))
[[ $rc == 0 && -z $out && $elapsed -le 4 && $(get last_event) == fail ]] &&
  ok "6 MB payload: silent, exit 0, fast, and the failure at its very end is still seen" ||
  ng "6 MB payload" "rc=$rc elapsed=${elapsed}s last_event=$(get last_event) out=${out:0:80}"

out=$(printf 'not json at all \x01\x02' | bash "$PET" event pre_tool_use 2>&1)
rc=$?
[[ $rc == 0 && -z $out ]] && ok "garbage payload: silent, exit 0" || ng "garbage payload" "rc=$rc out=$out"

: > "$work/a-file"
out=$(bash_payload xrun | CHIP_PET_HOME=$work/a-file/pet bash "$PET" event pre_tool_use 2>&1)
rc=$?
[[ $rc == 0 && -z $out ]] && ok "unwritable state directory: silent, exit 0" || ng "unwritable state directory" "rc=$rc out=$out"

out=$(bash "$PET" event pre_tool_use < /dev/null 2>&1)
rc=$?
[[ $rc == 0 && -z $out ]] && ok "no payload at all: silent, exit 0" || ng "no payload at all" "rc=$rc out=$out"

[[ -z $SILENT_BAD ]] && ok "every hook call above printed nothing and exited 0" || ng "hook silence" "$SILENT_BAD"

# --- concurrency (several agents, chip-swarm teams) -------------------------
lock_modes=(mkdir)
command -v flock > /dev/null 2>&1 && lock_modes+=(flock)
for mode in "${lock_modes[@]}"; do
  before=$(get tools)
  n=30
  for ((i = 0; i < n; i++)); do
    bash_payload xrun | CHIP_PET_LOCK=$mode bash "$PET" event pre_tool_use &
  done
  wait
  after=$(get tools)
  [[ $after == $((before + n)) ]] && ok "lock ($mode): $n simultaneous events, none lost" ||
    ng "lock ($mode): $n simultaneous events" "tools $before -> $after, want $((before + n))"
done
[[ ! -e $CHIP_PET_HOME/.lock.d ]] && ok "lock: no stale lock directory left behind" || ng "lock: stale lock directory left behind"

# --- user input is data -----------------------------------------------------
bash "$PET" rename $'Evil\nname=$(touch pwned)\t' > /dev/null
name=$(get name)
lines_ok=1
while IFS= read -r line; do
  [[ $line =~ ^[a-z_]+= ]] || lines_ok=
done < "$CHIP_PET_HOME/state"
[[ ! -e pwned && -n $lines_ok && $name == 'Evilname$(touch pwned)' ]] &&
  ok "rename: control characters and '=' stripped, nothing executed" ||
  ng "rename: sanitising" "name=[$name] pwned=$([[ -e pwned ]] && echo yes) lines_ok=$lines_ok"

bash "$PET" adopt dragon > /dev/null 2>&1 && ng "adopt: unknown species is refused" || ok "adopt: unknown species is refused"
bash "$PET" adopt owl Hoot > /dev/null
[[ $(get species) == owl && $(get name) == Hoot && $(get tools) -gt 0 ]] && ok "adopt: switches species, keeps the stats" || ng "adopt: switches species"

# --- rendering ---------------------------------------------------------------
card=$(bash "$PET" card 2>&1)
rc=$?
esc=$'\e'
maxw=0
while IFS= read -r line; do
  ((${#line} > maxw)) && maxw=${#line}
done <<< "$card"
[[ $rc == 0 && $card == *Hoot* && $card != *"$esc"* && $maxw -le 60 ]] &&
  ok "card: plain text when piped (no escape codes), at most 60 columns" || ng "card" "rc=$rc maxw=$maxw"

bad=
for sp in chip cat owl ghost bot frog; do
  bash "$PET" adopt "$sp" > /dev/null
  out=$(bash "$PET" demo --once 2>&1)
  rc=$?
  frames=$(grep -c '^=== ' <<< "$out")
  [[ $rc == 0 && $frames == 24 && $out != *"unbound"* && $out != *"syntax error"* ]] || bad+="[$sp rc=$rc frames=$frames] "
done
[[ -z $bad ]] && ok "demo: all 24 moods render for all 6 species" || ng "demo: all moods render" "$bad"

out=$(CHIP_PET_ASCII=1 bash "$PET" demo --once 2>&1)
[[ $(LC_ALL=C grep -c $'[\x80-\xff]' <<< "$out") == 0 ]] && ok "CHIP_PET_ASCII=1: pure ASCII output" || ng "CHIP_PET_ASCII=1: pure ASCII output"

out=$(bash "$PET" slash pet 2>&1)
rc=$?
[[ $rc == 0 && $out == *"Lv "* ]] && ok "/pet: 'slash pet' pets and prints the card" || ng "/pet: slash pet" "rc=$rc"
bash "$PET" slash bogus > /dev/null 2>&1 && ng "/pet: unknown argument is refused" || ok "/pet: unknown argument is refused"

if [[ -n $PY ]]; then
  out=$(CHIP_PET_LANG=zh-TW bash "$PET" demo --once 2>&1)
  # Every speech-bubble line must be exactly as wide as its border.
  verdict=$(printf '%s' "$out" | "$PY" -I -c '
import sys, unicodedata
def w(s): return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
bad = 0
lines = sys.stdin.buffer.read().decode("utf-8").splitlines()
for i, l in enumerate(lines):
    if l.startswith(" ."):
        width = w(l)
        j = i + 1
        while j < len(lines) and lines[j].startswith("( "):
            if w(lines[j]) != width: bad += 1
            j += 1
print("ok" if bad == 0 else "bad %d" % bad)')
  [[ $verdict == ok ]] && ok "zh-TW: CJK speech bubbles are aligned (display width, not bytes)" || ng "zh-TW bubble alignment" "$verdict"
else
  echo "SKIP  zh-TW bubble alignment (no python3)"
fi

out=$(timeout 3 bash "$PET" watch < /dev/null 2> /dev/null)
rc=$?
[[ $rc == 124 && $out == *"Lv "* && $out == *$'\e[H'* ]] && ok "watch: draws frames until stopped (rc=124 from timeout)" || ng "watch" "rc=$rc"

# --- plugin manifests ---------------------------------------------------------
toml=$here/plugins/chip-pet/hooks/hooks.toml
if [[ -n $PY ]]; then
  verdict=$("$PY" -I -c '
import sys, tomllib, json, os
root = sys.argv[1]
t = tomllib.load(open(os.path.join(root, "hooks/hooks.toml"), "rb"))
allowed = {"startup","workflow_start","post_edit","post_turn","end_turn","shutdown","pre_turn","pre_tool_use","post_tool_use","pre_compact","post_compact"}
problems = []
if "post_turn_restarts" in t: problems.append("sets post_turn_restarts")
for ev, hooks in t.items():
    if ev not in allowed: problems.append("unknown event " + ev); continue
    for h in hooks:
        if h.get("type") != "bash": problems.append(ev + " not bash")
        if h.get("blocking") or h.get("enable_restarts"): problems.append(ev + " can block")
        if "${CHIPAGENTS_PLUGIN_ROOT}/bin/chip-pet" not in h.get("command", ""): problems.append(ev + " command")
j = json.load(open(os.path.join(root, "hooks/hooks.json")))
for ev, groups in j["hooks"].items():
    for g in groups:
        for h in g["hooks"]:
            if "${CLAUDE_PLUGIN_ROOT}/bin/chip-pet" not in h["command"]: problems.append("json " + ev)
for f in (".claude-plugin/plugin.json", ".chipagents-plugin/plugin.json"):
    json.load(open(os.path.join(root, f)))
json.load(open(os.path.join(root, "../../.claude-plugin/marketplace.json")))
print("ok %d events" % len(t) if not problems else "; ".join(problems))' "$here/plugins/chip-pet")
  [[ $verdict == ok* ]] && ok "manifests: hooks.toml ($verdict) never blocks, no post_turn_restarts; JSON files parse" ||
    ng "manifests" "$verdict"
else
  echo "SKIP  manifest parsing (no python3 with tomllib)"
fi

echo
echo "$passed passed, $failed failed"
[[ $failed == 0 ]]
