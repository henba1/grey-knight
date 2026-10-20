-- ╔══════════════════════════════════════════════════════════════╗
-- ║  File explorer (<leader>e, snacks): cd right from the tree,  ║
-- ║  move and copy through the tree, typed paths as typed        ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Snacks' own "." and "<BS>" only move the tree. These keys change Neovim's working directory (pickers,
-- terminals and runs start there); the explorer follows DirChanged by itself, so tree and :pwd stay the
-- same. Keys: plugins/snacks.lua
--   .           the folder under the cursor becomes the working directory (on a file: its folder)
--   <BS>  -     one folder up (cd ..)
--   m  c        move / copy the marked items into the folder under the cursor; nothing marked: mark this one
--   r  C  a     rename or move / copy / create at a typed path (absolute paths as typed)
local M = {}

local WIN = vim.fn.has("win32") == 1

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

-- ── Moving and copying through the tree, typed paths (2026-10-20) ──────────
-- snacks' m and c work on marked items (<Tab>), and with nothing marked m fell back to a rename prompt.
-- Now m / c with nothing marked mark the item under the cursor, so a file goes somewhere else by the
-- tree: m on it, then m (move) or c (copy) on the target folder. Typed paths (r, C, a): snacks put every
-- answer below a base folder, an absolute one too - C:\dev\files became <cwd>\C\dev\files, /home/nix0/x.py
-- <cwd>/home/nix0/x.py. Absolute paths (also ~ and \\server\share) go where they say now; an existing
-- folder (or a path ending in / or \) takes the item under its own name, like mv; nothing is overwritten.

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Explorer" }) end
local function warn(msg) notify(msg, vim.log.levels.WARN) end
local function show(path) return vim.fn.fnamemodify(path, ":~") end
-- paths compare as the file system does: without case on Windows
local function key(path) path = vim.fs.normalize(path); return WIN and path:lower() or path end
local function eq(a, b) return key(a) == key(b) end
local function inside(path, dir) return vim.startswith(key(path), key(dir) .. "/") end
local function path_of(item) return item and Snacks.picker.util.path(item) or nil end

--- What a typed path names: an absolute one (/x, ~/x, C:\x, \\server\x) as it is, a relative one below `base`.
--- Returns the path and whether it names a folder (typed with a trailing / or \).
function M.resolve(base, value)
  value = vim.trim(value or "")
  local folder = value:find("[/\\]$") ~= nil
  value = vim.fs.normalize(value) -- ~ and $VARS expanded, \ -> / on Windows
  if vim.fn.isabsolutepath(value) == 0 then value = base .. "/" .. value end
  return vim.fs.normalize(vim.fn.fnamemodify(value, ":p")), folder -- :p: /x on Windows -> the current drive
end

--- The same file system entry (on Windows also under another case of its name)
function M.same(a, b)
  local ra, rb = vim.uv.fs_realpath(a), vim.uv.fs_realpath(b)
  return ra ~= nil and rb ~= nil and eq(ra, rb)
end

-- Where `from` lands for a typed path: in a folder that exists (or was typed with a trailing / or \) under its
-- own name, like mv; else at the path itself
local function into(from, path, folder)
  local stat = vim.uv.fs_stat(path)
  if folder or (stat and stat.type == "directory" and not M.same(path, from)) then
    return vim.fs.normalize(path .. "/" .. vim.fs.basename(from))
  end
  return path
end

-- The tree after a change: these folders read again, the cursor on `target`
local function refresh(picker, dirs, target)
  local Tree = require("snacks.explorer.tree")
  for _, dir in ipairs(dirs) do Tree:refresh(dir) end
  require("snacks.explorer.actions").update(picker, { target = target })
end

-- m / c with nothing marked: mark the item under the cursor
local function mark(picker, item)
  local from = path_of(item)
  if not from then return end
  if eq(from, picker:cwd()) then return warn("That is the tree's root (<BS> goes one folder up)") end
  picker.list:select(item)
  notify(vim.fs.basename(from) .. " marked: on the target folder m moves it there, c copies it"
    .. " (<Tab> marks more, m in its own folder unmarks)")
end

