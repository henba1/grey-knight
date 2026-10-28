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
      -- A slot opens the file by its own name: harpoon looked its buffer up with bufnr(), whose argument is a pattern -
      -- "notes [draft].txt" also named an open "notes d.txt", and the slot opened that one (2026-10-21). As harpoon's
      -- own select otherwise: the cursor where it was for a file not open yet, split / vsplit / tabedit, its event.
      local win = vim.fn.has("win32") == 1
      local function key(path)
        path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
        return win and path:lower() or path
      end
      local function select(item, _, options)
        if item == nil then return end
        options = options or {}
        local buf
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(b) ~= "" and key(vim.api.nvim_buf_get_name(b)) == key(item.value) then buf = b end
        end
        local fresh = buf == nil
        -- a file that is gone (deleted, moved outside Neovim): its slot made an empty new file there (2026-10-22)
        if fresh and vim.uv.fs_stat(vim.fn.fnamemodify(item.value, ":p")) == nil then
          return vim.notify(("%s is gone - <leader>hh: the list, dd there removes it"):format(item.value), vim.log.levels.WARN, { title = "Harpoon" })
        end
        if fresh then buf = vim.fn.bufadd(vim.fn.fnamemodify(item.value, ":p")) end
        if not vim.api.nvim_buf_is_loaded(buf) then
          vim.fn.bufload(buf)
          vim.bo[buf].buflisted = true
        end
        if options.vsplit then vim.cmd("vsplit") elseif options.split then vim.cmd("split") elseif options.tabedit then vim.cmd("tabedit") end
        vim.api.nvim_set_current_buf(buf)
        if fresh and type(item.context) == "table" then
          local row = math.max(1, math.min(item.context.row or 1, vim.api.nvim_buf_line_count(buf)))
          local col = math.min(item.context.col or 0, #(vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""))
          pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
        end
        local Extensions = require("harpoon.extensions")
        Extensions.extensions:emit(Extensions.event_names.NAVIGATE, { buffer = buf })
      end
      -- A slot keeps its file relative to the working directory, worked out from normalized names (2026-10-22):
      -- harpoon's own (plenary's make_relative) compares the names as they are - on Windows a buffer named with "/"
      -- (snacks opens files as C:/...) kept its whole path, and the same file pinned from a buffer named with "\" was
      -- a second slot. Two slots are the same file by key() - the ones written before as well.
      local function relative(name)
        local file = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
        local root = vim.fs.normalize(vim.uv.cwd())
        if root:sub(-1) ~= "/" then root = root .. "/" end
        if (win and file:lower() or file):sub(1, #root) == (win and root:lower() or root) then return file:sub(#root + 1) end
        return file
      end
      local function create_list_item(_, name)
        name = relative(name or vim.api.nvim_buf_get_name(0))
        local pos = { 1, 0 } -- the cursor, when the file is the one in this window
        if key(vim.api.nvim_buf_get_name(0)) == key(name) then pos = vim.api.nvim_win_get_cursor(0) end
        return { value = name, context = { row = pos[1], col = pos[2] } }
      end
      local function equals(a, b)
        if a == nil or b == nil then return a == b end
        return key(a.value) == key(b.value)
      end
      harpoon:setup({
        settings = {
          save_on_toggle = true,   -- closing the menu with q / Esc keeps your edits (default: drops them)
          sync_on_ui_close = true, -- and writes them to disk right away, not only when Neovim exits
        },
        default = { select = select, create_list_item = create_list_item, equals = equals },
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
          if list.items[i] and key(list.items[i].value) == key(value) then
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
        -- in diff mode (Diffview) ]c / [c stay Vim's; in a file with the agent's edits to review they go to those
        -- (integrations/agent_review.lua), else to git's changes
        local function review(dir) return package.loaded["integrations.agent_review"] and require("integrations.agent_review").jump(dir) end
        map("n", "]c", function() if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) elseif not review(1) then gs.nav_hunk("next") end end, "Git: Next change (the agent's to review first)")
        map("n", "[c", function() if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) elseif not review(-1) then gs.nav_hunk("prev") end end, "Git: Previous change (the agent's to review first)")
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
        -- easy mode (Alt+N): EASY where Vim's INSERT was - typing there is the plain editor's, not Vim's insert mode
        lualine_a = { { "mode", fmt = function(m) return vim.g.greyknight_easymode and m == "INSERT" and "EASY" or m end } },
        lualine_b = { "branch", "diff", "diagnostics" },
        -- a terminal by its name, not its buffer's - term://<cwd>//<pid>:<the whole command line> (2026-10-23)
        lualine_c = { { "filename", path = 1, fmt = function(name)
          if vim.bo.buftype == "terminal" then return require("config.termname").name(0) end
          return name
        end } },
        lualine_x = { "overseer", "filetype" }, -- overseer: running / done / failed tasks
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- codediff — VS Code's diff for git: its algorithm (a native library, downloaded once on first use), the lines and
  -- the words within them colored, side by side or inline (t). <leader>gv: the changes of the working tree, also as
  -- they land while an agent works; stage / unstage / discard a file (-) or a hunk right there. And branches, staged
  -- changes, a file's history, merge conflicts (:CodeDiff ...)
  -- Where codediff cannot get its library (a download that failed), Diffview takes over (config/gitdiff.lua). The keys
  -- (<leader>gv, <leader>gh) are in config/keymaps.lua: as lazy.nvim keys they would load codediff first - and loading
  -- it without its library is its download, an error when that fails
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    opts = {
      -- a hunk as gitsigns' keys do it in a file: <leader>gs stages, <leader>gr discards; <leader>gu unstages
      keymaps = { view = { stage_hunk = "<leader>gs", unstage_hunk = "<leader>gu", discard_hunk = "<leader>gr" } },
    },
  },

  -- Diffview: where codediff has no library; its commands stay (:DiffviewOpen, :DiffviewFileHistory). The old side's
  -- changes red as deletions, as codediff and VS Code show them
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewFileHistory" }, opts = { enhanced_diff_hl = true } },

  -- render-markdown — beautiful markdown in-buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown" } },
  },
}
