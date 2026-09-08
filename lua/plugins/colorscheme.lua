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
      cache = true,
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
