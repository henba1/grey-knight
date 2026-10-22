-- Grey Knight dev suite tests: run / tasks / errors / debug / REPL / Qwen / completion. Run with tests/run.sh
-- Many tests start real processes (python, ipython3, bash, debugpy, bashdb) and wait for them.
-- On Windows the bash, bashdb and sudo tests are skipped (Python first, 2026-10-19).
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/harness.lua")
local test = H.test

-- T12: Bash + Python dev suite (lua/devsuite/) and the Qwen Code agent (lua/integrations/agent.lua)
local function wait(ms, fn) return vim.wait(ms, function() return fn() and true or false end, 50) end
local function text(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return "" end
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function scratch(ft, lines)
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = ft
  if lines then vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines) end
  return buf
end

local WIN = vim.fn.has("win32") == 1
-- Bash, bashdb, sudo and POSIX shell syntax: Linux only for now (Windows: Python first)
local function linux_only(what) if WIN then H.skip(what .. " - Linux only for now") end end
-- Python stands in for sleep / true / echo: the same commands on Linux and Windows
local function py_argv(code) return { require("devsuite.util").system_python(), "-c", code } end
local function py_cmd(code) return table.concat(vim.tbl_map(vim.fn.shellescape, py_argv(code)), " ") end
-- A temp directory: a working directory that exists everywhere (unlike /tmp)
local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end
-- A virtualenv with a (fake) python in it - bin/python, Scripts\python.exe on Windows; returns the python
local function fake_venv(venv)
  local python = require("devsuite.util").venv_python(venv)
  vim.fn.mkdir(vim.fs.dirname(python), "p")
  vim.fn.writefile({ "#!/bin/sh" }, python)
  vim.fn.setfperm(python, "rwx------")
  return python
