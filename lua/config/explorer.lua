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

-- The file buffers of `path` - its own, for a folder those of the files in it - by their paths. snacks asked bufnr(),
-- which takes a name for a pattern: for a folder it found a file in it, and [ ] in a name matched other names.
local function buffers_of(path)
  local found = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.bo[buf].buftype == "" and (eq(name, path) or inside(name, path)) then found[#found + 1] = buf end
  end
  return found
end

-- Why `path` stays where it is: buffers of it with unsaved changes (moving it would lose them), else nil
local function unsaved(path)
  local names = {}
  for _, buf in ipairs(buffers_of(path)) do
    if vim.bo[buf].modified then names[#names + 1] = vim.fs.basename(vim.api.nvim_buf_get_name(buf)) end
  end
  if #names == 0 then return nil end
  return ("%s: unsaved changes in %s - save them (:w) or drop them (:e!) first"):format(vim.fs.basename(path), table.concat(names, ", "))
end

-- The explorer's watchers on `path` and the folders in it end first: on Windows a watched folder can be neither deleted
-- nor moved - d and m on a folder whose subfolders were open in the tree failed (2026-10-21). The next listing watches
-- what is still there.
local function unwatch(path)
  local ok, watch = pcall(require, "snacks.explorer.watch")
  if not ok or type(watch._watches) ~= "table" then return end
  for watched in pairs(watch._watches) do
    if eq(watched, path) or inside(watched, path) then watch.stop(watched) end
  end
end

-- harpoon's slots of the moved: their new path, as harpoon writes one (relative to the working directory: the
-- config's create_list_item, plugins/editor.lua)
local function harpoon_moved(from, to)
  local ok, harpoon = pcall(require, "harpoon")
  if not ok then return end
  local list, changed = harpoon:list(), false
  for i = 1, list:length() do
    local item = list.items[i]
    if item and type(item.value) == "string" and item.value ~= "" then
      local path = vim.fs.normalize(vim.fn.fnamemodify(item.value, ":p"))
      local new = eq(path, from) and to or (inside(path, from) and to .. path:sub(#vim.fs.normalize(from) + 1)) or nil
      if new then
        item.value = list.config.create_list_item(list.config, vim.fs.normalize(new)).value
        changed = true
      end
    end
  end
  if changed then pcall(harpoon.sync, harpoon) end
end

--- A file or folder moved or renamed - by the explorer (m, r) or in an oil buffer (autocmds.lua): what points to it
--- follows - bookmarks, also of files not open, and harpoon's slots. They kept the old path: a slot opened an empty
--- new file there (2026-10-22).
function M.moved(from, to)
  pcall(function() require("config.bookmarks").moved(from, to) end)
  pcall(harpoon_moved, from, to)
end

-- Move a file or folder; its open buffers go along, in the same windows, the cursor where it was; language servers
-- hear of it (snacks). snacks' own move (rename.lua) did that for the buffer bufnr() found: for a folder a file in it,
-- which a buffer of the folder replaced. And it threw away a buffer with unsaved changes - callers check unsaved()
-- first (2026-10-21). vim.fn.rename(): another case of a name on Windows, and a file onto another drive, work too.
local function relocate(from, to)
  local ok = false
  Snacks.rename.on_rename_file(from, to, function()
    vim.fn.mkdir(vim.fs.dirname(to), "p")
    unwatch(from)
    ok = vim.fn.rename(from, to) == 0
    for _ = 1, WIN and not ok and 5 or 0 do -- Windows: a stopped watcher's handle on the folder can outlast it a moment
      vim.wait(100)
      ok = vim.fn.rename(from, to) == 0
      if ok then break end
    end
    if not ok then return end
    -- bookmarks and harpoon's slots go along - before the buffers at the new path load, so these find theirs
    M.moved(from, to)
    for _, buf in ipairs(buffers_of(from)) do
      local new = to .. vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):sub(#from + 1)
      local target = vim.fn.bufadd(new)
      if target == buf then
        -- Windows, another case of the name: the same buffer, only its name changes - edited again (it has no
        -- unsaved changes), so :w writes without "file exists"
        vim.api.nvim_buf_set_name(buf, new)
        if vim.api.nvim_buf_is_loaded(buf) then vim.api.nvim_buf_call(buf, function() vim.cmd("silent! edit!") end) end
      else
        vim.bo[target].buflisted = vim.bo[buf].buflisted
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
          local cursor = vim.api.nvim_win_get_cursor(win)
          vim.api.nvim_win_set_buf(win, target)
          pcall(vim.api.nvim_win_set_cursor, win, cursor)
        end
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end)
  if not ok then Snacks.notify.error("Could not move " .. show(from) .. " to " .. show(to), { title = "Explorer" }) end
  return ok
end

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
    elseif not copying and unsaved(from) then
      stay[#stay + 1] = unsaved(from)
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
      relocate(mv.from, mv.to) -- open buffers and language servers follow
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
  if unsaved(from) then return warn(unsaved(from)) end
  local base = vim.fs.normalize(vim.fn.getcwd(0))
  if not inside(from, base) then base = vim.fs.dirname(from) end
  local shown = from:sub(#base + 2)
  Snacks.input({ prompt = "Rename / move to (from " .. show(base) .. ", or an absolute path)", default = shown, completion = "file" },
    function(value)
      if not value or vim.trim(value) == "" or value == shown then return end
      local to = into(from, M.resolve(base, value))
      -- the same path; another case of the name is a new name (on Windows the same file: M.same below)
      if to == from then return end
      if inside(to, from) then return warn(vim.fs.basename(from) .. ": not into itself") end
      if vim.uv.fs_stat(to) and not M.same(to, from) then return warn(show(to) .. " exists - nothing overwritten") end
      if relocate(from, to) then refresh(picker, { vim.fs.dirname(from), vim.fs.dirname(to) }, to) end
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

-- ── Rename by regex (%, 2026-10-22) ──

--- s/regex/replacement/flags - any delimiter after the s, as sed's (s#a/b#c#), a \ before it: the delimiter itself;
--- the last one may be left out. { regex, replacement, global (g: every match), ignore_case (i) } or nil and why.
function M.parse_substitution(text)
  text = vim.trim(text or "")
  local d = text:match("^s([^%w%s\\])")
  if not d then return nil, "not s/regex/replacement/" end
  local parts, cur, i = {}, {}, 3
  while i <= #text do
    local c = text:sub(i, i)
    if c == "\\" and i < #text then
      local n = text:sub(i + 1, i + 1)
      cur[#cur + 1] = n == d and n or (c .. n)
      i = i + 2
    elseif c == d and #parts < 2 then
      parts[#parts + 1], cur, i = table.concat(cur), {}, i + 1
    else
      cur[#cur + 1], i = c, i + 1
    end
  end
  local regex, replacement, flags
  if #parts == 2 then
    regex, replacement, flags = parts[1], parts[2], table.concat(cur)
  elseif #parts == 1 then
    regex, replacement, flags = parts[1], table.concat(cur), ""
  else
    return nil, "not s/regex/replacement/"
  end
  if regex == "" then return nil, "the regex is empty" end
  if flags:find("[^gi]") then return nil, "flags: g (every match), i (case ignored)" end
  return { regex = regex, replacement = replacement, global = flags:find("g") ~= nil, ignore_case = flags:find("i") ~= nil }
end

-- $n and ${n} of a replacement for groups `by` further on; $$ and names stay
local function shift_groups(replacement, by)
  local out, i = {}, 1
  while i <= #replacement do
    local c, n = replacement:sub(i, i), replacement:sub(i + 1, i + 1)
    if c == "$" and n == "$" then
      out[#out + 1], i = "$$", i + 2
    elseif c == "$" and n == "{" and replacement:find("}", i + 2, true) then
      local close = replacement:find("}", i + 2, true)
      local ref = replacement:sub(i + 2, close - 1)
      out[#out + 1] = ref:match("^%d+$") and ("${" .. (tonumber(ref) + by) .. "}") or replacement:sub(i, close)
      i = close + 1
    elseif c == "$" and n:match("%d") then
      local digits = replacement:match("^%d+", i + 1)
      out[#out + 1], i = "${" .. (tonumber(digits) + by) .. "}", i + 1 + #digits
    else
      out[#out + 1], i = c, i + 1
    end
  end
  return table.concat(out)
end

--- The names after a substitution (M.parse_substitution) - rg does it, the same Rust regex as the search: $1 /
--- ${name} / $0 in the replacement. As sed: the first match of a name, every one with g. nil and why for a regex
--- rg cannot read.
function M.substitute(names, sub)
  local rg = vim.fn.exepath("rg")
  if rg == "" then return nil, "ripgrep (rg) is needed" end
  local regex, replacement = sub.regex, sub.replacement
  if not sub.global then -- the first match only: rg replaces every one - so the match from the start, the text before it kept
    regex, replacement = "^(.*?)(" .. regex .. ")", "${1}" .. shift_groups(replacement, 2)
  end
  local r = vim.system({ rg, "--no-config", "--passthru", "--no-line-number", "--no-filename", "--color", "never",
    sub.ignore_case and "--ignore-case" or "--case-sensitive", "--replace=" .. replacement, "--regexp=" .. regex, "-" },
    { stdin = table.concat(names, "\n") .. "\n", text = true }):wait(10000)
  if r.code == 2 then
    local last = vim.trim((r.stderr or ""):match("([^\n]*)%s*$") or "")
    local msg = last:gsub("^error:%s*", "")
    return nil, msg ~= "" and msg or "not a regex"
  end
  local out = vim.split((r.stdout or ""):gsub("\r", ""), "\n", { plain = true })
  if out[#out] == "" then table.remove(out) end
  if #out ~= #names then return nil, ("rg gave %d names for %d"):format(#out, #names) end
  return out
end

--- %: rename the marked items (else the one under the cursor) by regex - s/regex/replacement/ on their names: the
--- first match, g every one, i case ignored; $1 / ${name} in the replacement. The new names are listed, then yes /
--- no. One that would leave its folder, be another's too or land on something that exists stays as it is. Open
--- buffers, language servers, bookmarks and harpoon slots follow, as with r. The last one comes back as the default.
function M.rename_regex(picker, item)
  local items = picker:selected()
  if #items == 0 then items = { item } end
  local froms = {}
  for _, it in ipairs(items) do
    local from = path_of(it)
    if from and not eq(from, picker:cwd()) then froms[#froms + 1] = from end
  end
  if #froms == 0 then return warn("Nothing to rename - mark items (<Tab>, Ctrl+a in a search)") end
  local what_ = #froms == 1 and vim.fs.basename(froms[1]) or (#froms .. " items")
  Snacks.input({ prompt = "Rename " .. what_ .. " by regex: s/regex/replacement/ (g, i)", default = M.last_substitution or "s/" }, function(value)
    if not value or vim.trim(value) == "" or vim.trim(value) == "s/" then return end
    local sub, why = M.parse_substitution(value)
    if not sub then return warn(why) end
    M.last_substitution = vim.trim(value)
    local names = vim.tbl_map(vim.fs.basename, froms)
    local new, err = M.substitute(names, sub)
    if not new then return warn("Regex: " .. err) end
    local todo, stay, by_target = {}, {}, {}
    for i, from in ipairs(froms) do
      local name = new[i]
      if name ~= names[i] then
        local to = vim.fs.normalize(vim.fs.dirname(from) .. "/" .. name)
        if name == "" or name == "." or name == ".." or name:find("[/\\]") then
          stay[#stay + 1] = ("%s: %q is no name in its folder (m moves)"):format(names[i], name)
        elseif unsaved(from) then
          stay[#stay + 1] = unsaved(from)
        elseif vim.uv.fs_stat(to) and not M.same(to, from) then
          stay[#stay + 1] = show(to) .. " exists - nothing overwritten"
        elseif by_target[key(to)] then
          local other = by_target[key(to)]
          other.clash = true
          stay[#stay + 1] = ("%s and %s would both be %s"):format(vim.fs.basename(other.from), names[i], name)
        else
          by_target[key(to)] = { from = from, to = to }
          todo[#todo + 1] = by_target[key(to)]
        end
      end
    end
    todo = vim.tbl_filter(function(t) return not t.clash end, todo)
    if #stay > 0 then warn(table.concat(stay, "\n")) end
    if #todo == 0 then
      if #stay == 0 then notify("No name changes: " .. M.last_substitution .. " matched none") end
      return
    end
    local lines = {}
    for i, t in ipairs(todo) do
      if i > 15 then
        lines[#lines + 1] = ("… and %d more"):format(#todo - 15)
        break
      end
      lines[#lines + 1] = vim.fs.basename(t.from) .. "  →  " .. vim.fs.basename(t.to)
    end
    local id = "greyknight.rename_regex"
    Snacks.notify(table.concat(lines, "\n"), { id = id, title = "Rename by regex", timeout = 15000 })
    Snacks.picker.util.confirm(("Rename %s as listed?"):format(#todo == 1 and vim.fs.basename(todo[1].from) or (#todo .. " items")), function()
      Snacks.notifier.hide(id)
      table.sort(todo, function(a, b) return #a.from > #b.from end) -- a file in a folder renamed too goes first
      local dirs = {}
      for _, t in ipairs(todo) do
        relocate(t.from, t.to) -- open buffers, language servers, bookmarks, harpoon slots follow
        dirs[#dirs + 1] = vim.fs.dirname(t.from)
      end
      picker.list:set_selected()
      refresh(picker, dirs, todo[#todo].to)
    end)
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
    local function gone(path) -- its buffers - for a folder those of the files in it (snacks closed only one named
      local bufs = {}         -- like the path itself)
      for _, buf in ipairs(buffers_of(path)) do bufs[buf] = true end
      if next(bufs) then Snacks.bufdelete({ filter = function(buf) return bufs[buf] end, force = true }) end
    end
    local function finish() -- the cursor on its item, or the next one still there below it, else above
      picker.list:set_selected()
      local stay
      for i = at, #order do
        if vim.uv.fs_lstat(order[i]) then stay = order[i]; break end
      end
      for i = at - 1, 1, -1 do
        if stay then break end
        if vim.uv.fs_lstat(order[i]) then stay = order[i] end
      end
      -- scheduled twice: after the explorer followed a buffer change (an open file was deleted), which it schedules
      vim.schedule(function()
        vim.schedule(function()
          if not picker.closed then actions.update(picker, { target = stay }) end
        end)
      end)
    end
    local refused = {}
    for _, path in ipairs(paths) do
      unwatch(path)
      local ok, err = actions.trash(path)
      for _ = 1, WIN and not ok and 5 or 0 do -- as in relocate(): a watcher's handle can outlast its stop a moment
        vim.wait(100)
        ok, err = actions.trash(path)
        if ok then break end
      end
      if ok then gone(path) else refused[#refused + 1] = { path = path, err = tostring(err) } end
      Tree:refresh(vim.fs.dirname(path))
    end
    finish()
    if #refused == 0 then return end
    -- The trash refused - gio does on /tmp ("Trashing on system internal mounts is not supported"), and d deleted
    -- nothing there but said so as an error (2026-10-22): for good then, after asking. delete() takes a link itself,
    -- never what it points to.
    local reason = vim.trim(refused[1].err:match("([^:\n]+)%s*$") or refused[1].err)
    local which = #refused == 1 and show(refused[1].path) or (#refused .. " items")
    Snacks.picker.util.confirm(("%s cannot go to the trash here (%s) - delete for good?"):format(which, reason), function()
      for _, r in ipairs(refused) do
        unwatch(r.path)
        if vim.fn.delete(r.path, "rf") == 0 then gone(r.path) else Snacks.notify.error("Failed to delete `" .. r.path .. "`") end
        Tree:refresh(vim.fs.dirname(r.path))
      end
      finish()
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
-- Regex (2026-10-22): R searches files by regex, Alt+r in the search box switches the file and folder search between
-- fuzzy and regex - it stays so until switched back. The text goes to fd then: a Rust regex (\d \w \b (?i) (a|b)
-- {2,3}; no lookaround, no backreferences) against the name, or - when it has a / - the path below the tree's root;
-- a text with a * and nothing only a regex has is a glob (*.sh, test_*.py, *.{sh,bash}; with a /: below the root, as
-- in .gitignore). The title says which: "Search files (regex)", "(glob)", "(regex: unclosed group)". Ctrl+a marks
-- the matches of a search - not the folders shown above them - for m / c / d.

local LABEL = { file = "Search files", folder = "Search folders", view = "Search current view" }
local NEXT = { file = "folder", folder = "view", view = "file" }
local searches = setmetatable({}, { __mode = "k" }) -- per explorer: { mode, title, before, error, checked }

--- Regex (and glob) search for files and folders instead of fuzzy: R turns it on, Alt+r switches; for the session
M.regex = false

local function search_of(picker)
  local s = searches[picker]
  if not s then
    s = { mode = "file", title = picker.title } -- title: the explorer's own ("Explorer")
    searches[picker] = s
  end
  return s
end

local function searching(picker) return not picker.input.filter:is_empty() end

-- Back to the tree with the cursor on `target` (<CR> on a match, <Esc> to where the search started). snacks
-- (explorer/actions.lua, update) puts it there when its find is done - but a find started meanwhile replaced that one,
-- the watcher's refresh after a change on disk (batched, 100 ms later) for one, and the cursor stayed on the row
-- number it had in the search list: <CR> on alpha/beta/gamma left it on alpha/beta (2026-10-21, in the tests 1 in 5
-- runs on Kali). Now the first find to finish in the tree puts it there (setup, on_show).
local reveals = setmetatable({}, { __mode = "k" }) -- per explorer: the path the cursor goes to
local function to_tree(picker, target)
  reveals[picker] = target
  require("snacks.explorer.actions").update(picker, { target = target })
end

--- A glob, not a regex: a * in it and nothing only a regex has (\ ^ $ ( ) | + .*) - *.sh, test_*.py, *.{sh,bash}.
--- A ? alone keeps it a regex (colou?r).
function M.is_glob(text)
  return text:find("*", 1, true) ~= nil and not text:find("[\\%^%$%(%)|%+]") and not text:find(".*", 1, true)
end

-- The search box's title names the search while there is one (or the box has the cursor), else it is the
-- explorer's own; a regex or glob search says so, a regex fd cannot read says why. A search that ended - no text
-- left, the cursor out of the box - leaves file search next.
local function sync(picker)
  if picker.closed then return end
  local s = search_of(picker)
  local typing = picker.input.win:valid() and vim.api.nvim_get_current_win() == picker.input.win.win
  local on = typing or searching(picker)
  if not on then s.mode = "file" end
  local title = on and LABEL[s.mode] or s.title
  if on and picker.opts.live and s.mode ~= "view" then
    local glob = M.is_glob(vim.trim(picker.input.filter.search))
    title = ("%s (%s%s)"):format(title, glob and "glob" or "regex", (not glob and s.error) and (": " .. s.error) or "")
  end
  if picker.title ~= title then
    picker.title = title
    picker:update_titles()
  end
end

-- Folders that cannot be read (EPERM / EACCES: Windows' legacy junctions in the home folder like "Anwendungsdaten",
-- another user's folder): opened in the tree they stay empty, and watching them was an error each time ("Failed to
-- watch ...: EPERM", 2026-10-21, the Windows error log). They are not watched now, and the first time a word says
-- why they are empty. One that is gone is left out without a word.
local unreadable = {}
local function guard_watch()
  local watch = require("snacks.explorer.watch")
  if watch.gk_guarded then return end
  watch.gk_guarded = true
  local start = watch.start
  watch.start = function(path, cb)
    local fs, err = vim.uv.fs_scandir(path)
    if fs then return start(path, cb) end
    if not unreadable[path] and not tostring(err):find("ENOENT", 1, true) then
      unreadable[path] = true
      notify(("%s cannot be read (%s) - it stays empty"):format(show(path), tostring(err)))
    end
  end
end

--- The explorer's config: snacks' own, then the searches' - the search box's title follows the search when
--- snacks switches between the tree and a search, and when the cursor goes in or out of the search box; the
--- item under the cursor when a search starts is where <Esc> goes back to, and <CR> on a match and <Esc> get the
--- cursor there also when a refresh comes in between. Marks go by path. And closing it right after a find leaves
--- no error behind (below).
function M.setup(opts)
  guard_watch()
  opts = require("snacks.picker.source.explorer").setup(opts)
  local transform = opts.filter.transform
  opts.filter.transform = function(picker, filter)
    local was = filter.meta.searching
    local flipped = transform(picker, filter) -- true when it switched between the tree and a search
    if flipped and filter.meta.searching and not was then
      local item = picker:current() -- still the tree's
      search_of(picker).before = item and item.file
      reveals[picker] = nil -- a new search: the cursor stays where it is
    end
    sync(picker)
    return flipped
  end
  -- <CR> on a match: snacks' own (to the tree, the cursor on it), sure to get there (to_tree)
  local confirm = opts.actions.confirm
  opts.actions.confirm = function(picker, item, action)
    if item and picker.input.filter.meta.searching then return to_tree(picker, item.file) end
    return confirm(picker, item, action)
  end
  -- Marks (<Tab>) by path. snacks keyed them by the item's text, which is the full path in the tree, the path below
  -- the root in file search and the name in folder and view search: a file marked in a search was not marked in the
  -- tree, and <Tab> on it there marked it a second time - m moved it twice (2026-10-21)
  local item_transform = Snacks.picker.config.transform(opts)
  opts.transform = function(item, ctx)
    item._select_key = item.file
    if item_transform then return item_transform(item, ctx) end
  end
  local on_show = opts.on_show
  opts.on_show = function(picker)
    local ref = picker:ref()
    local function later() vim.schedule(function() if ref() then sync(ref()) end end) end
    picker.input.win:on({ "BufEnter", "BufLeave" }, function() later() end, { buf = true })
    -- every find that finishes (not one that a later find replaced) - in the tree, the cursor to where to_tree sends it
    local done = picker.matcher.opts.on_done
    picker.matcher.opts.on_done = function(matcher)
      if done then done(matcher) end
      local p = ref()
      local target = p and reveals[p]
      if target and not p.closed and not p:is_active() and p.input.filter:is_empty() then
        reveals[p] = nil
        require("snacks.explorer.actions").reveal(p, target)
      end
    end
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
  require("config.slots").add_keys(opts) -- !1 .. !9 and !!: script slots (config/slots.lua)
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
    local rows, want, copies, hits = {}, {}, {}, {}
    tree(function(row) rows[#rows + 1] = row end)
    for _, row in ipairs(rows) do
      if search == "" or (row.parent and hit(vim.fs.basename(row.file))) then
        hits[row] = search ~= "" -- a match; the folders above it only come along (Ctrl+a marks matches)
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
        item.gk_hit = hits[row] or nil
        copies[row] = item
        cb(item)
      end
    end
  end
end

-- ── Regex and glob search (fd) ──
local function regex_escape(s) return (s:gsub("[\\%.%+%*%?%(%)|%[%]{}%^%$]", "\\%0")) end

-- A / of the text as Windows' paths have it too (fd matches the full path with \ there): [/\\] - in a [...] class
-- the \ goes in beside it
local function both_slashes(text)
  local out, i, class = {}, 1, false
  while i <= #text do
    local c, n = text:sub(i, i), text:sub(i + 1, i + 1)
    if c == "\\" and n ~= "" then
      out[#out + 1] = n == "/" and (class and "/\\\\" or "[/\\\\]") or (c .. n)
      i = i + 2
    else
      if class and c == "]" then class = false elseif not class and c == "[" then class = true end
      out[#out + 1] = c == "/" and (class and "/\\\\" or "[/\\\\]") or c
      i = i + 1
    end
  end
  return table.concat(out)
end

--- The regex for fd --full-path (an absolute path) from one for the path below root: ^ anchors at the root, else it
--- matches anywhere in that path. win: separators may be \ too, the root's case does not count.
function M.regex_below(text, root, win)
  local sep = win and "[/\\\\]" or "/"
  local parts = vim.split(vim.fs.normalize(root):gsub("/+$", ""), "/", { plain = true })
  local prefix = table.concat(vim.tbl_map(regex_escape, parts), sep)
  if win then prefix = "(?i:" .. prefix .. ")" end
  local body = win and both_slashes(text) or text
  if body:sub(1, 1) == "^" then return "^" .. prefix .. sep .. "(?:" .. body:sub(2) .. ")" end
  return "^" .. prefix .. sep .. ".*?(?:" .. body .. ")"
end

--- A glob as a regex for a path: **/ any depth, * and ? within a folder, [!x] [^x], {a,b} (?:a|b). fd's own globs do
--- not match a full path with Windows' \ (2026-10-22: src/*.ts found nothing there).
function M.glob_to_regex(glob)
  local out, i, braces = {}, 1, 0
  while i <= #glob do
    local c = glob:sub(i, i)
    if c == "*" and glob:sub(i, i + 2) == "**/" then
      out[#out + 1], i = "(?:.*/)?", i + 3
    elseif c == "*" and glob:sub(i + 1, i + 1) == "*" then
      out[#out + 1], i = ".*", i + 2
    elseif c == "*" then
      out[#out + 1], i = "[^/]*", i + 1
    elseif c == "?" then
      out[#out + 1], i = "[^/]", i + 1
    elseif c == "[" and glob:find("]", i + 2, true) then
      local close = glob:find("]", i + 2, true)
      local class = glob:sub(i + 1, close - 1):gsub("^!", "^"):gsub("\\", "\\\\")
      out[#out + 1], i = "[" .. class .. "]", close + 1
    elseif c == "{" then
      out[#out + 1], i, braces = "(?:", i + 1, braces + 1
    elseif c == "}" and braces > 0 then
      out[#out + 1], i, braces = ")", i + 1, braces - 1
    elseif c == "," and braces > 0 then
      out[#out + 1], i = "|", i + 1
    else
      out[#out + 1], i = regex_escape(c), i + 1
    end
  end
  return table.concat(out)
end

--- fd's arguments for a regex or glob search below root: the text against the name, or with a / against the path
--- below the root. Smart case from the text. o: { type = "f" | "d", hidden, ignored, follow, exclude, win }
---@return string[] args
---@return "regex"|"glob" kind
function M.fd_args(text, root, o)
  o = o or {}
  local win = o.win
  if win == nil then win = WIN end
  local glob = M.is_glob(text)
  local args = { "--type", o.type or "f", "--color", "never", "-E", ".git", "--path-separator", "/" }
  if o.hidden then args[#args + 1] = "--hidden" end
  if o.ignored then args[#args + 1] = "--no-ignore" end
  if o.follow then args[#args + 1] = "-L" end
  for _, g in ipairs(o.exclude or {}) do vim.list_extend(args, { "-E", g }) end
  args[#args + 1] = text:find("%u") and "--case-sensitive" or "--ignore-case"
  local pattern, how = text, glob and "--glob" or "--regex"
  if text:find("/", 1, true) then
    args[#args + 1] = "--full-path"
    -- a glob with a / is relative to the root, as in .gitignore - as the regex it is (glob_to_regex)
    if glob then pattern = "^" .. M.glob_to_regex((text:gsub("^/+", ""))) .. "$" end
    pattern, how = M.regex_below(pattern, root, win), "--regex"
  end
  vim.list_extend(args, { how, "--", pattern, root })
  return args, glob and "glob" or "regex"
end

-- Whether fd can read the regex: rg reads the same (both Rust's regex) and says what is wrong - in the title. Later,
-- for the text then typed only.
local function validate(picker, text)
  local s = search_of(picker)
  if s.checked == text then return end
  local had = s.error
  s.checked, s.error = text, nil
  if had then vim.schedule(function() sync(picker) end) end -- the title without the last text's error
  local rg = vim.fn.exepath("rg")
  if M.is_glob(text) or rg == "" then return end
  vim.system({ rg, "--no-config", "--quiet", "-e", text, "-" }, { stdin = "", text = true }, function(r)
    vim.schedule(function()
      if picker.closed or s.checked ~= text then return end
      if r.code == 2 then -- rg's last line: "error: unclosed group"
        local last = vim.trim((r.stderr or ""):match("([^\n]*)%s*$") or "")
        local msg = last:gsub("^error:%s*", "")
        s.error = msg ~= "" and msg or "not a regex"
        sync(picker)
      end
    end)
  end)
end

-- Files (kind "f") or folders ("d") fd finds for the typed regex or glob, under the folders they are in; the matches
-- carry gk_hit (Ctrl+a marks those), the folders above them are only there for the tree
local function regex_find(opts, ctx, kind)
  local fd = require("snacks.picker.source.files").get_cmd("fd") -- fd or fdfind; says so when there is none
  local text = vim.trim(ctx.filter.search)
  if not fd or text == "" then return function() end end
  validate(ctx.picker, text)
  local Tree, cwd = require("snacks.explorer.tree"), ctx.filter.cwd
  local args = M.fd_args(text, cwd, { type = kind, hidden = opts.hidden, ignored = opts.ignored, follow = opts.follow, exclude = opts.exclude })
  local list = require("snacks.picker.source.proc").proc({ cmd = fd, args = args, notify = false }, ctx)
  return function(cb)
    local root = { file = cwd, dir = true, open = true, text = "", sort = "" }
    local items, last = { [cwd] = root }, {}
    local function add(path, dir, hit)
      local parent, name = items[vim.fs.dirname(path)] or root, vim.fs.basename(path)
      local node = Tree:node(path)
      local item = {
        file = path, dir = dir, open = dir or nil, parent = parent, text = name, gk_hit = hit,
        sort = parent.sort .. (dir and "!" or "#") .. name .. " ", -- the tree's order, as snacks sorts its search
        hidden = name:sub(1, 1) == ".",
        type = node and node.type or (dir and "directory" or "file"),
        status = node and (not dir or opts.git_status_open) and node.status or nil,
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
      if items[path] then -- there already, as the folder above an earlier match
        items[path].gk_hit = true
        return
      end
      for dir in Snacks.picker.util.parents(path, cwd) do
        if not items[dir] then add(dir, true, nil) end
      end
      add(path, kind == "d", true)
    end)
  end
end

--- The explorer's finder: the tree and file search are snacks' own; folder search, the current view and the regex
--- searches (the picker is live then: the text goes to the finder) are here.
function M.finder(opts, ctx)
  local E = require("snacks.picker.source.explorer")
  local mode = search_of(ctx.picker).mode
  local regex = ctx.picker.opts.live and mode ~= "view"
  if ctx.filter:is_empty() or (mode == "file" and not regex) then return E.explorer(opts, ctx) end
  E.get_state(ctx.picker):setup(ctx) -- as snacks' search starts: the open folders are watched
  local find
  if regex then
    find = regex_find(opts, ctx, mode == "folder" and "d" or "f")
  else
    find = mode == "folder" and folders(opts, ctx) or view(opts, ctx)
  end
  ctx.picker.matcher.opts.keep_parents = true -- a match shows up under its folders (after snacks' tree finder)
  ctx.picker.list:set_target()
  return find
end

-- Regex or fuzzy: the picker live (the typed text goes to the finder, snacks' matcher stays out) or not - the text in
-- the box stays (snacks' toggle_live showed the other one it keeps)
local function set_live(picker, live)
  if picker.opts.live == live then return end
  local f = picker.input.filter
  local text = picker.opts.live and f.search or f.pattern -- what the box shows (hidden when no search runs)
  picker.opts.live = live
  f.pattern, f.search = live and "" or text, live and text or ""
  if picker.input.win:valid() then picker.input:set(f.pattern, f.search) end
end

-- Start a search in `mode` (during a search: switch to it, the text stays); typing in the search box again. regex:
-- true / false switches regex search on / off (R, Alt+r), nil keeps it
local function search(picker, mode, regex)
  local s = search_of(picker)
  if regex ~= nil then M.regex = regex end
  local live = M.regex and mode ~= "view"
  if s.mode ~= mode or picker.opts.live ~= live then
    s.mode = mode
    set_live(picker, live)
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
  to_tree(picker, search_of(picker).before)
end

--- R - a file search by regex (a glob too: *.sh); regex search stays on until Alt+r
function M.search_regex(picker) search(picker, "file", true) end

--- Alt+r in the search box - the file or folder search by regex, or fuzzy again; the text stays. In the current
--- view (names, plain text): a file search by regex.
function M.regex_toggle(picker)
  local mode = search_of(picker).mode
  search(picker, mode == "view" and "file" or mode, not M.regex)
end

-- A match of the search, not one of the folders above them: a file search's files, a folder search's folders, a
-- row of the current view that matched. Fuzzy: snacks' matcher says which rows only came along (child_match_only).
local function match(picker, item)
  if not item.parent then return false end -- the root
  local mode = search_of(picker).mode
  if mode == "view" or picker.opts.live then return item.gk_hit == true end
  return (item.score or 0) > 0 and not item.child_match_only and (item.dir == true) == (mode == "folder")
end

--- The paths a search shows as matches (not the folders above them) - what Ctrl+a marks
function M.matches(picker)
  local list = {}
  for item in picker:iter() do
    if match(picker, item) then list[#list + 1] = item.file end
  end
  return list
end

--- A search started for the agent (integrations/agent_tools.lua, show_in_file_tree): files or folders, fuzzy or regex
--- (the user's R / Alt+r stays as it was), the text in the box - shown, the cursor stays in the list.
--- Done when it found: on_done(picker).
function M.search_for(picker, text, opts, on_done)
  opts = opts or {}
  local function run()
    local s = search_of(picker)
    if not searching(picker) then
      local item = picker:current()
      s.before = item and item.file -- <Esc> goes back there
    end
    s.mode = opts.folders and "folder" or "file"
    set_live(picker, opts.regex == true)
    local f = picker.input.filter
    if picker.opts.live then f.pattern, f.search = "", text else f.pattern, f.search = text, "" end
    picker.input:set(f.pattern, f.search)
    picker:find()
    sync(picker)
    local started = vim.uv.now()
    local function wait()
      if picker.closed then return end
      if vim.uv.now() - started < 150 or picker:is_active() then return vim.defer_fn(wait, 50) end
      if on_done then on_done(picker) end
    end
    vim.defer_fn(wait, 50)
  end
  if picker.input.win:valid() then return run() end
  picker:toggle("input", { enable = true, focus = "list" }) -- the box is hidden while no search runs
  local tries = 0
  local function shown()
    tries = tries + 1
    if picker.input.win:valid() then return run() end
    if tries < 100 then vim.defer_fn(shown, 20) end
  end
  vim.defer_fn(shown, 20)
end

--- For the agent too: the tree with the cursor on `path` - a search running ends first (snacks' reveal opens the
--- explorer when it is not, and widens its root when the path is outside). Returns the explorer.
function M.show(path)
  local picker = Snacks.picker.get({ source = "explorer" })[1]
  if picker and not picker.closed and searching(picker) then
    set_live(picker, false)
    picker.input.filter.pattern, picker.input.filter.search = "", ""
    if picker.input.win:valid() then picker.input:set("", "") end
    search_of(picker).mode = "file"
  end
  picker = Snacks.explorer.reveal({ file = path })
  if picker then reveals[picker] = path end -- a refresh in between does not leave the cursor elsewhere (to_tree)
  return picker
end

--- Ctrl+a - in a search: marks its matches, the files of a file search, the folders of a folder search; not the
--- folders above them - snacks' select_all marked those too, and d deleted them whole. Again: unmarks them. Marks
--- of before stay. Outside a search: snacks' own (every row).
function M.mark_matches(picker)
  if not searching(picker) then return picker.list:select_all() end
  local hits = {}
  for item in picker:iter() do
    if match(picker, item) then hits[#hits + 1] = item end
  end
  if #hits == 0 then return notify("Nothing to mark - no match") end
  local all = true
  for _, item in ipairs(hits) do all = all and picker.list:is_selected(item) end
  local keys, selected = {}, {}
  for _, item in ipairs(hits) do keys[picker.list:select_key(item)] = true end
  for _, item in ipairs(picker.list.selected) do
    if not (all and keys[picker.list:select_key(item)]) then selected[#selected + 1] = item end
  end
  if not all then
    for _, item in ipairs(hits) do
      if not picker.list:is_selected(item) then selected[#selected + 1] = item end
    end
  end
  picker.list:set_selected(selected)
  notify(("%s %d match%s - m / c / d act on the marked"):format(all and "Unmarked" or "Marked", #hits, #hits == 1 and "" or "es"))
end

return M
