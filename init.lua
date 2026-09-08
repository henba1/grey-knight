-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Grey Knight Neovim — init.lua                             ║
-- ║  Modular config: lua/config/* + lua/plugins/*              ║
-- ╚══════════════════════════════════════════════════════════════╝
require("config.options")
require("config.lazy")      -- bootstrap lazy.nvim + load lua/plugins/*
require("config.keymaps")   -- after plugins are loaded
require("config.autocmds")
