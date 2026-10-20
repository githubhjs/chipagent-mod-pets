# chipagent-mod-pets: a pet for ChipAgents

English | [繁體中文](README.zh-TW.md)

An ASCII pet that watches ChipAgents work. It stares at a scrolling waveform
while `xrun` runs, hunts latches during lint, cheers at `UVM_ERROR : 0`,
panics at `%Error`, and falls asleep when you leave. It costs **zero tokens**:
the agent never sees it.

```
Dippy the chip · Lv 1 · baby
 .-----------------------------------------.
( Simulating... time moves faster in there )
( than out here.                           )
 '-----------------------------------------'
     \
  .n.n.n.n.   clk |‾|_|‾|_|‾|_|‾
 =|O    O|=   dat __/‾\_____/‾‾‾
 =|  o   |=
  'u'u'u'u'   @ 50 ns

[#         ] 34/100 xp
turns 1 · tools 32 · sims 32
✓ 0  ✗ 0 · fifo_ip
```

It is pure bash and coreutils (no jq, Python, Node or Bun), so it runs on a
stock CentOS 8 box, over SSH, in tmux.

## How it works

ChipAgents has no status line, and what a hook prints can be added to the
agent's context (measured on 0.42.3: a post_turn hook's stdout comes back in
the next transcript). A pet that printed ASCII art from a hook would spend
tokens and distract the model. So the pet is split in two:

```
ChipAgents ──hooks──> chip-pet event <name>  ──> ~/.chipagents/pet/state
                     (prints nothing, exit 0)            │
tmux pane / 2nd terminal:  chip-pet watch  <── reads ────┘  (4 frames/s)
```

- **Hooks** (`hooks/hooks.toml`) run `chip-pet event` on `startup`, `pre_turn`,
  `pre_tool_use`, `post_tool_use`, `post_compact`, `post_turn`, `end_turn` and
  `shutdown`. It reads the JSON payload, updates a small state file under a
  lock, prints nothing and always exits 0, even on a bug. None of these hooks
  can block or rerun the agent, and `post_turn_restarts` is deliberately not
  set (the first value found while loading wins, so a plugin value could
  replace your budget).
- **The viewer** (`chip-pet watch`) animates the pet from that file. Run it in
  a tmux side pane or a second terminal.
- **`/pet`** shows the pet in the conversation on request (this one does cost
  a few hundred tokens, only when you ask).

## What it reacts to

