-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Dev suite engine: overseer.nvim runs every script as a task ║
-- ║  (several side by side, task list, restart, watch on save); ║
-- ║  the bash + python logic lives in lua/devsuite/             ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerTaskAction" },
    opts = {
      task_list = {
        -- <C-j>/<C-k> stay window navigation (as everywhere else) instead of scrolling the preview
        keymaps = { ["<C-j>"] = false, ["<C-k>"] = false },
      },
    },
  },
}
