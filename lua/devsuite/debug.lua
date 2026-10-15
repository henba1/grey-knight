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
  local python = venv and (venv .. "/bin/python") or vim.fn.exepath("python3")
  return python ~= "" and python or nil
end

--- Launch configuration for a Python file. "integratedTerminal" gives the program a real terminal
--- (the DAP console pane), so input() works - debugpy's default internalConsole has no stdin.
--- The interpreter is the one the runner uses: the project's virtualenv, else python3.
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
  }
end

--- The bash debug adapter (bashdb, from Mason's bash-debug-adapter); false when it is not installed.
function M.setup_bash()
  if vim.fn.executable(BASHDB .. "/bash-debug-adapter") ~= 1 then return false end
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
    if not M.setup_bash() then return notify("Debug: bash debugger missing - run :MasonInstall bash-debug-adapter", WARN) end
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

--- Debug the pytest test at the cursor (the file when the cursor is not in a test).
function M.debug_test()
  if vim.bo.filetype ~= "python" then return notify("Debug: tests are for Python files", WARN) end
  local file = vim.fn.expand("%:p")
  vim.cmd("silent! update")
  local target = vim.fn.fnamemodify(file, ":.")
  local node = util.pytest_node(0)
  if node then target = target .. "::" .. node end
  require("dap").run(M.pytest_config(file, target))
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
