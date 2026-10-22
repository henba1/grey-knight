-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Bookmarks: lines to come back to, per project - IntelliJ's ║
-- ║  F11 / Shift+F11. A ⚑ in the sign column; the list opens    ║
-- ║  the file at the line                                        ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Kept in stdpath("data")/bookmarks.json by project (Neovim's directory, as the sessions are). A bookmark moves with its
-- line while you edit; deleting the line deletes it once the file is saved (undo before that brings both back). Changed
-- outside Neovim (git pull, another editor), a file's bookmarks find their lines again by their text when it is opened.
local M = {}

M.file = vim.fn.stdpath("data") .. "/bookmarks.json" -- the tests use their own
M.SIGN = "⚑"

local NS = vim.api.nvim_create_namespace("greyknight.bookmarks")
local WIN = vim.fn.has("win32") == 1
local HINT = " - <leader>mm sets one on the cursor's line"

-- this project's bookmarks: { file, line, name?, text? } - text is the line's, to find it again; buf and id: its sign
local state = { project = nil, list = {} }

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Bookmarks" }) end
local function full(path) return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")) end
local function key(path) local p = full(path); return WIN and p:lower() or p end -- Windows: case does not count
local function project() return key(vim.fn.getcwd(-1, -1)) end -- the global directory, not a window's :lcd

--- The file a buffer shows - none for a terminal, the explorer, help ...
local function file_of(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return nil end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and full(name) or nil
end

local function read_all()
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(M.file), "\n")) end)
  if not ok or type(data) ~= "table" then data = {} end
  if type(data.projects) ~= "table" then data.projects = {} end
  return data
end

--- The project's bookmarks into the file; the other projects' stay as the file has them (another Neovim's changes)
function M.save()
  if not state.project then return end
  local data = read_all()
  local list = {}
  for _, b in ipairs(state.list) do list[#list + 1] = { file = b.file, line = b.line, name = b.name, text = b.text } end
  data.projects[state.project] = #list > 0 and list or nil
  data.version = 1
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(M.file), "p")
    assert(vim.fn.writefile({ vim.json.encode(data) }, M.file) == 0, "cannot write " .. M.file)
  end)
  if not ok then notify("Bookmarks not saved: " .. tostring(err), vim.log.levels.WARN) end
end

local function unmark(b)
  if b.buf and b.id and vim.api.nvim_buf_is_valid(b.buf) then pcall(vim.api.nvim_buf_del_extmark, b.buf, NS, b.id) end
  b.buf, b.id = nil, nil
end

local function mark(b, buf)
  unmark(b)
  b.line = math.min(math.max(b.line, 1), vim.api.nvim_buf_line_count(buf))
  b.buf = buf
  -- invalidate: the sign goes with its line, undo brings it back
  b.id = vim.api.nvim_buf_set_extmark(buf, NS, b.line - 1, 0, {
    sign_text = M.SIGN, sign_hl_group = "GreyKnightBookmark", priority = 20, invalidate = true,
  })
end

--- A bookmark whose file changed outside Neovim: the nearest line with its text
local function relocate(b, lines)
  local text = b.text and vim.trim(b.text) or ""
  if text == "" or (lines[b.line] and vim.trim(lines[b.line]) == text) then return end
  for d = 1, #lines do
    for _, i in ipairs({ b.line - d, b.line + d }) do
      if lines[i] and vim.trim(lines[i]) == text then
        b.line = i
        return
      end
    end
  end
end

--- Signs for the bookmarks of the file in buf, their lines as the file has them now
function M.place(buf)
  local file = file_of(buf)
  if not file or not vim.api.nvim_buf_is_loaded(buf) then return end
  local k, lines, moved = key(file), nil, false
  for _, b in ipairs(state.list) do
    if key(b.file) == k then
      lines = lines or vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local line = b.line
      relocate(b, lines)
      moved = moved or b.line ~= line
      mark(b, buf)
    end
  end
  if moved then M.save() end
end

--- The bookmarks of buf where their signs are now (they move with their lines); one whose line was deleted goes
local function sync(buf)
  local changed = false
  for i = #state.list, 1, -1 do
    local b = state.list[i]
    if b.buf == buf and b.id and vim.api.nvim_buf_is_loaded(buf) then
      local at = vim.api.nvim_buf_get_extmark_by_id(buf, NS, b.id, { details = true })
      if not at[1] or (at[3] and at[3].invalid) then
        unmark(b)
        table.remove(state.list, i)
        changed = true
      else
        local text = vim.api.nvim_buf_get_lines(buf, at[1], at[1] + 1, false)[1]
        if at[1] + 1 ~= b.line or text ~= b.text then b.line, b.text, changed = at[1] + 1, text, true end
      end
    end
  end
  return changed
end

--- Read the project's bookmarks when Neovim's directory (the project) changed; true when it did
local function load()
  local p = project()
  if state.project == p then return false end
  for _, b in ipairs(state.list) do unmark(b) end
  state.project, state.list = p, {}
  for _, b in ipairs(read_all().projects[p] or {}) do
    if type(b) == "table" and type(b.file) == "string" and tonumber(b.line) then
      state.list[#state.list + 1] = {
        file = b.file,
        line = tonumber(b.line),
        name = type(b.name) == "string" and b.name ~= "" and b.name or nil,
        text = type(b.text) == "string" and b.text or nil,
      }
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do M.place(buf) end
  return true
end

--- Read the file again (the tests: another file)
function M.reload()
  for _, b in ipairs(state.list) do unmark(b) end
  state.project, state.list = nil, {}
  load()
