-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Cyberdream — high-contrast futuristic theme                ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "default",
      transparent = false,
      italic_comments = true,
      hide_fillchars = true,
      borderless_pickers = true,
      terminal_colors = true,
      -- no cache (2026-10-22): a start without its file - a new machine, an emptied ~/.cache, changed options -
      -- built it and applied the theme a second later, with "A restart may be required"; after an update of the
      -- theme the cache kept the old colors. It saved 4 ms a start.
      cache = false,
      extensions = {
        blinkcmp          = true,
        dashboard         = true,
        gitsigns          = true,
        grugfar           = true,
        mini              = true,
        snacks            = true,
        treesitter        = true,
        treesittercontext = true,
        trouble           = true,
        whichkey          = true,
        dapui             = true,
        markdown          = true,
      },
    },
    config = function(_, opts)
      require("cyberdream").setup(opts)
      vim.cmd.colorscheme("cyberdream")
    end,
  },
}
