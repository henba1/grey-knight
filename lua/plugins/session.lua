-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Session persistence — auto-save/restore per project        ║
-- ║  Uses snacks.nvim dashboard "Restore Session" integration   ║
-- ║  Falls back to persisted.nvim for auto-save                 ║
-- ╚══════════════════════════════════════════════════════════════╝
-- persisted.nvim 2 (2026-10-21): auto_save, suppressed_dirs and bypass_save_filetypes were version 1's options,
-- ignored since - sessions were saved in ~, / and /tmp, quitting from the start screen overwrote a project's
-- session with an empty one, and a restored session brought the explorer's frame back as an empty window and the
-- terminals as new shells (an agent's too).
return {
  {
    "olimorris/persisted.nvim",
    lazy = false,
    init = function()
      -- A session keeps files, splits and tabs - no empty windows (the explorer's frame), no terminals (a restored
      -- one started its program again, outside toggleterm)
      vim.opt.sessionoptions:remove({ "blank", "terminal" })
    end,
    opts = {
      autostart      = true,    -- record the session; it is saved when Neovim quits
      autoload       = false,   -- don't auto-restore (let dashboard handle it via 's' key)
      use_git_branch = true,    -- separate sessions per git branch
      save_dir       = vim.fn.expand(vim.fn.stdpath("data") .. "/sessions/"),
      -- No sessions for the home folder itself, the root, temp folders
      ignored_dirs   = { { "~", exact = true }, { "/", exact = true }, "/tmp" },
      -- Quitting with no file open (the start screen, a picker) keeps the session there was; :Persisted save
      -- (<leader>ps) saves anyway. Nor in a folder of ignored_dirs Neovim moved to: persisted checks those when it
      -- starts only - a :cd /tmp/x before quitting saved a session for it (2026-10-21)
      should_save    = function()
        if not require("persisted").allowed_dir() then return false end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and name ~= "" and vim.uv.fs_stat(name) then
            return true
          end
        end
        return false
      end,
    },
    config = function(_, opts)
      -- The session file is named after the folder with % for every separator, and persisted read every % back as /:
      -- the folder "100% done" became "100/ done", no such folder, and :Persisted clean deleted its session
      -- (2026-10-21). A % of the name is %% in the file name now - names without one stay as they were.
      local utils = require("persisted.utils")
      utils.make_fs_safe = function(text) return (text:gsub("%%", "%%%%"):gsub("[\\/:]+", "%%")) end
      utils.replace_separators = function(text)
        return (text:gsub("%%(%%?)", function(second) return second == "%" and "%" or "/" end))
      end
      require("persisted").setup(opts)
    end,
    keys = {
      { "<leader>ps", "<cmd>Persisted save<cr>",   desc = "Session: Save" },
      { "<leader>pl", "<cmd>Persisted load<cr>",   desc = "Session: Load (cwd)" },
      { "<leader>pd", "<cmd>Persisted delete<cr>", desc = "Session: Delete" },
    },
  },
}
