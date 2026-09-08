# ⚔️ Grey Knight Neovim

A curated, agentic Neovim IDE built for security researchers and developers who run local LLMs.

**38 plugins • Cyberdream theme • AI sidebar (Avante) • Zero cloud dependencies**

![Stack](https://img.shields.io/badge/Neovim-0.12%2B-57A143?logo=neovim)
![Theme](https://img.shields.io/badge/Theme-Cyberdream-ff00ff)
![AI](https://img.shields.io/badge/AI-Avante%20(local%20LLM)-00d4ff)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **AI-powered coding** — Avante.nvim sidebar with agentic mode (read files, edit code, run commands)
- **Local LLM** — Points at any OpenAI-compatible endpoint (llama.cpp, Ollama, vLLM)
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
| **Rust/cargo** | Auto-installed | Avante build + tree-sitter CLI |
| **ripgrep** | Auto-installed | Live grep |
| **fd** | Auto-installed | File finder |
| **lazygit** | Auto-installed | Git TUI |
| **Node.js 20+** | Optional | For Qwen Code / OpenCode agents |

The install script handles Rust, tree-sitter CLI, ripgrep, fd, and lazygit automatically.

### Manual Install

```bash
# 1. Backup existing config
mv ~/.config/nvim ~/.config/nvim.bak

# 2. Copy files
mkdir -p ~/.config/nvim
cp -r init.lua lua/ after/ CHEATSHEET.md ~/.config/nvim/

# 3. Install Rust + tree-sitter CLI
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
cargo install tree-sitter-cli

# 4. Open nvim (plugins auto-install on first launch)
nvim

# 5. Inside nvim, install treesitter parsers:
# :TSInstall markdown markdown_inline python bash lua vim vimdoc query
```

## LLM Configuration

Default endpoint: `http://192.168.2.173:8000/v1` (llama.cpp)

To change it, edit `lua/plugins/ai.lua`:

```lua
providers = {
  ["qwen-local"] = {
    __inherited_from = "openai",
    endpoint = "http://YOUR_LLM_HOST:PORT/v1",  -- ← change this
    model = "local-model",
    ...
  },
},
```

Works with any OpenAI-compatible API: llama.cpp, Ollama (`http://localhost:11434/v1`), vLLM, LM Studio, etc.

## Structure

```
init.lua                    4-line entry point
├── lua/config/
│   ├── options.lua         vim opts, language toggles
│   ├── lazy.lua            lazy.nvim bootstrap
│   ├── keymaps.lua         all global keymaps + which-key groups
│   └── autocmds.lua        yank highlight, cursor restore
├── lua/plugins/
│   ├── ai.lua              Avante → local LLM (agentic mode)
│   ├── colorscheme.lua     Cyberdream (neon cyberpunk)
│   ├── completion.lua      blink.cmp v1 (Rust-powered)
│   ├── editor.lua          flash, harpoon, oil, surround, trouble, etc.
│   ├── hacker.lua          hex editor, toggleterm, DAP
│   ├── lsp.lua             LSP, Mason, Treesitter, conform
│   ├── session.lua         persisted.nvim
│   └── snacks.lua          picker, explorer, dashboard, notify
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
  -c "Lazy load avante.nvim flash.nvim trouble.nvim oil.nvim grug-far.nvim harpoon gitsigns.nvim render-markdown.nvim persisted.nvim conform.nvim mini.surround mini.ai" \
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
- [avante.nvim](https://github.com/yetone/avante.nvim) — AI sidebar
- [snacks.nvim](https://github.com/folke/snacks.nvim) — QoL mega-plugin
- [blink.cmp](https://github.com/saghen/blink.cmp) — Rust-powered completion
- [cyberdream.nvim](https://github.com/scottmckendry/cyberdream.nvim) — colorscheme
- And 30+ more plugins (see `lua/plugins/`)

## License

MIT