end
-- Language servers of a test go when it ends (the next test's files are elsewhere)
local function stop_clients(buf)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do client:stop(true) end
  wait(5000, function() return #vim.lsp.get_clients({ bufnr = buf }) == 0 end)
end
-- An executable that does nothing: a #!/bin/sh script, a .cmd on Windows; returns its path
local function fake_exe(path)
  if WIN then path = path .. ".cmd" end
  vim.fn.writefile(WIN and { "@exit /b 0" } or { "#!/bin/sh" }, path)
  vim.fn.setfperm(path, "rwx------")
  return path
end

test("Dev suite: dedent, cells, shebang", function()
  local util = require("devsuite.util")
  local d = util.dedent({ "    if x:", "        y()", "  ", "    z()" })
  assert(d[1] == "if x:" and d[2] == "    y()" and d[3] == "" and d[4] == "z()", "dedent: " .. vim.inspect(d))
  local buf = scratch("sh", { "#!/usr/bin/env bash", "a", "# %%", "b", "c", "# %% two", "d" })
  local sb = util.shebang(buf)
  assert(sb and sb[1] == "/usr/bin/env" and sb[2] == "bash", "shebang: " .. vim.inspect(sb))
  local first, last, lines = util.cell_range(buf, 4)
  assert(first == 4 and last == 5 and #lines == 2, ("cell %s-%s"):format(first, last))
  assert(util.cell_range(buf, 7) == 7, "last cell")
  local f0, l0 = util.cell_range(buf, 1)
  assert(f0 == 1 and l0 == 2, "cell before the first marker")
  assert(util.cell_range(scratch("python", { "x = 1" }), 1) == nil, "no cells")
end)

test("Dev suite: project .venv found from a file deep inside", function()
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(root .. "/pkg/sub", "p")
  fake_venv(root .. "/.venv")
  local saved = vim.env.VIRTUAL_ENV
  vim.env.VIRTUAL_ENV = nil
  local venv = require("devsuite.util").find_venv(root .. "/pkg/sub/tool.py")
  vim.env.VIRTUAL_ENV = saved
  assert(venv == root .. "/.venv", tostring(venv))
  -- a venv in the home directory is a toolbox, not the project's environment
  local saved_home = vim.env.HOME
  vim.env.HOME = root
  vim.env.VIRTUAL_ENV = nil
  local from_home = require("devsuite.util").find_venv(root .. "/pkg/sub/tool.py")
  vim.env.HOME, vim.env.VIRTUAL_ENV = saved_home, saved
  assert(from_home == nil, "home venv used: " .. tostring(from_home))
end)

test("Dev suite: pytest node at the cursor", function()
  local util = require("devsuite.util")
  local buf = scratch("python", { "class TestMath:", "    def test_add(self):", "        assert 1 + 1 == 2", "", "def helper():", "    pass" })
  assert(util.pytest_node(buf, 3, 8) == "TestMath::test_add", tostring(util.pytest_node(buf, 3, 8)))
  assert(util.pytest_node(buf, 6, 4) == nil, "helper is not a test")
end)

test("Run/Debug/REPL keymaps present", function()
  local function has(mode, lhs)
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if m.lhs == lhs then return true end
    end
  end
  for _, lhs in ipairs({ " rr", " ra", " rR", " rp", " rP", " rl", " rc", " rx", " rt", " rT", " rw", " rk", " ro", " rL", " rf",
    " ri", " re", " rE", " dl", " dL", " dt", " de", " dc", " dh", " dq", " dR", "<F5>", "<F6>", "<F9>", "<F10>" }) do
    assert(has("n", lhs), lhs .. " missing (normal)")
  end
  for _, lhs in ipairs({ " rs", " re", " aa", " ae" }) do
    assert(has("v", lhs), lhs .. " missing (visual)")
  end
end)

local function task_out(task) return text(task and task:get_bufnr()) end

test("Runner: python input() reads from the terminal (task in a pty)", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = vim.fn.tempname() .. ".py"
  vim.fn.writefile({ 'name = input("name? ")', 'print("hello " + name)' }, file)
  vim.cmd.edit(file)
  runner.run_file()
  local task = tasks.state.last
  -- no trailing space in the patterns: Windows' ConPTY draws trailing blanks as cursor moves
  assert(wait(10000, function() return task_out(task):find("name?", 1, true) end), "no prompt: " .. task_out(task))
  vim.fn.chansend(task.strategy.job_id, "knight\r")
  assert(wait(10000, function() return task:is_complete() end), "did not exit: " .. task_out(task))
  assert(task.status == "SUCCESS" and task_out(task):find("hello knight", 1, true), task.status .. ": " .. task_out(task))
end)

-- 2026-10-19: tasks carried overseer's display_duration, a deprecated stub that only warned at every start
-- (GreyKnight measures the duration itself). Every component a task gets must be current in overseer.
test("Tasks: no deprecated overseer components", function()
  local tasks = require("devsuite.tasks")
  local task = tasks.run({ key = "test:components", name = "components", cmd = py_cmd("pass"), cwd = tmpdir(), focus = false })
  local deprecated = {}
  for _, comp in ipairs(task.components) do
    local ok, def = pcall(require, "overseer.component." .. comp.name:gsub("/", "."))
    assert(ok and type(def) == "table", "unknown overseer component " .. comp.name)
    if def.deprecated_message then deprecated[#deprecated + 1] = comp.name .. " (" .. def.deprecated_message .. ")" end
  end
  wait(5000, function() return task:is_complete() end)
  assert(#task.components > 0, "a task without components")
  assert(#deprecated == 0, "deprecated overseer components: " .. table.concat(deprecated, ", "))
end)

test("Runner: bash snippet (indented selection) with read", function()
  linux_only("bash")
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  scratch("sh")
  runner.run_lines({ "    read -r -p 'pick? ' x", '    echo "got:$x"' }, "test", 1)
  local task = tasks.state.last
  assert(wait(10000, function() return task_out(task):find("pick? ", 1, true) end), "no prompt: " .. task_out(task))
  vim.fn.chansend(task.strategy.job_id, "42\r")
  assert(wait(10000, function() return task:is_complete() end), "did not exit")
  assert(task_out(task):find("got:42", 1, true), "no output: " .. task_out(task))
end)

test("Tasks: scripts run side by side, a re-run replaces its own task", function()
  local tasks = require("devsuite.tasks")
  local dir = tmpdir()
  local a = tasks.run({ key = "test:a", name = "a", cmd = py_cmd("import time; time.sleep(1); print('A-done')"), cwd = dir, focus = false })
  local b = tasks.run({ key = "test:b", name = "b", cmd = py_cmd("import time; time.sleep(1); print('B-done')"), cwd = dir, focus = false })
  assert(a:is_running() and b:is_running(), "not running side by side")
  local a2 = tasks.run({ key = "test:a", name = "a", cmd = py_cmd("print('A2')"), cwd = dir, focus = false })
  assert(a:is_disposed() and not b:is_disposed(), "re-run did not replace only its own task")
  assert(wait(10000, function() return a2:is_complete() and b:is_complete() end), "did not finish")
  assert(a2.status == "SUCCESS" and b.status == "SUCCESS", a2.status .. "/" .. b.status)
end)

local function run_diags(key, file)
  return vim.diagnostic.get(vim.fn.bufnr(file), { namespace = vim.api.nvim_create_namespace("greyknight.run." .. key) })
end

test("Errors: a python traceback marks the failing line, quickfix has the frames", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = vim.fn.tempname() .. ".py"
  vim.fn.writefile({ "def divide(a, b):", "    return a / b", "", "print(divide(1, 0))" }, file)
  vim.cmd.edit(file)
  runner.run_file()
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  vim.wait(200)
  local d = run_diags("file:" .. file, file)
  assert(#d == 1 and d[1].lnum == 1 and d[1].message:find("ZeroDivisionError", 1, true), vim.inspect(d))
  local qf = vim.fn.getqflist()
  assert(#qf == 2 and qf[1].lnum == 4 and qf[2].lnum == 2, vim.inspect(qf))
  local prompt = tasks.fix_prompt()
  assert(prompt and prompt:find("exit code 1", 1, true) and prompt:find("ZeroDivisionError", 1, true) and prompt:find("(line 2)", 1, true), tostring(prompt))
end)

test("Errors: a bash error marks its line", function()
  linux_only("bash")
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = vim.fn.tempname() .. ".sh"
  vim.fn.writefile({ "#!/bin/bash", "echo start", "no_such_command_gk", "echo end" }, file)
  vim.cmd.edit(file)
  runner.run_file()
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  vim.wait(200)
  local d = run_diags("file:" .. file, file)
  assert(#d == 1 and d[1].lnum == 2 and d[1].message:find("not found", 1, true), vim.inspect(d))
end)

test("Errors: snippet errors point at the lines in the file", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = vim.fn.tempname() .. ".py"
  vim.fn.writefile({ "a = 1", "b = 2", "c = 3", "", "x = 1", "y = x / 0", "print(y)" }, file)
  vim.cmd.edit(file)
  runner.run_lines(vim.api.nvim_buf_get_lines(0, 4, 7, false), "test", 5)
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  vim.wait(200)
  local d = run_diags("snippet:" .. file, file)
  assert(#d == 1 and d[1].lnum == 5, vim.inspect(d))
end)

test("Errors: <CR> finds the code location in an output line", function()
  local errors = require("devsuite.errors")
  local file = vim.fn.tempname() .. ".py"
  vim.fn.writefile({ "x" }, file)
  local want = vim.fs.normalize(file) -- a Windows path comes back with /
  local path, lnum = errors.location('  File "' .. file .. '", line 7, in main')
  assert(path == want and lnum == 7, tostring(path) .. ":" .. tostring(lnum))
  local p2, l2 = errors.location("\27[31m" .. file .. ": line 3: foo: command not found\27[0m")
  assert(p2 == want and l2 == 3, tostring(p2) .. ":" .. tostring(l2))
  -- 2026-10-19: file:line with a drive letter (C:\x.py:12) - the colon after the drive ended the path
  local p3, l3 = errors.location(file .. ":12: UserWarning: careful")
  assert(p3 == want and l3 == 12, tostring(p3) .. ":" .. tostring(l3))
  assert(errors.location("10.10.10.5:8080 open") == nil, "host:port is not a file")
end)

-- 2026-10-21: a script where people keep them - a folder with spaces, an umlaut, #, % and & - run with arguments in
-- quotes, one with an umlaut, and stdin from a file (cmd.exe on Windows, sh elsewhere); its error marks the line, and
-- <CR> finds the file from the traceback and from a "file:line:" line with a space in the name
test("Runner: a script in a folder with spaces, ä, #, % and & - quoted args, < input; its error marks the line", function()
  local runner, tasks, errors = require("devsuite.runner"), require("devsuite.tasks"), require("devsuite.errors")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local dir = root .. "/my scripts ä #1 100% & co"
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/prog ü.py"
  vim.fn.writefile({ "import sys", 'print("ARGV=" + "|".join(sys.argv[1:]))', 'print("STDIN=" + sys.stdin.readline().strip())' }, file)
  vim.fn.writefile({ "from the file" }, dir .. "/input.txt")
  local before = vim.fn.getcwd()
  vim.fn.chdir(dir)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(file))
    runner.run_file({ args = '"a b" ä < input.txt' })
    local task = tasks.state.last
    assert(wait(10000, function() return task:is_complete() end), "did not finish: " .. task_out(task))
    local out = task_out(task)
    assert(task.status == "SUCCESS" and out:find("ARGV=a b|ä", 1, true) and out:find("STDIN=from the file", 1, true), task.status .. ": " .. out)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1", "y = x / 0" })
    vim.cmd("silent write")
    tasks.set_args(file, "")
    runner.run_file()
    task = tasks.state.last
    assert(wait(10000, function() return task:is_complete() end), "did not finish: " .. task_out(task))
    vim.wait(200)
    local d = run_diags("file:" .. file, file)
    assert(#d == 1 and d[1].lnum == 1 and d[1].message:find("ZeroDivisionError", 1, true), vim.inspect(d) .. "\n" .. task_out(task))
    local path, lnum = errors.location('  File "' .. file .. '", line 2, in <module>')
    assert(path == file and lnum == 2, "traceback line: " .. tostring(path) .. ":" .. tostring(lnum))
    local p2, l2 = errors.location("prog ü.py:2: ZeroDivisionError: division by zero", { cwd = dir })
    assert(p2 == file and l2 == 2, "file:line: " .. tostring(p2) .. ":" .. tostring(l2))
  end)
  tasks.set_args(file, "")
  vim.fn.chdir(before)
  -- the script's buffer stays (deleting it closed the code window, and the next tests found only the output)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: on Windows fnameescape() left [ ] alone, and :edit took the path as a pattern - <CR> on an error in
-- app/[id]/page.py opened app/i/page.py
test("Runner: <CR> on an error line opens a file in a folder named with [ ] - not one its name matches as a pattern", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p")
  vim.fn.mkdir(root .. "/app/[id]", "p")
  vim.fn.mkdir(root .. "/app/i", "p")
  local file = root .. "/app/[id]/page.py"
  vim.fn.writefile({ "x = 1", "y = x / 0" }, file)
  vim.fn.writefile({ "decoy = 1", "decoy = 2" }, root .. "/app/i/page.py")
  vim.fn.writefile({ "import sys", 'print("app/[id]/page.py:2: boom")', "sys.exit(1)" }, root .. "/check.py")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  local ok, err = pcall(function()
    vim.cmd.edit({ args = { root .. "/check.py" }, magic = { file = false } })
    runner.run_file()
    local task = tasks.state.last
    assert(wait(10000, function() return task:is_complete() end), "did not finish: " .. task_out(task))
    vim.wait(200)
    local out = task:get_bufnr()
    local lnum
    for i, l in ipairs(vim.api.nvim_buf_get_lines(out, 0, -1, false)) do
      if l:find("page.py:2: boom", 1, true) then lnum = i end
    end
    assert(lnum, "no error line in the output: " .. task_out(task))
    local win = vim.fn.bufwinid(out)
    assert(win ~= -1, "the output is not shown")
    vim.api.nvim_set_current_win(win)
    vim.cmd("stopinsert")
    vim.api.nvim_win_set_cursor(win, { lnum, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    local shown = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
    assert(shown == file and vim.fn.line(".") == 2, "<CR> went to " .. shown .. ":" .. vim.fn.line("."))
  end)
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Runner: arguments are remembered per script (across sessions)", function()
  local tasks = require("devsuite.tasks")
  local key = "/tmp/greyknight-args-test.sh"
  tasks.set_args(key, "--host 10.0.0.1 -v")
  local stored = vim.json.decode(table.concat(vim.fn.readfile(tasks.args_file), "\n"))
  assert(stored[key] == "--host 10.0.0.1 -v" and tasks.get_args(key) == "--host 10.0.0.1 -v", vim.inspect(stored[key]))
  tasks.set_args(key, "")
  assert(tasks.get_args(key) == "", "not forgotten")
end)

test("Runner: project scripts are found and run from the project root", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local root = vim.fn.tempname()
  for _, dir in ipairs({ "/.git", "/scripts", "/tools", "/src" }) do vim.fn.mkdir(root .. dir, "p") end
  vim.fn.writefile({ "#!/bin/bash", "echo ROOT=$(pwd)" }, root .. "/launch.sh")
  vim.fn.writefile({ "echo e2e" }, root .. "/scripts/run_e2e.sh")
  vim.fn.writefile({ "import os", "def main(): print('ROOT=' + os.getcwd())", 'if __name__ == "__main__":', "    main()" }, root .. "/tools/report.py")
  vim.fn.writefile({ "def helper(): pass" }, root .. "/lib.py")
  vim.fn.writefile({ "# readme" }, root .. "/README.md")
  vim.fn.writefile({ "echo nested" }, root .. "/src/deep.sh")
  local found = vim.tbl_map(function(p) return p:sub(#root + 2) end, runner.project_scripts(root))
  assert(vim.deep_equal(found, { "launch.sh", "scripts/run_e2e.sh", "tools/report.py" }), vim.inspect(found))
  -- Windows: the Python script (bash is Linux only for now); both print the directory they run in
  runner.run_script(root .. (WIN and "/tools/report.py" or "/launch.sh"), false, root)
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  local printed = task_out(task):match("ROOT=(%S+)")
  local function real(p) return p and vim.fs.normalize(vim.uv.fs_realpath(p) or p) end
  assert(printed and real(printed) == real(root), task_out(task))
end)

test("Debug: a bash script stops at a breakpoint (bashdb)", function()
  linux_only("bash debugging (bashdb)")
  local dbg, dap = require("devsuite.debug"), require("dap")
  assert(dbg.setup_bash()) -- else why: the adapter missing, or node
  local file = vim.fn.tempname() .. ".sh"
  vim.fn.writefile({ "#!/bin/bash", "x=41", "x=$((x + 1))", 'echo "x is $x"' }, file)
  vim.cmd.edit(file)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  dap.toggle_breakpoint()
  local ok, err = pcall(function()
    dap.run(dbg.bash_config(file))
    local function line() local s = dap.session(); return s and s.current_frame and s.current_frame.line end
    assert(wait(30000, function() return line() ~= nil end), "never stopped")
    if line() ~= 4 then -- bashdb stops on the first line first
      dap.continue()
      assert(wait(20000, function() return line() == 4 end), "not at the breakpoint: " .. tostring(line()))
    end
    dap.continue()
    assert(wait(20000, function() return dap.session() == nil end), "session did not end")
  end)
  dap.clear_breakpoints()
  if dap.session() then dap.terminate() end
  assert(ok, err)
end)

-- 2026-10-21: bash-debug-adapter is a Node program - without node on the PATH (the pi: nvm puts it there in interactive
-- shells only) F5 started nothing and waited; the test above said "never stopped"
test("Debug: F5 on a bash script without node on the PATH says why (bash-debug-adapter is a Node program)", function()
  linux_only("bash debugging (bashdb)")
  local dbg = require("devsuite.debug")
  if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/bash-debug-adapter") ~= 1 then
    H.skip("bash-debug-adapter not installed (Mason)")
  end
  vim.cmd.edit(vim.fn.fnameescape(H.file("nonode.sh", { "#!/bin/bash", "echo hi" })))
  local notes, notify, path = {}, vim.notify, vim.env.PATH
  vim.notify = function(msg, ...) notes[#notes + 1] = tostring(msg); return notify(msg, ...) end
  vim.env.PATH = vim.fn.tempname() -- a folder that is not there: no node
  local ok, err = pcall(dbg.launch)
  vim.env.PATH, vim.notify = path, notify
  assert(ok, err)
  assert(table.concat(notes, " | "):find("Node.js", 1, true), "no word of node: " .. table.concat(notes, " | "))
  assert(require("dap").session() == nil, "a debug session started anyway")
end)

test("Debug: a python program reads input() in the DAP console", function()
  local dbg, dap = require("devsuite.debug"), require("dap")
  local file = vim.fn.tempname() .. ".py"
  vim.fn.writefile({ 'name = input("dbg? ")', 'print("dbg hello " + name)' }, file)
  vim.cmd.edit(file)
  local ended = false
  dap.listeners.after.event_terminated["gk_smoke"] = function() ended = true end
  dap.run(dbg.python_config(file))
  local function find(pattern)
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" and text(b):find(pattern, 1, true) then return b end
    end
  end
  assert(wait(40000, function() return find("dbg?") ~= nil end), "no prompt in a terminal")
  vim.fn.chansend(vim.bo[find("dbg?")].channel, "sir\r")
  assert(wait(20000, function() return find("dbg hello sir") ~= nil end), "input() did not get the answer")
  wait(10000, function() return ended end)
  dap.listeners.after.event_terminated["gk_smoke"] = nil
end)

-- 2026-10-19: dap-ui hands out one console buffer; when an earlier program's terminal still ran in it
-- (bashdb's sometimes outlives its session), the next start failed with
-- "jobstart(...,{term=true}) requires unmodified buffer"
test("Debug: dap-ui's console goes through fresh_console", function()
  require("lazy").load({ plugins = { "nvim-dap-ui" } })
  local dbg = require("devsuite.debug")
  assert(dbg.console_cmd and require("dap").defaults.fallback.terminal_win_cmd == dbg.console_cmd, "terminal_win_cmd is not wrapped")
end)

test("Debug: a fresh console when an old program's terminal still runs", function()
  local dbg = require("devsuite.debug")
  local console = vim.api.nvim_create_buf(false, true)
  local function get_buf() -- like dap-ui: the same buffer until it is gone
    if not vim.api.nvim_buf_is_valid(console) then console = vim.api.nvim_create_buf(false, true) end
    return console
  end
  local old, job = console, nil
  vim.api.nvim_buf_call(old, function() job = vim.fn.jobstart(py_argv("import time; time.sleep(60)"), { term = true }) end)
  assert(job > 0 and vim.bo[old].buftype == "terminal", "no leftover terminal")
  local buf = dbg.fresh_console(get_buf, {})
  assert(buf ~= old and vim.api.nvim_buf_is_valid(buf), "the same buffer was handed out again")
  assert(not vim.api.nvim_buf_is_valid(old), "the old console buffer is still there")
  assert(wait(3000, function() return vim.fn.jobwait({ job }, 0)[1] ~= -1 end), "the old program still runs")
  local started
  vim.api.nvim_buf_call(buf, function() started = vim.fn.jobstart(py_argv("pass"), { term = true }) end)
  assert(started > 0, "jobstart(term) failed in the fresh console")
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end)

test("Debug: a program whose session still runs keeps its terminal", function()
  local dbg, dap = require("devsuite.debug"), require("dap")
  local console, job = vim.api.nvim_create_buf(false, true), nil
  vim.api.nvim_buf_call(console, function() job = vim.fn.jobstart(py_argv("import time; time.sleep(60)"), { term = true }) end)
  local sessions = dap.sessions
  dap.sessions = function() return { { term_buf = console } } end
  local ok, buf, win = pcall(dbg.fresh_console, function() return console end, {})
  dap.sessions = sessions
  if ok and win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  local alive = vim.fn.jobwait({ job }, 0)[1] == -1
  vim.fn.jobstop(job)
  pcall(vim.api.nvim_buf_delete, console, { force = true })
  if ok and buf ~= console then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  assert(ok, buf)
  assert(buf ~= console, "the running program's terminal was handed out again")
  assert(alive, "the running program was stopped")
end)

-- 2026-10-22: dap-ui closed the console's window under a program that was still ending; on Windows Neovim crashed
-- right after now and then (the input() test above, twice in about ten runs of the suite)
test("Debug: a session ends - dap-ui closes; with the program still running in its console once it has exited", function()
  require("lazy").load({ plugins = { "nvim-dap-ui" } })
  local dbg, dapui, dap = require("devsuite.debug"), require("dapui"), require("dap")
  local close, session = dapui.close, dap.session
  local closed, bufs = 0, {}
  dapui.close = function() closed = closed + 1 end
  local function console(seconds) -- a program in a terminal of its own, as the console runs it
    local buf = vim.api.nvim_create_buf(false, true)
    bufs[#bufs + 1] = buf
    vim.api.nvim_buf_call(buf, function() vim.fn.jobstart(py_argv(("import time; time.sleep(%s)"):format(seconds)), { term = true }) end)
    return buf
  end
  local function ended(buf) return vim.fn.jobwait({ vim.b[buf].terminal_job_id }, 0)[1] ~= -1 end
  local ok, err = pcall(function()
    local buf = console(1.5)
    dbg.close_ui({ term_buf = buf })
    assert(closed == 0, "closed while the program still ran")
    assert(wait(10000, function() return closed == 1 end), "not closed once the program had exited")
    dbg.close_ui({ term_buf = buf }) -- over already: at once
    assert(closed == 2, "not closed at once after the program's end")
    local later = console(1)
    dbg.close_ui({ term_buf = later })
    dap.session = function() return {} end -- a session started since: its UI stays
    assert(wait(10000, function() return ended(later) end), "the program did not end")
    vim.wait(300)
    assert(closed == 2, "closed the UI of a session started since")
  end)
  dapui.close, dap.session = close, session
  for _, buf in ipairs(bufs) do
    wait(5000, function() return ended(buf) end) -- a terminal goes once its program is over (Windows, 0.12.6)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  assert(ok, err)
end)

test("Debug: four bash sessions in a row", function()
  linux_only("bash debugging (bashdb)")
  local dbg, dap = require("devsuite.debug"), require("dap")
  assert(dbg.setup_bash()) -- else why: the adapter missing, or node
  local file = vim.fn.tempname() .. ".sh"
  vim.fn.writefile({ "#!/bin/bash", 'echo "run"' }, file)
  vim.cmd.edit(file)
  for i = 1, 4 do
    dap.run(dbg.bash_config(file))
    local deadline = vim.uv.hrtime() + 30e9
    while dap.session() and vim.uv.hrtime() < deadline do -- F5 until the end: bashdb stops on the first line
      wait(8000, function() local s = dap.session(); return s == nil or s.stopped_thread_id ~= nil end)
      local s = dap.session()
      if s and s.stopped_thread_id then dap.continue(); wait(300, function() return false end) end
    end
    local ended = dap.session() == nil
    if not ended then dap.terminate() end
    assert(ended, "session " .. i .. " did not end")
  end
end)

-- 2026-10-22: bash-debug-adapter names its FIFO /tmp/vscode-bash-debug-fifo-<10000..19999> at random, and every session
-- left a file of that name (bashdb's goodbye); a session that drew a taken name hung - on the pi the test above did,
-- with 153 such files. Here all 10000 names are taken.
test("Debug: a bash session runs though leftover files hold every name the adapter can draw for its FIFO", function()
  linux_only("bash debugging (bashdb)")
  local dbg, dap = require("devsuite.debug"), require("dap")
  assert(dbg.setup_bash()) -- else why: the adapter missing, or node
  local file = vim.fn.tempname() .. ".sh"
  vim.fn.writefile({ "#!/bin/bash", 'echo "run"' }, file)
  vim.cmd.edit(file)
  -- empty files do it (mkfifo fails on any); touch leaves a FIFO - a session running elsewhere - as it is
  local made = vim.system({ "bash", "-c", "touch /tmp/vscode-bash-debug-fifo-{10000..19999}" }):wait()
  local ok, err = pcall(function()
    assert(made.code == 0, made.stderr)
    dap.run(dbg.bash_config(file))
    local deadline = vim.uv.hrtime() + 30e9
    while dap.session() and vim.uv.hrtime() < deadline do -- F5 until the end: bashdb stops on the first line
      wait(8000, function() local s = dap.session(); return s == nil or s.stopped_thread_id ~= nil end)
      local s = dap.session()
      if s and s.stopped_thread_id then dap.continue(); wait(300, function() return false end) end
    end
    assert(dap.session() == nil, "the session hangs (its FIFO's name was taken)")
  end)
  if dap.session() then dap.terminate(); wait(5000, function() return dap.session() == nil end) end
  if dap.session() then dap.close() end
  vim.system({ "find", "/tmp", "-maxdepth", "1", "-type", "f", "-name", "vscode-bash-debug-fifo-*", "-delete" }):wait()
  assert(ok, err)
end)

test("Debug: bashdb's leftover files go before a bash session; a FIFO (a session that runs) stays", function()
  linux_only("FIFOs")
  local dbg = require("devsuite.debug")
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local function path(name) return dir .. "/" .. name end
  local function kind(name) local s = vim.uv.fs_lstat(path(name)); return s and s.type end
  vim.fn.writefile({ "12345 ######", "bashdb: That's all, folks..." }, path("vscode-bash-debug-fifo-12345"))
  vim.fn.writefile({}, path("vscode-bash-debug-fifo-12346_in"))
  vim.fn.writefile({ "mine" }, path("vscode-bash-debug-fifo-notes.txt"))
  local fifo = vim.system({ "mkfifo", path("vscode-bash-debug-fifo-12347"), path("vscode-bash-debug-fifo-12347_in") }):wait()
  local ok, err = pcall(function()
    assert(fifo.code == 0, fifo.stderr)
    dbg.clear_bash_fifos(dir)
    assert(kind("vscode-bash-debug-fifo-12345") == nil, "a leftover stayed")
    assert(kind("vscode-bash-debug-fifo-12346_in") == nil, "a leftover _in stayed")
    assert(kind("vscode-bash-debug-fifo-12347") == "fifo", "a running session's FIFO went")
    assert(kind("vscode-bash-debug-fifo-12347_in") == "fifo", "a running session's _in FIFO went")
    assert(kind("vscode-bash-debug-fifo-notes.txt") == "file", "a file of another name went")
  end)
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- "python": the flavor this machine's Python gets (bracketed paste from 3.13, else classic); "classic":
-- exec() of a temp file, forced, so Linux with 3.13 covers it too (2026-10-19: Windows came with 3.12)
for _, flavor in ipairs({ "ipython", "python", "classic" }) do
test("REPL (" .. flavor .. "): block with blank lines, then input()", function()
  if flavor == "ipython" and vim.fn.executable("ipython3") == 0 then H.skip("ipython3 not installed - the REPL uses python then") end
  local repl = require("devsuite.repl")
  local command = repl.command
  local python = require("devsuite.util").system_python()
  local exe = flavor == "ipython" and "ipython3 --no-autoindent --no-confirm-exit --no-banner" or python
  local as = flavor == "python" and repl.python_flavor(python) or flavor
  repl.command = function() return exe, as end
  local old = require("toggleterm.terminal").get(repl.IDS.python, true)
  if old then old:shutdown() end
  scratch("python")
  repl.send({ "def greet():", "    a = 'hel'", "", "    return a + 'lo'", "", "print(greet() * 2)" })
  local term = require("toggleterm.terminal").get(repl.IDS.python, true)
  assert(term, "no REPL terminal")
  assert(wait(20000, function() return text(term.bufnr):find("hellohello", 1, true) end), "block did not run: " .. text(term.bufnr))
  repl.send({ "x = input('v' + 'al? ')", "print('val=' + x)" })
  assert(wait(10000, function() return text(term.bufnr):find("val?", 1, true) end), "no input prompt: " .. text(term.bufnr))
  vim.fn.chansend(term.job_id, "7\r")
  assert(wait(10000, function() return text(term.bufnr):find("val=7", 1, true) end), "input() got the wrong line: " .. text(term.bufnr))
  repl.send({ "for i in range(2): print('loop', i)" })
  assert(wait(10000, function() return text(term.bufnr):find("loop 1", 1, true) end), "one-line block did not run: " .. text(term.bufnr))
  term:shutdown()
  repl.command = command
end)
end

-- 2026-10-21: umlauts and symbols into the REPL and back out (Windows: ConPTY between Neovim and Python). The length
-- says whether Python got the characters or their bytes.
test("REPL: umlauts and symbols go in and come out as typed (Grüße äöü ß € ✓)", function()
  local repl = require("devsuite.repl")
  local command = repl.command
  local python = require("devsuite.util").system_python()
  repl.command = function() return python, repl.python_flavor(python) end
  local old = require("toggleterm.terminal").get(repl.IDS.python, true)
  if old then old:shutdown() end
  scratch("python")
  local ok, err = pcall(function()
    repl.send({ 's = "Grüße äöü ß € ✓"', "print(s, len(s))" })
    local term = require("toggleterm.terminal").get(repl.IDS.python, true)
    assert(term, "no REPL terminal")
    assert(wait(20000, function() return text(term.bufnr):find("Grüße äöü ß € ✓ 15", 1, true) end), "the REPL printed: " .. text(term.bufnr))
  end)
  local term = require("toggleterm.terminal").get(repl.IDS.python, true)
  if term then term:shutdown() end
  repl.command = command
  assert(ok, err)
end)

test("Qwen: ask/edit prompts reference the file", function()
  local qwen = require("integrations.agent")
  local p = qwen.prompt("edit", { rel = "src/my file.py", ft = "python", sel = { text = "x = 1", first = 3, last = 3 } }, "rename x to y")
  assert(p:find("@src/my\\ file.py", 1, true) and p:find("lines 3-3", 1, true) and p:find("rename x to y", 1, true), p)
end)

test("Qwen: new agent gets -i, a running agent one bracketed paste", function()
  linux_only("the fake agent (sh + cat -v)")
  local qwen = require("integrations.agent")
  local T = require("toggleterm.terminal")
  local fake = vim.fn.tempname() .. "-qwen"
  vim.fn.writefile({ "#!/bin/sh", 'printf "ARGV:%s\\n" "$*"', "exec cat -v" }, fake)
  vim.fn.setfperm(fake, "rwx------")
  local saved, saved_agent = vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT
  vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT = fake, "qwen"
  local old = T.get(qwen.AGENTS.agent, true)
  if old then old:shutdown() end
  local ok, err = pcall(function()
    qwen.send("first prompt")
    local term = T.get(qwen.AGENTS.agent, true)
    assert(term, "no agent terminal")
    assert(wait(10000, function() return text(term.bufnr):find("ARGV:-i first prompt", 1, true) end), "no -i: " .. text(term.bufnr))
    qwen.send("line one\nline two")
    assert(wait(10000, function()
      local t = text(term.bufnr)
      return t:find("^[[200~line one", 1, true) and t:find("line two^[[201~", 1, true)
    end), "no bracketed paste: " .. text(term.bufnr))
    term:shutdown()
  end)
  vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT = saved, saved_agent
  assert(ok, err)
end)

-- 2026-10-19: with $QWEN_BIN unset, ~/.local/bin/qwen was never looked at (ipairs stops at a nil), so an
-- older qwen first on the PATH could run (kali: /usr/bin/qwen 0.23.0 next to 0.25.1 in ~/.local/bin)
test("Agent: without QWEN_BIN, Qwen Code comes from ~/.local/bin", function()
  linux_only("~/.local/bin/qwen")
  local agent = require("integrations.agent")
  local home = vim.fn.tempname()
  vim.fn.mkdir(home .. "/.local/bin", "p")
  local own = home .. "/.local/bin/qwen"
  vim.fn.writefile({ "#!/bin/sh" }, own)
  vim.fn.setfperm(own, "rwx------")
  local saved = { vim.env.HOME, vim.env.QWEN_BIN }
  vim.env.HOME, vim.env.QWEN_BIN = home, nil
  local ok, got = pcall(agent.BACKENDS.qwen.bin)
  vim.env.HOME, vim.env.QWEN_BIN = saved[1], saved[2]
  assert(ok and got == own, tostring(got))
end)

test("Agent: GREYKNIGHT_AGENT picks the agent; unset, Qwen Code where it is installed", function()
  local agent = require("integrations.agent")
  local fake = fake_exe(vim.fn.tempname() .. "-qwen")
  local saved = { vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT }
  local ok, err = pcall(function()
    vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT = fake, nil
    assert(agent.backend_id() == "qwen", "unset: " .. agent.backend_id())
    vim.env.GREYKNIGHT_AGENT = "opencode"
    assert(agent.backend_id() == "opencode" and agent.backend().new_session == "/new", "opencode: " .. agent.backend_id())
    vim.env.GREYKNIGHT_AGENT = "qwen"
    assert(agent.backend_id() == "qwen" and agent.bin() == fake, "qwen: " .. agent.bin())
  end)
  vim.env.QWEN_BIN, vim.env.GREYKNIGHT_AGENT = saved[1], saved[2]
  assert(ok, err)
end)

test("Agent (OpenCode): the first prompt is pasted once the TUI is up, /new starts a session", function()
  linux_only("the fake agent (sh + cat -v)")
  local agent, T = require("integrations.agent"), require("toggleterm.terminal")
  local fake = vim.fn.tempname() .. "-opencode"
  vim.fn.writefile({ "#!/bin/sh", 'printf "ARGV:%s|\\n" "$*"', "exec cat -v" }, fake)
  vim.fn.setfperm(fake, "rwx------")
  local saved = { vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT, agent.READY_DELAY }
  vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT, agent.READY_DELAY = fake, "opencode", 100
  local old = T.get(agent.AGENTS.agent, true)
  if old then old:shutdown() end
  local ok, err = pcall(function()
    agent.send("first line\nsecond line")
    local term = T.get(agent.AGENTS.agent, true)
    assert(term and term.display_name == "OpenCode", "no OpenCode terminal")
    assert(wait(10000, function()
      local t = text(term.bufnr)
      return t:find("^[[200~first line", 1, true) and t:find("second line^[[201~", 1, true)
    end), "first prompt not pasted: " .. text(term.bufnr))
    assert(text(term.bufnr):find("ARGV:|", 1, true), "the prompt went on the command line: " .. text(term.bufnr))
    agent.new_session()
    assert(wait(5000, function() return text(term.bufnr):find("/new", 1, true) end), "no /new: " .. text(term.bufnr))
    local msg
    agent.model_info(function(m) msg = m end)
    assert(msg and msg:find("/models", 1, true), tostring(msg))
    term:shutdown()
  end)
  vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT, agent.READY_DELAY = saved[1], saved[2], saved[3]
  assert(ok, err)
end)

-- 2026-10-19: the agent was started by its quoted name. cmd.exe gives a .cmd it found on the PATH the current
-- directory as its own folder (%~dp0): on Windows opencode.cmd did not find its launcher script.
-- 2026-10-21: the agent's command goes through cmd.exe on Windows (toggleterm), which expands %VAR% even in quotes - a
-- first prompt about "%PATH%" arrived with the machine's PATH in it. On Windows it is pasted once the TUI is up.
test("Agent: a first prompt never goes through cmd.exe - Windows pastes it, elsewhere it is one quoted argument", function()
  local agent = require("integrations.agent")
  local saved = vim.g.greyknight_agent
  vim.g.greyknight_agent = "qwen"
  local ok, err = pcall(function()
    local prompt = 'explain "100% of %PATH%" & <this> !x! $(y) `z`'
    local cmd = agent.command(prompt)
    if WIN then
      assert(not cmd:find("PATH", 1, true) and not cmd:find(" -i ", 1, true), "the prompt is on cmd.exe's command line: " .. cmd)
    else
      assert(vim.endswith(cmd, " -i " .. vim.fn.shellescape(prompt)), cmd)
      local out = vim.fn.system({ "sh", "-c", "printf '%s' " .. vim.fn.shellescape(prompt) })
      assert(out == prompt, "sh read the argument as " .. out)
    end
  end)
  vim.g.greyknight_agent = saved
  assert(ok, err)
end)

test("Agent: starts by the full path of its binary, not by a name looked up on the PATH", function()
  local agent = require("integrations.agent")
  local dir = tmpdir()
  local fake = fake_exe(dir .. "/gk-fake-opencode")
  local saved = { vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT, vim.env.PATH }
  vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT = "gk-fake-opencode", "opencode"
  vim.env.PATH = dir .. (WIN and ";" or ":") .. vim.env.PATH
  local ok, got = pcall(agent.command)
  vim.env.OPENCODE_BIN, vim.env.GREYKNIGHT_AGENT, vim.env.PATH = saved[1], saved[2], saved[3]
  vim.fn.delete(dir, "rf")
  assert(ok, got)
  local unquoted = got:match('^"(.*)"$') or got:match("^'(.*)'$") or got
  local function same(a, b) -- Windows: case does not matter (exepath() has the extension as in PATHEXT: .CMD)
    a, b = vim.fs.normalize(a), vim.fs.normalize(b)
    if WIN then a, b = a:lower(), b:lower() end
    return a == b
  end
  assert(same(unquoted, fake), got)
end)

-- 2026-10-20: going to a toggleterm window (an agent, the REPL, a shell) means typing there - insert (terminal) mode,
-- also when <C-h> left it in normal mode, which toggleterm brings back on the way in (persist_mode); not once its
-- program has exited (a key would close the window). startinsert / stopinsert are recorded here instead of done:
-- their order is the point. The stand-in is a plain toggleterm terminal, as a shell or the REPL is.
test("Terminals: going to a shell, REPL or agent window means insert mode, not once its program has exited", function()
  local T = require("toggleterm.terminal")
  local code = vim.api.nvim_get_current_win()
  local term = T.Terminal:new({ cmd = py_cmd("import time; time.sleep(60)"), direction = "vertical", close_on_exit = false })
  local real, calls = vim.cmd, {}
  local function enter_from_code() -- out of the agent's window the way <C-h> leaves it, then back in (<C-l>)
    vim.api.nvim_set_current_win(code)
    term.__state.mode = T.mode.NORMAL -- what toggleterm remembers after <C-h> (<C-\><C-n> first)
    calls = {}
    vim.cmd = setmetatable({}, {
      __call = function(_, c)
        if c == "startinsert" or c == "stopinsert" then calls[#calls + 1] = c else return real(c) end
      end,
      __index = function(_, k) return real[k] end,
    })
    vim.api.nvim_set_current_win(term.window)
    wait(300, function() return false end) -- the scheduled callbacks run
    vim.cmd = real
    return calls
  end
  local ok, err = pcall(function()
    term:open(40, "vertical")
    local seq = enter_from_code()
    assert(seq[1] == "stopinsert" and seq[#seq] == "startinsert", "not insert mode on the way in: " .. vim.inspect(seq))
    vim.fn.jobstop(term.job_id)
    assert(wait(5000, function() return vim.fn.jobwait({ term.job_id }, 0)[1] ~= -1 end), "the stand-in agent did not stop")
    seq = enter_from_code()
    assert(seq[#seq] ~= "startinsert", "insert mode in an exited program's window: " .. vim.inspect(seq))
  end)
  vim.cmd = real
  pcall(function() term:shutdown() end)
  if vim.api.nvim_win_is_valid(code) then vim.api.nvim_set_current_win(code) end
  assert(ok, err)
end)

-- 2026-10-21: every terminal, not only toggleterm's - a run's output where the program waits for input, :terminal:
-- going there means terminal mode (on Windows they stayed in normal mode); not once the program has exited
test("Terminals: going to any terminal whose program runs - a run's output, :terminal - means terminal mode; not once it has exited", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local code = vim.api.nvim_get_current_win()
  local real = vim.cmd
  local function enter(win) -- from the code window into `win`; startinsert / stopinsert recorded, not done
    vim.api.nvim_set_current_win(code)
    local calls = {}
    vim.cmd = setmetatable({}, {
      __call = function(_, c)
        if c == "startinsert" or c == "stopinsert" then calls[#calls + 1] = c else return real(c) end
      end,
      __index = function(_, k) return real[k] end,
    })
    vim.api.nvim_set_current_win(win)
    wait(300, function() return false end) -- the scheduled callbacks run
    vim.cmd = real
    vim.api.nvim_set_current_win(code)
    return calls
  end
  local root = tmpdir()
  local file = root .. "/ask.py"
  vim.fn.writefile({ 'input("name? ")' }, file)
  local term_win, term_buf, task
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(file))
    code = vim.api.nvim_get_current_win()
    runner.run_file()
    task = tasks.state.last
    assert(wait(10000, function() return task_out(task):find("name?", 1, true) end), "the run did not ask: " .. task_out(task))
    local out_win = vim.fn.bufwinid(task:get_bufnr())
    assert(out_win ~= -1, "the run's output is not shown")
    local seq = enter(out_win)
    assert(seq[#seq] == "startinsert", "a run's output waiting for input: no terminal mode on the way in - " .. vim.inspect(seq))
    vim.cmd("belowright split")
    vim.cmd.terminal(py_cmd("import time; time.sleep(60)"))
    term_win, term_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(code)
    seq = enter(term_win)
    assert(seq[#seq] == "startinsert", ":terminal: no terminal mode on the way in - " .. vim.inspect(seq))
    vim.fn.jobstop(vim.b[term_buf].terminal_job_id)
    assert(wait(5000, function() return vim.fn.jobwait({ vim.b[term_buf].terminal_job_id }, 0)[1] ~= -1 end), ":terminal's program did not end")
    seq = enter(term_win)
    assert(seq[#seq] ~= "startinsert", "terminal mode in an exited program's window: " .. vim.inspect(seq))
  end)
  vim.cmd = real
  if task then pcall(function() task:stop() end) end
  if term_win and vim.api.nvim_win_is_valid(term_win) then pcall(vim.api.nvim_win_close, term_win, true) end
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then pcall(vim.api.nvim_buf_delete, term_buf, { force = true }) end
  if vim.api.nvim_win_is_valid(code) then vim.api.nvim_set_current_win(code) end
  vim.cmd("stopinsert")
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: in a terminal only the window keys are Neovim's - Ctrl+H/J/K/L to the next window, Ctrl+arrows resize;
-- every other key is the program's: bash's Ctrl+A/E/W/U/R and Alt+B/F as typed. Ctrl+L went to the shell (its clear),
-- Ctrl+arrows too. The stand-in reports every key it gets (Windows: msvcrt, where Alt+B arrives as b).
local KEY_REPORTER = WIN and {
  "import msvcrt, sys",
  "print('READY', flush=True)",
  "while True:",
  "    c = msvcrt.getwch()",
  "    s = c + (msvcrt.getwch() if c in '\\x00\\xe0' else '')",
  "    print('GOT ' + ' '.join('%02x' % ord(ch) for ch in s), flush=True)",
} or {
  "import os, sys, tty, termios",
  "fd = sys.stdin.fileno(); old = termios.tcgetattr(fd); tty.setraw(fd)",
  "os.write(1, b'READY\\r\\n')",
  "try:",
  "    while True:",
  "        os.write(1, ('GOT ' + ' '.join('%02x' % x for x in os.read(fd, 32)) + '\\r\\n').encode())",
  "finally:",
  "    termios.tcsetattr(fd, termios.TCSADRAIN, old)",
}
test("Terminals: Ctrl+L goes to the window on the right, Ctrl+arrows resize - bash's own keys reach the program as typed", function()
  local script = vim.fn.tempname() .. ".py"
  vim.fn.writefile(KEY_REPORTER, script)
  local start = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local right = vim.api.nvim_get_current_win()
  vim.cmd("wincmd h")
  local left = vim.api.nvim_get_current_win()
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    vim.fn.jobstart({ require("devsuite.util").system_python(), script }, { term = true })
    assert(wait(10000, function() return text(buf):find("READY", 1, true) end), "the stand-in did not start: " .. text(buf))
    local width, narrowed = vim.api.nvim_win_get_width(left), nil
    local keys, i = { "<C-a>", "<A-b>", "<A-f>", "<C-e>", "<C-w>", "<C-u>", "<C-r>", "<C-Left>", "<C-l>" }, 0
    local function step() -- one key every 200 ms, in terminal mode
      i = i + 1
      if keys[i - 1] == "<C-Left>" then narrowed = vim.api.nvim_win_get_width(left) end
      if not keys[i] then return end
      vim.api.nvim_feedkeys(vim.keycode(keys[i]), "t", false)
      vim.defer_fn(step, 200)
    end
    vim.defer_fn(step, 200)
    local stop = vim.uv.new_timer() -- out of terminal mode if Ctrl+L does not leave it
    stop:start(15000, 0, vim.schedule_wrap(function() vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n>"), "nt", false) end))
    vim.api.nvim_feedkeys("i", "tx!", false) -- returns when terminal mode ends
    stop:stop()
    stop:close()
    assert(vim.api.nvim_get_current_win() == right, "Ctrl+L did not go to the window on the right")
    assert(narrowed == width - 2, ("Ctrl+Left: the terminal is %s wide, was %d"):format(tostring(narrowed), width))
    local want = WIN and { "01", "62", "66", "05", "17", "15", "12" } or { "01", "1b 62", "1b 66", "05", "17", "15", "12" }
    wait(3000, function() local _, n = text(buf):gsub("GOT ", ""); return n >= #want end)
    local got = {}
    for g in text(buf):gmatch("GOT ([%x ]+)") do got[#got + 1] = vim.trim(g) end
    assert(vim.deep_equal(got, want), "typed " .. vim.inspect(want) .. ", the program got " .. vim.inspect(got))
  end)
  -- the program ended before its window changes size: Neovim 0.12.6 on Windows crashed (access violation) deleting a
  -- terminal that was resized between jobstop() and the end of its program
  local job = vim.b[buf].terminal_job_id
  if job then
    pcall(vim.fn.jobstop, job)
    wait(5000, function() return vim.fn.jobwait({ job }, 0)[1] ~= -1 end)
  end
  if vim.api.nvim_win_is_valid(right) and right ~= start then pcall(vim.api.nvim_win_close, right, true) end
  if vim.api.nvim_win_is_valid(left) then vim.api.nvim_set_current_win(left) end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.cmd("stopinsert")
  vim.fn.delete(script)
  assert(ok, err)
end)

-- ── Stabilization: the behaviour of 2026-10-15, pinned down ──

-- Completion: types like a user; each step waits until the menu is open (or 5 s), then feeds its keys
local function complete_scenario(steps)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foobar_long_identifier = 1", "" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  local seen = {}
  local function step_at(i, waited)
    local step = steps[i]
    if not step then return end
    local cmp = require("blink.cmp")
    if step.menu and not cmp.is_visible() and waited < 5000 then
      return vim.defer_fn(function() step_at(i, waited + 100) end, 100)
    end
    if step.probe then
      seen.visible = cmp.is_visible()
      seen.selected = require("blink.cmp.completion.list").selected_item_idx
      seen.ghost = require("blink.cmp.completion.windows.ghost_text").is_open()
    end
    vim.api.nvim_feedkeys(vim.keycode(step.keys), "t", false)
    vim.defer_fn(function() step_at(i + 1, 0) end, 300)
  end
  vim.defer_fn(function() step_at(1, 0) end, 100)
  vim.api.nvim_feedkeys("Afoo", "tx!", false) -- returns when <Esc> ends insert mode
  vim.wait(300)
  return seen, vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local ENTER = { { keys = "<CR>", menu = true, probe = true }, { keys = "<Esc>" } }
local TAB_ENTER = { { keys = "<Tab>", menu = true, probe = true }, { keys = "<CR>" }, { keys = "<Esc>" } }

test("Completion: Enter at the end of a line is a new line when nothing was picked", function()
  complete_scenario(ENTER) -- warm-up: blink loads its matcher on first use
  local seen, lines = complete_scenario(ENTER)
  assert(seen.visible, "completion menu did not open")
  assert(seen.selected == nil, "an item was preselected: " .. tostring(seen.selected))
  assert(seen.ghost, "no grey preview of the top suggestion")
  assert(vim.deep_equal(lines, { "foobar_long_identifier = 1", "foo", "" }), vim.inspect(lines))
end)

test("Completion: Tab picks the suggestion, Enter accepts it", function()
  local seen, lines = complete_scenario(TAB_ENTER)
  assert(seen.visible, "completion menu did not open")
  assert(vim.deep_equal(lines, { "foobar_long_identifier = 1", "foobar_long_identifier" }), vim.inspect(lines))
end)

-- 2026-10-21: completion as you use it - types `typed` at the end of line `lnum` (insert mode), waits until the menu
-- has an item whose label starts with `want` (from `source`: lsp, snippets, path, buffer), picks it with <Tab>, takes
-- it with <CR> and, once blink has taken it, leaves with <Esc> (opts.at_once: <CR><Esc> in one go, faster than blink).
-- Returns the buffer's lines and what the menu showed.
local function complete_in(lnum, typed, want, source, opts)
  opts = opts or {}
  local cmp = require("blink.cmp")
  local seen, waited = {}, 0
  -- the steps are over: taken and left, given up, or failed. A snippet ends insert mode by itself (its placeholder
  -- is selected), so the keys below return before the last step ran - on a busy machine after the 300 ms that were
  -- waited for it, and "not taken" was read before it was told (2026-10-22)
  local done = false
  -- an error in a step ends insert mode and is told: unseen, it was a hit-enter prompt that kept the test window
  -- waiting for keys that never came
  local function guarded(fn)
    return function(...)
      local ok, e = pcall(fn, ...)
      if not ok then
        seen.error, done = tostring(e), true
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "t", false)
      end
    end
  end
  local function match(it) return it and tostring(it.label):find(want, 1, true) == 1 and (not source or it.source_id == source) end
  local function find()
    for _, it in ipairs(cmp.get_items() or {}) do if match(it) then return it end end
  end
  local taken, waited_esc = false, 0
  local esc
  -- <Esc> once blink has taken the item - a moment after <CR>; on a busy machine it took over 5 s, and the Esc
  -- before it dropped the item (as it should) - else after 15 s
  esc = guarded(function()
    if not taken and waited_esc < 15000 then
      waited_esc = waited_esc + 50
      return vim.defer_fn(esc, 50)
    end
    seen.taken, seen.mode = taken, vim.api.nvim_get_mode().mode
    if not taken then -- what there was instead, for the failure message
      local sel = cmp.get_selected_item()
      seen.instead = ("line %q, menu %s, selected %s"):format(vim.api.nvim_get_current_line(), tostring(cmp.is_visible()), sel and tostring(sel.label) or "nothing")
    end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "t", false)
    done = true
  end)
  local pick
  pick = guarded(function(n) -- <Tab> until the item is the selected one, then <CR>
    if match(cmp.get_selected_item()) then
      if opts.at_once then
        done = true
        return vim.api.nvim_feedkeys(vim.keycode("<CR><Esc>"), "t", false)
      end
      vim.api.nvim_create_autocmd("User", { pattern = "BlinkCmpAccept", once = true, callback = function() taken = true end })
      vim.api.nvim_feedkeys(vim.keycode("<CR>"), "t", false)
      return vim.defer_fn(esc, 50)
    end
    if n > 40 then -- never selected: what was, for the failure message
      local sel = cmp.get_selected_item()
      seen.instead = ("Tab never reached it - selected %s, %d items"):format(sel and tostring(sel.label) or "nothing", #(cmp.get_items() or {}))
      done = true
      return vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "t", false)
    end
    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "t", false)
    vim.defer_fn(function() pick(n + 1) end, 150)
  end)
  -- Tab once the menu has settled - the same items twice in a row: the sources answer one after the other (the
  -- snippets load on first use), and a list still filling up moved the selection away under the Tabs
  local last_count
  local poll
  poll = guarded(function()
    local count = #(cmp.get_items() or {})
    if (find() and count == last_count) or waited >= 20000 then
      seen.found = find() ~= nil
      seen.items = vim.tbl_map(function(it) return tostring(it.source_id) .. ":" .. tostring(it.label) end, vim.list_slice(cmp.get_items() or {}, 1, 12))
      if seen.found then return pick(0) end
      done = true
      return vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "t", false)
    end
    last_count = count
    waited = waited + 100
    vim.defer_fn(poll, 100)
  end)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  -- "A" first, the text a moment later, as a person types: queued with the "A", blink missed the session's first
  -- completion (its menu came only with the next key)
  vim.defer_fn(guarded(function()
    vim.api.nvim_feedkeys(typed, "t", false)
    vim.defer_fn(poll, 100)
  end), 50)
  vim.api.nvim_feedkeys("A", "tx!", false) -- returns when insert mode ends: our <Esc>, or a snippet's placeholder
  wait(30000, function() return done end)
  vim.wait(300)
  assert(not seen.error, "a completion step failed: " .. tostring(seen.error))
  return vim.api.nvim_buf_get_lines(0, 0, -1, false), seen
end

test("Completion: pyright's suggestions in the menu - os.getc offers getcwd (LSP), Tab picks it, Enter takes it", function()
  if vim.fn.executable("pyright-langserver") == 0 then H.skip("pyright-langserver not installed (Mason installs it with the first Python file)") end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p")
  vim.fn.writefile({ "import os", "" }, root .. "/main.py")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  for _, c in ipairs(vim.lsp.get_clients()) do if c.name == "pyright" or c.name == "ruff" then c:stop(true) end end
  -- gone, not only stopping: the file was given to the stopping one (an earlier test's), which answered nothing
  wait(10000, function() return #vim.lsp.get_clients({ name = "pyright" }) + #vim.lsp.get_clients({ name = "ruff" }) == 0 end)
  local buf
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
    buf = vim.api.nvim_get_current_buf()
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "pyright" }) > 0 end), "pyright did not start")
    -- attached is not ready: on a busy machine pyright answered the first request (at the ".") only seconds later,
    -- the menu stayed shut until the next key. Typing starts once it answers one - at the end of "import os".
    assert(wait(60000, function()
      local res = vim.lsp.buf_request_sync(buf, "textDocument/completion",
        { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 9 } }, 5000)
      for _, r in pairs(res or {}) do if r.result then return true end end
    end), "pyright does not answer")
    local lines, seen = complete_in(2, "os.getc", "getcwd", "lsp")
    assert(seen.found, "no getcwd from pyright in the menu: " .. vim.inspect(seen.items))
    assert(lines[2]:find("os.getcwd", 1, true) == 1, "after Tab and Enter: " .. lines[2])
  end)
  if buf then stop_clients(buf) end
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Completion: snippets - ifmain becomes the main guard (friendly-snippets), its placeholder selected to type over", function()
  vim.cmd("enew!")
  vim.bo.filetype = "python"
  -- the snippets alone: a language server's late answer replaced the menu's items, and the picked one with them
  vim.wait(100)
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do vim.lsp.buf_detach_client(0, c.id) end
  local ok, err = pcall(function()
    local lines, seen = complete_in(1, "ifmai", "ifmain", "snippets")
    assert(seen.found, "no ifmain snippet in the menu: " .. vim.inspect(seen.items))
    assert(seen.taken, "blink did not take the snippet within 15 s - " .. tostring(seen.instead))
    assert(table.concat(lines, "\n"):find('if __name__ == "__main__":', 1, true), "after Enter: " .. vim.inspect(lines))
    assert(seen.mode == "s", "the placeholder is not selected to type over - mode " .. tostring(seen.mode))
  end)
  pcall(vim.snippet.stop)
  vim.cmd("bwipeout!")
  assert(ok, err)
end)

test("Completion: paths - ./sub/al offers alpha.txt from the file's folder (path source), Enter takes it", function()
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "x" }, root .. "/sub/alpha.txt")
  vim.fn.writefile({ "" }, root .. "/notes.txt")
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes.txt"))
    local lines, seen = complete_in(1, "./sub/al", "alpha.txt", "path")
    assert(seen.found, "no alpha.txt from the path source: " .. vim.inspect(seen.items))
    assert(lines[1] == "./sub/alpha.txt", "after Enter: " .. lines[1])
  end)
  vim.cmd("bwipeout!")
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Completion: Enter and Esc in one go - the item Tab showed stays, no window left behind, no error", function()
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/sub", "p")
  vim.fn.writefile({ "x" }, root .. "/sub/alpha.txt")
  vim.fn.writefile({ "" }, root .. "/notes.txt")
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, o)
    if (level or 0) >= vim.log.levels.ERROR then notes[#notes + 1] = tostring(msg) end
    return notify(msg, level, o)
  end
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes.txt"))
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local _, seen = complete_in(1, "./sub/al", "alpha.txt", "path", { at_once = true })
    assert(seen.found, "no alpha.txt from the path source: " .. vim.inspect(seen.items))
    vim.wait(500) -- blink's accept comes now, after the Esc
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      assert(vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "blink-cmp-dot-repeat", "blink's 1x1 dot-repeat window was left open")
    end
    assert(vim.api.nvim_get_current_win() == win, "the cursor is in another window, on " .. vim.bo.filetype)
    assert(vim.api.nvim_get_mode().mode == "n", "mode " .. vim.api.nvim_get_mode().mode)
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    assert(line == "./sub/alpha.txt", "the line: " .. line)
    assert(#notes == 0, "an error: " .. table.concat(notes, " | "))
  end)
  vim.notify = notify
  for _, w in ipairs(vim.api.nvim_list_wins()) do -- a window left behind would hold every later test
    if vim.api.nvim_win_get_config(w).relative ~= "" then pcall(vim.api.nvim_win_close, w, true) end
  end
  vim.cmd("silent! bwipeout!")
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Keys: F6 runs the current file as a task", function()
  local tasks = require("devsuite.tasks")
  vim.cmd.edit(H.file("hello.py", { 'print("via F6")' }))
  local before = tasks.state.last
  vim.api.nvim_feedkeys(vim.keycode("<F6>"), "x", false)
  local task = tasks.state.last
  assert(task and task ~= before, "F6 started no task")
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  assert(task.status == "SUCCESS" and task_out(task):find("via F6", 1, true), task.status .. ": " .. task_out(task))
end)

test("Keys: <leader>rs runs the visual selection (lines 2-3 only)", function()
  local tasks = require("devsuite.tasks")
  vim.cmd.edit(H.file("sel.py", { "print('first')", "print('second')", "print('third')" }))
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.api.nvim_feedkeys("Vj rs", "x", false)
  local task = tasks.state.last
  assert(wait(10000, function() return task and task:is_complete() end), "did not finish")
  local out = task_out(task)
  assert(out:find("second", 1, true) and out:find("third", 1, true) and not out:find("first", 1, true), out)
  assert(task.name:find("L2-3", 1, true), task.name)
end)

test("Keys: <leader>aa / <leader>ae send the file and the selected lines to Qwen", function()
  local qwen = require("integrations.agent")
  local send, input, cwd = qwen.send, vim.ui.input, vim.fn.getcwd()
  local sent = {}
  qwen.send = function(text) sent[#sent + 1] = text end
  vim.ui.input = function(_, cb) cb("rename it") end
  local ok, err = pcall(function()
    local file = H.file("calc.py", { "def add(a, b):", "    return a + b", "", "print(add(1, 2))" })
    vim.cmd.cd(vim.fs.dirname(file))
    vim.cmd.edit(file)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys("Vj aa", "x", false) -- ask about lines 1-2
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys("V ae", "x", false) -- edit line 2
    vim.api.nvim_feedkeys(" aa", "x", false) -- ask about the whole file
    assert(#sent == 3, "expected 3 prompts, got " .. #sent)
    local ask, edit, file_ask = sent[1], sent[2], sent[3]
    assert(ask:find("@calc.py", 1, true) and ask:find("lines 1-2", 1, true) and ask:find("return a + b", 1, true), ask)
    assert(ask:find("rename it", 1, true) and ask:find("do not modify", 1, true), ask)
    assert(edit:find("Edit @calc.py, lines 2-2", 1, true) and edit:find("Instruction: rename it", 1, true), edit)
    assert(not edit:find("def add", 1, true), "edit prompt contains unselected lines: " .. edit)
    assert(file_ask:find("@calc.py", 1, true) and not file_ask:find("lines ", 1, true), file_ask)
  end)
  qwen.send, vim.ui.input = send, input
  vim.cmd.cd(cwd)
  assert(ok, err)
end)

-- 2026-10-21: what a pytest run on Windows wrote, as it arrived - ConPTY skips blank lines with a move to a later row
-- ("\27[19;1H"), which joined "E ... where 4 = add(2, 2)" and "test_calc.py:6: AssertionError": no mark, no quickfix
test("Errors: Windows' ConPTY output - a move to a later row starts a line; pytest's failure after one is found", function()
  local errors = require("devsuite.errors")
  local dir = tmpdir()
  vim.fn.writefile({ "x" }, dir .. "/test_calc.py")
  local raw = {
    "collected 1 item      \27[9;1Htest_calc.py \27]9;4;2;0\27\\\27]9;4;0;\27\\F     [100%]\27[11;1H===== FAILURES =====",
    ">       assert add(2, 2) == 5",
    "E       assert 4 == 5",
    "E        +  where 4 = add(2, 2)\27[19;1Htest_calc.py:6: AssertionError",
  }
  local lines = errors.lines(raw)
  assert(vim.deep_equal(vim.list_slice(lines, #lines - 1), { "E        +  where 4 = add(2, 2)", "test_calc.py:6: AssertionError" }), vim.inspect(lines))
  assert(lines[2] == "test_calc.py F     [100%]", vim.inspect(lines))
  local items = errors.parse(raw, { cwd = dir })
  assert(#items == 1 and items[1].lnum == 6 and items[1].text:find("assert 4 == 5", 1, true), vim.inspect(items))
end)

test("Errors: parser fixtures (chained, SyntaxError, library frames, set -u, dash, warnings, noise)", function()
  local errors = require("devsuite.errors")
  local py = H.file("app.py", { "x" })
  local sh = H.file("job.sh", { "x" })
  local function kinds(items) return table.concat(vim.tbl_map(function(i) return i.type .. i.lnum end, items), " ") end
  local chained = errors.parse({
    "Traceback (most recent call last):", ('  File "%s", line 3, in load'):format(py), "    return d['k']", "KeyError: 'k'", "",
    "During handling of the above exception, another exception occurred:", "",
    "Traceback (most recent call last):", ('  File "%s", line 9, in <module>'):format(py), "    load()",
    ('  File "%s", line 5, in load'):format(py), "    raise ValueError('bad')", "ValueError: bad",
  }, {})
  assert(kinds(chained) == "E3 I9 E5", kinds(chained))
  assert(chained[1].text == "KeyError: 'k'" and chained[3].text == "ValueError: bad", vim.inspect(chained))
  local syntax = errors.parse({ ('  File "%s", line 4'):format(py), "    if x", "        ^", "SyntaxError: expected ':'" }, {})
  assert(kinds(syntax) == "E4" and syntax[1].text == "SyntaxError: expected ':'", vim.inspect(syntax))
  local lib = errors.parse({
    "Traceback (most recent call last):", ('  File "%s", line 7, in <module>'):format(py), "    json.loads(s)",
    '  File "/usr/lib/python3.13/json/__init__.py", line 346, in loads', "    return _default_decoder.decode(s)",
    "json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)",
  }, {})
  local own = vim.tbl_filter(function(i) return i.type == "E" end, lib)
  assert(#own == 1 and own[1].filename == vim.fs.normalize(py) and own[1].lnum == 7, vim.inspect(lib))
  if not WIN then -- bash / dash output: Linux only for now
    assert(kinds(errors.parse({ sh .. ": line 4: TARGET: unbound variable", sh .. ": 6: nmapx: not found" }, {})) == "E4 E6", "bash / dash")
  end
  assert(kinds(errors.parse({ py .. ":2: DeprecationWarning: old api" }, {})) == "W2", "warning")
  local noise = errors.parse({ "Error: 404: Not Found", "10.10.10.5:8080 open", "HTTP/1.1 200 OK", "line 3: nothing", "E   not pytest" }, {})
  assert(#noise == 0, "noise matched: " .. vim.inspect(noise))
end)

test("Tasks: stop, hide/show the output, status bar, watch, restart", function()
  local tasks = require("devsuite.tasks")
  vim.cmd.edit(H.file("loop.py", { "import time", "print('started', flush=True)", "time.sleep(30)" }))
  require("devsuite.runner").run_file()
  local task = tasks.state.last
  assert(wait(5000, function() return task_out(task):find("started", 1, true) end), "did not start")
  vim.g.statusline_winid = tasks.state.win
  assert(tasks.winbar():find("RUNNING", 1, true), tasks.winbar())
  tasks.toggle_watch()
  assert(task:has_component("restart_on_save"), "watch did not turn on")
  tasks.toggle_watch()
  assert(not task:has_component("restart_on_save"), "watch did not turn off")
  tasks.stop()
  assert(wait(5000, function() return task:is_complete() end), "did not stop")
  assert(task.status == "CANCELED", task.status)
  assert(task_out(task):find("started", 1, true), "output gone after stop")
  tasks.toggle()
  assert(tasks.state.win == nil, "output window still open")
  tasks.toggle()
  assert(tasks.state.win and vim.api.nvim_win_get_buf(tasks.state.win) == task:get_bufnr(), "output not shown again")
  local run = tasks.state.runs[task.id]
  local starts = run.starts
  tasks.rerun()
  assert(wait(5000, function() return run.starts > starts end), "did not restart")
  tasks.stop()
  wait(5000, function() return task:is_complete() end)
end)

-- 2026-10-21: <leader>ro with the output as the last window - a notification (a float) counted as a second window, the
-- output was closed: E444 "Cannot close last window"
test("Tasks: <leader>ro hides the output also when it is the last window, a notification up - the window shows code", function()
  local tasks = require("devsuite.tasks")
  local code = H.file("last.py", { "print('last window')" })
  vim.cmd.edit(code)
  require("devsuite.runner").run_file()
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, { relative = "editor", row = 1, col = 1, width = 20, height = 2 })
  local ok, err = pcall(function()
    vim.api.nvim_set_current_win(tasks.state.win)
    vim.cmd("only") -- the output is the last window (the float aside)
    tasks.toggle()
    assert(tasks.state.win == nil, "output still shown")
    local win = vim.api.nvim_get_current_win()
    assert(vim.api.nvim_win_get_buf(win) ~= task:get_bufnr() and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "", "the window does not show code")
    assert(vim.wo[win].number == vim.go.number and vim.wo[win].signcolumn == vim.go.signcolumn, "the output's window options stayed")
    tasks.toggle() -- and back
    assert(tasks.state.win and vim.api.nvim_win_get_buf(tasks.state.win) == task:get_bufnr(), "output not shown again")
  end)
  pcall(vim.api.nvim_win_close, float, true)
  assert(ok, err)
end)

-- ── Dev workflows (2026-10-21): the loops of a working day, end to end with the real tools ───────────────────────

test("Python: pyright and ruff - an undefined name marked, gd to another file, <leader>rn in both, a code action, :w formats", function()
  for _, exe in ipairs({ "pyright-langserver", "ruff" }) do
    if vim.fn.executable(exe) == 0 then H.skip(exe .. " not installed (Mason installs it with the first Python file)") end
  end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p") -- the project's root for the servers
  vim.fn.writefile({ "def greet(name):", '    return "hi " + name' }, root .. "/helpers.py")
  vim.fn.writefile({ "import os", "from helpers import greet", "", 'print(greet("x"))', "print(undefined_name)", "x=1" }, root .. "/main.py")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  -- the project's own servers, as in a session started there: earlier tests' pyright had a temp folder above this one
  -- as its workspace - this project was no workspace of its own, and pyright found "nothing to rename" (Kali)
  for _, c in ipairs(vim.lsp.get_clients()) do
    if c.name == "pyright" or c.name == "ruff" then c:stop(true) end
  end
  wait(5000, function() return #vim.lsp.get_clients({ name = "pyright" }) + #vim.lsp.get_clients({ name = "ruff" }) == 0 end)
  local buf
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
    buf = vim.api.nvim_get_current_buf()
    local function client(name) return #vim.lsp.get_clients({ bufnr = buf, name = name }) > 0 end
    assert(wait(60000, function() return client("pyright") and client("ruff") end), "servers: " .. table.concat(
      vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = buf })), ", "))
    local function diag(lnum, text)
      for _, d in ipairs(vim.diagnostic.get(buf, { lnum = lnum })) do
        if (d.message .. " " .. tostring(d.code)):find(text, 1, true) then return d end
      end
    end
    assert(wait(60000, function() return diag(4, "undefined_name") and diag(0, "F401") end), "marks: " .. vim.inspect(vim.tbl_map(
      function(d) return d.lnum .. ": " .. d.message end, vim.diagnostic.get(buf))))
    -- gd: to the function in helpers.py
    vim.api.nvim_win_set_cursor(0, { 4, 7 })
    vim.api.nvim_feedkeys("gd", "x", false)
    local function shown() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
    assert(wait(10000, function() return shown() == root .. "/helpers.py" end), "gd went to " .. shown())
    assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "gd: line " .. vim.api.nvim_win_get_cursor(0)[1])
    -- <leader>rn: greet -> welcome, here and in helpers.py
    vim.cmd.buffer(buf)
    vim.api.nvim_win_set_cursor(0, { 4, 7 })
    local helpers = vim.fn.bufnr(root .. "/helpers.py")
    local function has(b, text) return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n"):find(text, 1, true) ~= nil end
    local function renamed() return has(buf, 'welcome("x")') and has(buf, "import welcome") and has(helpers, "def welcome") end
    for _ = 1, 15 do -- pyright answers "nothing to rename" while it is still analysing: as you would, again
      vim.lsp.buf.rename("welcome")
      if wait(2000, renamed) then break end
    end
    assert(renamed(), "rename: " .. H.text(buf) .. " | " .. H.text(helpers))
    -- ruff's code action: the unused import goes (the cursor on it, as on any mark)
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    vim.lsp.buf.code_action({ apply = true, filter = function(a) return (a.title or ""):find("Remove unused import", 1, true) ~= nil end })
    assert(wait(10000, function() return not has(buf, "import os") end), "code action: " .. H.text(buf))
    -- :w formats (ruff format); both files written (not :wall - an earlier test's buffer may have no name)
    for _, b in ipairs({ buf, helpers }) do vim.api.nvim_buf_call(b, function() vim.cmd("silent write") end) end
    assert(wait(5000, function() return vim.tbl_contains(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "x = 1") end), "not formatted: " .. H.text(buf))
    assert(vim.fn.readfile(root .. "/helpers.py")[1] == "def welcome(name):", "helpers.py on disk: " .. vim.fn.readfile(root .. "/helpers.py")[1])
  end)
  if buf then stop_clients(buf) end
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- A language server in this process that can only what `capabilities` says; answers[method](params) answers a request
local function fake_lsp(capabilities, answers)
  answers = answers or {}
  return function(dispatchers)
    local closing, id = false, 0
    return {
      request = function(method, params, callback)
        id = id + 1
        if method == "initialize" then callback(nil, { capabilities = capabilities })
        elseif method == "shutdown" then callback(nil, vim.NIL)
        elseif answers[method] then
          local result = answers[method](params)
          vim.schedule(function() callback(nil, result) end) -- an answer comes later, as from a process
        end
        return true, id
      end,
      notify = function(method)
        if method == "exit" then
          closing = true
          dispatchers.on_exit(0, 0)
        end
        return true
      end,
      is_closing = function() return closing end,
      terminate = function() closing = true end,
    }
  end
end

-- 2026-10-21, from the error log: gd in a file whose server finds no definitions (html, ruff alone) said "method
-- textDocument/definition is not supported by any server" - the LSP keys came with every server
test("LSP: keys only for what the server can - gd is Vim's where none finds definitions; ]d / [d jump (not the deprecated goto)", function()
  local file = H.file("plain.txt", { "value = 1", "print(value)", "" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, opts)
    notes[#notes + 1] = tostring(msg)
    return notify(msg, level, opts)
  end
  local ok, err = pcall(function()
    vim.lsp.start({ name = "gk-fake", cmd = fake_lsp({}), root_dir = vim.fs.dirname(file) }, { bufnr = buf })
    assert(wait(5000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "gk-fake" }) > 0 end), "the fake server did not attach")
    vim.wait(50)
    assert(vim.fn.maparg("gd", "n", false, true).buffer ~= 1, "gd is the LSP's for a server without definitions")
    vim.api.nvim_win_set_cursor(0, { 2, 7 }) -- on value
    vim.api.nvim_feedkeys("gd", "x", false)
    assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "gd (Vim's): line " .. vim.api.nvim_win_get_cursor(0)[1] .. " - " .. table.concat(notes, " | "))
    -- ]d / [d between diagnostics
    local ns = vim.api.nvim_create_namespace("gk-test-jump")
    vim.diagnostic.set(ns, buf, { { lnum = 1, col = 0, message = "here", severity = vim.diagnostic.severity.WARN } })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local jump = vim.fn.maparg("]d", "n", false, true)
    assert(jump.callback ~= vim.diagnostic.goto_next, "]d is the deprecated vim.diagnostic.goto_next")
    -- nothing deprecated: Neovim 0.12 tells a soft deprecation nowhere but in :checkhealth (float = true was one)
    local deprecate, deprecated = vim.deprecate, {}
    vim.deprecate = function(name, ...) deprecated[#deprecated + 1] = name; return deprecate(name, ...) end
    local fed = pcall(vim.api.nvim_feedkeys, "]d", "x", false)
    vim.deprecate = deprecate
    assert(fed and vim.api.nvim_win_get_cursor(0)[1] == 2, "]d: line " .. vim.api.nvim_win_get_cursor(0)[1])
    assert(#deprecated == 0, "]d used what is deprecated: " .. table.concat(deprecated, ", "))
    local function shown() -- the message in a float, as before (on_jump runs scheduled, as Neovim's own float did)
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative ~= "" and H.text(vim.api.nvim_win_get_buf(win)):find("here", 1, true) then return true end
      end
    end
    assert(wait(3000, shown), "]d: no float with the message")
    vim.diagnostic.reset(ns, buf)
    for _, note in ipairs(notes) do assert(not note:find("deprecated", 1, true) and not note:find("not supported", 1, true), note) end
  end)
  vim.notify = notify
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do -- ]d's float
    if vim.api.nvim_win_get_config(win).relative ~= "" then pcall(vim.api.nvim_win_close, win, true) end
  end
  stop_clients(buf)
  assert(ok, err)
end)

-- ── Ctrl+Click as in IntelliJ (config/navigate.lua, 2026-10-22) ──
-- A Ctrl+Click at a line and (byte) column of a window, as the terminal sends it: nvim_input_mouse queues it with its
-- place; a running test reads it back and types it - so the mapping runs, getmousepos() sees the click
local function ctrl_click(win, lnum, col)
  vim.cmd.redraw()
  local at = vim.fn.screenpos(win, lnum, col)
  assert(at.row > 0, ("line %d, column %d is not on the screen"):format(lnum, col))
  vim.api.nvim_input_mouse("left", "press", "C", 0, at.row - 1, at.col - 1)
  local key = vim.fn.getcharstr(0)
  vim.api.nvim_input_mouse("left", "release", "C", 0, at.row - 1, at.col - 1)
  vim.fn.getcharstr(0)
  assert(key ~= "", "the click was not queued")
  vim.api.nvim_feedkeys(key, "mx", false)
end

local function where() return vim.fs.basename(vim.api.nvim_buf_get_name(0)) .. ":" .. table.concat(vim.api.nvim_win_get_cursor(0), ":") end

test("Ctrl+Click (IntelliJ): on a name to its declaration (<C-o> back); on the declaration its usages - just one: there", function()
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local decl, use = dir .. "/decl.txt", dir .. "/use.txt"
  vim.fn.writefile({ "", "def greet(): pass" }, decl)
  vim.fn.writefile({ "x = greet()", "y = greet()" }, use)
  local function loc(path, line, from, to)
    return { uri = vim.uri_from_fname(path), range = { start = { line = line, character = from }, ["end"] = { line = line, character = to } } }
  end
  local usages, asked = { loc(use, 0, 4, 9), loc(use, 1, 4, 9) }, nil
  local answers = {
    ["textDocument/definition"] = function() return { loc(decl, 1, 4, 9) } end,
    ["textDocument/references"] = function(params) asked = params.context; return usages end,
  }
  vim.cmd("silent! only")
  -- every click on the same spot as the one before: a double click, then a triple one, as a quick second Ctrl+Click
  -- is to Neovim - it did nothing at first (2026-10-22)
  local mousetime = vim.o.mousetime
  vim.o.mousetime = 60000
  local bufs = {}
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(use))
    bufs.use = vim.api.nvim_get_current_buf()
    local client = vim.lsp.start({ name = "gk-fake-nav", cmd = fake_lsp({ definitionProvider = true, referencesProvider = true }, answers), root_dir = dir }, { bufnr = bufs.use })
    assert(wait(5000, function() return #vim.lsp.get_clients({ bufnr = bufs.use, name = "gk-fake-nav" }) > 0 end), "the fake server did not attach")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ctrl_click(0, 2, 6) -- greet in y = greet()
    assert(wait(5000, function() return where() == "decl.txt:2:4" end), "not at the declaration: " .. where())
    bufs.decl = vim.api.nvim_get_current_buf()
    vim.api.nvim_feedkeys(vim.keycode("<C-o>"), "x", false)
    assert(where() == "use.txt:2:5", "<C-o> did not come back where the click was: " .. where())
    -- on the declaration itself: its usages, without the declaration - two in the quickfix list
    vim.cmd.buffer(bufs.decl)
    vim.lsp.buf_attach_client(bufs.decl, client)
    assert(wait(5000, function() return #vim.lsp.get_clients({ bufnr = bufs.decl, name = "gk-fake-nav" }) > 0 end), "not attached to decl.txt")
    ctrl_click(0, 2, 6) -- greet in def greet()
    assert(wait(5000, function() return #vim.fn.getqflist() == 2 end),
      ("no list of the usages - at %s, references asked: %s, list: %s"):format(where(), vim.inspect(asked), vim.inspect(vim.fn.getqflist())))
    assert(asked and asked.includeDeclaration == false, "the declaration asked for too: " .. vim.inspect(asked))
    local lines = vim.tbl_map(function(q) return vim.fs.basename(vim.api.nvim_buf_get_name(q.bufnr)) .. ":" .. q.lnum end, vim.fn.getqflist())
    assert(vim.deep_equal(lines, { "use.txt:1", "use.txt:2" }), "usages: " .. vim.inspect(lines))
    vim.cmd("cclose")
    vim.fn.setqflist({}, "r")
    -- just one usage: IntelliJ goes there
    usages = { loc(use, 1, 4, 9) }
    vim.cmd.buffer(bufs.decl)
    ctrl_click(0, 2, 6)
    assert(wait(5000, function() return where() == "use.txt:2:4" end), "not at the only usage: " .. where())
    assert(#vim.fn.getqflist() == 0, "a list for one usage")
  end)
  vim.o.mousetime = mousetime
  vim.cmd("silent! cclose")
  for _, buf in pairs(bufs) do stop_clients(buf) end
  for _, buf in pairs(bufs) do pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- angularls and ts_ls in a .ts file both name the declaration: a quickfix list of the same place twice, no jump
test("Ctrl+Click: two servers naming the same declaration - one jump, not a list of the same place twice", function()
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local decl, use = dir .. "/decl.txt", dir .. "/use.txt"
  vim.fn.writefile({ "", "def greet(): pass" }, decl)
  vim.fn.writefile({ "x = greet()" }, use)
  local answers = {
    ["textDocument/definition"] = function()
      return { { uri = vim.uri_from_fname(decl), range = { start = { line = 1, character = 4 }, ["end"] = { line = 1, character = 9 } } } }
    end,
  }
  vim.cmd("silent! only")
  vim.fn.setqflist({}, "r")
  vim.cmd.edit(vim.fn.fnameescape(use))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    for _, name in ipairs({ "gk-fake-one", "gk-fake-two" }) do
      vim.lsp.start({ name = name, cmd = fake_lsp({ definitionProvider = true }, answers), root_dir = dir }, { bufnr = buf })
    end
    assert(wait(5000, function() return #vim.lsp.get_clients({ bufnr = buf }) >= 2 end), "the two fake servers did not attach")
    ctrl_click(0, 1, 6)
    assert(wait(5000, function() return where() == "decl.txt:2:4" end), "no jump: " .. where() .. ", list: " .. #vim.fn.getqflist())
    assert(#vim.fn.getqflist() == 0, "a list of the same place twice")
  end)
  stop_clients(buf)
  vim.cmd("silent! %bwipeout!")
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

test("Ctrl+Click without a language server: Vim's gd; after the end of a line only the cursor moves; in help the tag", function()
  vim.cmd("silent! only")
  vim.cmd.edit(vim.fn.fnameescape(H.file("plain.txt", { "alpha = 1", "", "beta = alpha + 1" })))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    ctrl_click(0, 3, 9) -- alpha in beta = alpha + 1
    assert(where() == "plain.txt:1:0", "gd: " .. where())
    ctrl_click(0, 3, 20) -- after the end of the line
    assert(where() == "plain.txt:3:15", "after the end: " .. where())
    vim.cmd("help help.txt")
    local row = vim.fn.search([[|quickref|]], "w")
    assert(row > 0, "no |quickref| in help.txt")
    ctrl_click(0, row, vim.fn.col(".") + 4) -- amid quickref: help hides the bars, a column either way is on it
    assert(wait(3000, function() return vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "quickref.txt" end), "the tag: " .. where())
  end)
  pcall(vim.cmd, "helpclose")
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  assert(ok, err)
end)

test("Ctrl+Click with pyright: a call goes to the def; the def lists its calls", function()
  if vim.fn.executable("pyright-langserver") == 0 then H.skip("pyright-langserver not installed (Mason installs it with the first Python file)") end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p")
  vim.fn.writefile({ "def greet(name):", '    return "hi " + name', "", "", 'print(greet("a"))', 'print(greet("b"))' }, root .. "/main.py")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  for _, c in ipairs(vim.lsp.get_clients()) do if c.name == "pyright" or c.name == "ruff" then c:stop(true) end end
  wait(10000, function() return #vim.lsp.get_clients({ name = "pyright" }) + #vim.lsp.get_clients({ name = "ruff" }) == 0 end)
  vim.cmd("silent! only")
  local buf
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
    buf = vim.api.nvim_get_current_buf()
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "pyright" }) > 0 end), "pyright did not start")
    assert(wait(60000, function() -- attached is not ready: ready once it answers
      local res = vim.lsp.buf_request_sync(buf, "textDocument/definition",
        { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 4, character = 7 } }, 5000)
      for _, r in pairs(res or {}) do if type(r.result) == "table" and next(r.result) then return true end end
    end), "pyright does not answer")
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    ctrl_click(0, 6, 8) -- greet in print(greet("b"))
    assert(wait(10000, function() return where() == "main.py:1:4" end), "not at the def: " .. where())
    ctrl_click(0, 1, 6) -- greet in def greet(name)
    assert(wait(10000, function() return #vim.fn.getqflist() == 2 end), "no list of the calls: " .. vim.inspect(vim.fn.getqflist()))
    local lnums = vim.tbl_map(function(q) return q.lnum end, vim.fn.getqflist())
    table.sort(lnums)
    assert(vim.deep_equal(lnums, { 5, 6 }), "the calls: " .. vim.inspect(lnums))
  end)
  vim.cmd("silent! cclose")
  vim.fn.setqflist({}, "r")
  if buf then stop_clients(buf) end
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-22: each language server the config sets up starts on a file of its kind and marks its error, where it is
-- installed - only pyright, lua_ls and ruff had tests that saw them run, a server's setup could break unnoticed
-- (bashls' test passes with its fallback too). The file outside any project: with Neovim's own vim.lsp.config there
-- lua_ls had no workspace and marked nothing (the old setup gave it the file's folder). Only installed servers: a
-- missing html or css server is installed with the first such file.
test("LSP: each server the config sets up starts on a file of its kind outside any project and marks its error", function()
  local lang = vim.g.lang or {}
  local shellcheck = vim.fn.executable("shellcheck") == 1 -- bashls' marks are shellcheck's
  local cases = {
    { lang = "python", server = "pyright", exe = "pyright-langserver", file = "a.py", lines = { "print(undefined_name)" }, marks = true },
    { lang = "python", server = "ruff", exe = "ruff", file = "b.py", lines = { "import os" }, marks = true },
    { lang = "lua", server = "lua_ls", exe = "lua-language-server", file = "c.lua", lines = { "print(not_defined_anywhere)" }, marks = true },
    { lang = "bash", server = "bashls", exe = "bash-language-server", file = "d.sh", lines = { "#!/bin/bash", "echo $1" }, marks = shellcheck },
    { lang = "c", server = "clangd", exe = "clangd", file = "e.c", lines = { "int main(void) { return undeclared_x; }" }, marks = true },
    { lang = "typescript", server = "ts_ls", exe = "typescript-language-server", file = "f.ts", lines = { 'const x: number = "a";' }, marks = true },
    { lang = "angular", server = "html", exe = "vscode-html-language-server", file = "g.html", lines = { "<p>hi</p>" } },
    { lang = "angular", server = "cssls", exe = "vscode-css-language-server", file = "h.css", lines = { "p { color: red; }" } },
  }
  local checked, failed, skipped = {}, {}, {}
  for _, c in ipairs(cases) do
    if not lang[c.lang] then
      skipped[#skipped + 1] = c.server .. " (off)"
    elseif vim.fn.executable(c.exe) == 0 then
      skipped[#skipped + 1] = c.server .. " (not installed)"
    else
      local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir()))) -- no .git, no marker of any server above it
      vim.fn.writefile(c.lines, dir .. "/" .. c.file)
      vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. c.file))
      local buf = vim.api.nvim_get_current_buf()
      local function client() return vim.lsp.get_clients({ bufnr = buf, name = c.server })[1] end
      local function marks() -- this server's own: pushed (nvim.lsp.<name>.<id>) or pulled (.<id>.<the pull's identifier>)
        local cl = client()
        if not cl then return 0 end
        local prefix, n = ("nvim.lsp.%s.%d"):format(cl.name, cl.id), 0
        for ns, info in pairs(vim.diagnostic.get_namespaces()) do
          if info.name == prefix or vim.startswith(info.name, prefix .. ".") then n = n + #vim.diagnostic.get(buf, { namespace = ns }) end
        end
        return n
      end
      checked[#checked + 1] = c.server
      if not wait(60000, client) then
        local others = vim.tbl_map(function(cl) return cl.name end, vim.lsp.get_clients({ bufnr = buf }))
        failed[#failed + 1] = ("%s did not start on %s (there: %s)"):format(c.server, c.file, #others > 0 and table.concat(others, ", ") or "none")
      elseif c.marks and not wait(60000, function() return marks() > 0 end) then
        failed[#failed + 1] = ("%s marked nothing in %s (workspace folders: %s)"):format(c.server, c.file, vim.inspect(client().workspace_folders))
      end
      stop_clients(buf)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
      vim.fn.delete(dir, "rf")
    end
  end
  assert(#failed == 0, table.concat(failed, "; ") .. " - checked " .. table.concat(checked, ", "))
  if #checked == 0 then H.skip("no language server installed - " .. table.concat(skipped, ", ")) end
end)

-- 2026-10-22: vim.lsp.enable() starts servers for every buffer of their filetype, scratch buffers (:enew, a filetype
-- set) too - nvim-lspconfig's old setup only for files. And files outside any project share one client: after the
-- interpreter test's scratch buffers bashls marked no bash file any more (devsuite/util.lua lsp_root).
test("LSP: no server for a buffer without a file (a scratch buffer, a URL); a bash file outside a project is marked after it", function()
  local cases = {
    { ft = "sh", exe = "bash-language-server" },
    { ft = "python", exe = "pyright-langserver" },
    { ft = "lua", exe = "lua-language-server" },
  }
  local scratches, attached = {}, {}
  for _, c in ipairs(cases) do
    if vim.fn.executable(c.exe) == 1 then scratches[#scratches + 1] = H.scratch(c.ft, { "x = 1" }) end
  end
  if vim.fn.executable("pyright-langserver") == 1 then -- named by a URL (netrw's scp:// ...): not a file either
    local url = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(url, "scp://host/remote.py")
    vim.api.nvim_set_current_buf(url)
    vim.bo[url].filetype = "python"
    scratches[#scratches + 1] = url
  end
  if #scratches == 0 then H.skip("none of bashls, pyright, lua_ls installed") end
  vim.wait(3000) -- a server starts for a file in under a second
  for _, buf in ipairs(scratches) do
    for _, cl in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      attached[#attached + 1] = ("%s on %s (%s)"):format(cl.name, vim.api.nvim_buf_get_name(buf) ~= "" and vim.api.nvim_buf_get_name(buf) or "a scratch", vim.bo[buf].filetype)
    end
  end
  local ok, err = pcall(function()
    assert(#attached == 0, "servers on buffers without a file: " .. table.concat(attached, ", "))
    if vim.fn.executable("bash-language-server") == 0 or vim.fn.executable("shellcheck") == 0 then return end
    vim.cmd.edit(vim.fn.fnameescape(H.file("after.sh", { "#!/bin/bash", "echo $1" })))
    local buf = vim.api.nvim_get_current_buf()
    local function marks()
      local cl = vim.lsp.get_clients({ bufnr = buf, name = "bashls" })[1]
      if not cl then return 0 end
      local prefix, n = ("nvim.lsp.%s.%d"):format(cl.name, cl.id), 0
      for ns, info in pairs(vim.diagnostic.get_namespaces()) do
        if info.name == prefix or vim.startswith(info.name, prefix .. ".") then n = n + #vim.diagnostic.get(buf, { namespace = ns }) end
      end
      return n
    end
    assert(wait(30000, function() return marks() > 0 end), "bashls marked nothing in a bash file after the scratch buffers")
    stop_clients(buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end)
  for _, buf in ipairs(scratches) do
    stop_clients(buf)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  assert(ok, err)
end)

-- 2026-10-22: nvim-lspconfig defines :LspInfo, :LspLog, :LspStart, :LspStop and :LspRestart only where Neovim has no :lsp
-- of its own - on 0.12 there were none, and the docs named :LspInfo and :LspLog
test("LSP: :LspRestart, :LspStop, :LspStart, :LspLog and :LspInfo do what they say (over Neovim's own :lsp)", function()
  if vim.fn.executable("pyright-langserver") == 0 or vim.fn.executable("ruff") == 0 then H.skip("pyright or ruff not installed") end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p")
  vim.fn.writefile({ "import os" }, root .. "/main.py")
  vim.cmd("silent! only")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
  local buf, tab = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_tabpage()
  local function client(name) return vim.lsp.get_clients({ bufnr = buf, name = name })[1] end
  local ok, err = pcall(function()
    assert(wait(60000, function() return client("pyright") and client("ruff") end), "pyright and ruff did not attach")
    local before = client("pyright").id
    vim.cmd("LspRestart pyright")
    assert(wait(30000, function() return client("pyright") and client("pyright").id ~= before end), ":LspRestart did not restart pyright")
    vim.cmd("LspStop ruff")
    assert(wait(10000, function() return client("ruff") == nil end), ":LspStop did not stop ruff")
    vim.cmd("LspStart ruff")
    assert(wait(10000, function() return client("ruff") ~= nil end), ":LspStart did not start ruff for this buffer")
    vim.cmd("LspLog")
    local log = vim.api.nvim_buf_get_name(0)
    assert(vim.fs.normalize(log) == vim.fs.normalize(vim.lsp.log.get_filename()), ":LspLog opened " .. log)
    vim.cmd("LspInfo")
    assert(vim.bo.filetype == "checkhealth", ":LspInfo opened a " .. vim.bo.filetype .. " buffer")
  end)
  for _, t in ipairs(vim.api.nvim_list_tabpages()) do -- the log's and the health check's tabs
    if t ~= tab and vim.api.nvim_tabpage_is_valid(t) then pcall(vim.cmd.tabclose, vim.api.nvim_tabpage_get_number(t)) end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do -- and their buffers
    local name = vim.api.nvim_buf_get_name(b)
    if vim.bo[b].filetype == "checkhealth" or (name ~= "" and vim.fs.normalize(name) == vim.fs.normalize(vim.lsp.log.get_filename())) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  if vim.api.nvim_tabpage_is_valid(tab) then vim.api.nvim_set_current_tabpage(tab) end
  vim.cmd("silent! only")
  stop_clients(buf)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-22: require("lspconfig")[server].setup() is deprecated and goes with nvim-lspconfig v3 - config/lazy.lua
-- kept its warning quiet, a plugin update would have left every server off. Now Neovim's own vim.lsp.config and
-- vim.lsp.enable; pyright's interpreter (the project's virtualenv) comes from before_init, not on_new_config.
test("LSP: servers set up by Neovim's own vim.lsp.config, none through the deprecated lspconfig framework; pyright gets the .venv", function()
  require("lazy").load({ plugins = { "nvim-lspconfig" } })
  local lang, servers = vim.g.lang or {}, {}
  if lang.python then vim.list_extend(servers, { "pyright", "ruff" }) end
  if lang.lua then servers[#servers + 1] = "lua_ls" end
  if lang.bash then servers[#servers + 1] = "bashls" end
  if lang.c then servers[#servers + 1] = "clangd" end
  if lang.typescript then servers[#servers + 1] = "ts_ls" end
  if lang.angular then -- the web servers set up at start: the installed ones (integrations/web.lua)
    for name, s in pairs(require("integrations.web").SERVERS) do
      if vim.fn.executable(s.cmd) == 1 then servers[#servers + 1] = name end
    end
  end
  local framework = package.loaded["lspconfig.configs"]
  for _, name in ipairs(servers) do
    assert(vim.lsp.is_enabled(name), name .. " is not enabled with vim.lsp.enable")
    assert(not (framework and rawget(framework, name)), name .. " went through require('lspconfig')")
  end
  if not lang.python or vim.fn.executable("pyright-langserver") == 0 then return end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p")
  local python = fake_venv(root .. "/.venv")
  vim.fn.writefile({ "import os" }, root .. "/main.py")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/main.py"))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "pyright" }) > 0 end), "pyright did not attach")
    local client = vim.lsp.get_clients({ bufnr = buf, name = "pyright" })[1]
    local path = vim.tbl_get(client.settings or {}, "python", "pythonPath")
    assert(path and vim.fs.normalize(path) == vim.fs.normalize(python), "pyright's python: " .. tostring(path) .. ", not " .. python)
  end)
  stop_clients(buf)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- The config's own files: lua_ls knows Neovim's API and Snacks (lsp.lua: globals, the runtime as library)
test("Lua: lua_ls knows vim and Snacks - no undefined global for them, one for a name that is defined nowhere", function()
  if vim.fn.executable("lua-language-server") == 0 then H.skip("lua-language-server not installed (Mason)") end
  local file = H.file("conf.lua", { "local buf = vim.api.nvim_get_current_buf()", "Snacks.notify(tostring(buf))", "print(not_defined_anywhere)" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "lua_ls" }) > 0 end), "lua_ls did not attach")
    local function messages() return vim.tbl_map(function(d) return d.lnum .. ": " .. d.message end, vim.diagnostic.get(buf)) end
    assert(wait(90000, function()
      for _, d in ipairs(vim.diagnostic.get(buf)) do if d.message:find("not_defined_anywhere", 1, true) then return true end end
    end), "no mark for the undefined global: " .. vim.inspect(messages()))
    for _, m in ipairs(messages()) do -- lua_ls: Undefined global `name`.
      assert(not m:find("global", 1, true) or m:find("not_defined_anywhere", 1, true), m)
    end
  end)
  stop_clients(buf)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  assert(ok, err)
end)

-- 2026-10-22: saving a Lua file reformatted it in lua_ls' own style (stylua, the formatter for Lua, is not installed):
-- one save of this config's keymaps.lua rewrote 74 hand-aligned lines. Now Lua is saved as written unless the project
-- formats with stylua (a stylua.toml); <leader>fm still formats.
test("Formatting: :w keeps a hand-aligned Lua file as written (no stylua.toml); <leader>fm formats it", function()
  if vim.fn.executable("lua-language-server") == 0 then H.skip("lua-language-server not installed (Mason)") end
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.git", "p") -- a project: lua_ls attaches
  local lines = { "local o = vim.opt", "o.tabstop     = 2", "o.shiftwidth  = 2", "local t = {a=1,b='two'}", "return t" }
  vim.fn.writefile(lines, root .. "/conf.lua")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/conf.lua"))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "lua_ls" }) > 0 end), "lua_ls did not attach")
    vim.cmd("silent write")
    assert(vim.deep_equal(vim.fn.readfile(root .. "/conf.lua"), lines), ":w reformatted it: " .. vim.inspect(vim.fn.readfile(root .. "/conf.lua")))
    vim.api.nvim_feedkeys(vim.keycode("<leader>fm"), "x", false)
    assert(wait(30000, function() return vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]:find("{ a = 1, b = 'two' }", 1, true) end),
      "<leader>fm did not format: " .. vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
  end)
  stop_clients(buf)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("pytest: <leader>rt marks a failing assert, ]q goes there; fixed, <leader>rl passes and clears the mark; <leader>rT runs one test", function()
  local python = require("devsuite.util").system_python()
  vim.fn.system({ python, "-c", "import pytest" })
  if vim.v.shell_error ~= 0 then H.skip("pytest not installed (pip install pytest)") end
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local file = root .. "/test_calc.py"
  vim.fn.writefile({ "def add(a, b):", "    return a + b", "", "", "def test_add():", "    assert add(2, 2) == 5", "", "",
    "def test_other():", "    assert add(1, 1) == 2" }, file)
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(file))
    local buf = vim.api.nvim_get_current_buf()
    runner.test_file() -- <leader>rt
    local task = tasks.state.last
    assert(wait(60000, function() return task:is_complete() end), "pytest did not finish: " .. task_out(task))
    assert(task.status == "FAILURE" and task_out(task):find("1 failed, 1 passed", 1, true), task.status .. ": " .. task_out(task))
    vim.wait(200)
    local key = "pytest:" .. vim.api.nvim_buf_get_name(buf) -- the runner's key: the buffer's name
    local d = run_diags(key, file)
    assert(#d >= 1 and d[1].lnum == 5, "marks: " .. vim.inspect(vim.tbl_map(function(x) return x.lnum .. " " .. x.message end,
      vim.diagnostic.get(buf))) .. " out: " .. task_out(task))
    -- ]q: to the failing line, in the file
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("cfirst")
    assert(vim.api.nvim_get_current_buf() == buf and vim.api.nvim_win_get_cursor(0)[1] == 6,
      "]q: " .. vim.api.nvim_buf_get_name(0) .. ":" .. vim.api.nvim_win_get_cursor(0)[1])
    -- fixed, <leader>rl: passes, the mark is gone
    vim.api.nvim_buf_set_lines(buf, 5, 6, false, { "    assert add(2, 2) == 4" })
    vim.cmd("silent write")
    local run = tasks.state.runs[task.id]
    local starts = run.starts
    tasks.rerun()
    assert(wait(60000, function() return run.starts > starts and task:is_complete() end), "re-run did not finish: " .. task_out(task))
    assert(task.status == "SUCCESS" and task_out(task):find("2 passed", 1, true), task.status .. ": " .. task_out(task))
    vim.wait(200)
    assert(#run_diags(key, file) == 0, "the mark stayed after the fix")
    -- <leader>rT in test_other: that test only
    vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
    vim.api.nvim_win_set_cursor(0, { 10, 4 })
    runner.test_nearest()
    task = tasks.state.last
    assert(wait(60000, function() return task:is_complete() end), "pytest (nearest) did not finish")
    assert(task_out(task):find("1 passed", 1, true) and not task_out(task):find("2 passed", 1, true), task_out(task))
  end)
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Debug (python): F9 sets a breakpoint, F5 stops there, F10 steps, a variable's value, F5 runs to the end", function()
  local dbg, dap = require("devsuite.debug"), require("dap")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir()))) -- no .vscode/launch.json: F5 debugs the file
  local file = root .. "/steps.py"
  vim.fn.writefile({ "x = 41", "y = x + 1", "z = y * 2", 'print("z is", z)' }, file)
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  vim.cmd.edit(vim.fn.fnameescape(file))
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.fn.maparg("<F9>", "n", false, true).callback()
    vim.fn.maparg("<F5>", "n", false, true).callback()
    local function line() local s = dap.session(); return s and s.current_frame and s.current_frame.line end
    assert(wait(30000, function() return line() == 2 end), "did not stop at line 2: " .. tostring(line()))
    vim.fn.maparg("<F10>", "n", false, true).callback()
    assert(wait(10000, function() return line() == 3 end), "F10: line " .. tostring(line()))
    local value
    local s = dap.session()
    s:request("evaluate", { expression = "y", frameId = s.current_frame.id, context = "repl" }, function(e, r) value = r and r.result or tostring(e) end)
    assert(wait(10000, function() return value end) and value == "42", "y = " .. tostring(value))
    vim.fn.maparg("<F5>", "n", false, true).callback() -- continue
    assert(wait(20000, function() return dap.session() == nil end), "the session did not end")
  end)
  dap.clear_breakpoints()
  if dap.session() then dap.terminate() end
  vim.fn.chdir(before)
  assert(ok, err)
end)

-- VS Code writes launch.json with comments; people (and VS Code itself, when it edits) leave trailing commas.
-- 2026-10-21: also as the first F5 of a session - nvim-dap's own, strict decoder is put back here; overseer's lenient
-- one came only with the first run, so before it F5 offered none of the file's configurations
test("Debug: F5 with a VS Code launch.json (comments, trailing commas) - the picked configuration runs with its args and env", function()
  local dbg, dap = require("devsuite.debug"), require("dap")
  local vscode = require("dap.ext.vscode")
  local lenient = vscode.json_decode
  vscode.json_decode = vim.json.decode -- as nvim-dap starts
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  vim.fn.mkdir(root .. "/.vscode", "p")
  vim.fn.writefile({ "import os, sys", 'print("ARGS=" + " ".join(sys.argv[1:]) + " GK=" + os.environ.get("GK_MODE", "-"))' }, root .. "/app.py")
  vim.fn.writefile({
    "{",
    "    // Use IntelliSense to learn about possible attributes.",
    '    "version": "0.2.0",',
    '    "configurations": [',
    "        {",
    '            "name": "App: with args",',
    '            "type": "debugpy",',
    '            "request": "launch",',
    '            "program": "${workspaceFolder}/app.py",',
    '            "args": ["--name", "knight"],',
    '            "env": { "GK_MODE": "dev" },',
    '            "console": "integratedTerminal",',
    "        },",
    "        {",
    '            "name": "App: plain", /* the old type name */',
    '            "type": "python",',
    '            "request": "launch",',
    '            "program": "${file}"',
    "        }",
    "    ]",
    "}",
  }, root .. "/.vscode/launch.json")
  local before, select = vim.fn.getcwd(), vim.ui.select
  local offered
  vim.ui.select = function(items, opts, choose)
    offered = vim.tbl_map(function(item) return item.name or tostring(item) end, items)
    for _, item in ipairs(items) do
      if item.name == "App: with args" then return choose(item) end
    end
    choose(nil)
  end
  vim.fn.chdir(root)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/app.py"))
    dbg.start_or_continue() -- F5
    assert(wait(5000, function() return offered end), "no configurations offered")
    assert(vim.tbl_contains(offered, "App: with args") and vim.tbl_contains(offered, "App: plain"), "offered: " .. vim.inspect(offered))
    -- the line as printed, wrapped or not: the console is narrow on a test run's 80 columns, and since dap-ui closes
    -- only after the program's end (devsuite/debug.lua close_ui) nothing widens the terminal before (Kali, 2026-10-22)
    local function printed()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype == "terminal" and H.text(b):gsub("%s+", ""):find("ARGS=--nameknightGK=dev", 1, true) then return true end
      end
    end
    assert(wait(30000, printed), "the program did not run with the configuration's args and env")
    wait(10000, function() return dap.session() == nil end)
  end)
  vim.ui.select = select
  if vscode.json_decode == vim.json.decode then vscode.json_decode = lenient end
  if dap.session() then dap.terminate() end
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Debug (python): <leader>de stops where an exception is raised, a caught one too; <leader>de again: only uncaught ones", function()
  local dbg, dap = require("devsuite.debug"), require("dap")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local file = root .. "/exc.py"
  vim.fn.writefile({ "def risky():", "    raise ValueError('boom')", "", "", "try:", "    risky()", "except ValueError:", "    print('caught')",
    "print('done')" }, file)
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  vim.cmd.edit(vim.fn.fnameescape(file))
  local function line() local s = dap.session(); return s and s.current_frame and s.current_frame.line end
  local ok, err = pcall(function()
    vim.fn.maparg("<leader>de", "n", false, true).callback() -- on: every raised exception
    assert(dbg.break_on_raised, "<leader>de did not turn it on")
    dbg.start_or_continue()
    assert(wait(30000, function() return line() == 2 end), "did not stop at the raise: " .. tostring(line()))
    for _ = 1, 5 do -- on to the end: debugpy stops once more where the exception passes into the caller
      local s = dap.session()
      if not s then break end
      if s.stopped_thread_id then dap.continue() end
      wait(5000, function() return dap.session() == nil end)
    end
    assert(dap.session() == nil, "the session did not end")
    vim.fn.maparg("<leader>de", "n", false, true).callback() -- off: the caught one runs through
    assert(not dbg.break_on_raised, "<leader>de did not turn it off")
    local stopped = false
    dap.listeners.after.event_stopped["gk_test"] = function() stopped = true end
    dbg.start_or_continue()
    assert(wait(30000, function() return dap.session() ~= nil end), "no session")
    assert(wait(20000, function() return dap.session() == nil end), "the session did not end")
    assert(not stopped, "stopped at a caught exception with only uncaught ones on")
  end)
  dap.listeners.after.event_stopped["gk_test"] = nil
  if dbg.break_on_raised then dbg.toggle_exceptions() end
  if dap.session() then dap.terminate() end
  vim.fn.chdir(before)
  assert(ok, err)
end)

test("Debug (python): <leader>dt debugs the test at the cursor - its breakpoint stops, the other test does not run", function()
  local python = require("devsuite.util").system_python()
  vim.fn.system({ python, "-c", "import pytest" })
  if vim.v.shell_error ~= 0 then H.skip("pytest not installed (pip install pytest)") end
  local dap = require("dap")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmpdir())))
  local file = root .. "/test_dbg.py"
  vim.fn.writefile({ "def test_one():", "    total = 20 + 22", "    assert total == 42", "", "", "def test_two():", "    assert True" }, file)
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  vim.cmd.edit(vim.fn.fnameescape(file))
  local function line() local s = dap.session(); return s and s.current_frame and s.current_frame.line end
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 3, 4 })
    dap.toggle_breakpoint()
    vim.fn.maparg("<leader>dt", "n", false, true).callback()
    assert(wait(60000, function() return line() == 3 end), "did not stop in test_one: " .. tostring(line()))
    local value
    local s = dap.session()
    s:request("evaluate", { expression = "total", frameId = s.current_frame.id, context = "repl" }, function(e, r) value = r and r.result or tostring(e) end)
    assert(wait(10000, function() return value end) and value == "42", "total = " .. tostring(value))
    dap.continue()
    assert(wait(30000, function() return dap.session() == nil end), "the session did not end")
    local function printed()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype == "terminal" and H.text(b):find("1 passed", 1, true) then return true end
      end
    end
    assert(wait(5000, printed), "pytest did not report 1 passed (only the test at the cursor)")
  end)
  dap.clear_breakpoints()
  if dap.session() then dap.terminate() end
  vim.fn.chdir(before)
  assert(ok, err)
end)

test("Tasks: <leader>rw runs the script again with the new code whenever a file of its folder is saved", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = H.file("watched.py", { 'print("version one")' })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()
  runner.run_file()
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end) and task_out(task):find("version one", 1, true), task_out(task))
  vim.fn.maparg("<leader>rw", "n", false, true).callback()
  local ok, err = pcall(function()
    assert(task:has_component("restart_on_save"), "watch did not turn on")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'print("version two")' })
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
    assert(wait(15000, function() return task_out(task):find("version two", 1, true) end), "not run again on save: " .. task_out(task))
  end)
  if task:has_component("restart_on_save") then tasks.toggle_watch() end
  assert(ok, err)
end)

test("Runner: <leader>rc runs only the # %% cell at the cursor - its error marks the line in the file", function()
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local file = H.file("cells.py", { "# %% one", 'print("cell " + "one")', "", "# %% two", 'print("cell " + "two")', "x = 1 / 0", "",
    "# %% three", 'print("cell " + "three")' })
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.api.nvim_win_set_cursor(0, { 5, 0 })
  vim.fn.maparg("<leader>rc", "n", false, true).callback()
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish: " .. task_out(task))
  local out = task_out(task)
  assert(out:find("cell two", 1, true) and not out:find("cell one", 1, true) and not out:find("cell three", 1, true), out)
  vim.wait(200)
  local name = vim.api.nvim_buf_get_name(vim.fn.bufnr(file)) -- the runner's key: the buffer's name, as Neovim writes it
  local d = run_diags("snippet:" .. name, file)
  assert(#d == 1 and d[1].lnum == 5 and d[1].message:find("ZeroDivisionError", 1, true), vim.inspect(d) .. " all: " .. vim.inspect(
    vim.tbl_map(function(x) return x.lnum .. " " .. x.message end, vim.diagnostic.get(vim.fn.bufnr(file)))) .. " out: " .. out)
end)

test("Terminal: <leader>tl sends the line to terminal #2, which runs it", function()
  local python = require("devsuite.util").system_python()
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { vim.fn.shellescape(python) .. [[ -c "print('gk' + str(6*7))"]] })
  local scratch_buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    vim.fn.maparg("<leader>tl", "n", false, true).callback()
    local term = require("toggleterm.terminal").get(2)
    assert(wait(5000, function() return term ~= nil or require("toggleterm.terminal").get(2) ~= nil end), "no terminal #2")
    term = require("toggleterm.terminal").get(2)
    assert(wait(15000, function()
      for _, line in ipairs(vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false)) do
        if vim.trim(line) == "gk42" then return true end
      end
    end), "terminal #2 did not run it: " .. H.text(term.bufnr))
  end)
  local term = require("toggleterm.terminal").get(2)
  if term then pcall(function() term:shutdown() end) end
  pcall(vim.api.nvim_buf_delete, scratch_buf, { force = true })
  assert(ok, err)
end)

test("Runner: commands for sudo, trace, remembered args, venv python, plain executables", function()
  linux_only("sudo, bash -x and POSIX shell quoting")
  local runner, tasks = require("devsuite.runner"), require("devsuite.tasks")
  local real = tasks.run
  local specs = {}
  tasks.run = function(spec) specs[#specs + 1] = spec end
  local saved_venv = vim.env.VIRTUAL_ENV
  vim.env.VIRTUAL_ENV = nil
  local ok, err = pcall(function()
    local sh = H.file("scan.sh", { "#!/usr/bin/env bash", "echo hi" })
    vim.cmd.edit(sh)
    runner.run_sudo()
    assert(specs[#specs].cmd:match("^sudo "), specs[#specs].cmd)
    runner.run_trace()
    assert(specs[#specs].cmd:find("'-x' ", 1, true), specs[#specs].cmd)
    local args = "--target 10.0.0.1 'two words'"
    tasks.set_args(sh, args)
    runner.run_file()
    tasks.set_args(sh, "")
    assert(specs[#specs].cmd:sub(-#args) == args, specs[#specs].cmd)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/.venv/bin", "p")
    vim.fn.mkdir(root .. "/src", "p")
    vim.fn.writefile({ "#!/bin/sh" }, root .. "/.venv/bin/python")
    vim.fn.setfperm(root .. "/.venv/bin/python", "rwx------")
    vim.fn.writefile({ "#!/usr/bin/env python3", "print(1)" }, root .. "/src/tool.py")
    vim.cmd.edit(root .. "/src/tool.py")
    runner.run_file()
    assert(specs[#specs].cmd:find(root .. "/.venv/bin/python", 1, true), "venv python not used: " .. specs[#specs].cmd)
    local bin = H.file("helper", { "echo bin" })
    vim.fn.setfperm(bin, "rwx------")
    runner.run_script(bin, false, vim.fs.dirname(bin))
    assert(specs[#specs].cmd == vim.fn.shellescape(bin), specs[#specs].cmd)
  end)
  tasks.run = real
  vim.env.VIRTUAL_ENV = saved_venv
  assert(ok, err)
end)

-- 2026-10-19: Windows keeps a virtualenv's python in Scripts\ and has no /usr/bin/env for a #! line
test("Runner: a .py file runs with the project's virtualenv python, else its #! line (Windows: python)", function()
  local runner, tasks, util = require("devsuite.runner"), require("devsuite.tasks"), require("devsuite.util")
  local real, specs = tasks.run, {}
  tasks.run = function(spec) specs[#specs + 1] = spec end
  local saved_venv = vim.env.VIRTUAL_ENV
  vim.env.VIRTUAL_ENV = nil
  local ok, err = pcall(function()
    local root = vim.fs.normalize(vim.fn.tempname())
    vim.fn.mkdir(root .. "/src", "p")
    local python = fake_venv(root .. "/.venv")
    vim.fn.writefile({ "#!/usr/bin/env python3", "print(1)" }, root .. "/src/tool.py")
    vim.cmd.edit(root .. "/src/tool.py")
    runner.run_file()
    assert(specs[#specs].cmd:find(python, 1, true), "venv python not used: " .. specs[#specs].cmd)
    vim.fn.delete(root .. "/.venv", "rf")
    runner.run_file()
    local first = vim.fn.shellescape(WIN and util.system_python() or "/usr/bin/env")
    assert(specs[#specs].cmd:sub(1, #first) == first, "without a venv: " .. specs[#specs].cmd)
  end)
  tasks.run = real
  vim.env.VIRTUAL_ENV = saved_venv
  assert(ok, err)
end)

test("Dev suite: interpreters from #! lines and filetypes", function()
  local util = require("devsuite.util")
  local saved = vim.env.VIRTUAL_ENV
  vim.env.VIRTUAL_ENV = nil
  local function argv(ft, first)
    local a = util.interpreter(H.scratch(ft, first and { first } or nil), vim.fn.tempname())
    return a and table.concat(a, " ")
  end
  local got = {
    py = argv("python", "#!/usr/bin/env -S python3 -u"),
    sh = argv("sh"),
    dash = argv("sh", "#!/bin/sh"),
    zsh = argv("zsh"),
    js = argv("javascript"),
    md = argv("markdown"),
  }
  vim.env.VIRTUAL_ENV = saved
  -- Windows ignores the #! line of a Python file (no /usr/bin/env there)
  local py = WIN and util.system_python() or "/usr/bin/env -S python3 -u"
  assert(got.py == py and got.sh == "bash" and got.dash == "/bin/sh", vim.inspect(got))
  assert(got.zsh == "zsh" and got.js == "node" and got.md == nil, vim.inspect(got))
end)

test("Bash: shellcheck findings appear once, on the right line (bashls or fallback)", function()
  if vim.fn.executable("shellcheck") == 0 then H.skip("shellcheck not installed") end
  vim.cmd.edit(H.file("check.sh", { "#!/bin/bash", "echo $1" }))
  assert(wait(20000, function()
    return #vim.lsp.get_clients({ bufnr = 0, name = "bashls" }) > 0 and #vim.diagnostic.get(0) > 0
  end), "no bash diagnostics - bashls: " .. vim.inspect(vim.tbl_map(function(c)
    return { id = c.id, root = c.root_dir, buffers = vim.tbl_keys(c.attached_buffers), stopped = c:is_stopped(), initialized = c.initialized }
  end, vim.lsp.get_clients({ name = "bashls" }))):gsub("%s+", " ") .. ", this buffer " .. vim.api.nvim_get_current_buf())
  vim.wait(1500)
  local d = vim.diagnostic.get(0)
  assert(#d == 1 and d[1].lnum == 1 and tostring(d[1].code):find("2086", 1, true), vim.inspect(d))
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do client:stop(true) end
  wait(5000, function() return #vim.lsp.get_clients({ bufnr = 0 }) == 0 end)
  vim.cmd("silent write")
  local f = vim.diagnostic.get(0)
  assert(#f == 1 and f[1].lnum == 1 and tostring(f[1].code) == "2086", vim.inspect(f))
end)

test("Errors in GreyKnight itself reach the error log (task callbacks do not fail silently)", function()
  local el, errors, tasks = require("config.errorlog"), require("devsuite.errors"), require("devsuite.tasks")
  vim.notify("a test error\nsecond line", vim.log.levels.ERROR, { title = "Test" })
  vim.notify("only info", vim.log.levels.INFO)
  local parse = errors.parse
  errors.parse = function() error("boom from a test") end
  local ok, err = pcall(function()
    local task = tasks.run({ key = "test:guard", name = "guard", cmd = py_cmd("pass"), cwd = tmpdir(), focus = false })
    assert(wait(5000, function() return task:is_complete() end), "did not finish")
    assert(wait(3000, function()
      return vim.fn.filereadable(el.path) == 1 and table.concat(vim.fn.readfile(el.path), "\n"):find("boom from a test", 1, true)
    end), "internal error was not reported")
  end)
  errors.parse = parse
  assert(ok, err)
  local log = table.concat(vim.fn.readfile(el.path), "\n")
  assert(log:find("ERROR [Test] a test error\n      second line", 1, true), log)
  assert(log:find("ERROR [Run] internal error in finished", 1, true), log)
  assert(not log:find("only info", 1, true), "info was logged")
end)

test("Harpoon and the error keys are wired", function()
  local function has(lhs)
    for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
      if m.lhs == lhs then return true end
    end
  end
  for _, lhs in ipairs({ " ha", " hh", " 1", " 2", " 3", " 4", " ue", " um", " un" }) do assert(has(lhs), lhs .. " missing") end
  local list = require("harpoon"):list() -- read only: adding files would change your real harpoon lists
  assert(list and type(list.add) == "function" and type(list.select) == "function", "no harpoon list")
end)

test("Harpoon: pin files, see their slot, jump, menu edits kept on q", function()
  local harpoon = require("harpoon")
  harpoon.sync = function() end -- this test process never writes your real harpoon lists
  assert(harpoon.config.settings.save_on_toggle and harpoon.config.settings.sync_on_ui_close, "menu settings")
  local cwd, notify = vim.fn.getcwd(), vim.notify
  local notes = {}
  vim.notify = function(msg, level, opts)
    notes[#notes + 1] = msg
    return notify(msg, level, opts)
  end
  local ok, err = pcall(function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ "a = 1" }, dir .. "/a.py")
    vim.fn.writefile({ "echo b" }, dir .. "/b.sh")
    vim.cmd.cd(dir) -- a list of its own (lists are per working directory)
    vim.cmd.edit(dir .. "/a.py")
    vim.api.nvim_feedkeys(" ha", "x", false)
    vim.cmd.edit(dir .. "/b.sh")
    vim.api.nvim_feedkeys(" ha", "x", false)
    local list = harpoon:list()
    assert(list:length() == 2 and list.items[1].value == "a.py" and list.items[2].value == "b.sh", vim.inspect(list.items))
    assert(notes[#notes]:find("b.sh is slot 2", 1, true) and notes[#notes]:find("<leader>2", 1, true), vim.inspect(notes))
    vim.api.nvim_feedkeys(" 1", "x", false)
    assert(vim.fn.expand("%:t") == "a.py", "slot 1 opened " .. vim.fn.expand("%:t"))
    vim.api.nvim_feedkeys(" hh", "x", false)
    assert(harpoon.ui.win_id ~= nil, "menu did not open")
    vim.api.nvim_feedkeys("ggddq", "x", false) -- unpin a.py, close with q
    assert(harpoon.ui.win_id == nil, "menu still open")
    assert(list.items[1] and list.items[1].value == "b.sh", "q dropped the edit: " .. vim.inspect(list.items))
  end)
  vim.notify = notify
  vim.cmd.cd(cwd)
  assert(ok, err)
end)

test("Error log: a plugin that wraps vim.notify does not break notifications", function()
  local el = require("config.errorlog")
  local previous, calls = vim.notify, 0
  vim.notify = function(msg, level, opts) -- what plugins do: wrap and call the previous one
    calls = calls + 1
    return previous(msg, level, opts)
  end
  local ok, err = pcall(function()
    vim.notify("wrapped warning one", vim.log.levels.WARN, { title = "Wrap" })
    vim.notify("wrapped warning two", vim.log.levels.WARN, { title = "Wrap" })
  end)
  vim.notify = previous
  assert(ok, "notifications broke: " .. tostring(err))
  assert(calls == 2, "wrapper called " .. calls .. " times")
  assert(table.concat(vim.fn.readfile(el.path), "\n"):find("WARN  [Wrap] wrapped warning two", 1, true), "not logged")
end)

-- 2026-10-21: the log in a folder whose name has spaces and umlauts (a user name like that is in every path below the
-- home folder); at startup a log past 512 KB keeps its last 2000 lines
test("Error log: a path with spaces and umlauts works; past 512 KB it keeps the last 2000 lines (startup)", function()
  local el = require("config.errorlog")
  local saved_path, saved_notify = el.path, vim.notify
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/Jürgen Müller/state", "p")
  el.path = vim.fs.normalize(assert(vim.uv.fs_realpath(root .. "/Jürgen Müller/state"))) .. "/greyknight.log"
  local ok, err = pcall(function()
    el.write("WARN", "test", "a warning with ü")
    local lines = vim.fn.filereadable(el.path) == 1 and vim.fn.readfile(el.path) or {}
    assert(lines[#lines] and lines[#lines]:find("WARN  [test] a warning with ü", 1, true), "not logged: " .. vim.inspect(lines))
    local big = {}
    for i = 1, 6000 do big[i] = ("2026-01-01 00:00:00 WARN  [old] line %05d %s"):format(i, string.rep("x", 80)) end
    vim.fn.writefile(big, el.path) -- about 780 KB
    el.setup()
    local kept = vim.fn.readfile(el.path)
    assert(#kept == 2000 and kept[1]:find("line 04001", 1, true) and kept[2000]:find("line 06000", 1, true),
      #kept .. " lines, from " .. tostring(kept[1]))
  end)
  el.path, vim.notify = saved_path, saved_notify
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Qwen: <leader>am names the model the server runs, and says when none runs", function()
  local qwen = require("integrations.agent")
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode({ model_path = "/m/Fake-27B-Q6_K.gguf", default_generation_settings = { n_ctx = 4096 } }) }, dir .. "/props")
  local port = 18000 + vim.uv.hrtime() % 1000
  local base = ("http://127.0.0.1:%d"):format(port)
  local server = vim.fn.jobstart({ require("devsuite.util").system_python(), "-m", "http.server", tostring(port), "--bind", "127.0.0.1", "--directory", dir })
  local saved, saved_agent = vim.env.QWEN_BASE_URL, vim.env.GREYKNIGHT_AGENT
  vim.env.GREYKNIGHT_AGENT = "qwen"
  local ok, err = pcall(function()
    -- python's http.server took over 5 s to answer on a busy Windows (IntelliJ indexing, 2026-10-22)
    assert(H.wait(15000, function()
      return vim.system({ "curl", "-s", "--max-time", "1", base .. "/props" }):wait().code == 0
    end), "fake server did not start")
    vim.env.QWEN_BASE_URL = base .. "/v1"
    local got
    qwen.model_info(function(msg) got = msg end)
    assert(H.wait(5000, function() return got end), "no answer")
    assert(got:find("Fake-27B-Q6_K", 1, true) and got:find("4096", 1, true), got)
    vim.env.QWEN_BASE_URL = "http://127.0.0.1:9/v1" -- nothing listens there
    got = nil
    qwen.model_info(function(msg) got = msg end)
    -- Windows answers a closed port only after ~2 s of SYN retries (curl's limit is 3 s): 5 s were too tight, and on a
    -- busy one (IntelliJ indexing) starting curl and reading its answer took over 10 s (2026-10-22)
    assert(H.wait(20000, function() return got end) and got:find("No model is running", 1, true), tostring(got))
  end)
  vim.fn.jobstop(server)
  vim.env.QWEN_BASE_URL, vim.env.GREYKNIGHT_AGENT = saved, saved_agent
  assert(ok, err)
end)

-- 2026-10-19: Java through jdtls (lua/integrations/jdtls.lua) - started like for a G3 file, end to end
local function jdtls_end_to_end()
  local jdtls = require("integrations.jdtls")
  if not jdtls.server_java() then H.skip("no Java 21+ for jdtls") end
  local launcher = vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar")
  if launcher == "" then H.skip("jdtls not installed (Mason) - opening a Java file installs it") end
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(root .. "/.git", "p") -- jdtls' root
  vim.fn.mkdir(root .. "/src/demo", "p")
  vim.fn.writefile({ "package demo;", "", "public class Helper {", '    public static String greet() { return "hi"; }', "}" }, root .. "/src/demo/Helper.java")
  vim.fn.writefile({
    "package demo;", "", "public class Main {", "    public static void main(String[] args) {",
    "        String s = Helper.greet();", '        int broken = "text";', "    }", "}",
  }, root .. "/src/demo/Main.java")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/src/demo/Main.java"))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(wait(90000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "jdtls" }) > 0 end), "jdtls did not start")
    assert(wait(120000, function()
      for _, d in ipairs(vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })) do
        if d.lnum == 5 then return true end
      end
    end), "no error on line 6: " .. vim.inspect(vim.diagnostic.get(buf)))
    local params = { textDocument = vim.lsp.util.make_text_document_params(buf), position = { line = 4, character = 27 } }
    assert(wait(60000, function()
      for _, r in pairs(vim.lsp.buf_request_sync(buf, "textDocument/definition", params, 10000) or {}) do
        local x = r.result
        local uri = x and (x.uri or (x[1] and (x[1].uri or x[1].targetUri)))
        if uri and uri:find("Helper.java", 1, true) then return true end
      end
    end), "the definition of Helper.greet() was not found")
    -- 2026-10-22: Ctrl+Click into the JDK as into any dependency - on String a jdt:// buffer with its source or the
    -- decompiled class (nvim-jdtls reads those in), <C-o> back
    vim.cmd("silent! only")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ctrl_click(0, 5, 10) -- String in "String s = Helper.greet();"
    assert(wait(60000, function()
      local name = vim.api.nvim_buf_get_name(0)
      return name:find("^jdt://") ~= nil and name:find("String", 1, true) ~= nil and vim.api.nvim_buf_line_count(0) > 1
    end), "Ctrl+Click on String did not open the JDK's class: " .. vim.api.nvim_buf_get_name(0))
    vim.api.nvim_feedkeys(vim.keycode("<C-o>"), "x", false)
    assert(vim.api.nvim_get_current_buf() == buf, "<C-o> did not come back to Main.java: " .. vim.api.nvim_buf_get_name(0))
    -- 2026-10-21: completion from jdtls as it is typed - Helper.gr offers greet() (LSP), Tab and Enter take it
    vim.api.nvim_buf_set_lines(buf, 5, 5, false, { "        String t = " })
    local lines, seen = complete_in(6, "Helper.gr", "greet", "lsp")
    assert(seen.found, "no greet() from jdtls in the menu: " .. vim.inspect(seen.items))
    assert(lines[6]:find("Helper.greet()", 1, true), "after Tab and Enter: " .. lines[6])
  end)
  for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do client:stop(true) end
  wait(10000, function() return #vim.lsp.get_clients({ name = "jdtls" }) == 0 end)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(jdtls.workspace(root), "rf")
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

test("Java: jdtls starts on a project, marks a type error and finds the definition in another class", jdtls_end_to_end)

-- 2026-10-19: the same without IntelliJ - jdtls on a JDK GreyKnight finds on the machine (on the work laptop
-- $JAVA_HOME is 17, the JDK 21 sits next to it). Where IntelliJ is not installed the test above ran that way.
test("Java without IntelliJ: jdtls starts on a JDK found on the machine, end to end as above", function()
  if not require("integrations.intellij").config_dir() then H.skip("no IntelliJ here: the test above ran without it") end
  local saved = vim.env.GREYKNIGHT_INTELLIJ_CONFIG
  vim.env.GREYKNIGHT_INTELLIJ_CONFIG = vim.fn.tempname() -- nothing there: no IntelliJ
  local ok, err = pcall(jdtls_end_to_end)
  vim.env.GREYKNIGHT_INTELLIJ_CONFIG = saved
  if not ok then error(err, 0) end -- a skip stays a skip
end)

-- 2026-10-19: Angular templates get angularls (lua/integrations/web.lua). 2026-10-21: in a workspace folder named R&D
-- - on Windows cmd.exe ran Mason's ngserver.cmd and split the server's probe paths at the & (unquoted: no space)
test("Angular: angularls attaches to a template of an Angular workspace - one in a folder named R&D too", function()
  if vim.fn.executable("ngserver") == 0 then H.skip("angular-language-server not installed (Mason) - an Angular file installs it") end
  local parent = vim.fs.normalize(vim.fn.tempname())
  local root = parent .. "/R&D"
  vim.fn.mkdir(root .. "/src/app", "p")
  vim.fn.writefile({ '{ "version": 1, "projects": {} }' }, root .. "/angular.json")
  vim.fn.writefile({ '{ "compilerOptions": { "target": "es2022", "experimentalDecorators": true } }' }, root .. "/tsconfig.json")
  vim.fn.writefile({
    "import { Component } from '@angular/core';",
    "@Component({ selector: 'app-root', templateUrl: './app.component.html' })",
    "export class AppComponent { title = 'x'; }",
  }, root .. "/src/app/app.component.ts")
  vim.fn.writefile({ "<h1>{{ title }}</h1>" }, root .. "/src/app/app.component.html")
  for _, client in ipairs(vim.lsp.get_clients({ name = "angularls" })) do client:stop(true) end -- one for this root
  wait(10000, function() return #vim.lsp.get_clients({ name = "angularls" }) == 0 end)
  vim.cmd.edit({ args = { root .. "/src/app/app.component.html" }, magic = { file = false } })
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(vim.bo[buf].filetype == "htmlangular", "filetype " .. vim.bo[buf].filetype)
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "angularls" }) > 0 end), "angularls did not attach")
    -- the server stays: with its probe paths cut at the &, it found no language service and ended
    local client = vim.lsp.get_clients({ bufnr = buf, name = "angularls" })[1]
    local answered = wait(30000, function()
      local res = vim.lsp.buf_request_sync(buf, "textDocument/hover", { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 8 } }, 5000)
      return res ~= nil and next(res) ~= nil
    end)
    assert(answered and not client:is_stopped(), "angularls does not answer, or ended")
  end)
  for _, client in ipairs(vim.lsp.get_clients({ name = "angularls" })) do client:stop(true) end
  wait(10000, function() return #vim.lsp.get_clients({ name = "angularls" }) == 0 end)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(parent, "rf")
  assert(ok, err)
end)

H.report("Dev Suite Test Results")
