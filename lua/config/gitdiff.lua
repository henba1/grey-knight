-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Git diffs (<leader>gv, <leader>gh): codediff - VS Code's    ║
-- ║  diff - where its library is; else Diffview. Both: the old   ║
-- ║  side red, the new side green, the changed words within a    ║
-- ║  line in a stronger shade.                                   ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local tried = false

-- codediff's folder: lazy.nvim knows it without loading the plugin
local function plugin_dir()
  local ok, config = pcall(require, "lazy.core.config")
  local plugin = ok and config.plugins["codediff.nvim"]
  return plugin and plugin.dir
end

--- Whether codediff's native library (of its version) is in its folder - looked at without loading codediff: loading
--- it downloads the library when it is missing, and fails with an error when that download does
--- (codediff/core/diff.lua; 2026-10-22: a 403 on the work laptop once, the next try worked)
function M.library()
  local dir = plugin_dir()
  if not dir then return false end
  local ext = vim.fn.has("win32") == 1 and "dll" or vim.fn.has("mac") == 1 and "dylib" or "so"
  local version = vim.fn.filereadable(dir .. "/VERSION") == 1 and vim.trim(vim.fn.readfile(dir .. "/VERSION", "", 1)[1] or "") or ""
  for _, name in ipairs({ "libvscode_diff." .. ext, ("libvscode_diff_%s.%s"):format(version, ext) }) do
    if vim.uv.fs_stat(dir .. "/" .. name) then return true end
  end
  return false
end

--- Whether codediff diffs here: its library is there - else one try a session, quietly: loading codediff downloads it
--- (a download filter, GitHub's limit for a company's address may refuse it; codediff's and lazy.nvim's messages then
--- are errors - none of GreyKnight's)
function M.codediff()
  if M.library() then return true end
  if tried then return false end
  tried = true
  local notify = vim.notify
  vim.notify = function() end
  pcall(require("lazy").load, { plugins = { "codediff.nvim" } })
  vim.notify = notify
  return M.library()
end

local function diffview(cmd)
  vim.notify_once("codediff's diff library could not be downloaded here - Diffview instead (again in the next session)",
    vim.log.levels.INFO, { title = "Git" })
  vim.cmd(cmd)
end

--- <leader>gv: the changes of the working tree, live (also while an agent writes them)
function M.review()
  if M.codediff() then return vim.cmd("CodeDiff") end
  diffview("DiffviewOpen")
end

--- <leader>gh: the current file's history
function M.history()
  if M.codediff() then return vim.cmd("CodeDiff history %") end
  diffview("DiffviewFileHistory %")
end

return M
