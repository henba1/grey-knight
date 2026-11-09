-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Grey Knight Neovim — init.lua                             ║
-- ║  Modular config: lua/config/* + lua/plugins/*              ║
-- ╚══════════════════════════════════════════════════════════════╝
require("config.settings").load() -- your settings (~/.config/greyknight.lua): before anything reads them
require("config.options")
require("config.settings").apply_options() -- your options over GreyKnight's
require("config.lazy")      -- bootstrap lazy.nvim + load lua/plugins/*
require("config.errorlog").setup() -- warnings + errors -> ~/.local/state/nvim/greyknight.log
require("config.keymaps")   -- after plugins are loaded
require("config.autocmds")
require("config.winbar").setup() -- a bar per file window: its name, split / close buttons
require("config.separators").setup() -- the borders between windows: a line, lit under the mouse (drag to resize)
require("integrations.agent_sessions").setup() -- the agent's sessions: the pane's tabs, <leader>as
require("integrations.scrubjay").setup() -- with scrubjay: every machine's and agent's sessions in that list, <leader>aS
require("config.easymode").setup() -- Alt+N: a plain text editor's keys in file windows (this session)
require("config.terminal").setup() -- Alt+T: a shell in the agent's pane, again: the agent
require("config.landing").setup() -- started without files: tree, start page, agent (the settings' landing)
require("config.settings").setup() -- :GreyKnightConfig, your keys over GreyKnight's (last: over all of them)

-- Optional: AI Dashboard bridge — only inside its Dev Environment (the session sets AIDASH_TOKEN)
if vim.env.AIDASH_TOKEN then require("integrations.aidash").setup() end
