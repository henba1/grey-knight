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
    -- 2026-10-20: going to a toggleterm window - an agent, the REPL, a shell (<C-l>, a click) - means typing there:
    -- insert (terminal) mode. Before, <C-h> left a terminal in normal mode (<C-\><C-n> first) and toggleterm
    -- brought that mode back on the way in (persist_mode), so every return began with i. Not once the program in
    -- it has exited: a key would close the window. <Esc><Esc> still gives normal mode inside (scroll, copy).
    init = function()
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("greyknight.terminal_insert", { clear = true }),
        pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" }, -- toggleterm's buffer names
        callback = function(ev)
          -- scheduled twice: after toggleterm's restore of the old mode, which it schedules from its own BufEnter
          vim.schedule(function()
            vim.schedule(function()
              if vim.api.nvim_get_current_buf() ~= ev.buf then return end
              local job = vim.b[ev.buf].terminal_job_id
              if job and vim.fn.jobwait({ job }, 0)[1] == -1 and vim.api.nvim_get_mode().mode:sub(1, 1) == "n" then
                vim.cmd("startinsert")
              end
            end)
          end)
        end,
      })
    end,
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
