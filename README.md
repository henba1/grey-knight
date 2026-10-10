# ⚔️ Grey Knight Neovim

A curated, agentic Neovim IDE built for security researchers and developers who run local LLMs.

**37 plugins • Cyberdream theme • AI agent (Qwen Code) • Zero cloud dependencies**

![Stack](https://img.shields.io/badge/Neovim-0.12%2B-57A143?logo=neovim)
![Theme](https://img.shields.io/badge/Theme-Cyberdream-ff00ff)
![AI](https://img.shields.io/badge/AI-Qwen%20Code%20(local%20LLM)-00d4ff)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **AI-powered coding** — Qwen Code agent (agentic mode: read files, edit code, run commands)
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
| **Qwen Code** | Yes | The built-in AI agent (requires Node 22+) |
| **ripgrep** | Auto-installed | Live grep |
| **fd** | Auto-installed | File finder |
| **lazygit** | Auto-installed | Git TUI |

The install script handles Rust, tree-sitter CLI, ripgrep, fd, and lazygit automatically.

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

## Structure

```
init.lua                    entry point (+ the optional dashboard bridge)
├── lua/config/
│   ├── options.lua         vim opts, language toggles
│   ├── lazy.lua            lazy.nvim bootstrap
│   ├── keymaps.lua         all global keymaps + which-key groups
│   └── autocmds.lua        yank highlight, cursor restore
├── lua/plugins/
│   ├── ai.lua              Qwen Code agent (shell-out terminal)
│   ├── colorscheme.lua     Cyberdream (neon cyberpunk)
│   ├── completion.lua      blink.cmp v1 (Rust-powered)
│   ├── editor.lua          flash, harpoon, oil, surround, trouble, etc.
│   ├── hacker.lua          hex editor, toggleterm, DAP
│   ├── lsp.lua             LSP, Mason, Treesitter, conform
│   ├── session.lua         persisted.nvim
│   └── snacks.lua          picker, explorer, dashboard, notify
├── lua/integrations/
│   └── aidash.lua          AI Dashboard bridge: preview, up/download, notify —
│                           loaded only inside its Dev Environment (USAGE.md → Terminal)
├── after/ftplugin/
│   ├── python.lua          4-space indent, col 88
│   └── markdown.lua        wrap + spellcheck
├── CHEATSHEET.md           keybinding reference
└── tests/smoke_test.lua    automated test suite
```

## Language Support

Edit `lua/config/options.lua` to toggle languages:

```lua
vim.g.lang = {
  python     = true,   -- pyright + ruff + debugpy
  bash       = true,   -- bashls + shfmt
  c          = true,   -- clangd + codelldb
  typescript = true,   -- ts_ls + prettier
  lua        = true,   -- lua_ls + stylua
}
```

Adding a new language:
1. Add toggle in `vim.g.lang`
2. Add TS parsers, LSP server, formatters in `lua/plugins/lsp.lua`
3. Optionally add `after/ftplugin/<lang>.lua`

## Key Bindings

See [CHEATSHEET.md](CHEATSHEET.md) for the full reference. Highlights:

| Key | Action |
|-----|--------|
| `Space+at` | AI sidebar toggle |
| `Space+ff` | Find files |
| `Space+fg` | Live grep |
| `Space+e` | File explorer |
| `Space+gg` | Lazygit |
| `Space+tt` | Toggle terminal |
| `Space+t1/t2/t3` | Named terminals |
| `Space+;` | Dashboard |
| `Space+1-4` | Harpoon quick files |
| `Space+hx` | Hex view toggle |
| `s` | Flash jump |
| `-` | Oil (filesystem as buffer) |
| `Space+sr` | Search & replace (project-wide) |
| `Space+xx` | Trouble diagnostics |

## Running Tests

```bash
# Automated smoke tests (33 checks)
nvim --headless \
  -c "Lazy load flash.nvim trouble.nvim oil.nvim grug-far.nvim harpoon gitsigns.nvim render-markdown.nvim persisted.nvim conform.nvim mini.surround mini.ai" \
  -c "luafile tests/smoke_test.lua" \
  -c "qa!"
```

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
