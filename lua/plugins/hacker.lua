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

  -- Toggleterm now lives in ai.lua (shared with the Qwen Code agent terminal)

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

-- Debugger backends: ensure the ones the enabled languages use (Mason skips what is already present)
if lang.c or lang.python then
  local ensure = {}
  if lang.c then ensure[#ensure + 1] = "codelldb" end
  if lang.python then ensure[#ensure + 1] = "debugpy" end
  table.insert(plugins, {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = { ensure_installed = ensure },
  })
end

return plugins
