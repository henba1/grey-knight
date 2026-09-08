-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Session persistence — auto-save/restore per project        ║
-- ║  Uses snacks.nvim dashboard "Restore Session" integration   ║
-- ║  Falls back to persisted.nvim for auto-save                 ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  {
    "olimorris/persisted.nvim",
    lazy = false,
    opts = {
      autostart     = true,    -- auto-record session
      auto_save     = true,    -- save on exit
      autoload      = false,   -- don't auto-restore (let dashboard handle it via 's' key)
      use_git_branch = true,   -- separate sessions per git branch
      save_dir      = vim.fn.expand(vim.fn.stdpath("data") .. "/sessions/"),
      -- Don't restore sessions for home dir or tmp
      suppressed_dirs = { "~", "/tmp", "/" },
      -- Close these before saving (they don't restore well)
      bypass_save_filetypes = { "snacks_dashboard", "lazy", "mason", "toggleterm", "Avante", "AvanteInput" },
    },
    keys = {
      { "<leader>ps", "<cmd>Persisted save<cr>",   desc = "Session: Save" },
      { "<leader>pl", "<cmd>Persisted load<cr>",   desc = "Session: Load (cwd)" },
      { "<leader>pd", "<cmd>Persisted delete<cr>", desc = "Session: Delete" },
    },
  },
}
