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
        -- No icons on the start page: Nerd Font glyphs show up as boxes or wrong characters in terminals
        -- without a Nerd Font (the AI Dashboard's web terminal). Also drops the file-type icons of the lists.
        formats = { icon = function() return { "" } end },
        preset = {
          keys = {
            { key = "f", desc = "Find File",      action = ":lua Snacks.dashboard.pick('files')" },
            { key = "n", desc = "New File",        action = ":ene | startinsert" },
            { key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { key = "r", desc = "Recent Files",    action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { key = "c", desc = "Config",          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { key = "s", desc = "Restore Session", section = "session" },
            { key = "a", desc = "AI (" .. require("integrations.agent").backend().name .. ")",    action = ":lua vim.g.qwen_launch('agent', 'vertical')" },
            { key = "L", desc = "Lazy",            action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { key = "q", desc = "Quit",            action = ":qa" },
          },
          header = [[
   ██████╗ ██████╗ ███████╗██╗   ██╗    ██╗  ██╗███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗
  ██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝    ██║ ██╔╝████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝
  ██║  ███╗██████╔╝█████╗   ╚████╔╝     █████╔╝ ██╔██╗ ██║██║██║  ███╗███████║   ██║
  ██║   ██║██╔══██╗██╔══╝    ╚██╔╝      ██╔═██╗ ██║╚██╗██║██║██║   ██║██╔══██║   ██║
  ╚██████╔╝██║  ██║███████╗   ██║       ██║  ██╗██║ ╚████║██║╚██████╔╝██║  ██║   ██║
   ╚═════╝ ╚═╝  ╚═╝╚══════╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
                            Qwen 3.8 27B · 192.168.2.173   ]],
        },
        sections = {
          { section = "header" },
          { section = "keys",         gap = 1, padding = 1 },
          { title = "Recent Files",  section = "recent_files", indent = 2, padding = 1 },
          { title = "Projects",      section = "projects",     indent = 2, padding = 1 },
          {
            title = "Git Status",
            section = "terminal",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git status --short --branch --renames",
            height = 5,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup", icon = "" },
        },
      },
      explorer  = { enabled = true },
      indent    = { enabled = true },
      input     = { enabled = true },
      notifier  = { enabled = true, timeout = 3000 },
      picker    = {
        enabled = true,
        sources = {
          -- explorer: "." = cd to the folder under the cursor, "<BS>" / "-" = cd ..; m / c move and copy the
          -- marked items into the folder under the cursor (nothing marked: mark this one); r / C / a take typed
          -- paths, absolute ones as typed (config/explorer.lua). Same names as snacks' actions: they replace them.
          explorer = {
            actions = {
              gk_cd_here      = { action = function(p) require("config.explorer").cd_here(p) end,        desc = "cd here (working directory)" },
              gk_cd_up        = { action = function(p) require("config.explorer").cd_up(p) end,          desc = "cd .. (one folder up)" },
              explorer_move   = { action = function(p, item) require("config.explorer").move(p, item) end,   desc = "Move the marked here (nothing marked: mark this)" },
              explorer_copy   = { action = function(p, item) require("config.explorer").copy(p, item) end,   desc = "Copy the marked here (nothing marked: mark this)" },
              explorer_rename = { action = function(p, item) require("config.explorer").rename(p, item) end, desc = "Rename / move to a path" },
              gk_copy_to      = { action = function(p, item) require("config.explorer").copy_to(p, item) end, desc = "Copy to a path" },
              explorer_add    = { action = function(p) require("config.explorer").add(p) end,              desc = "New file or folder" },
              explorer_del    = { action = function(p, item) require("config.explorer").delete(p, item) end, desc = "Delete (the cursor stays)" },
            },
            win = { list = { keys = { ["."] = "gk_cd_here", ["<BS>"] = "gk_cd_up", ["-"] = "gk_cd_up", ["C"] = "gk_copy_to" } } },
          },
        },
      },
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
