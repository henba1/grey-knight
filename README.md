# ⚔️ Grey Knight Neovim

> **GreyKnight is the work of [Nix0](https://gitlab.com/nix02).** The original project lives at
> **[gitlab.com/nix02/grey-knight](https://gitlab.com/nix02/grey-knight)** - all credit for the editor goes there.
> This repository carries it on GitHub, with an OLED look by default and Claude Code as a third agent.

A curated, agentic Neovim IDE built for security researchers and developers who run local LLMs.

**38 plugins • OLED black (or Cyberdream's grey) • AI agent (Qwen Code, OpenCode or Claude Code) • Bash + Python dev suite • Zero cloud dependencies**

![Stack](https://img.shields.io/badge/Neovim-0.12%2B-57A143?logo=neovim)
![Theme](https://img.shields.io/badge/Theme-Cyberdream-ff00ff)
![AI](https://img.shields.io/badge/AI-Qwen%20Code%20(local%20LLM)-00d4ff)
![Claude Code](https://img.shields.io/badge/AI-Claude%20Code-D97757?logo=claude&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **OLED look** — cyberdream's neon on true black, so an OLED screen's pixels stay off;
  cyberdream's own grey is `:GreyKnightStyle greyknight` away ([the look](docs/start.md#the-look-oled-or-greyknight))

- **A coding agent that works in the editor** — Qwen Code, OpenCode or Claude Code in a terminal next to the code
  (`GREYKNIGHT_AGENT`). Asked where something is, it opens the file tree on it or marks files there; it shows code at
  a line and asks Neovim's language servers. **Its edits show in your buffers** as in Zed or Cursor - the old lines
  red, the new green - to keep or revert, each change (a click on Accept / Reject under it) or the whole file
  (`<leader>ay` / `<leader>an`, `<leader>ar`);
  a window **follows the agent** to each edit as it lands (`<leader>af`); `@` in the tree hands files to it. Qwen Code
  sees the open files and the selection, and in its ask mode each edit opens as a diff first; `<leader>ad` lists what
  the agent changed; one you are not looking at says when it is done; **several sessions as tabs** in its pane,
  past Claude Code / OpenCode sessions resumed from a list (`<leader>as`) or carried over to the other agent
  ([the coding agent](docs/agent.md))
- **Speech to text** — `<leader>av` speaks a prompt to the agent, `<leader>aV` dictates at the cursor, written down by
  whisper.cpp on your machine (`:VoiceInstall`) ([speech to text](docs/agent.md#speech-to-text))
- **Diffs as in a pull request** — codediff (VS Code's diff) reviews the changes live as they land, the old side red,
  the new green, the changed words stronger; stage or discard a hunk right there (`<leader>gv`) ([git](docs/git.md))
- **Bash + Python dev suite** — one-key runs as tasks in a real terminal (`input()`, `read`, `sudo` work), project
  scripts, cells, pytest; errors marked in the code; debugging Python and bash; an IPython / bash REPL; a failed run
  goes to the agent with one key; LaTeX builds on save with its errors in the code
  ([running and debugging](docs/run-debug.md))
- **Java and Angular, the IntelliJ way** — jdtls with the project's JDK and IntelliJ's Maven settings, TestNG / JUnit
  and debugging, angularls, ESLint; no IntelliJ needed ([G3-DEVELOPMENT.md](G3-DEVELOPMENT.md): the guide for G3)
- **A file tree that does the work** — moves and copies by the tree, searches files and folders fuzzy or by regex
  (`.*\.sh$`, `*.sh`), renames the marked by regex, runs your scripts on them (`!1` … `!9`); oil, harpoon, bookmarks
  ([files](docs/files.md))
- **IntelliJ habits** — Ctrl+Click goes to a declaration (on it: its usages), bookmarks on lines (`<leader>mm`,
  Shift+F11 lists them), the buffers in the order you used them (`<leader><Tab>`)
- **Easy mode** — `Alt+N`: file windows as in a plain text editor - always typing, Ctrl+S / Z / Y / C / X / V,
  Shift+arrows select; `Esc` is Neovim's normal mode for one command ([easy mode](docs/start.md#easy-mode))
- **Windows and terminals** — `Ctrl+H/J/K/L` between windows and terminals alike, `Ctrl+arrows` resize, a terminal
  takes your keys as soon as you go to it; sessions per project and git branch ([windows](docs/windows.md))
- **Over SSH** — copies over OSC 52, PuTTY's keys understood ([remote](docs/ssh.md))
- **Local LLM** — Qwen Code points at any OpenAI-compatible endpoint (llama.cpp, Ollama, vLLM)
  ([the model](docs/agent.md#the-model))
- **2026 plugin stack** — snacks.nvim (picker, explorer, notifications), blink.cmp, Flash, Harpoon v2, Oil,
  mini.surround/ai, grug-far, Trouble v3, codediff, Cyberdream

## Documentation

| Topic | |
|-------|-|
| [Getting started](docs/start.md) | First launch, the start screen, the modes, tips, when something goes wrong |
| [The coding agent](docs/agent.md) | The agent in the editor, Qwen Code's diffs, its changes, speech to text, the model |
| [Files](docs/files.md) | The file tree, oil, harpoon, bookmarks |
| [Windows, buffers, terminals, sessions](docs/windows.md) | Splits, resizing, buffers, terminals, sessions |
| [Finding](docs/find.md) | Pickers, search and replace, flash |
| [Code](docs/code.md) | Editing, language servers, completion, diagnostics, formatting, Java / Angular |
| [Running and debugging](docs/run-debug.md) | Tasks, the REPL, errors, debugging |
| [Git](docs/git.md) | Lazygit, codediff, gitsigns |
| [Remote](docs/ssh.md) | SSH, PuTTY, the clipboard, the dashboard's Dev Environment |
| [Testbook](docs/testbook.md) | Workflows to try by hand: what to do, what you should see |
| [G3 development](G3-DEVELOPMENT.md) | Java, ngx-his, html5 clients - with or without IntelliJ |
| [CHEATSHEET](CHEATSHEET.md) | Every key on one page |

In Neovim, `<leader>gd` opens them read-only; `gd` or `Enter` on a link follows it.

## Quick Install

```bash
git clone https://github.com/YOUR_USER/grey-knight-nvim.git
cd grey-knight-nvim
./install.sh
```

### Prerequisites

| Tool | Required | Why |
|------|----------|-----|
| **Neovim 0.12+** | Yes | Plugin compatibility |
| **git** | Yes | Plugin manager |
| **gcc** | Yes | Treesitter parser compilation |
| **curl** | Yes | Downloads |
| **Rust/cargo** | Auto-installed | tree-sitter CLI |
| **Qwen Code**, **OpenCode** or **Claude Code** | Yes | The coding agent (Qwen Code needs Node 22+; `GREYKNIGHT_AGENT=opencode` / `claude` picks the others) |
| **ripgrep** | Auto-installed | Live grep |
| **fd** | Auto-installed | File finder |
| **lazygit** | Auto-installed | Git TUI |
| **python3** (Windows: **python**) | For Python | Runs scripts; the REPL takes sent blocks as one paste from 3.13, older Pythons run them through `exec()` |
| **IPython** | Optional | Preferred Python REPL (`<leader>ri`); falls back to python |
| **pytest** | Optional | `<leader>rt` / `<leader>rT` / `<leader>dt` |
| **shellcheck** | Optional | Bash diagnostics (through bash-language-server) |
| **debugpy, bash-debug-adapter** | Auto-installed (Mason) | Python and bash debugging; the bash debugger runs on Node (Linux only) |

The install script handles Rust, tree-sitter CLI, ripgrep, fd, and lazygit automatically; Mason
installs the language servers and debuggers on the first start.

### Manual Install

```bash
# 1. Backup existing config
mv ~/.config/nvim ~/.config/nvim.bak

# 2. Copy files
mkdir -p ~/.config/nvim
cp -r init.lua lua/ after/ CHEATSHEET.md ~/.config/nvim/

# 3. Install tree-sitter CLI (Rust)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
cargo install tree-sitter-cli

# 4. Install Qwen Code (the AI agent)
sudo npm install -g @qwen-code/qwen-code

# 5. Open nvim (plugins auto-install on first launch)
nvim

# 6. Inside nvim, install treesitter parsers:
# :TSInstall markdown markdown_inline python bash lua vim vimdoc query
```

### Windows

GreyKnight runs on Windows 11 as well, without admin rights:

- Neovim 0.12+, ripgrep, fd, lazygit and the tree-sitter CLI as portable binaries on the `PATH`, and
  MinGW-w64 gcc (WinLibs) for the parsers: GreyKnight sets `CC=gcc` when `CC` is unset (the CLI looks
  for MSVC otherwise).
- The config as a junction: `mklink /J %LOCALAPPDATA%\nvim C:\path\to\grey-knight-nvim`.
- Python as `python` or the `py` launcher: `python3` is usually the Microsoft Store's placeholder there.
- OpenCode as the agent when Qwen Code is not installed. Behind a TLS-inspecting proxy, point
  `SSL_CERT_FILE` at its CA bundle; Mason's pip gets it as `PIP_CERT`.

Python runs, tasks, the REPL, Python debugging and error locations work; bash scripts (run, REPL,
debugging) and sudo runs are Linux only for now. Tests: `tests\run.ps1` (see Running Tests).

### The agent's model

Qwen Code talks to any OpenAI-compatible endpoint configured in `~/.qwen/settings.json` - the local LLM on the rig,
Ollama, vLLM: [docs/agent.md → The model](docs/agent.md#the-model).

## Structure

```
init.lua                    entry point (+ the optional dashboard bridge)
├── lua/config/
│   ├── options.lua         vim opts, language toggles
│   ├── clipboard.lua       over SSH: copy with OSC 52, paste the last copy; locally Neovim's own choice
│   ├── lazy.lua            lazy.nvim bootstrap
│   ├── keymaps.lua         all global keymaps + which-key groups
│   ├── autocmds.lua        yank highlight, cursor restore, terminal mode on the way into a terminal
│   ├── explorer.lua        file explorer keys: cd here (.), cd .. (<BS>, -), move / copy through the
│   │                       tree (m, c), typed paths as typed (r, C, a), search files / folders /
│   │                       the current view (/, D, S), by regex or glob (R, Alt+r), rename by regex (%)
│   ├── mdlinks.lua         markdown links: gd / Enter follow them (#heading, file, URL)
│   ├── slots.lua           explorer script slots: !1 … !9 and !!, the context, the scripts' dialogs
│   ├── bookmarks.lua       bookmarks: lines to come back to, per project, signs, the list (<leader>mm, <leader>ml)
│   ├── navigate.lua        Ctrl+Click as in IntelliJ: the declaration, on the declaration its usages
│   ├── switcher.lua        recent buffers in the order of use, the previous one preselected (<leader><Tab>)
│   ├── putty.lua           over SSH from PuTTY with its default keys: once a word on the settings that fix them
│   ├── gitdiff.lua         git diffs (<leader>gv, <leader>gh) - codediff (VS Code's diff) where its library is, else Diffview
│   ├── termname.lua        a terminal's name in the statusline: an agent's (and where it works), else its program
│   ├── style.lua           the look: OLED (true black) or cyberdream's grey (:GreyKnightStyle)
│   ├── winbar.lua          a bar per file window: its name, split right / below and close buttons
│   ├── easymode.lua        easy mode (Alt+N): a plain text editor's keys in file windows - always typing
│   └── errorlog.lua        warnings + errors of all sessions -> ~/.local/state/nvim/greyknight.log
├── lua/plugins/
│   ├── ai.lua              toggleterm (Qwen Code agents, REPLs)
│   ├── colorscheme.lua     Cyberdream - on true black, or its own grey (config/style.lua)
│   ├── completion.lua      blink.cmp v1 (Rust-powered)
│   ├── devsuite.lua        overseer.nvim (task engine of the dev suite)
│   ├── editor.lua          flash, harpoon, oil, surround, trouble, etc.
│   ├── hacker.lua          hex editor, DAP (debugpy, bashdb, dap-ui, inline values)
│   ├── java.lua            nvim-jdtls: jdtls starts with the first Java file (lua/integrations/jdtls.lua)
│   ├── lsp.lua             LSP, Mason, Treesitter, conform
│   ├── session.lua         persisted.nvim
│   └── snacks.lua          picker, explorer, dashboard, notify
├── lua/devsuite/           bash + python dev suite (docs/run-debug.md)
│   ├── runner.lua          what to run: file / args / sudo / project scripts / selection / cell / pytest
│   ├── tasks.lua           runs as overseer tasks: output window, args memory, watch, fix with Qwen
│   ├── errors.lua          tracebacks + bash errors -> quickfix + marks in the code
│   ├── latex.lua           latexmk: build / watch (-pvc), its errors -> quickfix + marks in the code
│   ├── repl.lua            IPython / python / bash REPL, bracketed paste (exec() before 3.13)
│   ├── debug.lua           Python (debugpy) + bash (bashdb) debugging, F5
│   └── util.lua            venv, #!, cells, dedent, pytest node ids
├── lua/integrations/
│   ├── agent.lua           coding agent terminals: Qwen Code, OpenCode or Claude Code (ask/edit prompts, own sessions)
│   ├── agent_link.lua      agents reach into this Neovim: the settings of the agents started here (Qwen Code's
│   │                       system defaults and lock file, OpenCode's inline config), the servers attached
│   ├── agent_server.lua    the MCP server agents start - Neovim runs it (nvim -l): stdio, relays to this Neovim
│   ├── agent_sessions.lua  the agent's sessions: tabs on its pane, past ones resumed or carried over (<leader>as)
│   ├── agent_tools.lua     the agent's editor tools: file tree, open at a line, quickfix, LSP, diagnostics
│   ├── agent_ide.lua       Qwen Code's IDE mode: its edits as diffs to accept / reject; open files as context
│   ├── agent_changes.lua   what changed since the agent started (<leader>ad): a git snapshot then, the files
│   │                       changed since with their diffs, a file taken back - the user's index untouched
│   ├── agent_review.lua    the agent's edits reviewed in their buffers (its hooks: before / after each edit) -
│   │                       keep or revert each change; a window following the agent; the list (<leader>ar)
│   ├── voice.lua           speech to text (<leader>av to the agent, <leader>aV at the cursor): recorded on this
│   │                       machine, whisper.cpp here (:VoiceInstall, pinned and checked) or $GREYKNIGHT_STT_URL
│   ├── aidash.lua          AI Dashboard bridge: preview, up/download, notify —
│   │                       loaded only inside its Dev Environment (docs/ssh.md)
│   ├── intellij.lua        IntelliJ's settings, read only: JDKs, a project's JDK and Maven, Actions on Save,
│   │                       Prettier, Remote JVM Debug configurations
│   ├── jdtls.lua           Java: jdtls with the project's JDK and Maven (IntelliJ's, else the machine's,
│   │                       as mvn), tests, debugging, attach
│   ├── mason.lua           Mason packages on demand: installed with the first file that needs them
│   └── web.lua             Angular / AngularJS: angularls, eslint, html and css servers
├── after/ftplugin/
│   ├── python.lua          4-space indent, col 88
│   └── markdown.lua        wrap + spellcheck
├── resources/
│   ├── intellij-java-format.xml   jdtls formatter profile close to IntelliJ's default Java code style
│   └── latex_preview.py    previews: PDFs (a LaTeX watch's, or any) and images, up to 20 on one port, changes marked
├── slots/                  explorer script slots (docs/files.md → Script slots)
│   ├── 1-info.py           slot 1: path, type, size, date, permissions of the marked items
│   └── lib/                helpers for the scripts: gk.py, gk.sh, gk.ps1
├── docs/                   the guide, a file per topic (README.md: the topics)
│   ├── start.md            first launch, start screen, modes, tips, when something goes wrong
│   ├── agent.md            the coding agent: in the editor, Qwen Code's diffs, its changes, speech to text, the model
│   ├── files.md            the file tree, oil, harpoon, bookmarks
│   ├── windows.md          windows, buffers, terminals, sessions
│   ├── find.md             pickers, search and replace, flash
│   ├── code.md             editing, language servers, completion, diagnostics, formatting, Java / Angular
│   ├── run-debug.md        running, tasks, the REPL, debugging
│   ├── git.md              lazygit, codediff, gitsigns
│   └── ssh.md              over SSH, PuTTY, the clipboard, the dashboard's Dev Environment
├── CHEATSHEET.md           every key on one page
├── G3-DEVELOPMENT.md       G3 work with or without IntelliJ: Java, ngx-his, html5 clients
└── tests/
    ├── run.sh              runs all suites; exit status 1 on failure
    ├── run.ps1             the same on Windows, each suite in a real (minimized) Neovim window
    ├── harness.lua         test(), helpers, report()
    ├── smoke_test.lua      config, plugins, parsers, tools, docs in step with the keys
    └── devsuite_test.lua   run / tasks / errors / debug / REPL / Qwen / completion, end to end
```

## Language Support

Edit `lua/config/options.lua` to toggle languages:

```lua
vim.g.lang = {
  python     = true,   -- pyright + ruff + debugpy (+ pytest, IPython)
  bash       = true,   -- bashls + shellcheck + shfmt + bashdb (debugger)
  c          = true,   -- clangd + codelldb
  typescript = true,   -- ts_ls + prettier
  lua        = true,   -- lua_ls + stylua
  java       = true,   -- jdtls + java-debug + java-test, the way IntelliJ has the project (or on its own)
  angular    = true,   -- angularls + eslint + html / css servers (Angular 2+; AngularJS: ts_ls + eslint)
}
```

Java and the Angular servers install themselves (Mason) with the first file that needs them.

Adding a new language:
1. Add toggle in `vim.g.lang`
2. Add TS parsers, LSP server, formatters in `lua/plugins/lsp.lua`
3. Optionally add `after/ftplugin/<lang>.lua`

## Key Bindings

See [CHEATSHEET.md](CHEATSHEET.md) for every key on one page, the [guide](docs/README.md) for how they work. Highlights:

| Key | Action |
|-----|--------|
| `Space+tt` | Agent toggle (Qwen Code, OpenCode or Claude Code) |
| `Space+ff` | Find files |
| `Space+fg` | Live grep |
| `Space+e` | File explorer |
| `Space+gg` | Lazygit |
| `F6` / `Space+rr` | Run file as a task (`input()` works) |
| `F5` | Debug this file (Python / bash; Java: main classes, IntelliJ's remote configs) |
| `Space+rp` | Run a project script |
| `Space+ri` | REPL (IPython / bash) |
| `Space+t1/t2/t3` | Extra Qwen agents (own sessions) |
| `Space+;` | Dashboard |
| `Space+1-4` | Harpoon quick files |
| `Space+hx` | Hex view toggle |
| `s` | Flash jump |
| `-` | Oil (filesystem as buffer) |
| `Space+sr` | Search & replace (project-wide) |
| `Space+xx` | Trouble diagnostics |

## Running Tests

```bash
# All suites, headless; exit status 1 when a test failed (about ten seconds)
tests/run.sh

# One suite: smoke (config, plugins, parsers, tools) or devsuite (run, tasks, errors, debug, REPL,
# Qwen, completion - starts python, ipython3, bash, debugpy and bashdb)
tests/run.sh smoke
tests/run.sh devsuite

# Some tests: those whose names contain one of the comma-separated pieces, or all but those
GK_TEST_ONLY='Explorer workflow,Session' tests/run.sh smoke
GK_TEST_SKIP=Debug tests/run.sh devsuite
```

On Windows, `powershell -ExecutionPolicy Bypass -File tests\run.ps1` (or `... tests\run.ps1 devsuite`)
runs each suite in a real, minimized Neovim window - a headless Neovim on Windows gets no output from
terminal jobs - and skips the bash tests. The filters work there too: `$env:GK_TEST_ONLY = 'Explorer'` first.

Warnings and errors that the tests provoke go to a temp log, not to `~/.local/state/nvim/greyknight.log`.
Nor does a test run touch the rest of your Neovim's state: its history (the ShaDa file - jumps, marks,
recent files) is neither read nor written, harpoon lists, sessions, picker history and run arguments are
not saved. Each suite runs with temp, state and cache folders of its own, deleted afterwards - what the
language servers and plugins leave there (temp folders, `lsp.log`, histories) does not pile up in yours.
When a suite ends without its report (a crash, the time limit), the runner names the test that was running.

## Optional: Terminal Coding Agents

These are standalone terminal agents that share the same local LLM:

```bash
# Qwen Code (Claude Code clone, requires Node 22+)
sudo npm install -g @qwen-code/qwen-code

# OpenCode (provider-agnostic terminal agent)
sudo npm install -g opencode-ai

# Both configured via:
# ~/.qwen/settings.json
# ~/.config/opencode/opencode.json
```

Their model: [docs/agent.md → The model](docs/agent.md#the-model).

## Credits

Built with:
- [lazy.nvim](https://github.com/folke/lazy.nvim) — plugin manager
- [Qwen Code](https://github.com/anthropics/qwen-code) — AI coding agent (local LLM)
- [snacks.nvim](https://github.com/folke/snacks.nvim) — QoL mega-plugin
- [blink.cmp](https://github.com/saghen/blink.cmp) — Rust-powered completion
- [cyberdream.nvim](https://github.com/scottmckendry/cyberdream.nvim) — colorscheme
- And 30+ more plugins (see `lua/plugins/`)

## License

MIT
