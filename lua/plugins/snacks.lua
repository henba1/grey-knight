-- ╔══════════════════════════════════════════════════════════════╗
-- ║  snacks.nvim — Folke's QoL mega-plugin                     ║
-- ║  Replaces: telescope, indent-blankline, notify, neo-tree   ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile   = { enabled = true },
      dashboard = {
        enabled = true,
        width = 64,
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File",      action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File",        action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files",    action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "c", desc = "Config",          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = "󱌣 ", key = "a", desc = "AI (Qwen Code)",    action = ":lua vim.g.qwen_launch('agent', 'vertical')" },
            { icon = "󰒲 ", key = "L", desc = "Lazy",            action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit",            action = ":qa" },
          },
          header = [[
   ██████╗ ██████╗ ███████╗██╗   ██╗    ██╗  ██╗███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗
  ██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝    ██║ ██╔╝████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝
  ██║  ███╗██████╔╝█████╗   ╚████╔╝     █████╔╝ ██╔██╗ ██║██║██║  ███╗███████║   ██║
  ██║   ██║██╔══██╗██╔══╝    ╚██╔╝      ██╔═██╗ ██║╚██╗██║██║██║   ██║██╔══██║   ██║
  ╚██████╔╝██║  ██║███████╗   ██║       ██║  ██╗██║ ╚████║██║╚██████╔╝██║  ██║   ██║
   ╚═════╝ ╚═╝  ╚═╝╚══════╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
                         ⚔  Qwen 3.8 27B · 192.168.2.173  ⚔]],
        },
        sections = {
          { section = "header" },
          { section = "keys",         gap = 1, padding = 1 },
          { icon = " ", title = "Recent Files",  section = "recent_files", indent = 2, padding = 1 },
          { icon = " ", title = "Projects",      section = "projects",     indent = 2, padding = 1 },
          {
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git status --short --branch --renames",
            height = 5,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup" },
        },
      },
      explorer  = { enabled = true },
      indent    = { enabled = true },
      input     = { enabled = true },
      notifier  = { enabled = true, timeout = 3000 },
      picker    = { enabled = true },
      quickfile = { enabled = true },
      scope     = { enabled = true },
      scroll    = { enabled = true },
      words     = { enabled = true },
    },
    keys = {
      -- Picker (replaces telescope)
      { "<leader>ff", function() Snacks.picker.files() end,                 desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.grep() end,                  desc = "Live grep" },
      { "<leader>fb", function() Snacks.picker.buffers() end,               desc = "Buffers" },
      { "<leader>fh", function() Snacks.picker.help() end,                  desc = "Help tags" },
      { "<leader>fr", function() Snacks.picker.recent() end,                desc = "Recent files" },
      { "<leader>fc", function() Snacks.picker.commands() end,              desc = "Commands" },
      { "<leader>fs", function() Snacks.picker.lsp_symbols() end,           desc = "LSP Symbols" },
      { "<leader>fd", function() Snacks.picker.diagnostics() end,           desc = "Diagnostics" },
      { "<leader>f:", function() Snacks.picker.command_history() end,        desc = "Command history" },
      { "<leader>fk", function() Snacks.picker.keymaps() end,               desc = "Keymaps" },
      { "<leader>/",  function() Snacks.picker.grep_buffers() end,          desc = "Grep open buffers" },
      -- Explorer
      { "<leader>e",  function() Snacks.explorer() end,                     desc = "File explorer" },
      -- Notifications
      { "<leader>un", function() Snacks.notifier.show_history() end,        desc = "Notification history" },
      -- Git (lazygit via snacks)
      { "<leader>gg", function() Snacks.lazygit() end,                      desc = "Lazygit" },
      { "<leader>gl", function() Snacks.lazygit.log() end,                  desc = "Git log" },
      -- Bufdelete
      { "<leader>bd", function() Snacks.bufdelete() end,                    desc = "Delete buffer" },
    },
  },
}
