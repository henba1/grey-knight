-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Options                                                    ║
-- ╚══════════════════════════════════════════════════════════════╝
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ── Language toggles ──────────────────────────────────────────
vim.g.lang = {
  python     = true,
  bash       = true,
  c          = true,
  typescript = true,
  lua        = true,
}

local o = vim.opt

-- UI
o.number         = true
o.relativenumber = true
o.cursorline     = true
o.wrap           = false
o.scrolloff      = 10
o.sidescrolloff  = 10
o.signcolumn     = "yes"
o.colorcolumn    = "100"
o.showmatch      = true
o.cmdheight      = 1
o.showmode       = false
o.laststatus     = 3          -- global statusline
o.pumheight      = 10
o.pumblend       = 10
o.winblend       = 0
o.conceallevel   = 2
o.concealcursor  = ""
o.synmaxcol      = 300
o.termguicolors  = true
o.fillchars      = { eob = " " }

-- Indentation
o.tabstop     = 2
o.shiftwidth  = 2
o.softtabstop = 2
o.expandtab   = true
o.smartindent = true
o.autoindent  = true

-- Search
o.ignorecase = true
o.smartcase  = true
o.hlsearch   = true
o.incsearch  = true

-- Files / Undo
local undodir = vim.fn.expand("~/.vim/undodir")
if vim.fn.isdirectory(undodir) == 0 then vim.fn.mkdir(undodir, "p") end
o.backup      = false
o.writebackup = false
o.swapfile    = false
o.undofile    = true
o.undodir     = undodir
o.updatetime  = 300
o.timeoutlen  = 500
o.ttimeoutlen = 50
o.autoread    = true
o.autowrite   = false

-- Behaviour
o.hidden       = true
o.errorbells   = false
o.backspace    = "indent,eol,start"
o.autochdir    = false
o.iskeyword:append("-")
o.path:append("**")
o.selection    = "inclusive"
o.mouse        = "a"
o.clipboard:append("unnamedplus")
o.modifiable   = true
o.completeopt  = "menuone,noinsert,noselect"

-- Cursor
o.guicursor = "n-v-c:block,i-ci-ve:block,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

-- Folding (treesitter)
o.foldmethod = "expr"
o.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel  = 99

-- Splits
o.splitbelow = true
o.splitright = true

-- Wildmenu
o.wildmenu = true
o.wildmode = "longest:full,full"
o.diffopt:append("linematch:60")
o.redrawtime    = 10000
o.maxmempattern = 20000

-- Clipboard: OSC 52 over SSH; the local system clipboard otherwise (Wayland first, then X11)
if os.getenv("SSH_TTY") then
  vim.g.clipboard = {
    name = "OSC 52",
    copy  = { ["+"] = require("vim.ui.clipboard.osc52").copy("+"), ["*"] = require("vim.ui.clipboard.osc52").copy("*") },
    paste = { ["+"] = require("vim.ui.clipboard.osc52").paste("+"), ["*"] = require("vim.ui.clipboard.osc52").paste("*") },
  }
elseif os.getenv("WAYLAND_DISPLAY") and vim.fn.executable("wl-copy") then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy  = { ["+"] = "wl-copy", ["*"] = "wl-copy" },
    paste = { ["+"] = "wl-paste", ["*"] = "wl-paste" },
  }
elseif os.getenv("DISPLAY") and vim.fn.executable("xclip") then
  vim.g.clipboard = {
    name = "xclip",
    copy  = { ["+"] = "xclip -selection clipboard", ["*"] = "xclip -selection primary" },
    paste = { ["+"] = "xclip -selection clipboard -o", ["*"] = "xclip -selection primary -o" },
  }
end
