-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Script slots in the explorer: !1 .. !9 run your scripts on  ║
-- ║  the item under the cursor and the marked items, !! lists    ║
-- ║  them. A script asks through Neovim's dialogs.               ║
-- ╚══════════════════════════════════════════════════════════════╝
-- A slot is a file named <n>-<name>.<ext> (n = 1..9) in <config>/slots - in git, on every machine - or in
-- <data>/slots - yours, not in git; it wins a number both have. .py runs everywhere, .sh on Linux, .ps1 on
-- Windows (PowerShell), an executable file on Linux. No shell in between: names with spaces, &, % or ^ reach the
-- script whole. Its output is a run of its own (lua/devsuite/tasks.lua) below the code; the cursor stays in the tree,
-- which is read again when the script ends.
--
-- What a script gets:
--   arguments          the marked items, in the order they were marked
--   GK_MARKED          a file with the marked items, one per line (empty when nothing is marked)
--   GK_CURSOR          the item under the cursor
--   GK_DIR, GK_ROOT    the folder the cursor is in (its item, on a folder) / the tree's root - the working directory
--   GK_SLOT            its number;  GK_LIB  the helpers: gk.py (on PYTHONPATH: import gk), gk.sh, gk.ps1
-- How it asks - a line on its output, the answer a line on its input, in any language:
--   ::gk::confirm::<question>         a Yes / No dialog                                  -> y | n
--   ::gk::input::<prompt>             a text box; a ::gk::default::<text> line before it fills it   -> the text
--   ::gk::select::<prompt>            a choice of the ::gk::option::<text> lines before it          -> the option
--   ::gk::notify::<message>           a notification (::gk::warn::, ::gk::error:: for the others)
--   ::gk::open::<path>[:<line>]       the file in the code window (a relative path: from GK_ROOT)
--   ::gk::refresh::                   the tree read again now
-- A dialog closed without an answer answers an empty line (n for a confirm). One line per request: a terminal
-- turns tabs into cursor moves on Windows (ConPTY), so nothing is split within a line.
local M = {}

local util = require("devsuite.util")
local WIN = util.WIN
local MAX = 9

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Script slots" }) end
local function native(path) return WIN and (path:gsub("/", "\\")) or path end
local function show(path) return vim.fn.fnamemodify(path, ":~") end

--- The folders slots come from: yours (not in git) first, then the config's.
function M.dirs() return { vim.fn.stdpath("data") .. "/slots", vim.fn.stdpath("config") .. "/slots" } end

--- The helpers' folder (gk.py, gk.sh, gk.ps1).
function M.lib() return vim.fn.stdpath("config") .. "/slots/lib" end

-- A script's description in !!: its first comment line (after a #! line)
local function describe(path)
  local ok, head = pcall(vim.fn.readfile, path, "", 6)
  for _, line in ipairs(ok and head or {}) do
    if not line:match("^#!") and line:match("%S") then
      return line:match("^%s*#%s*(.-)%s*$") or line:match("^%s*%-%-%s*(.-)%s*$") or ""
    end
  end
  return ""
end

