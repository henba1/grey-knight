-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Java: jdtls through nvim-jdtls, set up the way IntelliJ    ║
-- ║  has the project (lua/integrations/jdtls.lua)               ║
-- ╚══════════════════════════════════════════════════════════════╝
local lang = vim.g.lang or {}
if not lang.java then return {} end

return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local function start(buf) require("integrations.jdtls").start(buf) end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("greyknight.jdtls", { clear = true }),
        pattern = "java",
        callback = function(ev) start(ev.buf) end,
      })
      -- the Java buffer whose filetype loaded this plugin
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "java" then start(buf) end
      end
    end,
  },
}
