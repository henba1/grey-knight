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

  -- Harpoon v2 — pin the files of your current task to slots 1-4 (one list per project, kept)
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup({
        settings = {
          save_on_toggle = true,   -- closing the menu with q / Esc keeps your edits (default: drops them)
          sync_on_ui_close = true, -- and writes them to disk right away, not only when Neovim exits
        },
      })
      -- Pin the current file, save the list at once, and say which slot it got
      vim.keymap.set("n", "<leader>ha", function()
        if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
          return vim.notify("Harpoon: only files can be pinned", vim.log.levels.WARN, { title = "Harpoon" })
        end
        local list = harpoon:list()
        list:add()
        pcall(harpoon.sync, harpoon)
        local value = list.config.create_list_item(list.config).value
        for i = 1, list:length() do
          if list.items[i] and list.items[i].value == value then
            local key = i <= 4 and ("<leader>" .. i) or "the menu (<leader>hh)"
            return vim.notify(("%s is slot %d: %s"):format(value, i, key), vim.log.levels.INFO, { title = "Harpoon" })
          end
        end
      end, { desc = "Harpoon: Pin file" })
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
      -- A folder opened as a file (nvim <folder>, :e <folder>) is the explorer's (snacks, replace_netrw). Once loaded
      -- (- or <leader>o once) oil took every folder buffer, so the same :e opened the explorer or oil (2026-10-21)
      default_file_explorer = false,
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

  -- mini.surround — gsa / gsd / gsr. Its own sa / sd / sr began with flash's s: s then d, typed within timeoutlen to
  -- jump to a word with d, deleted a surrounding instead - flash lost every target starting with a, d, r, f, h or n
  -- (2026-10-21). The gs prefix is LazyVim's for the same reason.
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF", highlight = "gsh", replace = "gsr",
        update_n_lines = "gsn",
      },
    },
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

  -- Gitsigns: the changes in the gutter, and keys for them in files of a git repository
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end
        local function lines() -- the visual selection, top to bottom
          local a, b = vim.fn.line("."), vim.fn.line("v")
          return { math.min(a, b), math.max(a, b) }
        end
        -- in diff mode (Diffview) ]c / [c stay Vim's
        map("n", "]c", function() if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end end, "Git: Next change")
        map("n", "[c", function() if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end end, "Git: Previous change")
        map("n", "<leader>gs", gs.stage_hunk, "Git: Stage the change (again: unstage)")
        map("v", "<leader>gs", function() gs.stage_hunk(lines()) end, "Git: Stage the selected lines")
        map("n", "<leader>gr", gs.reset_hunk, "Git: Undo the change (u brings it back)")
        map("v", "<leader>gr", function() gs.reset_hunk(lines()) end, "Git: Undo the selected lines")
        map("n", "<leader>gp", gs.preview_hunk, "Git: Show the change")
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Git: Who changed the line (blame)")
      end,
    },
    config = function(_, opts)
      -- A git run that cannot start throws (vim.system: ENOENT when its folder went a moment before - a file's
      -- folder moved or deleted right after the file was opened). Inside gitsigns' repository lock that kept the
      -- lock taken for good: no file got signs any more for the rest of the session (2026-10-21; gitsigns' async.lua
      -- drops such a task without unwinding it, upstream too). Such a failure now comes back as a failed run. The
      -- git module takes this function once, when it loads - so before setup.
      local sys = require("gitsigns.system")
      local spawn = sys.system
      sys.system = function(cmd, o, on_exit)
        local ok, obj = pcall(spawn, cmd, o, on_exit)
        if ok then return obj end
        if not on_exit then error(obj, 0) end -- waited for in place: as before
        vim.schedule(function() on_exit({ code = 127, signal = 0, stdout = "", stderr = tostring(obj) }) end)
      end
      require("gitsigns").setup(opts)
    end,
  },

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
        lualine_x = { "overseer", "filetype" }, -- overseer: running / done / failed tasks
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
      -- <leader>gv: <leader>gd is the GreyKnight docs picker (lua/config/keymaps.lua)
      { "<leader>gv", "<cmd>DiffviewOpen<cr>",          desc = "Git: Diffview (side-by-side diff)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",  desc = "Git: File history" },
    },
  },

  -- render-markdown — beautiful markdown in-buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown" } },
  },
}
