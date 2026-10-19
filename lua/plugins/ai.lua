-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Qwen Code — agentic coding agent terminal                  ║
-- ║  Shell-out integration: drives the local Qwen Code CLI in a  ║
-- ║  persistent toggleterm window (replaces Avante.nvim).       ║
-- ║  Backend: Qwen 3.8 27B @ 192.168.2.173:8000 (llama.cpp)     ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- The agent lives in lua/integrations/agent.lua (keys in lua/config/keymaps.lua:
-- <leader>t*, <leader>a*); it drives the local Qwen Code CLI in these persistent terminals.
-- The REPLs of the dev suite (lua/devsuite/repl.lua) use toggleterm as well.

return {
  -- Toggleterm — persistent named terminals
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then return 15
        elseif term.direction == "vertical" then return vim.o.columns * 0.4
        end
      end,
      open_mapping = false,  -- manual mapping below (Ctrl+\ eaten by SSH)
      direction = "horizontal",
      shade_terminals = true,
      shade_factor = -30,
      float_opts = { border = "curved", width = 120, height = 30 },
    },
  },

  -- render-markdown — renders markdown in the agent's terminal output
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown" } },
  },
}