end

--- The project's bookmarks in file and line order
function M.list()
  load()
  local changed = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do changed = sync(buf) or changed end
  if changed then M.save() end
  local list = vim.list_slice(state.list)
  table.sort(list, function(a, b)
    local ka, kb = key(a.file), key(b.file)
    if ka ~= kb then return ka < kb end
    return a.line < b.line
  end)
  return list
end

local function at_line(file, line)
  local k = key(file)
  for _, b in ipairs(state.list) do
    if key(b.file) == k and b.line == line then return b end
  end
end

local function add(buf, file, line)
  local b = { file = file, line = line, text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] }
  state.list[#state.list + 1] = b
  mark(b, buf)
  return b
end

function M.remove(b)
  for i, x in ipairs(state.list) do
    if x == b then
      unmark(x)
      table.remove(state.list, i)
      return true
    end
  end
  return false
end

--- A bookmark on the cursor's line, or none any more (F11)
function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  local file = file_of(buf)
  if not file then return notify("Bookmarks are for lines of files - this buffer is none", vim.log.levels.WARN) end
  load()
  sync(buf)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local b = at_line(file, line)
  if b then M.remove(b) else add(buf, file, line) end
  M.save()
end

--- A name for the bookmark on the cursor's line, set there first if there is none (Ctrl+F11); no name takes it away
function M.name()
  local buf = vim.api.nvim_get_current_buf()
  local file = file_of(buf)
  if not file then return notify("Bookmarks are for lines of files - this buffer is none", vim.log.levels.WARN) end
  load()
  sync(buf)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local b = at_line(file, line)
  vim.ui.input({ prompt = "Bookmark name: ", default = b and b.name or "" }, function(input)
    if input == nil then return end
    if not b then
      if not vim.api.nvim_buf_is_loaded(buf) then return end
      b = add(buf, file, line)
    end
    input = vim.trim(input)
    b.name = input ~= "" and input or nil
    M.save()
  end)
end

--- To a bookmark: its file in this window, the cursor on its line (<C-o> comes back)
function M.open(b)
  vim.cmd("normal! m'")
  local buf = vim.fn.bufadd(b.file) -- the name as it is: [ ] in it is no pattern
  vim.bo[buf].buflisted = true
  vim.api.nvim_win_set_buf(0, buf) -- loads it: its signs come, its bookmarks find their lines
  vim.api.nvim_win_set_cursor(0, { math.min(b.line, vim.api.nvim_buf_line_count(buf)), 0 })
  vim.cmd("normal! zv")
end

--- The next bookmark after the cursor (dir 1) or the one before (-1), in file and line order; after the last the first
function M.jump(dir)
  local list = M.list()
  if #list == 0 then return notify("No bookmarks in this project" .. HINT) end
  local file = file_of(vim.api.nvim_get_current_buf())
  local here = { file and key(file) or "", vim.api.nvim_win_get_cursor(0)[1] }
  local function before(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end
  local target
  for i = dir > 0 and 1 or #list, dir > 0 and #list or 1, dir > 0 and 1 or -1 do
    local there = { key(list[i].file), list[i].line }
    if (dir > 0 and before(here, there)) or (dir < 0 and before(there, here)) then
      target = list[i]
      break
    end
  end
  M.open(target or list[dir > 0 and 1 or #list])
end

--- All of them in a picker: Enter opens the file at the line, dd (<C-x>) deletes (Shift+F11)
function M.pick()
  if #M.list() == 0 then return notify("No bookmarks in this project" .. HINT) end
  return Snacks.picker.pick({
    source = "bookmarks",
    title = "Bookmarks",
    finder = function()
      local items = {}
      for _, b in ipairs(M.list()) do
        local line = b.buf and vim.api.nvim_buf_is_loaded(b.buf) and vim.api.nvim_buf_get_lines(b.buf, b.line - 1, b.line, false)[1]
        line = line or b.text or ""
        items[#items + 1] = {
          file = b.file,
          pos = { b.line, 0 },
          label = b.name,
          line = line,
          bookmark = b,
          text = table.concat({ b.name or "", vim.fn.fnamemodify(b.file, ":."), line }, " "),
        }
      end
      return items
    end,
    format = "file",
    preview = "file",
    sort = { fields = { "score:desc", "idx" } },
    actions = {
      bookmark_delete = function(picker)
        picker.preview:reset()
        for _, item in ipairs(picker:selected({ fallback = true })) do M.remove(item.bookmark) end
        M.save()
        picker.list:set_selected()
        picker.list:set_target()
        picker:find()
      end,
    },
    win = {
      input = { keys = { ["<c-x>"] = { "bookmark_delete", mode = { "n", "i" }, desc = "Delete bookmark" } } },
      list = { keys = { ["dd"] = { "bookmark_delete", desc = "Delete bookmark" } } },
    },
  })
end

function M.setup()
  vim.api.nvim_set_hl(0, "GreyKnightBookmark", { default = true, link = "Special" })
  local group = vim.api.nvim_create_augroup("greyknight.bookmarks", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      if not load() then M.place(ev.buf) end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufUnload" }, {
    group = group,
    callback = function(ev)
      if state.project and sync(ev.buf) then M.save() end
      if ev.event == "BufUnload" then
        for _, b in ipairs(state.list) do
          if b.buf == ev.buf then b.buf, b.id = nil, nil end
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", { group = group, callback = function() load() end })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if not state.project then return end
      local changed = false
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do changed = sync(buf) or changed end
      if changed then M.save() end
    end,
  })
end

return M
