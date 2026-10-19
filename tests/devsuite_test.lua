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
-- (GreyNight measures the duration itself). Every component a task gets must be current in overseer.
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
  assert(dbg.setup_bash(), "bash-debug-adapter not installed (:MasonInstall bash-debug-adapter)")
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

test("Debug: four bash sessions in a row", function()
  linux_only("bash debugging (bashdb)")
  local dbg, dap = require("devsuite.debug"), require("dap")
  assert(dbg.setup_bash(), "bash-debug-adapter not installed (:MasonInstall bash-debug-adapter)")
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
  end), "no bash diagnostics")
  vim.wait(1500)
  local d = vim.diagnostic.get(0)
  assert(#d == 1 and d[1].lnum == 1 and tostring(d[1].code):find("2086", 1, true), vim.inspect(d))
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do client:stop(true) end
  wait(5000, function() return #vim.lsp.get_clients({ bufnr = 0 }) == 0 end)
  vim.cmd("silent write")
  local f = vim.diagnostic.get(0)
  assert(#f == 1 and f[1].lnum == 1 and tostring(f[1].code) == "2086", vim.inspect(f))
end)

test("Errors in GreyNight itself reach the error log (task callbacks do not fail silently)", function()
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
    assert(H.wait(5000, function()
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
    -- Windows answers a closed port only after ~2 s of SYN retries (curl's limit is 3 s): 5 s were too tight
    assert(H.wait(10000, function() return got end) and got:find("No model is running", 1, true), tostring(got))
  end)
  vim.fn.jobstop(server)
  vim.env.QWEN_BASE_URL, vim.env.GREYKNIGHT_AGENT = saved, saved_agent
  assert(ok, err)
end)

-- 2026-10-19: Java through jdtls (lua/integrations/jdtls.lua) - started like for a G3 file, end to end
test("Java: jdtls starts on a project, marks a type error and finds the definition in another class", function()
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
  end)
  for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do client:stop(true) end
  wait(10000, function() return #vim.lsp.get_clients({ name = "jdtls" }) == 0 end)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(jdtls.workspace(root), "rf")
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-19: Angular templates get angularls (lua/integrations/web.lua)
test("Angular: angularls attaches to a template of an Angular workspace", function()
  if vim.fn.executable("ngserver") == 0 then H.skip("angular-language-server not installed (Mason) - an Angular file installs it") end
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(root .. "/src/app", "p")
  vim.fn.writefile({ '{ "version": 1, "projects": {} }' }, root .. "/angular.json")
  vim.fn.writefile({ '{ "compilerOptions": { "target": "es2022", "experimentalDecorators": true } }' }, root .. "/tsconfig.json")
  vim.fn.writefile({
    "import { Component } from '@angular/core';",
    "@Component({ selector: 'app-root', templateUrl: './app.component.html' })",
    "export class AppComponent { title = 'x'; }",
  }, root .. "/src/app/app.component.ts")
  vim.fn.writefile({ "<h1>{{ title }}</h1>" }, root .. "/src/app/app.component.html")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/src/app/app.component.html"))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(vim.bo[buf].filetype == "htmlangular", "filetype " .. vim.bo[buf].filetype)
    assert(wait(60000, function() return #vim.lsp.get_clients({ bufnr = buf, name = "angularls" }) > 0 end), "angularls did not attach")
    vim.wait(3000)
    assert(#vim.lsp.get_clients({ bufnr = buf, name = "angularls" }) > 0, "angularls ended right away")
  end)
  for _, client in ipairs(vim.lsp.get_clients({ name = "angularls" })) do client:stop(true) end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

H.report("Dev Suite Test Results")
