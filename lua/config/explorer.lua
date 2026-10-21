-- ╔══════════════════════════════════════════════════════════════╗
-- ║  File explorer (<leader>e, snacks): cd right from the tree,  ║
-- ║  move and copy through the tree, typed paths as typed,       ║
-- ║  search for files, for folders or in the current view        ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Snacks' own "." and "<BS>" only move the tree. These keys change Neovim's working directory (pickers,
-- terminals and runs start there); the explorer follows DirChanged by itself, so tree and :pwd stay the
-- same. Keys: plugins/snacks.lua
--   .           the folder under the cursor becomes the working directory (on a file: its folder)
--   <BS>  -     one folder up (cd ..)
--   m  c        move / copy the marked items into the folder under the cursor; nothing marked: mark this one
--   r  C  a     rename or move / copy / create at a typed path (absolute paths as typed)
--   d           delete the marked, else this one - the cursor stays where it was
--   /  D  S     search files / folders / the current view (in the search box too, after <Esc>); <a-s> while
--               typing: the next of the three; <Esc> steps back: box -> list -> tree -> closed
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

--- d: delete the marked items, else the one under the cursor, after asking - into the system trash where there is
--- one, as snacks does. The cursor stays on its item; when that one went, it takes the next one below that is still
--- there (a deleted folder took its contents along), else the nearest above. snacks kept only the row: marked items
--- above the cursor moved another item under it, and a buffer change after deleting an open file could move it too.
function M.delete(picker, item)
  local paths = vim.tbl_map(Snacks.picker.util.path, picker:selected({ fallback = true }))
  if #paths == 0 then return end
  local order, at = {}, picker.list.cursor -- the tree as it is now, to find the cursor's item afterwards
  for i = 1, picker.list:count() do order[i] = picker.list:get(i).file end
  local what = #paths == 1 and show(paths[1]) or (#paths .. " items")
  Snacks.picker.util.confirm("Delete " .. what .. "?", function()
    local actions, Tree = require("snacks.explorer.actions"), require("snacks.explorer.tree")
    for _, path in ipairs(paths) do
      local ok, err = actions.trash(path)
      if ok then
        Snacks.bufdelete({ file = path, force = true })
      else
        Snacks.notify.error("Failed to delete `" .. path .. "`:\n" .. err)
      end
      Tree:refresh(vim.fs.dirname(path))
    end
    picker.list:set_selected()
    local stay
    for i = at, #order do
      if vim.uv.fs_stat(order[i]) then stay = order[i]; break end
    end
    for i = at - 1, 1, -1 do
      if stay then break end
      if vim.uv.fs_stat(order[i]) then stay = order[i] end
    end
    -- scheduled twice: after the explorer followed a buffer change (an open file was deleted), which it schedules
    vim.schedule(function()
      vim.schedule(function()
        if not picker.closed then actions.update(picker, { target = stay }) end
      end)
    end)
  end)
end

-- ── Searching: files, folders, the current view (2026-10-21) ────────────────
-- snacks' explorer had one search: / listed every file and folder below the tree's root (fd) and matched the
-- typed text against their paths. Now there are three, and the search box's title says which one runs:
--   /   Search files          snacks' own, as before: files and folders, the text matches the path below the root
--   D   Search folders        only folders (fd --type d), the text matches a folder's name; no file is shown
--   S   Search current view   only the rows the tree showed when the search started (the open folders'
--                             contents); the text matches their names, closed folders are not looked into
-- / D S in the list, or in the search box when not typing (after <Esc>), start that search; during one they
-- switch to it with the same text (2026-10-21: / went back to the search box, D in the box was Vim's D and
-- deleted the text). While typing <a-s> goes on to the next one. Matches show up under their folders; <CR> on
-- one: the tree with the cursor on it. <Esc> steps back: typing -> the search box -> the list (the results stay)
-- -> the tree (the cursor where it was before the search) -> the explorer closes. snacks' second <Esc> closed
-- the explorer from the search box, and there was no way back to the tree but <CR> on a match.

local LABEL = { file = "Search files", folder = "Search folders", view = "Search current view" }
local NEXT = { file = "folder", folder = "view", view = "file" }
local searches = setmetatable({}, { __mode = "k" }) -- per explorer: { mode, title, before }

local function search_of(picker)
  local s = searches[picker]
  if not s then
    s = { mode = "file", title = picker.title } -- title: the explorer's own ("Explorer")
    searches[picker] = s
  end
  return s
