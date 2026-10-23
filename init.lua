-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Grey Knight Neovim — init.lua                             ║
-- ║  Modular config: lua/config/* + lua/plugins/*              ║
-- ╚══════════════════════════════════════════════════════════════╝
require("config.options")
require("config.lazy")      -- bootstrap lazy.nvim + load lua/plugins/*
require("config.errorlog").setup() -- warnings + errors -> ~/.local/state/nvim/greyknight.log
require("config.keymaps")   -- after plugins are loaded
require("config.autocmds")
require("config.winbar").setup() -- a bar per file window: its name, split / close buttons

-- Optional: AI Dashboard bridge — only inside its Dev Environment (the session sets AIDASH_TOKEN)
if vim.env.AIDASH_TOKEN then require("integrations.aidash").setup() end