--- The slots by number: { slot, path, name, desc }; yours before the config's.
function M.list()
  local slots = {}
  for _, dir in ipairs(M.dirs()) do
    if vim.fn.isdirectory(dir) == 1 then
      local names = {}
      for name, kind in vim.fs.dir(dir) do
        -- not a folder, nor an editor's backup or swap file
        if kind ~= "directory" and not name:match("~$") and not name:match("%.sw.$") and not name:match("%.bak$") then
          names[#names + 1] = name
        end
      end
      table.sort(names) -- two files with one number: the first by name
      for _, name in ipairs(names) do
        local n = tonumber(name:match("^(%d)%-.+$") or name:match("^(%d)%.[^.]+$"))
        if n and n >= 1 and n <= MAX and not slots[n] then
          local path = vim.fs.normalize(dir .. "/" .. name)
          slots[n] = { slot = n, path = path, name = name, desc = describe(path) }
        end
      end
    end
  end
  return slots
end

--- How a script runs here: its argv, or nil and why it cannot.
function M.argv(path)
  local ext = (path:match("%.(%w+)$") or ""):lower()
  if ext == "py" then return { util.system_python(), path } end
  if ext == "sh" or ext == "bash" then
    if WIN then return nil, "a .sh script runs on Linux - on Windows write it in Python or PowerShell (.py, .ps1)" end
    return { "bash", path }
  end
  if ext == "ps1" then
    if WIN then return { "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path } end
    if vim.fn.executable("pwsh") == 1 then return { "pwsh", "-NoProfile", "-File", path } end
    return nil, "a .ps1 script needs PowerShell (pwsh), not installed here"
  end
  if WIN and ext == "exe" then return { path } end
  if not WIN and vim.fn.executable(path) == 1 then return { path } end
  return nil, "nothing runs it here - .py runs everywhere, .sh on Linux, .ps1 on Windows"
end

--- What a run gets from the explorer: the item under the cursor, the marked ones (in the order they were marked),
--- the cursor's folder and the tree's root.
function M.context(picker)
  local path = Snacks.picker.util.path
  local cur = picker:current()
  return {
    cursor = cur and path(cur) or nil,
    marked = vim.tbl_map(function(item) return path(item) end, picker:selected()),
    dir = picker:dir(),
    root = picker:cwd(),
  }
end

--- The run of a slot for this context (tasks.run's spec) and the file with the marked items; or nil and why not.
function M.spec(slot, ctx)
  local argv, why = M.argv(slot.path)
  if not argv then return nil, why end
  local list = vim.fn.tempname()
  vim.fn.writefile(vim.tbl_map(native, ctx.marked), list)
  local lib = native(M.lib())
  local pythonpath = vim.env.PYTHONPATH or ""
  return {
    key = "slot:" .. slot.slot,
    name = ("slot %d: %s"):format(slot.slot, slot.name),
    cmd = vim.list_extend(argv, vim.tbl_map(native, ctx.marked)),
    cwd = ctx.root,
    focus = false, -- the cursor stays in the tree; the run's window shows the output
    env = {
      GK_SLOT = tostring(slot.slot),
      GK_CURSOR = ctx.cursor and native(ctx.cursor) or "",
      GK_MARKED = native(list),
      GK_DIR = native(ctx.dir or ctx.root),
      GK_ROOT = native(ctx.root),
      GK_LIB = lib,
      PYTHONPATH = pythonpath ~= "" and (lib .. (WIN and ";" or ":") .. pythonpath) or lib,
      PYTHONUNBUFFERED = "1", -- a question reaches Neovim before the script waits for its answer
      PYTHONDONTWRITEBYTECODE = "1", -- no __pycache__ in the config's slots/lib (gk.py)
    },
  }, list
end

-- The tree read again from its root, if the explorer is still open
local function refresh(picker)
  if not picker or picker.closed then return end
  require("snacks.explorer.tree"):refresh(picker:cwd())
  require("snacks.explorer.actions").update(picker, {})
end

-- ::gk::open::<path>[:<line>] - in the explorer's code window (relative paths from the run's root)
local function open_file(spec, root, picker)
  local path, line = spec, nil
  local function full(p) return vim.fs.normalize(vim.fn.fnamemodify(p, ":p")) end
  if not spec:match("^%a:[/\\]") and not spec:match("^[/\\~]") then spec = root .. "/" .. spec end
  if not vim.uv.fs_stat(spec) then
    local p, l = spec:match("^(.*):(%d+)$")
    if p and vim.uv.fs_stat(p) then spec, line = p, tonumber(l) end
  end
  path = full(spec)
  if not vim.uv.fs_stat(path) then return notify("open: no such file " .. path, vim.log.levels.WARN) end
  local win = picker and picker.main
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
  vim.cmd.edit({ args = { path }, magic = { file = false } })
  if line then pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 }) end
end

