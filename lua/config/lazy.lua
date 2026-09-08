-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Bootstrap lazy.nvim + load lua/plugins/*                   ║
-- ╚══════════════════════════════════════════════════════════════╝
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Suppress lspconfig deprecation (harmless until v3)
local orig_deprecate = vim.deprecate
vim.deprecate = function(old, new, version, plugin, ...)
  if plugin and plugin:find("lspconfig") then return end
  return orig_deprecate(old, new, version, plugin, ...)
end

require("lazy").setup("plugins", {
  rocks = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "matchit", "matchparen", "netrwPlugin",
        "tarPlugin", "tohtml", "tutor", "zipPlugin",
      },
    },
  },
})
