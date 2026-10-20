# chipagent-mod-pets:ChipAgents 的寵物

[English](README.md) | 繁體中文

一隻看著 ChipAgents 工作的 ASCII 寵物。`xrun` 在跑時它盯著捲動的波形,
lint 時它抓 latch,看到 `UVM_ERROR : 0` 會歡呼,看到 `%Error` 會慌張,
你離開太久它就睡著。**完全不花 token**:agent 根本看不到它。

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

純 bash 加 coreutils(不需要 jq、Python、Node 或 Bun),所以在原裝的
CentOS 8、SSH、tmux 裡都能跑。設 `CHIP_PET_LANG=zh-TW` 會講中文。

## 運作方式

ChipAgents 沒有 status line,而 hook 印出的東西可能被加進 agent 的
context(0.42.3 實測:post_turn hook 的 stdout 會出現在下一輪的
transcript)。從 hook 印 ASCII 圖會花 token、也會干擾模型。所以寵物分成兩半:

```
ChipAgents ──hooks──> chip-pet event <name>  ──> ~/.chipagents/pet/state
                     (什麼都不印,exit 0)               │
tmux 窗格 / 第二個終端機:  chip-pet watch  <── 讀取 ─────┘  (每秒 4 格)
```

- **Hooks**(`hooks/hooks.toml`)在 `startup`、`pre_turn`、`pre_tool_use`、
  `post_tool_use`、`post_compact`、`post_turn`、`end_turn`、`shutdown` 執行
  `chip-pet event`。它讀 JSON payload、在鎖保護下更新一個小狀態檔、什麼都不印、
  永遠 exit 0(就算程式有 bug 也一樣)。這些 hook 都不能擋下或重跑 agent,
  而且刻意不設 `post_turn_restarts`(載入時先讀到的值優先,plugin 裡的值
  可能會蓋掉你自己設的預算)。
- **檢視器**(`chip-pet watch`)依狀態檔做動畫。放在 tmux 側邊窗格或第二個
  終端機。
- **`/pet`** 在對話裡顯示寵物(這個會花幾百個 token,只在你要求時)。

## 它會對什麼有反應

