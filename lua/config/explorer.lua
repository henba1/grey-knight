-- ╔══════════════════════════════════════════════════════════════╗
-- ║  File explorer (<leader>e, snacks): cd right from the tree   ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Snacks' own "." and "<BS>" only move the tree. These keys change Neovim's working directory (pickers,
-- terminals and runs start there); the explorer follows DirChanged by itself, so tree and :pwd stay the
-- same. Keys: plugins/snacks.lua
--   .           the folder under the cursor becomes the working directory (on a file: its folder)
--   <BS>  -     one folder up (cd ..)
local M = {}

--- cd to `dir` (a window- or tab-local directory stays local, like chdir()); the tree follows
function M.cd(picker, dir)
  if not dir or vim.fn.isdirectory(dir) ~= 1 then return end
  dir = vim.fs.normalize(dir)
  if vim.fs.normalize(vim.fn.getcwd()) ~= dir then
    -- snacks' explorer roots the tree at the new directory on DirChanged (picker/source/explorer.lua);
    -- rooting it here as well ran a second listing and showed every entry twice
    vim.fn.chdir(dir)
  elseif picker:cwd() ~= dir then
    picker:set_cwd(dir) -- already the working directory, so no DirChanged: move only the tree
    picker:find()
  end
  vim.notify("cwd: " .. vim.fn.fnamemodify(dir, ":~"), vim.log.levels.INFO, { title = "Explorer" })
end

--- "." - the folder under the cursor (for a file: its folder) becomes the working directory
function M.cd_here(picker) M.cd(picker, picker:dir()) end

--- "<BS>" / "-" - one folder up from the tree's root
function M.cd_up(picker) M.cd(picker, vim.fs.dirname(picker:cwd())) end

return M
