-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Debugging Python (debugpy) and bash (bashdb) with nvim-dap ║
-- ║  Programs get a terminal (the DAP console pane): input()    ║
-- ║  and read work while debugging                              ║
-- ╚══════════════════════════════════════════════════════════════╝
local util = require("devsuite.util")
local M = {}

local WARN = vim.log.levels.WARN
local BASHDB = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter"
local SHELLS = { sh = true, bash = true }

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Debug" }) end

local function python_for(file)
  local venv = util.find_venv(file)
  local python = venv and util.venv_python(venv) or vim.fn.exepath(util.system_python())
  return python ~= "" and python or nil
end

--- Launch configuration for a Python file. "integratedTerminal" gives the program a real terminal
--- (the DAP console pane), so input() works - debugpy's default internalConsole has no stdin.
--- The interpreter is the one the runner uses: the project's virtualenv, else the system Python.
function M.python_config(file, args)
  return {
    type = "python",
    request = "launch",
    name = "launch: " .. vim.fn.fnamemodify(file, ":t"),
    program = file,
    args = args or {},
    cwd = vim.fn.getcwd(),
    console = "integratedTerminal",
    pythonPath = python_for(file),
  }
end

--- Launch configuration for the pytest test (or file) `target`, e.g. "tests/test_x.py::test_add".
function M.pytest_config(file, target)
  return {
    type = "python",
    request = "launch",
    name = "pytest: " .. target,
    module = "pytest",
    args = { target },
    cwd = vim.fn.getcwd(),
    console = "integratedTerminal",
    pythonPath = python_for(file),
    env = { PYTHONDONTWRITEBYTECODE = "1" }, -- no stale bytecode after a quick fix (runner.lua, pytest)
  }
end

--- The bash debug adapter (bashdb, from Mason's bash-debug-adapter); false and why when it cannot run.
function M.setup_bash()
  if vim.fn.executable(BASHDB .. "/bash-debug-adapter") ~= 1 then
    return false, "bash debugger missing - run :MasonInstall bash-debug-adapter"
  end
  -- a Node program: without node on the PATH it never started and F5 waited for nothing (2026-10-21, the pi: nvm puts
  -- node on the PATH in interactive shells only)
  if vim.fn.executable("node") ~= 1 then
    return false, "bash debugging needs Node.js on the PATH (bash-debug-adapter is a Node program) - start Neovim"
      .. " from a shell where node runs (with nvm: one that loaded it)"
  end
  local dap = require("dap")
  dap.adapters.bashdb = dap.adapters.bashdb or { type = "executable", command = BASHDB .. "/bash-debug-adapter", name = "bashdb" }
  return true
end

--- Launch configuration for a bash script (breakpoints, stepping, variables; read works in the console).
function M.bash_config(file, args)
  local lib = BASHDB .. "/extension/bashdb_dir"
  return {
    type = "bashdb",
    request = "launch",
    name = "launch: " .. vim.fn.fnamemodify(file, ":t"),
    program = file,
    args = args or {},
    cwd = vim.fn.getcwd(),
    env = {},
    pathBash = vim.fn.exepath("bash"),
    pathBashdb = lib .. "/bashdb",
    pathBashdbLib = lib,
    pathCat = vim.fn.exepath("cat"),
    pathMkfifo = vim.fn.exepath("mkfifo"),
    pathPkill = vim.fn.exepath("pkill"),
    terminalKind = "integrated",
    showDebugOutput = false,
    trace = false,
  }
end

--- Debug the current Python or bash file; with_args asks for program arguments first.
function M.launch(with_args)
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local config
  if ft == "python" then
    config = M.python_config
  elseif SHELLS[ft] then
    if util.WIN then return notify("Debug: bash scripts are debugged on Linux (bashdb)", WARN) end
    local ok, why = M.setup_bash()
    if not ok then return notify("Debug: " .. why, WARN) end
    config = M.bash_config
  else
    return require("dap").continue() -- other languages: the configurations nvim-dap knows
  end
  vim.cmd("silent! update")
  if not with_args then return require("dap").run(config(file)) end
  vim.ui.input({ prompt = "Debug with args: " }, function(input)
    if input == nil then return end
    require("dap").run(config(file, vim.split(vim.trim(input), "%s+", { trimempty = true })))
  end)
end

--- F5: continue a stopped session; else the project's .vscode/launch.json; else debug this file.
function M.start_or_continue()
  local dap = require("dap")
  if dap.session() then return dap.continue() end
  if vim.fn.filereadable(vim.fn.getcwd() .. "/.vscode/launch.json") == 1 then return dap.continue() end
  M.launch()
end

--- Debug the pytest test at the cursor (the file when the cursor is not in a test); in Java files the TestNG /
--- JUnit test at the cursor.
function M.debug_test()
  if vim.bo.filetype == "java" then return require("devsuite.runner").java_test(true, true) end
  if vim.bo.filetype ~= "python" then return notify("Debug: tests are for Python and Java files", WARN) end
  local file = vim.fn.expand("%:p")
  vim.cmd("silent! update")
  local target = vim.fn.fnamemodify(file, ":.")
  local node = util.pytest_node(0)
  if node then target = target .. "::" .. node end
  require("dap").run(M.pytest_config(file, target))
end

--- terminal_win_cmd for the program terminal: dap-ui's console (`get_buf`), but never a buffer that still
--- runs an earlier program. dap-ui returns the same "DAP Console" buffer every time, and nvim-dap takes a
--- terminal buffer back only when its job ends. bashdb's terminal sometimes outlives its session, so the
--- next start used a buffer that still ran the old program and failed with "jobstart(...,{term=true})
--- requires unmodified buffer" (reproduced 2026-10-19: the 4th bash run in a row).
--- A leftover job whose session is over is stopped and dap-ui gets a fresh buffer, shown in the same
--- windows. A program whose session still runs keeps its terminal; the new one gets a split of its own.
function M.fresh_console(get_buf, config)
  local buf, win = get_buf(config)
  if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal") then return buf, win end
  for _, s in pairs(require("dap").sessions()) do
    if s.term_buf == buf then
      local cur = vim.api.nvim_get_current_win()
      vim.cmd("belowright new")
      local split_buf, split_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(cur)
      return split_buf, split_win
    end
  end
  local job = vim.b[buf].terminal_job_id
  if job then pcall(vim.fn.jobstop, job) end
  local wins = vim.fn.win_findbuf(buf)
  local placeholder = vim.api.nvim_create_buf(false, true)
  for _, w in ipairs(wins) do pcall(vim.api.nvim_win_set_buf, w, placeholder) end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  buf, win = get_buf(config)
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) then pcall(vim.api.nvim_win_set_buf, w, buf) end
  end
  pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
  return buf, win
end

--- Wraps dap-ui's terminal_win_cmd in fresh_console (plugins/hacker.lua, right after dapui.setup()).
function M.wrap_console(get_buf)
  if type(get_buf) ~= "function" then return get_buf end
  M.console_cmd = function(config) return M.fresh_console(get_buf, config) end
  return M.console_cmd
end

M.break_on_raised = false

--- Python: stop at every raised exception (also caught ones), or only at uncaught ones (default).
function M.toggle_exceptions()
  local dap = require("dap")
  M.break_on_raised = not M.break_on_raised
  local filters = M.break_on_raised and { "raised", "uncaught" } or { "uncaught" }
  dap.defaults.python.exception_breakpoints = filters
  if dap.session() then dap.set_exception_breakpoints(filters) end
  notify(M.break_on_raised and "Stop on every raised exception" or "Stop on uncaught exceptions only")
end

return M