| ChipAgents 在做 | 寵物 |
|---|---|
| 啟動 | 揮手打招呼 |
| 思考(`pre_turn`、`post_turn`、工具回傳之後) | 冒出思考泡泡 |
| 執行 `xrun`、`vcs`、`simv`、`vsim`、`verilator`、`iverilog`、`make sim` 等 | 盯著捲動的 clk/data 波形,模擬時間往上跳 |
| 執行 `slang`、`verible`、`spyglass`、`verilator --lint-only` | 掃一行 `always_ff` 找 latch |
| 執行 `dc_shell`、`genus`、`yosys`、`vivado` | 齒輪轉動 |
| 執行 `jg`、`vcf`、`sby` | 證明中 |
| 執行 `verdi`、`simvision`、`gtkwave`,或用 queryWaveform | 放大縮小波形 |
| 執行 `git` 或 `git-flock-commit` | commit 鏈變長 |
| 編輯/讀檔、開 subagent | 打字/拿放大鏡/等報告 |
| 輸出有 `UVM_ERROR : 0`、`TEST PASSED`、`N passed` | **PASS!** 還有點心(+10 xp) |
| 輸出有 `UVM_ERROR : 3`、`Error-[`、`%Error`、`*E,`、`Segmentation fault` | 慌張:「read the 1st error」 |
| context 被壓縮 | 頭暈 |
| 一輪結束(`end_turn`) | 慶祝;設 `CHIP_PET_BELL=1` 會響終端機鈴聲 |
| 唯讀 reviewer 在跑([review-gate](https://github.com/githubhjs/chipagents-loop-kit)、`chip-swarm investigate`) | 顯示「reviewer」,不加經驗值 |
| 10 分鐘沒動靜 | 睡著 |
| 8 小時沒有 PASS 也沒餵食 | 肚子餓(按 `f`) |

PASS/FAIL 是從 shell 指令輸出(頭尾各 64 KB)比對樣式而來,屬於推測;
可用 `CHIP_PET_PASS_RE`、`CHIP_PET_FAIL_RE`(bash ERE)配合自己的 log 格式。
用 Read 工具讀一個失敗的 log 不算,只有指令輸出才算。

寵物一開始是一顆蛋,20 xp 孵化,之後從 baby 長成 teen(Lv 3)再到
adult(Lv 6)。經驗值:每次工具呼叫 +1、每個 agent 回合 +2、每輪完成 +5、
每次通過 +10。chip-swarm 三隊競速會以三倍速成長。

六種寵物,全部原創(`chip-pet adopt` 列出):

```
  .n.n.n.n.     /\_/\         /\___/\        .---.           *           _   _
 =|o    o|=    ( o o )       ( (o)(o) )     / o o \        .-|-.        (o)_(o)
 =|  _   |=    =\ _ /=        \  _  /       |  _  |       [ o_o ]      (   _   )
  'u'u'u'u'     (___)~         ^^ ^^        ^v^v^v^        '-^-'        ^^   ^^
  chip          cat           owl           ghost         bot           frog
```

## 安裝

ChipAgents,用跑 session 的同一支執行檔(我們的機器上,PATH 前面一支較舊的
`chipagents` 裝 plugin 時不會註冊 hook;先看 `chipagents --version`):

```bash
chipagents plugin marketplace add githubhjs/chipagent-mod-pets --type claude
chipagents plugin install chip-pet@chip-pets
```

重開 ChipAgents(或 `/reload`)一次,讓 `startup` hook 執行並記下 plugin 的
位置。marketplace `git pull` 之後要用
`chipagents plugin update chip-pet@chip-pets`;對已安裝的 plugin,
`install` 什麼都不做。

檢視器要把 `chip-pet` 放進 `PATH`,從 clone 下來的目錄:

```bash
git clone https://github.com/githubhjs/chipagent-mod-pets.git ~/chipagent-mod-pets
ln -s ~/chipagent-mod-pets/bin/chip-pet ~/bin/chip-pet
```

如果檔案是經過 VM 共用資料夾或 zip 複製,執行位元可能會掉。這裡所有東西都
以 `bash <檔案>` 啟動所以不受影響,只有 symlink 的那個指令需要:
`chmod +x bin/chip-pet plugins/chip-pet/bin/chip-pet`。

Claude Code 也能用(`claude plugin marketplace add githubhjs/chipagent-mod-pets`
再 `claude plugin install chip-pet@chip-pets`):它用 `hooks/hooks.json`,
事件相同。

## 看寵物

在 tmux 裡:

```bash
chip-pet tmux            # 在右邊開一個 40 欄的窗格
```

或讓 ChipAgents 啟動時自動開:在 tmux 裡啟動 ChipAgents 之前
`export CHIP_PET_TMUX=1`。每個 window 最多開一個寵物窗格。

沒有 tmux 的話,任何第二個終端機都可以:

```bash
chip-pet watch
xterm -geometry 44x18 -e chip-pet watch &
```

檢視器按鍵:`p` 摸摸、`f` 餵食、`q` 離開。不開 ChipAgents 也能預覽所有
動畫:`chip-pet demo`。

在對話裡:

| 指令 | 效果 |
|---|---|
| `/pet` | 顯示寵物與統計 |
| `/pet pet`、`/pet feed` | 摸摸或餵食 |
| `/pet name 小晶` | 改名 |
| `/pet adopt owl` | 換物種,經驗值與統計保留 |

## 設定

| 變數 | 預設 | 作用 |
|---|---|---|
| `CHIP_PET_LANG` | 依 `LANG` | `zh-TW` 用繁體中文訊息 |
| `CHIP_PET_BELL` | 關 | `1`:每輪結束響終端機鈴聲(tmux 會在 window 上標示) |
| `CHIP_PET_TMUX` | 關 | `1`:ChipAgents 在 tmux 裡啟動時自動開檢視器窗格 |
| `CHIP_PET_PANE_WIDTH` | 40 | 該窗格寬度 |
| `CHIP_PET_FPS` | 4 | 每秒格數 |
| `CHIP_PET_SLEEP_AFTER` | 600 | 安靜幾秒後睡著 |
| `CHIP_PET_HUNGRY_AFTER` | 28800 | 幾秒沒有 PASS 或餵食會餓 |
| `CHIP_PET_TOOL_TIMEOUT` | 1800 | 沒有新消息時,工具姿勢(長時間模擬)保留多久 |
| `CHIP_PET_ASCII` | 關 | `1`:只用 ASCII,給不支援 UTF-8 的終端機 |
| `NO_COLOR` | 未設 | 不上色 |
| `CHIP_PET_OFF` | 未設 | `1`:hooks 什麼都不做(batch 執行時) |
| `CHIP_PET_HOME` | `~/.chipagents/pet` | 狀態目錄(有設 `$CHIPAGENTS_HOME` 時是 `$CHIPAGENTS_HOME/pet`) |
| `CHIP_PET_PASS_RE`、`CHIP_PET_FAIL_RE` | 見 `bin/chip-pet` | PASS/FAIL 樣式 |

## 已驗證與未驗證

`bash tests/selftest.sh`(32 項,Windows Git Bash;不需要 ChipAgents)驗證:
21 種工具呼叫的分類;VCS、Verilator、Xcelium、UVM 輸出的 PASS/FAIL;
6 MB payload 最末端的失敗也抓得到;所有路徑都不輸出且 exit 0(亂碼輸入、
沒有輸入、狀態目錄不可寫);30 個同時事件不遺失(mkdir 鎖;有 `flock`
的機器會再測 flock 路徑);名稱消毒;每個物種的每種心情都能畫;檢視器迴圈;
manifest(hooks.toml 事件、沒有會擋的 hook、沒有 `post_turn_restarts`)。

**還沒在真的 ChipAgents session 裡跑過。** 要在那裡確認的,依重要性:

1. `chipagents validate` 接受這個 hooks 檔。`add_to_context` 與
   `hide_from_ui` 只設在文件列出適用的事件上。
2. 你的模式下哪些事件會觸發。0.42.3 實測 `pre_tool_use` 在一般模式會觸發;
   `pre_turn`、`post_tool_use`、`post_compact` 文件寫的是 client-agent 事件。
   沒觸發的事件只是讓寵物少一些反應(沒有 `post_tool_use` 就沒有 PASS/FAIL)。
3. `end_turn`、`shutdown` hook 會不會在 UI 閃一行進度(文件沒列這兩個可用
   `hide_from_ui`)。
4. `/pet` 指令:`$ARGUMENTS` 替換,以及 `startup` hook 寫的 `plugin_root` 檔。

安裝後的快速檢查,在一個暫存目錄(agent 必須能執行一個無害的指令):

```bash
mkdir -p /tmp/pet-check && cd /tmp/pet-check
chip-pet card      # 記下 tools、✓、turns
chipagents batch --skip-permissions --name pet-check \
  --prompt "Run the shell command: echo TEST PASSED"
chip-pet card      # tools +1 證明 pre_tool_use,✓ +1 證明 post_tool_use,
                   # turns +1 證明 post_turn;project 顯示 pet-check
```

## Claude Code 的寵物,以及為什麼沒有一個直接移植

2026-10-20 搜尋(Claude plugin marketplace 與 GitHub):

| Plugin | ★ | 怎麼顯示寵物 | 在 ChipAgents |
|---|---|---|---|
| [ramarivera/coding-buddy](https://github.com/ramarivera/coding-buddy) | 464 | MCP server + status line + hooks.json(復活 Claude Code 拿掉的 `/buddy`) | ChipAgents 會載入 `mcpServers`,所以 MCP 工具可能能用,但機器上要有 Bun 和 npm 套件(`@modelcontextprotocol/sdk`、`node-pty` 等),身分取自 `~/.claude.json`,status line 與 hooks.json 都不支援。物種圖案是照搬 Claude Code 自己的。 |
| [Ido-Levi/claude-code-tamagotchi](https://github.com/Ido-Levi/claude-code-tamagotchi) | 435 | status line + `/pet-*` 指令;「行為監督」會把 transcript 送到 Groq | 沒有 status line;把設計 transcript 送給第三方 LLM,對晶片 IP 來說不行。 |
| [TeXmeijin/claude-code-mascot-statusline](https://github.com/TeXmeijin/claude-code-mascot-statusline) | 30 | hook 驅動的 Node status line | 沒有 status line。這裡借用的是它「hook 驅動狀態機」的概念。 |
| [vincent-k2026/codachi](https://github.com/vincent-k2026/codachi) | 14 | status line(`npx codachi init`) | 沒有 status line。 |
| [ryparker/claude-code-sounds](https://github.com/ryparker/claude-code-sounds) | 15 | hook 播放音效檔 | 遠端 CentOS 沒有喇叭;改用終端機鈴聲(`CHIP_PET_BELL=1`),會透過 SSH 與 tmux 傳到你的桌面。 |
| [davidurco/cc-tamagotchi](https://github.com/davidurco/cc-tamagotchi) | 0 | Claude Code mod API | 只有 Claude Code 有。 |

以上都是 MIT。沒有複製任何程式碼或圖案;chip-pet 是從頭寫的。

## 檔案

```
.claude-plugin/marketplace.json     marketplace "chip-pets"
plugins/chip-pet/
  .claude-plugin/plugin.json        Claude 格式 plugin(commands/)
  .chipagents-plugin/plugin.json    並列的 ChipAgents hooks metadata
  hooks/hooks.toml                  ChipAgents hooks(不輸出、不擋)
  hooks/hooks.json                  Claude Code 版
  commands/pet.md                   /pet
  bin/chip-pet                      全部功能:event、watch、card、demo...
bin/chip-pet                        放進 PATH 的 wrapper
tests/selftest.sh                   32 項檢查,不需要 ChipAgents
```

## 作者

Chih-Hsueh "Josh" HUANG

## 授權

MIT
