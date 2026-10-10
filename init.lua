-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Grey Knight Neovim — init.lua                             ║
-- ║  Modular config: lua/config/* + lua/plugins/*              ║
-- ╚══════════════════════════════════════════════════════════════╝
require("config.options")
require("config.lazy")      -- bootstrap lazy.nvim + load lua/plugins/*
require("config.keymaps")   -- after plugins are loaded
require("config.autocmds")

-- Optional: AI Dashboard bridge — only inside its Dev Environment (the session sets AIDASH_TOKEN)
if vim.env.AIDASH_TOKEN then require("integrations.aidash").setup() end
