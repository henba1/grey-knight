-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Tasks: every run is an overseer.nvim task                  ║
-- ║  One task per target - running a script again replaces its  ║
-- ║  task, other scripts keep running side by side. Output in a ║
-- ║  bottom window (a real pty: input() / read / sudo work),    ║
-- ║  errors -> code, arguments remembered across sessions.      ║
-- ╚══════════════════════════════════════════════════════════════╝
local errors = require("devsuite.errors")
local M = {}

local WARN = vim.log.levels.WARN
local KEEP_LINES = 400 -- output lines kept per run for error parsing and "fix with Qwen"

-- win: the output window; current: task shown there; last: last one started;
-- runs[task.id] = { task, lines, items, map, origin, started, starts, focus_next }
local state = { win = nil, current = nil, last = nil, last_failed = nil, runs = {} }
M.state = state

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Run" }) end

-- Errors in task callbacks would only reach overseer's log file: report them (and so the error log)
local function guard(what, fn)
  return function(...)
    local ok, err = xpcall(fn, debug.traceback, ...)
    if not ok then
      vim.schedule(function() notify(("internal error in %s:\n%s"):format(what, err), vim.log.levels.ERROR) end)
    end
  end
end

local function short(path)
  local home = vim.env.HOME
  if home and home ~= "" and path:sub(1, #home) == home then return "~" .. path:sub(#home + 1) end
  return path
end

-- ── Arguments per script, kept across sessions ──────────────
M.args_file = vim.fn.stdpath("data") .. "/greyknight/run-args.json"
local saved_args

local function all_args()
  if not saved_args then
    local ok, decoded = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(M.args_file), "\n")) end)
    saved_args = (ok and type(decoded) == "table") and decoded or {}
  end
  return saved_args
end

--- Arguments last used for a script ("" when none).
function M.get_args(path) return all_args()[path] or "" end

--- Remember arguments for a script ("" forgets them).
function M.set_args(path, args)
  local all = all_args()
  all[path] = (args and args ~= "") and args or nil
  vim.fn.mkdir(vim.fs.dirname(M.args_file), "p")
  vim.fn.writefile({ vim.json.encode(next(all) and all or vim.empty_dict()) }, M.args_file)
end

-- ── Output window ───────────────────────────────────────────
local function output_win()
  if state.win and vim.api.nvim_win_is_valid(state.win) then return state.win end
end

local function open_window()
  local win = output_win()
  if win then return win end
  vim.cmd(("botright %dsplit"):format(math.max(10, math.floor(vim.o.lines * 0.3))))
  win = vim.api.nvim_get_current_win()
  local options = {
    winfixheight = true, number = false, relativenumber = false, signcolumn = "no",
    colorcolumn = "", cursorline = false,
  }
  for option, value in pairs(options) do vim.wo[win][option] = value end
  state.win = win
  return win
end

-- A window with code in it: where the run was started from, else any normal window
local function code_window(run)
  if run and run.origin and run.origin ~= state.win and vim.api.nvim_win_is_valid(run.origin) then return run.origin end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if win ~= state.win and vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == "" then return win end
  end
end

local function task_of_buf(buf)
  for _, run in pairs(state.runs) do
    if not run.task:is_disposed() and run.task:get_bufnr() == buf then return run.task, run end
  end
end

--- Winbar of the output window: state, exit code, run time and what to do next.
function M.winbar()
  local win = vim.g.statusline_winid
  if not (win and vim.api.nvim_win_is_valid(win)) then return "" end
  local task, run = task_of_buf(vim.api.nvim_win_get_buf(win))
  if not task then return "" end
  local name = task.name:gsub("%%", "%%%%")
  local secs = run.started and ((run.ended or vim.uv.hrtime()) - run.started) / 1e9 or 0
  if task.status == "RUNNING" then
    return ("%%#DiagnosticInfo# RUNNING %%*  %s  %.0fs   %%#Comment#<leader>rk stop  <leader>rl restart%%*"):format(name, secs)
  elseif task.status == "SUCCESS" then
    return ("%%#DiagnosticOk# DONE %%*  exit 0  %.2fs  %s"):format(secs, name)
  elseif task.status == "FAILURE" then
    local hint = #vim.tbl_filter(function(i) return i.type == "E" end, run.items or {}) > 0
        and "   %#Comment#]q next error  <CR> on an error line: jump  <leader>rf fix with Qwen%*" or "   %#Comment#<leader>rf fix with Qwen%*"
    return ("%%#DiagnosticError# FAILED %%*  exit %s  %.2fs  %s%s"):format(tostring(task.exit_code), secs, name, hint)
  end
  return ("%%#DiagnosticWarn# %s %%*  %s"):format(task.status, name)
