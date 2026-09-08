-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Editor QoL — flash, harpoon, surround, oil, mini, etc    ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  -- Flash — lightning navigation
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
      { "r", mode = "o",               function() require("flash").remote() end,             desc = "Remote Flash" },
      { "R", mode = { "o", "x" },      function() require("flash").treesitter_search() end,  desc = "Treesitter Search" },
    },
  },

  -- Harpoon v2 — fast file marks
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup()
      vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end,            { desc = "Harpoon: Add file" })
      vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: Menu" })
      vim.keymap.set("n", "<leader>1",  function() harpoon:list():select(1) end,        { desc = "Harpoon 1" })
      vim.keymap.set("n", "<leader>2",  function() harpoon:list():select(2) end,        { desc = "Harpoon 2" })
      vim.keymap.set("n", "<leader>3",  function() harpoon:list():select(3) end,        { desc = "Harpoon 3" })
      vim.keymap.set("n", "<leader>4",  function() harpoon:list():select(4) end,        { desc = "Harpoon 4" })
    end,
  },

  -- Oil — edit filesystem like a buffer
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      view_options = { show_hidden = true },
      float = { padding = 4, max_width = 100, max_height = 30 },
      keymaps = {
        ["q"] = "actions.close",
      },
    },
    keys = {
      { "-", "<cmd>Oil<cr>",       desc = "Oil: Open parent dir" },
      { "<leader>o", "<cmd>Oil --float<cr>", desc = "Oil: Float" },
    },
  },

  -- mini.surround — sa/sd/sr
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {},
  },

  -- mini.ai — better text objects (daf, ciq, etc)
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    opts = {},
  },

  -- Grug-far — project-wide find and replace
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = {},
    keys = {
      { "<leader>sr", function() require("grug-far").open() end,                           desc = "Search & Replace" },
      { "<leader>sw", function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end, desc = "S&R: Current word" },
    },
  },

  -- which-key
  { "folke/which-key.nvim", event = "VeryLazy", config = true },

  -- Autopairs
  { "windwp/nvim-autopairs", event = "InsertEnter", config = true },

  -- Gitsigns
  { "lewis6991/gitsigns.nvim", event = "BufReadPost", config = true },

  -- todo-comments
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },

  -- Trouble v3
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              desc = "Trouble: Diagnostics" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Trouble: Buffer only" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>",                  desc = "Trouble: Loclist" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                  desc = "Trouble: Quickfix" },
    },
  },

  -- tiny-inline-diagnostic — beautiful inline diagnostics
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup({ preset = "powerline" })
      vim.diagnostic.config({ virtual_text = false })  -- disable default, let tiny handle it
    end,
  },

  -- Lualine
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        section_separators   = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- Diffview — side-by-side git diffs
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>",          desc = "Git: Diffview" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",  desc = "Git: File history" },
    },
  },

  -- render-markdown — beautiful markdown in-buffer (also used by Avante AI chat)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown", "Avante" } },
  },
}
