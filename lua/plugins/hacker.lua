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
      -- the program terminal in dap-ui's console, but never in one that still runs an earlier program
      dap.defaults.fallback.terminal_win_cmd = require("devsuite.debug").wrap_console(dap.defaults.fallback.terminal_win_cmd)
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open()  end
      dap.listeners.before.event_terminated["dapui_config"]  = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"]      = function() dapui.close() end
    end,
  },
  { "nvim-neotest/nvim-nio" },

  -- Variable values inline next to the code while a debug session is stopped
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },
}

-- Python DAP
if lang.python then
  table.insert(plugins, {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function()
      -- Mason's debugpy virtualenv: Scripts\python.exe on Windows, bin/python elsewhere
      local venv = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv"
      require("dap-python").setup(venv .. (vim.fn.has("win32") == 1 and "/Scripts/python.exe" or "/bin/python"))
    end,
  })
end

-- Debugger backends: ensure the ones the enabled languages use (Mason skips what is already present).
-- The names are nvim-dap's adapter names, not Mason's packages: mason-nvim-dap drops unknown names without a
-- word ("debugpy" was one, so a fresh machine never got the Python debugger).
if lang.c or lang.python or lang.bash then
  local ensure = {}
  if lang.c then ensure[#ensure + 1] = "codelldb" end
  if lang.python then ensure[#ensure + 1] = "python" end -- debugpy
  if lang.bash and vim.fn.has("win32") == 0 then ensure[#ensure + 1] = "bash" end -- bash-debug-adapter, Linux only
  table.insert(plugins, {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = { ensure_installed = ensure },
  })
end

return plugins