end

-- <CR> on an output line with a file:line jumps to the code
local function add_jump(buf, task)
  if vim.b[buf].greyknight_jump then return end
  vim.b[buf].greyknight_jump = true
  vim.keymap.set("n", "<CR>", function()
    local run = state.runs[task.id]
    local path, lnum = errors.location(vim.api.nvim_get_current_line(), { cwd = task.cwd, map = run and run.map })
    if not path then return end
    local win = code_window(run)
    if win then vim.api.nvim_set_current_win(win) else vim.cmd("aboveleft split") end
    vim.cmd.edit(vim.fn.fnameescape(path))
    pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
  end, { buffer = buf, desc = "Run: jump to the code of this output line" })
end

--- Show a task's output in the output window; focus = cursor into it (terminal mode, for input).
function M.show(task, focus)
  local buf = task:get_bufnr()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local origin = vim.api.nvim_get_current_win()
  local win = open_window()
  vim.api.nvim_win_set_buf(win, buf)
  -- winbar is global-local: set it after the buffer swap, or it stays with the previous buffer
  vim.wo[win].winbar = "%{%v:lua.require'devsuite.tasks'.winbar()%}"
  state.current = task
  add_jump(buf, task)
  local run = state.runs[task.id]
  if focus then
    if run and origin ~= win then run.origin = origin end
    vim.api.nvim_set_current_win(win)
    vim.cmd("startinsert")
  elseif origin ~= win and vim.api.nvim_win_is_valid(origin) then
    vim.api.nvim_set_current_win(origin)
  end
end

local function finished(task, status)
  local run = state.runs[task.id]
  if not run then return end
  run.ended = vim.uv.hrtime()
  local key = task.metadata.gk_key
  run.items = errors.parse(run.lines, { cwd = task.cwd, map = run.map })
  errors.publish(key, "Run: " .. task.name, run.items)
  local secs = (run.ended - run.started) / 1e9
  if status == "FAILURE" then
    state.last_failed = task
    local n = #vim.tbl_filter(function(i) return i.type == "E" end, run.items)
    notify(("%s: exit %s (%.2fs)%s"):format(task.name, tostring(task.exit_code), secs,
      n > 0 and (" - %d error location%s, ]q / <leader>xq; <leader>rf fix with Qwen"):format(n, n > 1 and "s" or "") or ""), WARN)
  elseif status == "SUCCESS" then
    notify(("%s: done (%.2fs)"):format(task.name, secs))
  end
  -- Leave terminal mode and go back to the code
  local win = output_win()
  if win and vim.api.nvim_get_current_win() == win and vim.api.nvim_win_get_buf(win) == task:get_bufnr() then
    vim.cmd("stopinsert")
    local code = code_window(run)
    if code then vim.api.nvim_set_current_win(code) end
  end
  vim.cmd("redrawstatus!")
end