| ChipAgents does | The pet |
|---|---|
| starts | waves hello |
| thinks (`pre_turn`, `post_turn`, after a tool returns) | thought bubble |
| runs `xrun`, `vcs`, `simv`, `vsim`, `verilator`, `iverilog`, `make sim`, ... | watches a scrolling clk/data waveform, sim time counting |
| runs `slang`, `verible`, `spyglass`, `verilator --lint-only` | scans an `always_ff` line for latches |
| runs `dc_shell`, `genus`, `yosys`, `vivado` | turns gears |
| runs `jg`, `vcf`, `sby` | proves things |
| runs `verdi`, `simvision`, `gtkwave`, or uses queryWaveform | zooms into waves |
| runs `git` or `git-flock-commit` | grows a commit chain |
| edits / reads files, starts a subagent | types / holds a magnifier / waits for the report |
| output says `UVM_ERROR : 0`, `TEST PASSED`, `N passed` | **PASS!** and a snack (+10 xp) |
| output says `UVM_ERROR : 3`, `Error-[`, `%Error`, `*E,`, `Segmentation fault` | panics: "read the 1st error" |
| compacts the context | gets dizzy |
| finishes the turn (`end_turn`) | celebrates, and rings the terminal bell with `CHIP_PET_BELL=1` |
| a read-only reviewer runs ([review-gate](https://github.com/githubhjs/chipagents-loop-kit), `chip-swarm investigate`) | shows "reviewer", earns nothing |
| nothing for 10 minutes | sleeps |
| no pass and no food for 8 hours | gets hungry (press `f`) |

Pass and fail come from patterns in a shell command's output (its first and
last 64 KB), so they are heuristics; set `CHIP_PET_PASS_RE` and
`CHIP_PET_FAIL_RE` (bash ERE) for your own log format. Reading a failing log
with a Read tool does not count, only commands do.

The pet starts as an egg and hatches at 20 xp, then grows from baby to teen
(Lv 3) to adult (Lv 6). XP: +1 per tool call, +2 per agent turn, +5 per
finished turn, +10 per passing run. A chip-swarm race with three teams earns
three times as fast.

Six species, all original art (`chip-pet adopt` lists them):

```
  .n.n.n.n.     /\_/\         /\___/\        .---.           *           _   _
 =|o    o|=    ( o o )       ( (o)(o) )     / o o \        .-|-.        (o)_(o)
 =|  _   |=    =\ _ /=        \  _  /       |  _  |       [ o_o ]      (   _   )
  'u'u'u'u'     (___)~         ^^ ^^        ^v^v^v^        '-^-'        ^^   ^^
  chip          cat           owl           ghost         bot           frog
```

## Install

ChipAgents, with the same binary that runs your sessions (on our machines an
older `chipagents` earlier on `PATH` installed plugins without registering
their hooks; check `chipagents --version`):

```bash
chipagents plugin marketplace add githubhjs/chipagent-mod-pets --type claude
chipagents plugin install chip-pet@chip-pets
```

Restart ChipAgents (or `/reload`) once, so the `startup` hook runs and records
where the plugin lives. After a `git pull` of the marketplace, use
`chipagents plugin update chip-pet@chip-pets`; `install` does nothing for an
installed plugin.

Put `chip-pet` on your `PATH` for the viewer, from a clone:

```bash
git clone https://github.com/githubhjs/chipagent-mod-pets.git ~/chipagent-mod-pets
ln -s ~/chipagent-mod-pets/bin/chip-pet ~/bin/chip-pet
```

If you copy the files through a VM share or a zip, the execute bits may be
lost. Everything here is started as `bash <file>`, so that does not matter,
except for the symlinked command: `chmod +x bin/chip-pet plugins/chip-pet/bin/chip-pet`.

Claude Code works too (`claude plugin marketplace add githubhjs/chipagent-mod-pets`,
then `claude plugin install chip-pet@chip-pets`): it uses `hooks/hooks.json`
with the same events.

## Watch it

Inside tmux:

```bash
chip-pet tmux            # opens a 40-column pane on the right
```

or let ChipAgents open it at start-up: `export CHIP_PET_TMUX=1` before
starting ChipAgents inside tmux. It opens at most one pet pane per window.

Without tmux, any second terminal works:

```bash
chip-pet watch
xterm -geometry 44x18 -e chip-pet watch &
```

Keys in the viewer: `p` pet, `f` feed, `q` quit. Preview every animation
without ChipAgents: `chip-pet demo`.

In the conversation:

| Command | Effect |
|---|---|
| `/pet` | shows the pet and its stats |
| `/pet pet`, `/pet feed` | pets or feeds it |
| `/pet name Mochi` | renames it |
| `/pet adopt owl` | switches species, keeping xp and stats |

## Settings

| Variable | Default | Effect |
|---|---|---|
| `CHIP_PET_LANG` | from `LANG` | `zh-TW` for Traditional Chinese messages |
| `CHIP_PET_BELL` | off | `1`: terminal bell when a turn ends (tmux shows it on the window) |
| `CHIP_PET_TMUX` | off | `1`: open the viewer pane when ChipAgents starts inside tmux |
| `CHIP_PET_PANE_WIDTH` | 40 | width of that pane |
| `CHIP_PET_FPS` | 4 | frames per second |
| `CHIP_PET_SLEEP_AFTER` | 600 | seconds of quiet before it sleeps |
| `CHIP_PET_HUNGRY_AFTER` | 28800 | seconds without a pass or food before it is hungry |
| `CHIP_PET_TOOL_TIMEOUT` | 1800 | how long a tool pose (a long sim) is kept without news |
| `CHIP_PET_ASCII` | off | `1`: ASCII only, for terminals without UTF-8 |
| `NO_COLOR` | unset | no colours |
| `CHIP_PET_OFF` | unset | `1`: the hooks do nothing (for batch runs) |
| `CHIP_PET_HOME` | `~/.chipagents/pet` | state directory (`$CHIPAGENTS_HOME/pet` when that is set) |
| `CHIP_PET_PASS_RE`, `CHIP_PET_FAIL_RE` | see `bin/chip-pet` | pass/fail patterns |

## Measured and not measured

Tested by `bash tests/selftest.sh` (32 checks, Windows Git Bash; it needs no
ChipAgents): classification of 21 tool calls, pass/fail on VCS, Verilator,
Xcelium and UVM output, a failure at the end of a 6 MB payload, silence and
exit 0 on every path (garbage input, no input, an unwritable state directory),
30 simultaneous events with no lost update (mkdir lock; the flock path runs
where `flock` exists), sanitised names, every mood for every species, the
viewer loop, and the manifests (hooks.toml events, nothing blocking, no
`post_turn_restarts`).

**Not yet run inside a real ChipAgents session.** What has to be confirmed
there, in order of importance:

1. `chipagents validate` accepts the hooks file. `add_to_context` and
   `hide_from_ui` are only set on the events the docs list them for.
2. Which events fire in your mode. `pre_tool_use` was measured to fire in
   normal mode on 0.42.3; `pre_turn`, `post_tool_use` and `post_compact` are
   documented as client-agent events. If one does not fire, the pet simply
   shows less (no pass/fail without `post_tool_use`).
3. Whether the `end_turn` and `shutdown` hooks flash a progress line in the
   UI (the docs do not list `hide_from_ui` for them).
4. The `/pet` command: `$ARGUMENTS` substitution and the `plugin_root` file
   written by the `startup` hook.

A quick check after installing, in a scratch directory (the agent has to be
allowed to run one harmless command):

```bash
mkdir -p /tmp/pet-check && cd /tmp/pet-check
chip-pet card      # note tools, ✓ and turns
chipagents batch --skip-permissions --name pet-check \
  --prompt "Run the shell command: echo TEST PASSED"
chip-pet card      # tools +1 proves pre_tool_use, ✓ +1 post_tool_use,
                   # turns +1 post_turn; project shows pet-check
```

## The Claude Code pets, and why none is ported as is

Searched on 2026-10-20 (Claude plugin marketplaces and GitHub):

| Plugin | ★ | How it shows the pet | In ChipAgents |
|---|---|---|---|
| [ramarivera/coding-buddy](https://github.com/ramarivera/coding-buddy) | 464 | MCP server + status line + hooks.json (restores Claude Code's removed `/buddy`) | ChipAgents does load `mcpServers`, so its MCP tools could work, but they need Bun plus npm packages (`@modelcontextprotocol/sdk`, `node-pty`, ...) on the box, the identity comes from `~/.claude.json`, and the status line and hooks.json are not supported. Its species art reproduces Claude Code's own. |
| [Ido-Levi/claude-code-tamagotchi](https://github.com/Ido-Levi/claude-code-tamagotchi) | 435 | status line + `/pet-*` commands; its "behavioral enforcement" sends transcripts to Groq | No status line; sending design transcripts to a third-party LLM is a no-go for chip IP. |
| [TeXmeijin/claude-code-mascot-statusline](https://github.com/TeXmeijin/claude-code-mascot-statusline) | 30 | Node status line driven by hooks | No status line. Its hook-driven state machine is the idea used here. |
| [vincent-k2026/codachi](https://github.com/vincent-k2026/codachi) | 14 | status line (`npx codachi init`) | No status line. |
| [ryparker/claude-code-sounds](https://github.com/ryparker/claude-code-sounds) | 15 | sound files played by hooks | A remote CentOS box has no speaker; replaced by the terminal bell (`CHIP_PET_BELL=1`), which reaches your desktop through SSH and tmux. |
| [davidurco/cc-tamagotchi](https://github.com/davidurco/cc-tamagotchi) | 0 | Claude Code mod API | Claude Code only. |

All of them are MIT. No code or art was copied; chip-pet is written from
scratch.

## Files

```
.claude-plugin/marketplace.json     marketplace "chip-pets"
plugins/chip-pet/
  .claude-plugin/plugin.json        Claude-format plugin (commands/)
  .chipagents-plugin/plugin.json    side-by-side ChipAgents hooks metadata
  hooks/hooks.toml                  ChipAgents hooks (silent, never block)
  hooks/hooks.json                  the same for Claude Code
  commands/pet.md                   /pet
  bin/chip-pet                      everything: event, watch, card, demo, ...
bin/chip-pet                        wrapper to put on PATH
tests/selftest.sh                   32 checks, no ChipAgents needed
```

## Author

Chih-Hsueh "Josh" HUANG

## License

MIT
