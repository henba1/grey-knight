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
  java       = true, -- jdtls: installed and started with the first Java file (lua/integrations/jdtls.lua)
  angular    = true, -- angularls, eslint, html, css: installed with the first file that needs them
}

-- Angular templates: htmlangular inside an Angular workspace (the angular parser, angularls); Neovim itself
-- detects them as html. AngularJS templates stay html.
if vim.g.lang.angular then
  vim.filetype.add({
    pattern = {
      [".*%.component%.html"] = function(path)
        if vim.fs.root(path, { "angular.json", "nx.json" }) then return "htmlangular" end
      end,
    },
  })
end

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
-- Diffs of Neovim's own (the agent's, :diffthis): changed lines paired up to 60 lines (linematch), the histogram
-- algorithm (a moved block stays whole), and within a changed line the changed words in a color of their own
-- (inline:char - Neovim 0.12's default too)
o.diffopt:remove("linematch:40")
o.diffopt:append({ "linematch:60", "algorithm:histogram", "inline:char", "indent-heuristic" })
o.redrawtime    = 10000
o.maxmempattern = 20000

-- Clipboard: over SSH copy with OSC 52 and paste the last copy; locally Neovim picks the tool (config/clipboard.lua)
vim.g.clipboard = require("config.clipboard").provider()

-- No plugin here talks to Neovim through Node, Perl, Ruby or Python (remote plugins): their providers are off -
-- no probing for host programs, no :checkhealth warnings about missing host packages (2026-10-21)
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

-- :Cfilter /regex/ keeps the quickfix list's entries whose file or text matches - a run's errors, Ctrl+Click's usages,
-- a grep - :Cfilter! drops them, :Lfilter does it for a location list. Neovim's own (an optional package, one Vim
-- script: loaded before lazy.nvim's runtimepath, its commands stay). Vim's regex: \v for (a|b) without backslashes.
pcall(vim.cmd.packadd, "cfilter")