end

local function searching(picker) return not picker.input.filter:is_empty() end

-- The search box's title names the search while there is one (or the box has the cursor), else it is the
-- explorer's own. A search that ended - no text left, the cursor out of the box - leaves file search next.
local function sync(picker)
  if picker.closed then return end
  local s = search_of(picker)
  local typing = picker.input.win:valid() and vim.api.nvim_get_current_win() == picker.input.win.win
  local on = typing or searching(picker)
  if not on then s.mode = "file" end
  local title = on and LABEL[s.mode] or s.title
  if picker.title ~= title then
    picker.title = title
    picker:update_titles()
  end
end

--- The explorer's config: snacks' own, then the searches' - the search box's title follows the search when
--- snacks switches between the tree and a search, and when the cursor goes in or out of the search box; the
--- item under the cursor when a search starts is where <Esc> goes back to. And closing it right after a find
--- leaves no error behind (below).
function M.setup(opts)
  opts = require("snacks.picker.source.explorer").setup(opts)
  local transform = opts.filter.transform
  opts.filter.transform = function(picker, filter)
    local was = filter.meta.searching
    local flipped = transform(picker, filter) -- true when it switched between the tree and a search
    if flipped and filter.meta.searching and not was then
      local item = picker:current() -- still the tree's
      search_of(picker).before = item and item.file
    end
    sync(picker)
    return flipped
  end
  local on_show = opts.on_show
  opts.on_show = function(picker)
    local ref = picker:ref()
    local function later() vim.schedule(function() if ref() then sync(ref()) end end) end
    picker.input.win:on({ "BufEnter", "BufLeave" }, function() later() end, { buf = true })
    if on_show then on_show(picker) end
  end
  -- Closing right after a find (a refresh, a cd, typing): snacks' cleanup (picker.lua, close) put a new task in
  -- place of the finder's last one, which still ran once - aborted, but not started yet. When it ended, snacks
  -- (finder.lua) took the new task for it, as not aborted, and resumed the matcher, gone by then: "attempt to
  -- index field 'matcher' (a nil value)" - a prompt, in the test window one that kept Neovim from quitting
  -- (2026-10-21; snacks' own, the searches here only made it likelier). The finder keeps its aborted task.
  local on_close = opts.on_close
  opts.on_close = function(picker)
    picker.finder.close = function(finder)
      finder.task:abort()
      finder._find = function() return {} end
    end
    if on_close then on_close(picker) end
  end
  return opts
end

-- Folder search: fd lists only folders (snacks' search, files.lua, lists files too and has no way to leave them
-- out). The tree is built as snacks' search builds it (picker/source/explorer.lua); the text matches the name.
local function folders(opts, ctx)
  local fd = require("snacks.picker.source.files").get_cmd("fd") -- fd or fdfind; says so when there is none
  if not fd then return function() end end
  local Tree, cwd = require("snacks.explorer.tree"), ctx.filter.cwd
  local args = { "--type", "d", "--color", "never", "-E", ".git", "--path-separator", "/" }
  if opts.hidden then args[#args + 1] = "--hidden" end
  if opts.ignored then args[#args + 1] = "--no-ignore" end
  if opts.follow then args[#args + 1] = "-L" end
  for _, glob in ipairs(opts.exclude or {}) do vim.list_extend(args, { "-E", glob }) end
  local pattern, extra = Snacks.picker.util.parse(ctx.filter.search) -- live search (<c-g>): fd matches names itself
  vim.list_extend(args, extra)
  vim.list_extend(args, { pattern ~= "" and pattern or ".", cwd })
  local list = require("snacks.picker.source.proc").proc({ cmd = fd, args = args, notify = false }, ctx)
  return function(cb)
    local root = { file = cwd, dir = true, open = true, text = "", sort = "" }
    local items, last = { [cwd] = root }, {}
    local function add(path)
      local parent, name = items[vim.fs.dirname(path)] or root, vim.fs.basename(path)
      local node = Tree:node(path)
      local item = {
        file = path, dir = true, open = true, parent = parent,
        text = name, -- what the typed text matches
        sort = parent.sort .. "!" .. name .. " ", -- the tree's order, as snacks sorts its search
        hidden = name:sub(1, 1) == ".",
        type = node and node.type or "directory",
        status = opts.git_status_open and node and node.status or nil,
      }
      if not last[parent] or last[parent].sort < item.sort then
        if last[parent] then last[parent].last = false end
        item.last, last[parent] = true, item
      end
      items[path] = item
      cb(item)
    end
    cb(root)
    list(function(line)
      local path = line.text:gsub("/$", "") -- fd ends a folder with /
      if items[path] then return end -- there already, as the parent of an earlier one
      for dir in Snacks.picker.util.parents(path, cwd) do
        if not items[dir] then add(dir) end
      end
      add(path)
    end)
  end
end

-- Current view: the rows the tree shows, nothing else; the text matches their names. They come from snacks' tree
-- finder as if nothing was typed: its open folders' contents, as on screen when the search started (a search
-- opens and closes no folder; after a cd it is the new root's tree). Copies, in the tree's order.
local KEEP = { "file", "dir", "open", "type", "hidden", "ignored", "status", "dir_status", "severity", "last" }
local function view(opts, ctx)
  local untyped = setmetatable({ pattern = "", search = "" }, { __index = ctx.filter })
  local tree = require("snacks.picker.source.explorer").explorer(opts, setmetatable({ filter = untyped }, { __index = ctx }))
  local search = vim.trim(ctx.filter.search) -- live search (<c-g>): a plain text here, case as smartcase
  local lower = search:lower() == search
  local function hit(name) return (lower and name:lower() or name):find(search, 1, true) ~= nil end
  return function(cb)
    local rows, want, copies = {}, {}, {}
    tree(function(row) rows[#rows + 1] = row end)
    for _, row in ipairs(rows) do
      if search == "" or (row.parent and hit(vim.fs.basename(row.file))) then
        local r = row -- with the folders above it
        while r and not want[r] do
          want[r] = true
          r = r.parent
        end
      end
    end
    for i, row in ipairs(rows) do
      if want[row] then
        local item = { sort = i }
        for _, key in ipairs(KEEP) do item[key] = row[key] end
        item.parent = row.parent and copies[row.parent] or nil
        item.text = item.parent and vim.fs.basename(row.file) or "" -- the root row: only there as the top
        copies[row] = item
        cb(item)
      end
    end
  end
end

--- The explorer's finder: the tree and file search are snacks' own; folder search and the current view are here.
function M.finder(opts, ctx)
  local E = require("snacks.picker.source.explorer")
  local mode = search_of(ctx.picker).mode
  if mode == "file" or ctx.filter:is_empty() then return E.explorer(opts, ctx) end
  E.get_state(ctx.picker):setup(ctx) -- as snacks' search starts: the open folders are watched
  local find = mode == "folder" and folders(opts, ctx) or view(opts, ctx)
  ctx.picker.matcher.opts.keep_parents = true -- a match shows up under its folders (after snacks' tree finder)
  ctx.picker.list:set_target()
  return find
end

-- Start a search in `mode` (during a search: switch to it, the text stays); typing in the search box again
local function search(picker, mode)
  local s = search_of(picker)
  if s.mode ~= mode then
    s.mode = mode
    if searching(picker) then picker:find() end -- the same text, found the other way
  end
  if vim.api.nvim_get_current_win() ~= picker.input.win.win then
    picker:focus("input", { show = true }) -- from the list: snacks starts typing in the box
  elseif vim.fn.mode() == "n" then
    vim.cmd("startinsert!") -- in the box after <Esc>: typing again, at the end of the text
  end
  sync(picker)
end

--- / - a file search (snacks' own); during a search: to it, with the same text
function M.search_files(picker) search(picker, "file") end

--- D - a folder search: only folders, the text matches their names
function M.search_folders(picker) search(picker, "folder") end

--- S - a search in the current view: only the rows the tree shows, the text matches their names
function M.search_view(picker) search(picker, "view") end

--- <a-s> while typing - the next search (files, folders, current view), the text stays
function M.search_next(picker) search(picker, NEXT[search_of(picker).mode]) end

--- <Esc> in the search box when not typing - to the list; the search and its results stay
function M.search_back(picker) picker:focus("list", { show = true }) end

--- <Esc> in the list - during a search: the search is over, the tree with the cursor where it was before it;
--- else snacks' own: the explorer closes
function M.search_leave(picker)
  if not searching(picker) then return require("snacks.picker.actions").cancel(picker) end
  require("snacks.explorer.actions").update(picker, { target = search_of(picker).before })
end

return M