--- Run a shell command as a task and show its output.
--- spec = { key, name, cmd, cwd, env?, map?, file?, focus? } - `key` names the target (a run of the
--- same key replaces that task), `map` maps temp snippet files to { file, offset } for error locations.
function M.run(spec)
  local overseer = require("overseer")
  local previous = {}
  for _, task in ipairs(overseer.list_tasks()) do
    if task.metadata.gk_key == spec.key then
      previous[#previous + 1] = task
      if task:is_running() then task:stop() end
    end
  end
  local task = overseer.new_task({
    name = spec.name,
    cmd = spec.cmd,
    cwd = spec.cwd,
    env = spec.env,
    metadata = { gk_key = spec.key, gk_file = spec.file },
    -- the duration comes from run.started / run.ended; overseer's display_duration is a deprecated stub
    -- that only warned at every start
    components = { "on_exit_set_status" },
  })
  local run = { task = task, lines = {}, items = {}, map = spec.map, starts = 0 }
  state.runs[task.id] = run
  task:subscribe("on_start", guard("on_start", function(t)
    run.starts = run.starts + 1
    run.lines, run.items, run.started, run.ended = {}, {}, vim.uv.hrtime(), nil
    errors.clear(spec.key)
    if run.starts > 1 then -- restarted (watch, <leader>rl, task list): it has a new output buffer
      local focus = run.focus_next
      run.focus_next = nil
      vim.schedule(function()
        if focus or state.current == t then M.show(t, focus) end
      end)
    end
  end))
  task:subscribe("on_output_lines", guard("on_output_lines", function(_, lines)
    vim.list_extend(run.lines, lines)
    if #run.lines > 2 * KEEP_LINES then run.lines = vim.list_slice(run.lines, #run.lines - KEEP_LINES + 1) end
  end))
  task:subscribe("on_complete", function(t, status) vim.schedule(guard("finished", function() finished(t, status) end)) end)
  task:subscribe("on_dispose", guard("on_dispose", function(t)
    state.runs[t.id] = nil
    if state.current == t then state.current = nil end
  end))
  task:start()
  state.last = task
  M.show(task, spec.focus ~= false)
  for _, old in ipairs(previous) do old:dispose(true) end
  return task
end

local function active()
  for _, task in ipairs({ state.current, state.last }) do
    if task and not task:is_disposed() then return task end
  end
end

--- Run the shown (or last) task again; the cursor goes to its output.
function M.rerun()
  local task = active()
  if not task then return notify("Run: nothing has run yet", WARN) end
  local run = state.runs[task.id]
  if run then run.focus_next = true end
  task:restart(true)
end

--- Stop the shown (or last) task; its output stays.
function M.stop()
  local task = active()
  if not (task and task:is_running()) then return notify("Run: nothing is running") end
  task:stop()
end

--- Show or hide the output window.
function M.toggle()
  local win = output_win()
  if win then
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then vim.api.nvim_win_close(win, false) end
    state.win = nil
    return
  end
  local task = active()
  if not task then return notify("Run: nothing has run yet", WARN) end
  M.show(task, false)
end

--- All tasks: status, duration; <CR> actions (restart, stop, open output, watch ...), dd removes.
function M.list() require("overseer").toggle({ enter = true }) end

--- Re-run the shown (or last) task whenever a file in its folder is saved.
function M.toggle_watch()
  local task = active()
  if not task then return notify("Run: run something first, then watch it", WARN) end
  if task:has_component("restart_on_save") then
    task:remove_component("restart_on_save")
    notify("Watch off: " .. task.name)
  else
    local file = task.metadata.gk_file
    task:add_component({ "restart_on_save", paths = { file and vim.fs.dirname(file) or task.cwd } })
    notify("Watch on: " .. task.name .. " runs again when you save a file in " .. short(file and vim.fs.dirname(file) or task.cwd))
  end
end

--- The failed run (shown one, else the last that failed) as a prompt for the coding agent.
function M.fix_prompt()
  local task = state.current
  if not (task and not task:is_disposed() and task.status == "FAILURE") then task = state.last_failed end
  if not task or task:is_disposed() or not state.runs[task.id] then return nil end
  local run = state.runs[task.id]
  local output = vim.tbl_map(errors.clean, vim.list_slice(run.lines, math.max(1, #run.lines - 60)))
  local refs, seen = {}, {}
  for _, item in ipairs(run.items or {}) do
    local ref = ("@%s (line %d)"):format(vim.fn.fnamemodify(item.filename, ":."):gsub(" ", "\\ "), item.lnum)
    if item.type == "E" and not seen[ref] then
      seen[ref] = true
      refs[#refs + 1] = ref
    end
  end
  if #refs == 0 and task.metadata.gk_file then refs[1] = "@" .. vim.fn.fnamemodify(task.metadata.gk_file, ":."):gsub(" ", "\\ ") end
  local cmd = type(task.cmd) == "table" and table.concat(task.cmd, " ") or task.cmd
  return table.concat({
    ("This command failed with exit code %s (working directory %s):"):format(tostring(task.exit_code), short(task.cwd)),
    "```", cmd, "```",
    "Last output:", "```", table.concat(output, "\n"), "```",
    #refs > 0 and ("Code: " .. table.concat(refs, " ")) or "",
    "Find the cause and fix it, then tell me how to verify the fix.",
  }, "\n")
end

--- Send the failed run to the coding agent (Qwen Code or OpenCode).
function M.fix_with_qwen()
  local prompt = M.fix_prompt()
  if not prompt then return notify("Run: no failed run to fix", WARN) end
  require("integrations.agent").send(prompt)
end

return M
