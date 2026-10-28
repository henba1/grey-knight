# GreyKnight - The coding agent

> Qwen Code, OpenCode or Claude Code in a terminal next to the code - and in the editor: it shows you files and marks them in the tree, its edits show in your buffers to keep or revert, a window follows it, you can speak to it.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [AI Assistant (Qwen Code)](#ai-assistant-qwen-code) · [The agent in your editor](#the-agent-in-your-editor)
· [Reviewing the agent's edits](#reviewing-the-agents-edits) · [Following the agent](#following-the-agent)
· [The file tree and the agent](#the-file-tree-and-the-agent) · [Qwen Code's IDE mode](#qwen-codes-ide-mode)
· [What the agent changed](#what-the-agent-changed) · [Speech to text](#speech-to-text)
· [Done, or waiting for you](#done-or-waiting-for-you) · [The model](#the-model)

## AI Assistant (Qwen Code)

Grey Knight drives the **local Qwen Code** CLI as an agentic coding agent, running it in a
persistent terminal window inside the editor. It is fully local — Qwen3.8-27B on the rig via
llama.cpp, zero cloud. For coding, start a coding launcher on the AI Dashboard's Models page:
`qwen38official-q6-text-think-mtp-128k` (official weights) or `qwen38alt-q6-text-think-mtp-128k`
(the uncensored "alternative" build), both without a chat persona, thinking on, 128k context.
`<leader>am` shows which model the rig is running ([The model](#the-model)).

**Qwen Code, OpenCode or Claude Code.** The agent is Qwen Code by default. The environment variable
`GREYKNIGHT_AGENT=opencode` switches to OpenCode, `GREYKNIGHT_AGENT=claude` to Claude Code (`qwen` pins
Qwen Code); unset, GreyKnight takes Qwen Code where it is installed, else OpenCode, else Claude Code, so
kali and the pi keep Qwen Code without any setting. The keys, `@path` references, ask/edit and `<leader>rf`
work the same with all three. A new OpenCode agent gets its first prompt pasted once it has started;
`<leader>ac` sends `/new` there, and `<leader>am` points to `/models` (OpenCode picks its model itself).
Claude Code takes its first prompt as an argument (`claude -- <prompt>`), `<leader>ac` sends `/clear`, and
`<leader>am` points to `/model`; it is found as `$CLAUDE_BIN`, `~/.local/bin/claude` (its native installer's),
else `claude` on the `PATH`.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50 split) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal-split AI agent |
| `<leader>tv` | n | Vertical-split AI agent |
| `<leader>t1` | n | Agent #1 (its own session) |
| `<leader>t2` | n | Agent #2 (its own session) |
| `<leader>t3` | n | Agent #3 (its own session) |
| `<leader>ac` | n | Fresh conversation in the main agent (`/clear`) |
| `<leader>am` | n | Which model the rig runs right now: name and context size (several launchers share the port) |
| `<leader>aa` | n | Ask about the current file (prompts for the question) |
| `<leader>aa` | v | Ask about the selected code (prompts for the question) |
| `<leader>ae` | v | Let the agent change the selected code (prompts for the instruction) |
| `<leader>rf` | n | Send the last failed run to the agent: command, exit code, output and code locations ([When it fails](run-debug.md#when-it-fails)) |

### Using the agent

1. **Open:** `<leader>tt` (or `tf`/`th`/`tv` for float/split orientation). Default is a
   **vertical 50/50** split.
2. **Type a prompt** in the terminal and press **Enter**
3. The agent (Qwen Code) responds and, in agentic mode, can read files, edit code, and
   run commands inside your project

> **Session persistence:** the agent terminal keeps its process alive when the pane is
> hidden, so toggling with `<leader>tt` **re-attaches the same live session** instead of
> restarting it. Conversational context accumulates within one live agent.

### Context

- The agent inherits the **current working directory** and any project
  `QWEN.md` / `AGENTS.md` context files **automatically**.
- **It keeps that folder.** A running program cannot change its folder: after a `cd` - the tree's `.` on another
  project, `:cd` - a running agent still works where it started. A warning says so, the statusline shows it
  (`OpenCode - in C:\dev\tools\nvim\bin`), and `<leader>ac` starts it anew in Neovim's folder (a new conversation; your
  OpenCode launcher asks for its mode again). Agents started after the `cd` start in the new folder.
- `<leader>aa` / `<leader>ae` ask for your question / instruction, then send one prompt with
  the file as `@path` (Qwen Code reads it itself) plus the selected lines and their line
  numbers. A running agent gets it as one bracketed paste (multi-line safe); a new agent
  starts with it (`qwen -i`).
- Going to the agent window (`Ctrl+l`, a click, `<leader>tt`) puts you straight into terminal mode, as
  every terminal window does ([Terminal](windows.md#terminal)): type away. The next time you come back it is terminal
  mode again - unless the agent has exited (a key would close its window).
- **The agent's window is the agent's, as in a terminal of its own.** Every key goes to it: `Esc` (interrupt),
  `Esc Esc` (Claude Code's rewind), `Ctrl+j` (a new line - `Shift+Enter` sends it too), `Ctrl+h/k/l`, `Ctrl+←` /
  `Ctrl+→` (word by word in its prompt), `Ctrl+r`, `Ctrl+o` ... GreyKnight keeps only keys no agent uses:
  - `Alt+h/j/k/l` - to the next window (also from any other window); a click elsewhere does the same.
  - The **scrollback**: the mouse wheel, a click, `Shift+PageUp` / `Shift+PageDown` show the agent's earlier output.
    Drag or double-click to select, `Ctrl+c` or `y` copies. **Any key typed there goes to the agent and you are
    typing again**, as a terminal snaps back to the bottom - `Esc` only goes back. Vim's keys (and `Space` as the
    leader) do not work in the agent's window: `Alt+h` out first.
  - Neovim's own `Ctrl+\ Ctrl+n` still gives the scrollback from the keyboard.

  To resize it: drag its border, or `Alt+h` and `Ctrl+arrows` from the window next to it. Qwen Code's input box can
  have a vim mode of its own (`general.vimMode` in `~/.qwen/settings.json`, `/vim` toggles it): a single `Esc` there
  puts that box into its NORMAL mode, which Neovim neither sees nor changes - `i` gets back to typing.

> Tip: for multi-agent work, keep agent #1 on one task and `<leader>t2` for another.

## Sessions: several agents, past conversations

The agent's pane holds **several sessions as tabs** - a bar on top of it: `1 Claude fix the flaky test`,
`2 OpenCode …`, `+` for a new one, `☰` for the list. A click on a tab shows that session in the pane (the others keep
running), a middle click ends it. `Alt+.` / `Alt+,` go to the next / previous tab, also from inside the pane.

`<leader>as` lists every session: the running ones first (`●`), then the past ones of this project, newest first -
Claude Code's (from `~/.claude/projects`, with the title Claude Code gave them) and OpenCode's (its session list,
which comes a moment later). The preview shows the conversation.

| Key in the list | What |
|---|---|
| `Enter` | A running session: show it. A past one: **resume** it in its own agent (`claude --resume`, `opencode --session`), in the folder it worked in, as a new tab |
| `Ctrl+O` | Go on with it in **another agent** (Claude Code ↔ OpenCode ↔ Qwen Code): its conversation is written to a file and a new session of that agent is told to read it first. The conversation carries over; its tool history does not |
| `Ctrl+N` | A new session (asks which agent when more than one is installed) - `<leader>ao` from anywhere |
| `Ctrl+X`, `dd` | End a running session |
| `Ctrl+A` | All projects / this project |

`<leader>tt`, `<leader>aa`, `<leader>ae`, the tree's `@` and speech go to the session the pane shows. A new Claude
Code session gets its id from GreyKnight (`--session-id`), so its tab knows its title and the list can resume it once
it has ended. `<leader>t1` … `t3` still open agents of their own below.

## The agent in your editor

An agent started here (`<leader>tt`, `t1` ... - Qwen Code and OpenCode alike) can **work in Neovim**, not only in
its terminal. Ask it *"where is the bookmarks code?"* and it finds it and opens the file tree on it, the file
highlighted; *"show me all shell scripts"* runs a search in the tree (regex `.*\.sh$`). Its tools:

| Tool | What the agent does with it |
|------|-----------------------------|
| `show_in_file_tree` | Opens the file tree on a file or folder (the cursor on it), or runs a search there - fuzzy, regex or glob, files or folders - and reads the matches |
| `mark_in_file_tree` | Marks files and folders in the tree (their folders open) - for you to move (`m`), copy (`c`), delete (`d`) or hand back (`@`) |
| `open_file` | Shows code in your code window at a line, the lines it talks about lit up for a moment |
| `show_locations` | Lists places - search hits, usages, errors - in the quickfix list: `Enter`, `]q` / `[q` |
| `editor_state` | Reads what you have open: the file, cursor, visible lines, the selected text, unsaved changes; the file tree (its cursor, what you marked there); the review of its edits (what still waits, what you reverted) |
| `diagnostics` | Reads the errors and warnings of the language servers and linters (one file, or all open ones) |
| `find_symbol`, `goto_definition`, `find_references` | Asks the language servers running in Neovim - jdtls, pyright, ts_ls ...: precise where a text search is not (overloads, imports, libraries); `show` puts the result in front of you |
| `notify` | A message in Neovim, e.g. that a long task is done |

They show and read - none changes a file or runs anything; the agent's own tools do that, with its permissions.
The agent sees them as the MCP server **`greyknight`** (`/mcp` lists it): Neovim itself runs it
(`nvim -l lua/integrations/agent_server.lua`), no Node or Python needed. Only agents started from this Neovim get it,
in their terminal's environment - the agents' settings files stay as they are: Qwen Code reads it as its *system
defaults* (`QWEN_CODE_SYSTEM_DEFAULTS_PATH`, the lowest level: your `~/.qwen/settings.json` wins), OpenCode as inline
config (`OPENCODE_CONFIG_CONTENT`, merged with your config). Claude Code gets them as arguments of its command line:
`--mcp-config` (the `greyknight` server, next to your own servers) and `--settings` (the hooks, and the `greyknight`
tools allowed without a question each time - on top of your `~/.claude/settings.json`, whose hooks run as well); both
files are in this Neovim's temp folder and go with it. A Qwen Code started in a shell outside Neovim stays as it
is. `vim.g.greyknight_agent_link = false` (in `init.lua`) connects no agent.

A launcher that starts the agent with an environment of its own - a company's OpenCode wrapper that resets
`OPENCODE_*` for its modes - has to let two of them through when `GREYKNIGHT_AGENT_ID` is set (the agent was started
from GreyKnight): `OPENCODE_CONFIG_CONTENT` (the tools) and `OPENCODE_CONFIG_DIR` (the word when it is done). `opencode
mcp list` shows `greyknight connected` when they arrived.

## Reviewing the agent's edits

Every edit the agent makes shows **in the file's own buffer**, as in Zed or Cursor: the old lines in red above the new
ones, the new lines green, the words that changed within a line stronger, `+` / `~` / `-` in the sign column - tints
of the theme's bright red and green, so they show on true black (OLED) too. Each change waits for you to keep or revert
it: a click on **✓ Accept** / **✗ Reject** in the bar under it, or the keys:

| Key | Mode | Action |
|-----|------|--------|
| `]c` / `[c` | n | Next / previous change of the agent's (in a file with git changes too: the agent's first) |
| `<leader>ay` | n, v | Keep the change at the cursor (visual: the changes the selection touches). The cursor on no change: a file with one bar - its change; with more - the cursor goes to the nearest, the key again keeps it |
| `<leader>an` | n, v | Revert it - the buffer and the file on disk get the old lines back |
| `<leader>aY` / `<leader>aN` | n | Keep / revert all of the agent's changes in the file (a file it made, reverted: deleted) |
| `<leader>ar` | n | Every change waiting, in all files - `Enter` goes there, `Ctrl+y` keeps it, `Ctrl+x` reverts it |

The bar under each change (changes one after the other share one) names the agent that made it and the keys; in a
narrow window it wraps onto more lines rather than being cut off. A file's review compares with the file before the agent's first
edit of it: a second edit adds to the same review, and what you keep is the new base. Your own edits in the buffer
count along (typed back to the old text, that change is gone). An edit of a file with unsaved changes of yours does not
overwrite them: a warning - `:e!` takes the agent's version (and shows its review), `:w` keeps yours. An edit you
accepted in Qwen Code's diff ([IDE mode](#qwen-codes-ide-mode)) is reviewed already. The agent reads what you reverted
(`editor_state`) and is asked not to do it again unless you say so.

How: Qwen Code's hooks before and after its edit tools (`PreToolUse` / `PostToolUse` on `edit`, `write_file`,
`notebook_edit` - in the same system defaults as its other hooks) and GreyKnight's OpenCode plugin (before / after
`edit`, `write`, `patch`, `apply_patch`, and `file.edited`) - and Claude Code's hooks (on `Edit`, `MultiEdit`,
`Write`, `NotebookEdit`, in its `--settings`) - tell Neovim the file: before the edit, the file as it is
becomes what the review compares with. A file the agent changed another way (a shell command) and then edits again
compares with the project's snapshot from when the agent started ([What the agent changed](#what-the-agent-changed)).
`vim.g.greyknight_agent_review = false` (in `init.lua`) turns the review off.

Qwen Code in its *auto-edit* mode (`Shift+Tab` in its input, or `/approval-mode auto-edit`) writes right away: this
review is then where you see its edits, as with OpenCode. In *Ask permissions* it asks with a diff first.

## Following the agent

`<leader>af` makes the current window **follow the agent**: each edit opens there as it lands - the file, the cursor
on the change, its review - while your cursor stays where you are (the agent's terminal, another window). The window's
bar says `◉ follows the agent`. From the agent's terminal or the tree, `<leader>af` takes the code window next to them
(none there: a new one). The file tree, when it is open, shows the file too. `<leader>af` in that window again stops.
Without a following window, an edit of a file in no window comes as a notification (`<leader>ar` lists it).

## The file tree and the agent

- **`@` in the tree** (`<leader>e`): the marked files (`Tab` marks; none marked: the one under the cursor) go into the
  agent's prompt as `@path` - typed, not sent: go on with *"... explain these"*. Both agents read files named so.
- **The agent marks files there** (`mark_in_file_tree`): *"mark every test that uses the parser"* - then `m` / `c` /
  `d` move, copy or delete them, or `@` hands them back.
- **The agent reads the tree** (`editor_state`): its cursor and what you marked - *"refactor the files I marked"*.
- Following the agent, the tree shows each file it edits ([Following the agent](#following-the-agent)).

## Qwen Code's IDE mode

Neovim is its IDE (`/ide status`: *Connected to Neovim (GreyKnight)*):

- It gets the **files open** here (the 10 used last), the **cursor** and the **selected text** as context - select
  lines, go to the agent and ask *"what does this do?"*, no `@path` needed.
- **Each edit it proposes opens as a diff** in a tab of its own before anything is written: the file as it is now on
  the left, its change on the right - the changed lines colored, the changed words within them too.

  | Key (in the diff) | Action |
  |-------------------|--------|
  | `ga` or `:w` | Accept - Qwen Code writes the file, a buffer of it shows the new text |
  | `q` | Reject - the file stays (closing the tab is a no as well) |
  | `]c` / `[c` | Next / previous change |
  | `do` | Take one change back (that hunk stays as it is now), then accept the rest |

  The right side is a normal buffer: edit it before accepting, Qwen Code writes what you accepted. Answering in
  the agent's terminal works too, and closes the diff. Qwen Code asks before an edit only in its *Ask permissions*
  mode - `/approval-mode default`, or `"tools": { "approvalMode": "default" }` in `~/.qwen/settings.json`; in its
  default mode (`auto`) and `auto-edit` / `yolo` it writes straight away, without a diff - then
  [the review in your buffers](#reviewing-the-agents-edits) shows its edits.
- How it finds Neovim: a lock file `~/.qwen/ide/<number>.lock` that names this Neovim's server (no web server -
  Qwen Code starts `nvim -l ... agent_server.lua ide` and talks to it over stdio); it goes when Neovim quits.

OpenCode has no IDE mode: it writes its edits right away (its own permission prompt asks first when
`"permission": { "edit": "ask" }`) - they show in your buffers to keep or revert
([Reviewing the agent's edits](#reviewing-the-agents-edits)), and it has the editor tools above.

## What the agent changed

`<leader>ad`. When the first agent starts in a project (and with a new conversation,
`<leader>ac`), GreyKnight notes the project as it is: a git snapshot of its tracked files - through a copy of the index,
so your index, `HEAD` and branches stay as they are - and the names of its untracked files. `<leader>ad` lists every
file changed since (yours too), the diff in the preview:

| Key (in the list) | Action |
|-------------------|--------|
| `Enter` | The file when the agent started and now, side by side (the old side red, the new green; the right side is the file - edit it). `q` in the old side closes it |
| `Ctrl+x` / `dd` | Take it back - as it was when the agent started (asks first); a new file is deleted. Your index stays |

A file that was untracked when the agent started has no snapshot: it is listed (*untracked then*), not taken back.
Git repositories only. For the whole picture as it lands, `<leader>gv` (codediff).

## Speech to text

Speak instead of typing: `<leader>av` records what you say to the agent; press it again to stop. whisper.cpp writes
it down, you see it in a box first - right what it heard wrong - and `Enter` sends it, like *"where are the bookmarks
saved?"*. `<leader>aV` dictates at the cursor instead (in a terminal - the agent's prompt, a shell - it is typed in).
`:VoiceCancel` drops a recording. It records on the machine Neovim runs on: `pw-record`, `parecord`, `arecord`,
`ffmpeg` or `sox` on Linux, Windows' own recorder (winmm) on Windows - nothing to install. Over SSH the microphone is on
your computer, not on the server: there Windows' voice typing (`Win+H`) types into PuTTY or the terminal.

| Command / variable | What |
|--------------------|------|
| `:VoiceInstall [small\|base\|turbo]` | Downloads whisper.cpp and a model into Neovim's data folder (`whisper/`), each checked by its sha256, and transcribes whisper.cpp's sample once to check it. `small` (190 MB, the default) understands German and English well and is quick on a CPU; `base` (60 MB) is quicker; `turbo` (large-v3-turbo, 574 MB) the best, slower |
| `GREYKNIGHT_STT_LANG` | The language, e.g. `de` (default: whisper finds it out) |
| `GREYKNIGHT_STT_URL` | Transcribe on a server instead - any OpenAI-compatible one (`.../v1`), e.g. speaches on the rig. Set it by hand in your shell's profile, on the machine that may talk to that server; it is in no file of GreyKnight's. `GREYKNIGHT_STT_KEY` (sent as a header, in no command line) and `GREYKNIGHT_STT_MODEL` if it needs them |
| `GREYKNIGHT_WHISPER`, `GREYKNIGHT_WHISPER_MODEL` | A whisper.cpp (`whisper-cli`) and model of your own |

## Done, or waiting for you

An agent you are not looking at says so: *"Qwen Code is done"* when it finished
answering, *"... waits for your answer"* (a warning) when it asks permission - not while its window is the current
one, nor while you look at the diff it asks about. Qwen Code tells it through two hooks (`Stop`, `PermissionRequest`)
in the same system defaults - your own hooks run as well; OpenCode through a plugin GreyKnight puts into a config
folder of its own (`OPENCODE_CONFIG_DIR`, added to yours; when you set that variable yourself, none).

---

## The model

The agent is **Qwen Code**, configured like any other Qwen Code install in `~/.qwen/settings.json` (an
OpenAI-compatible provider pointed at your local LLM):

```json
{
  "model": { "name": "llama-cpp", "baseUrl": "http://YOUR_LLM_HOST:PORT/v1" },
  "modelProviders": {
    "openai": [{ "id": "llama-cpp", "baseUrl": "http://YOUR_LLM_HOST:PORT/v1", "envKey": "QWEN_LOCAL_KEY" }]
  },
  "env": { "QWEN_LOCAL_KEY": "no-key" }
}
```

The default on this rig is `http://192.168.2.173:8000/v1` (llama.cpp). Works with any OpenAI-compatible API:
llama.cpp, Ollama (`http://localhost:11434/v1`), vLLM, LM Studio, etc. OpenCode picks its model itself (`/models` in
the agent).

**OpenCode with the local model** (`GREYKNIGHT_AGENT=opencode`; kali has it since 2026-10-23): a provider for the
llama.cpp server in `~/.config/opencode/opencode.json`. `small_model` keeps the session titles on it too - else OpenCode
asks a cloud model (gpt-5-nano on its Zen) for them - and `enabled_providers` lets no other provider in:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "rig": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Rig (llama.cpp, local)",
      "options": { "baseURL": "http://YOUR_LLM_HOST:PORT/v1", "apiKey": "local", "timeout": 600000 },
      "models": {
        "qwen38-official": { "name": "Qwen3.8-27B official", "tool_call": true, "reasoning": true,
                             "limit": { "context": 131072, "output": 32768 } }
      }
    }
  },
  "enabled_providers": ["rig"],
  "model": "rig/qwen38-official",
  "small_model": "rig/qwen38-official"
}
```

`opencode models` lists what it offers. An OpenCode from before 1.0 had `"provider": { "type": "openai", ... }` - 1.x
does not start with that ("Expected ProviderConfig").

For coding, start one of the two coding launchers on the AI Dashboard's Models page. Both have no chat persona in
the template, thinking on (effort medium), MTP and 128k context, and both passed the same Qwen Code checks (tool calls,
a bash task, a pytest bug fix; infra-scripts `tools/llm-eval`):

- **`qwen38official-q6-text-think-mtp-128k`**: the official Qwen3.8-27B weights
- **`qwen38alt-q6-text-think-mtp-128k`**: the "alternative" uncensored Qwen3.8-27B build, about 10 % faster

The chat launchers prepend a chat persona and have less context. `~/.qwen/settings.json` has a provider for each coding
launcher (`qwen38-official`, `qwen38-alternative`); both point to the rig, so whichever launcher runs answers -
`<leader>am` shows which model that is.