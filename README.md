# ⚔️ Grey Knight Neovim

A curated, agentic Neovim IDE built for security researchers and developers who run local LLMs.

**38 plugins • Cyberdream theme • AI agent (Qwen Code) • Bash + Python dev suite • Zero cloud dependencies**

![Stack](https://img.shields.io/badge/Neovim-0.12%2B-57A143?logo=neovim)
![Theme](https://img.shields.io/badge/Theme-Cyberdream-ff00ff)
![AI](https://img.shields.io/badge/AI-Qwen%20Code%20(local%20LLM)-00d4ff)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **AI-powered coding** — Qwen Code or OpenCode agent (`GREYKNIGHT_AGENT`; agentic mode: read files, edit code, run commands)
- **Bash + Python dev suite** — one-key runs as tasks (overseer.nvim): files, project scripts, selections,
  `# %%` cells and pytest, side by side, in a real terminal (`input()`/`read`/`sudo` work); errors marked in
  the code; debugging for Python and bash (F5, breakpoints, inline values); IPython/bash REPL; a failed
  run goes to the AI agent with one key
- **Java and Angular, the IntelliJ way** — jdtls with the project's JDK and IntelliJ's Maven settings, TestNG /
  JUnit and debugging (also IntelliJ's remote debug configurations); angularls, ESLint, AngularJS through ts_ls;
  saving and reformatting as IntelliJ's settings say ([G3-DEVELOPMENT.md](G3-DEVELOPMENT.md): the guide for G3)
- **Local LLM** — Qwen Code points at any OpenAI-compatible endpoint (llama.cpp, Ollama, vLLM)
- **Rust-powered completion** — blink.cmp with ghost text and signature help
- **Snacks.nvim** — Replaces Telescope, neo-tree, indent-blankline, and notifications
- **Hacker tools** — Hex editor, multiple terminals, send-to-terminal workflow
- **Session persistence** — Auto-saves per project + git branch
- **2026 plugin stack** — Flash, Harpoon v2, Oil, mini.surround/ai, grug-far, Trouble v3

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
| **Qwen Code** or **OpenCode** | Yes | The coding agent (Qwen Code needs Node 22+; `GREYKNIGHT_AGENT=opencode` picks OpenCode) |
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

GreyNight runs on Windows 11 as well, without admin rights:

- Neovim 0.12+, ripgrep, fd, lazygit and the tree-sitter CLI as portable binaries on the `PATH`, and
  MinGW-w64 gcc (WinLibs) for the parsers: GreyNight sets `CC=gcc` when `CC` is unset (the CLI looks
  for MSVC otherwise).
- The config as a junction: `mklink /J %LOCALAPPDATA%\nvim C:\path\to\grey-knight-nvim`.
- Python as `python` or the `py` launcher: `python3` is usually the Microsoft Store's placeholder there.
- OpenCode as the agent when Qwen Code is not installed. Behind a TLS-inspecting proxy, point
  `SSL_CERT_FILE` at its CA bundle; Mason's pip gets it as `PIP_CERT`.

Python runs, tasks, the REPL, Python debugging and error locations work; bash scripts (run, REPL,
debugging) and sudo runs are Linux only for now. Tests: `tests\run.ps1` (see Running Tests).

## LLM Configuration

The AI agent is **Qwen Code**, configured like any other Qwen Code install in
`~/.qwen/settings.json` (an OpenAI-compatible provider pointed at your local LLM):

```json
{
  "model": { "name": "llama-cpp", "baseUrl": "http://YOUR_LLM_HOST:PORT/v1" },
  "modelProviders": {
    "openai": [{ "id": "llama-cpp", "baseUrl": "http://YOUR_LLM_HOST:PORT/v1", "envKey": "QWEN_LOCAL_KEY" }]
  },
  "env": { "QWEN_LOCAL_KEY": "no-key" }
}
```

The default on this rig is `http://192.168.2.173:8000/v1` (llama.cpp). Works with any
OpenAI-compatible API: llama.cpp, Ollama (`http://localhost:11434/v1`), vLLM, LM Studio, etc.

For coding, start one of the two coding launchers on the AI Dashboard's Models page. Both have no
chat persona in the template, thinking on (effort medium), MTP and 128k context, and both passed the
same Qwen Code checks (tool calls, a bash task, a pytest bug fix; infra-scripts `tools/llm-eval`):

- **`qwen38official-q6-text-think-mtp-128k`**: the official Qwen3.8-27B weights
- **`qwen38alt-q6-text-think-mtp-128k`**: the "alternative" uncensored Qwen3.8-27B build, about 10 % faster

The chat launchers prepend a chat persona and have less context. `~/.qwen/settings.json` has a
provider for each coding launcher (`qwen38-official`, `qwen38-alternative`); both point to the rig, so
whichever launcher runs answers - `<leader>am` shows which model that is.

## Structure

```
init.lua                    entry point (+ the optional dashboard bridge)
├── lua/config/
│   ├── options.lua         vim opts, language toggles
│   ├── lazy.lua            lazy.nvim bootstrap
│   ├── keymaps.lua         all global keymaps + which-key groups
│   ├── autocmds.lua        yank highlight, cursor restore
│   ├── explorer.lua        file explorer keys: cd here (.), cd .. (<BS>, -)
│   ├── mdlinks.lua         markdown links: gd / Enter follow them (#heading, file, URL)
│   └── errorlog.lua        warnings + errors of all sessions -> ~/.local/state/nvim/greyknight.log
├── lua/plugins/
│   ├── ai.lua              toggleterm (Qwen Code agents, REPLs)
│   ├── colorscheme.lua     Cyberdream (neon cyberpunk)
│   ├── completion.lua      blink.cmp v1 (Rust-powered)
│   ├── devsuite.lua        overseer.nvim (task engine of the dev suite)
│   ├── editor.lua          flash, harpoon, oil, surround, trouble, etc.
│   ├── hacker.lua          hex editor, DAP (debugpy, bashdb, dap-ui, inline values)
│   ├── java.lua            nvim-jdtls: jdtls starts with the first Java file (lua/integrations/jdtls.lua)
│   ├── lsp.lua             LSP, Mason, Treesitter, conform
│   ├── session.lua         persisted.nvim
│   └── snacks.lua          picker, explorer, dashboard, notify
├── lua/devsuite/           bash + python dev suite (USAGE.md → Running Scripts & REPL, Debugging)
│   ├── runner.lua          what to run: file / args / sudo / project scripts / selection / cell / pytest
│   ├── tasks.lua           runs as overseer tasks: output window, args memory, watch, fix with Qwen
│   ├── errors.lua          tracebacks + bash errors -> quickfix + marks in the code
│   ├── repl.lua            IPython / python / bash REPL, bracketed paste (exec() before 3.13)
│   ├── debug.lua           Python (debugpy) + bash (bashdb) debugging, F5
│   └── util.lua            venv, #!, cells, dedent, pytest node ids
├── lua/integrations/
│   ├── agent.lua           coding agent terminals: Qwen Code or OpenCode (ask/edit prompts, own sessions)
│   ├── aidash.lua          AI Dashboard bridge: preview, up/download, notify —
│   │                       loaded only inside its Dev Environment (USAGE.md → Terminal)
│   ├── intellij.lua        IntelliJ's settings, read only: JDKs, a project's JDK and Maven, Actions on Save,
│   │                       Prettier, Remote JVM Debug configurations
│   ├── jdtls.lua           Java: jdtls with the project's JDK and IntelliJ's Maven, tests, debugging, attach
│   ├── mason.lua           Mason packages on demand: installed with the first file that needs them
│   └── web.lua             Angular / AngularJS: angularls, eslint, html and css servers
├── after/ftplugin/
│   ├── python.lua          4-space indent, col 88
│   └── markdown.lua        wrap + spellcheck
├── resources/
│   └── intellij-java-format.xml   jdtls formatter profile close to IntelliJ's default Java code style
├── CHEATSHEET.md           keybinding reference (USAGE.md: the full guide)
├── G3-DEVELOPMENT.md       G3 work next to IntelliJ: Java, ngx-his, html5 clients
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
  java       = true,   -- jdtls + java-debug + java-test, set up the way IntelliJ has the project
  angular    = true,   -- angularls + eslint + html / css servers (Angular 2+; AngularJS: ts_ls + eslint)
}
```

Java and the Angular servers install themselves (Mason) with the first file that needs them.

Adding a new language:
1. Add toggle in `vim.g.lang`
2. Add TS parsers, LSP server, formatters in `lua/plugins/lsp.lua`
3. Optionally add `after/ftplugin/<lang>.lua`

## Key Bindings

See [CHEATSHEET.md](CHEATSHEET.md) for the full reference. Highlights:

| Key | Action |
|-----|--------|
| `Space+tt` | Agent toggle (Qwen Code or OpenCode) |
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
```

On Windows, `powershell -ExecutionPolicy Bypass -File tests\run.ps1` (or `... tests\run.ps1 devsuite`)
runs each suite in a real, minimized Neovim window - a headless Neovim on Windows gets no output from
terminal jobs - and skips the bash tests.

Warnings and errors that the tests provoke go to a temp log, not to `~/.local/state/nvim/greyknight.log`.

## Optional: Terminal Coding Agents

These are standalone terminal agents that share the same local LLM:

```bash
# Qwen Code (Claude Code clone, requires Node 22+)
sudo npm install -g @qwen-code/qwen-code

# OpenCode (provider-agnostic terminal agent)
sudo npm install -g opencode-ai

# Both configured via:
# ~/.qwen/settings.json
# ~/.config/opencode/config.json
```

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
