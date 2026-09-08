-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Grey Knight Specials — hex, terminals, DAP                ║
-- ╚══════════════════════════════════════════════════════════════╝
local lang = vim.g.lang or {}

local plugins = {
  -- Hex editor — toggle any buffer to hex view
  {
    "RaafatTurki/hex.nvim",
    cmd = { "HexDump", "HexAssemble", "HexToggle" },
    opts = {},
    keys = {
      { "<leader>hx", "<cmd>HexToggle<cr>", desc = "Hex: Toggle view" },
    },
  },

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
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>",                     desc = "Term: Toggle" },
      { "<leader>tf", "<cmd>ToggleTerm direction=float<cr>",      desc = "Term: Float" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Term: Horizontal" },
      { "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>",   desc = "Term: Vertical" },
      { "<leader>t1", "<cmd>1ToggleTerm<cr>",                     desc = "Term: #1" },
      { "<leader>t2", "<cmd>2ToggleTerm<cr>",                     desc = "Term: #2" },
      { "<leader>t3", "<cmd>3ToggleTerm<cr>",                     desc = "Term: #3" },
    },
  },

  -- DAP (Debugging)
  { "mfussenegger/nvim-dap" },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open()  end
      dap.listeners.before.event_terminated["dapui_config"]  = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]      = function() dapui.close() end
    end,
  },
  { "nvim-neotest/nvim-nio" },
}

-- Python DAP
if lang.python then
  table.insert(plugins, {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function()
      require("dap-python").setup(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python")
    end,
  })
end

-- C/C++ DAP
if lang.c then
  table.insert(plugins, {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = { ensure_installed = { "codelldb" } },
  })
end

return plugins