-- The marked items and where they go in `dir` ({ from, to } each), and why others stay where they are
local function plan(picker, dir, copying)
  local todo, stay = {}, {}
  for _, it in ipairs(picker:selected()) do
    local from = path_of(it)
    local to = vim.fs.normalize(dir .. "/" .. vim.fs.basename(from))
    if eq(vim.fs.dirname(from), dir) then
      if copying then stay[#stay + 1] = vim.fs.basename(from) .. " is in this folder already (C copies it under a new name)" end
    elseif eq(dir, from) or inside(dir, from) then
      stay[#stay + 1] = vim.fs.basename(from) .. ": not into itself"
    elseif vim.uv.fs_stat(to) then
      stay[#stay + 1] = show(to) .. " exists - nothing overwritten"
    else
      todo[#todo + 1] = { from = from, to = to }
    end
  end
  return todo, stay
end

local function what(todo) return #todo == 1 and vim.fs.basename(todo[1].from) or (#todo .. " items") end

--- m: move the marked items into the folder under the cursor (on a file: its folder), after asking; nothing
--- marked: mark the item under the cursor.
function M.move(picker, item)
  if #picker:selected() == 0 then return mark(picker, item) end
  local dir = picker:dir()
  local todo, stay = plan(picker, dir, false)
  if #stay > 0 then warn(table.concat(stay, "\n")) end
  if #todo == 0 then
    picker.list:set_selected()
    if #stay == 0 then notify("Nothing moved: already in " .. show(dir) .. " - unmarked") end
    return
  end
  Snacks.picker.util.confirm(("Move %s to %s?"):format(what(todo), show(dir)), function()
    local dirs = { dir }
    for _, mv in ipairs(todo) do
      Snacks.rename.rename_file({ from = mv.from, to = mv.to }) -- open buffers and language servers follow
      dirs[#dirs + 1] = vim.fs.dirname(mv.from)
    end
    picker.list:set_selected()
    refresh(picker, dirs, todo[#todo].to)
  end)
end

--- c: copy the marked items into the folder under the cursor (on a file: its folder); nothing marked: mark the
--- item under the cursor.
function M.copy(picker, item)
  if #picker:selected() == 0 then return mark(picker, item) end
  local dir = picker:dir()
  local todo, stay = plan(picker, dir, true)
  for _, cp in ipairs(todo) do Snacks.picker.util.copy_path(cp.from, cp.to) end
  picker.list:set_selected()
  if #stay > 0 then warn(table.concat(stay, "\n")) end
  if #todo > 0 then
    notify(("Copied %s to %s"):format(what(todo), show(dir)))
    refresh(picker, { dir }, todo[#todo].to)
  end
end

--- r: rename the item under the cursor or move it anywhere - relative paths from the working directory (what the
--- prompt shows), absolute ones as typed, an existing folder: into it.
function M.rename(picker, item)
  local from = path_of(item)
  if not from then return end
  if eq(from, picker:cwd()) then return warn("That is the tree's root (<BS> goes one folder up)") end
  local base = vim.fs.normalize(vim.fn.getcwd(0))
  if not inside(from, base) then base = vim.fs.dirname(from) end
  local shown = from:sub(#base + 2)
  Snacks.input({ prompt = "Rename / move to (from " .. show(base) .. ", or an absolute path)", default = shown, completion = "file" },
    function(value)
      if not value or vim.trim(value) == "" or value == shown then return end
      local to = into(from, M.resolve(base, value))
      if eq(to, from) then return end
      if inside(to, from) then return warn(vim.fs.basename(from) .. ": not into itself") end
      if vim.uv.fs_stat(to) and not M.same(to, from) then return warn(show(to) .. " exists - nothing overwritten") end
      Snacks.rename.rename_file({
        from = from,
        to = to,
        on_rename = function(new, old) refresh(picker, { vim.fs.dirname(old), vim.fs.dirname(new) }, new) end,
      })
    end)
end

--- C: copy the item under the cursor to a typed path - relative ones from its folder, absolute ones as typed, an
--- existing folder: into it.
function M.copy_to(picker, item)
  local from = path_of(item)
  if not from then return end
  local base = vim.fs.dirname(from)
  Snacks.input({ prompt = "Copy to (from " .. show(base) .. ", or an absolute path)", completion = "file" }, function(value)
    if not value or vim.trim(value) == "" then return end
    local to = into(from, M.resolve(base, value))
    if eq(to, from) or inside(to, from) then return warn(vim.fs.basename(from) .. ": not onto or into itself") end
    if vim.uv.fs_stat(to) then return warn(show(to) .. " exists - nothing overwritten") end
    Snacks.picker.util.copy_path(from, to)
    refresh(picker, { vim.fs.dirname(to) }, to)
  end)
end

--- a: a new file, or a folder when the path ends in / (or \) - relative ones in the folder under the cursor,
--- absolute ones as typed.
function M.add(picker)
  local base = picker:dir()
  Snacks.input({ prompt = 'New file or folder (folders end in "/") in ' .. show(base) .. ", or an absolute path" }, function(value)
    if not value or vim.trim(value) == "" then return end
    local path, folder = M.resolve(base, value)
    local dir = folder and path or vim.fs.dirname(path)
    if not folder and vim.uv.fs_stat(path) then return warn(show(path) .. " exists") end
    vim.fn.mkdir(dir, "p")
    if not folder then
      local f = io.open(path, "w")
      if not f then return warn("Cannot create " .. show(path)) end
      f:close()
    end
    require("snacks.explorer.tree"):open(dir)
    refresh(picker, { dir }, path)
  end)
end

return M
