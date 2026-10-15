#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Grey Knight Neovim — Installer                             ║
# ║  Agentic coding setup with local LLM support                ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"

echo ""
echo "  ██████╗ ██████╗ ███████╗██╗   ██╗    ██╗  ██╗███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗"
echo " ██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝    ██║ ██╔╝████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝"
echo " ██║  ███╗██████╔╝█████╗   ╚████╔╝     █████╔╝ ██╔██╗ ██║██║██║  ███╗███████║   ██║   "
echo " ██║   ██║██╔══██╗██╔══╝    ╚██╔╝      ██╔═██╗ ██║╚██╗██║██║██║   ██║██╔══██║   ██║   "
echo " ╚██████╔╝██║  ██║███████╗   ██║       ██║  ██╗██║ ╚████║██║╚██████╔╝██║  ██║   ██║   "
echo "  ╚═════╝ ╚═╝  ╚═╝╚══════╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝"
echo ""
echo "  Agentic Neovim IDE — Installer"
echo ""

# ── Pre-flight checks ───────────────────────────────────────
info "Checking prerequisites..."

command -v git >/dev/null   || fail "git is required"
command -v curl >/dev/null  || fail "curl is required"
command -v gcc >/dev/null   || fail "gcc is required (for treesitter parser compilation)"
command -v make >/dev/null  || fail "make is required"

# Neovim version check
if command -v nvim >/dev/null; then
  NVIM_VER=$(nvim --version | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+')
  NVIM_MAJOR=$(echo "$NVIM_VER" | cut -d. -f1)
  NVIM_MINOR=$(echo "$NVIM_VER" | cut -d. -f2)
  if [[ "$NVIM_MAJOR" -lt 1 && "$NVIM_MINOR" -lt 12 ]]; then
    fail "Neovim 0.12+ required (found $NVIM_VER). Install from: https://github.com/neovim/neovim-releases/releases"
  fi
  ok "Neovim $(nvim --version | head -1 | grep -oP 'NVIM \K.*')"
else
  fail "Neovim not found. Install 0.12+ from: https://github.com/neovim/neovim-releases/releases"
fi

# ── Backup existing config ──────────────────────────────────
if [ -d "$NVIM_CONFIG" ]; then
  BACKUP="${NVIM_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
  warn "Existing nvim config found. Backing up to $BACKUP"
  cp -r "$NVIM_CONFIG" "$BACKUP"
fi

# ── Install Rust/Cargo (needed for avante + tree-sitter-cli) ─
if ! command -v cargo >/dev/null; then
  info "Installing Rust toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  ok "Rust $(cargo --version)"
else
  source "$HOME/.cargo/env" 2>/dev/null || true
  ok "Rust already installed ($(cargo --version))"
fi

# ── Install tree-sitter CLI ─────────────────────────────────
if ! command -v tree-sitter >/dev/null; then
  info "Installing tree-sitter CLI (needed for parser compilation)..."
  cargo install tree-sitter-cli
  ok "tree-sitter $(tree-sitter --version 2>/dev/null || echo 'installed')"
else
  ok "tree-sitter CLI already installed"
fi

# ── Install system tools (if sudo available) ────────────────
install_if_missing() {
  local cmd="$1" pkg="${2:-$1}"
  if ! command -v "$cmd" >/dev/null; then
    if command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
      info "Installing $pkg..."
      sudo apt-get install -y "$pkg" >/dev/null 2>&1 && ok "$pkg installed" || warn "Failed to install $pkg (install manually)"
    else
      warn "$cmd not found. Install manually: sudo apt install $pkg"
    fi
  else
    ok "$cmd found"
  fi
}

install_if_missing rg ripgrep
install_if_missing lazygit lazygit

# fd is named fdfind on Debian/Kali
if ! command -v fd >/dev/null; then
  install_if_missing fdfind fd-find
  if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
    mkdir -p ~/.local/bin
    ln -sf "$(which fdfind)" ~/.local/bin/fd
    ok "Symlinked fdfind → fd"
  fi
else
  ok "fd found"
fi

# ── Deploy nvim config ──────────────────────────────────────
info "Deploying Grey Knight config..."
mkdir -p "$NVIM_CONFIG"

# Copy config files
cp "$SCRIPT_DIR/init.lua" "$NVIM_CONFIG/"
cp -r "$SCRIPT_DIR/lua" "$NVIM_CONFIG/"
cp -r "$SCRIPT_DIR/after" "$NVIM_CONFIG/"
cp "$SCRIPT_DIR/CHEATSHEET.md" "$NVIM_CONFIG/"
cp "$SCRIPT_DIR/README.md" "$NVIM_CONFIG/" 2>/dev/null || true

ok "Config deployed to $NVIM_CONFIG"

# ── Install plugins ─────────────────────────────────────────
info "Installing plugins (this may take a minute)..."
nvim --headless "+Lazy! install" +qa 2>&1 | tail -3

# ── Install Qwen Code (the AI agent) ────────────────────────
if command -v qwen >/dev/null; then
  ok "Qwen Code $(qwen --version 2>/dev/null | head -1 || echo 'installed')"
elif command -v npm >/dev/null; then
  info "Installing Qwen Code (AI agent)..."
  npm install -g @qwen-code/qwen-code >/dev/null 2>&1 && ok "Qwen Code installed" \
    || warn "Qwen Code install failed (install manually: npm install -g @qwen-code/qwen-code)"
else
  warn "npm not found. Install Qwen Code manually: npm install -g @qwen-code/qwen-code"
fi

# ── Install treesitter parsers ──────────────────────────────
info "Compiling treesitter parsers..."
nvim --headless -c "lua vim.defer_fn(function() vim.cmd('TSInstall! markdown markdown_inline python bash lua vim vimdoc query c cpp typescript javascript tsx json html css regex diff') end, 2000)" -c "sleep 120" -c "qa!" 2>&1 | grep "Installed" | tail -3
ok "Treesitter parsers compiled"

# ── Configure LLM endpoint ──────────────────────────────────
echo ""
info "LLM Configuration"
echo "  The AI agent is Qwen Code. Configure it like any other Qwen Code"
echo "  install in: $HOME/.qwen/settings.json"
echo "  Point the OpenAI-compatible provider at your local LLM endpoint."
echo "  The default on this rig is http://192.168.2.173:8000/v1 (llama.cpp)."
echo ""

# ── Shell aliases (optional) ────────────────────────────────
if ! grep -q "GREY_KNIGHT" ~/.bashrc 2>/dev/null; then
  read -p "  Add shell aliases to ~/.bashrc? (v=nvim, lg=lazygit, etc.) [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    cat >> ~/.bashrc << 'ALIASES'

# ── GREY KNIGHT aliases ──
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
alias v='nvim'
alias vi='nvim'
alias lg='lazygit'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline -20'
alias cheat='nvim ~/.config/nvim/CHEATSHEET.md'
ALIASES
    ok "Aliases added to ~/.bashrc"
  fi
fi

# ── Done ────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Grey Knight installed successfully!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  Launch:     nvim"
echo "  Cheatsheet: nvim ~/.config/nvim/CHEATSHEET.md"
echo "  AI agent:   Space+tt (Qwen Code; requires the local LLM running)"
echo "  Run/debug:  F6 run file, F5 debug, Space+rp project scripts, Space+rL task list"
echo "  Run tests:  nvim --headless -c 'luafile tests/smoke_test.lua' -c 'qa!'"
echo ""
echo "  For full keybinding reference, see CHEATSHEET.md"
echo ""