--- A run's conversation: the lines of its output that ask (::gk::...), answered on its input.
function M.converse(task, picker)
  local pending = { options = {} }
  local function reply(text)
    local job = task.strategy and task.strategy.job_id
    if job and task:is_running() then pcall(vim.fn.chansend, job, text .. "\r") end
  end
  local level = vim.log.levels
  local handlers = {
    default = function(text) pending.default = text end,
    option = function(text) table.insert(pending.options, text) end,
    confirm = function(text)
      vim.ui.select({ "No", "Yes" }, { prompt = text, snacks = { layout = { layout = { max_width = 60 } } } },
        function(_, idx) reply(idx == 2 and "y" or "n") end)
    end,
    input = function(text)
      local default = pending.default
      pending.default = nil
      vim.ui.input({ prompt = text, default = default }, function(value) reply(value or "") end)
    end,
    select = function(text)
      local options = pending.options
      pending.options = {}
      vim.ui.select(options, { prompt = text }, function(choice) reply(choice or "") end)
    end,
    notify = function(text) vim.notify(text, level.INFO, { title = task.name }) end,
    warn = function(text) vim.notify(text, level.WARN, { title = task.name }) end,
    error = function(text) vim.notify(text, level.ERROR, { title = task.name }) end,
    open = function(text) open_file(text, task.cwd, picker) end,
    refresh = function() refresh(picker) end,
  }
  task:subscribe("on_start", function() pending = { options = {} } end) -- <leader>rl: a new conversation
  task:subscribe("on_output_lines", function(_, lines)
    -- terminal sequences out first (ConPTY puts some before a line); a callback that returns true is unsubscribed
    for _, line in ipairs(require("devsuite.errors").lines(lines)) do
      local kind, text = line:match("^%s*::gk::(%a+)::(.-)%s*$")
      local handler = kind and handlers[kind]
      if handler then
        vim.schedule(function()
          local ok, err = pcall(handler, text)
          if not ok then notify(("%s: %s failed - %s"):format(task.name, kind, tostring(err)), level.ERROR) end
        end)
      end
    end
  end)
end

--- Run slot n on what the explorer shows; returns the task.
function M.run(picker, n)
  local slot = M.list()[n]
  if not slot then
    return notify(("No script in slot %d - put one into %s as %d-<name>.py (.sh, .ps1); !! lists the slots")
      :format(n, show(M.dirs()[2]), n), vim.log.levels.WARN)
  end
  local spec, list = M.spec(slot, M.context(picker))
  if not spec then return notify(("Slot %d (%s): %s"):format(n, slot.name, list), vim.log.levels.WARN) end
  local tasks = require("devsuite.tasks")
  -- from the code window: the run's window is split off it, not off the tree's float (its look came along)
  local task
  local main = picker.main
  if main and vim.api.nvim_win_is_valid(main) then
    vim.api.nvim_win_call(main, function() task = tasks.run(spec) end)
  else
    task = tasks.run(spec)
  end
  M.converse(task, picker)
  task:subscribe("on_complete", function()
    vim.schedule(function()
      vim.fn.delete(list)
      refresh(picker)
    end)
  end)
  return task
end

--- !!: the slots to pick from.
function M.pick(picker)
  local slots = vim.tbl_values(M.list())
  table.sort(slots, function(a, b) return a.slot < b.slot end)
  if #slots == 0 then
    return notify(("No script slots yet - put scripts into %s as 1-<name>.py ... 9-<name>.py"):format(show(M.dirs()[2])))
  end
  vim.ui.select(slots, {
    prompt = "Script slots",
    format_item = function(s) return ("!%d  %s%s"):format(s.slot, s.name, s.desc ~= "" and ("  - " .. s.desc) or "") end,
  }, function(choice) if choice then M.run(picker, choice.slot) end end)
end

--- The explorer's keys and actions: !1 .. !9 run a slot, !! lists them (config/explorer.lua, setup).
function M.add_keys(opts)
  opts.actions = opts.actions or {}
  opts.win = opts.win or {}
  opts.win.list = opts.win.list or {}
  opts.win.list.keys = opts.win.list.keys or {}
  for n = 1, MAX do
    opts.actions["gk_slot_" .. n] = { action = function(picker) M.run(picker, n) end, desc = "Script slot " .. n }
    opts.win.list.keys["!" .. n] = "gk_slot_" .. n
  end
  opts.actions.gk_slots = { action = function(picker) M.pick(picker) end, desc = "Script slots" }
  opts.win.list.keys["!!"] = "gk_slots"
end

return M
