-- Grey Knight dev suite tests: run / tasks / errors / debug / REPL / Qwen / completion. Run with tests/run.sh
-- Many tests start real processes (python3, ipython3, bash, debugpy, bashdb) and wait for them.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/harness.lua")
local test = H.test

-- T12: Bash + Python dev suite (lua/devsuite/) and the Qwen Code agent (lua/integrations/qwen.lua)
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
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.venv/bin", "p")
  vim.fn.mkdir(root .. "/pkg/sub", "p")
  vim.fn.writefile({ "#!/bin/sh" }, root .. "/.venv/bin/python")
  vim.fn.setfperm(root .. "/.venv/bin/python", "rwx------")
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
  assert(wait(10000, function() return task_out(task):find("name? ", 1, true) end), "no prompt: " .. task_out(task))
  vim.fn.chansend(task.strategy.job_id, "knight\r")
  assert(wait(10000, function() return task:is_complete() end), "did not exit: " .. task_out(task))
  assert(task.status == "SUCCESS" and task_out(task):find("hello knight", 1, true), task.status .. ": " .. task_out(task))
end)

test("Runner: bash snippet (indented selection) with read", function()
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
  local a = tasks.run({ key = "test:a", name = "a", cmd = "sleep 1; echo A-done", cwd = "/tmp", focus = false })
  local b = tasks.run({ key = "test:b", name = "b", cmd = "sleep 1; echo B-done", cwd = "/tmp", focus = false })
  assert(a:is_running() and b:is_running(), "not running side by side")
  local a2 = tasks.run({ key = "test:a", name = "a", cmd = "echo A2", cwd = "/tmp", focus = false })
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
  local path, lnum = errors.location('  File "' .. file .. '", line 7, in main')
  assert(path == file and lnum == 7, tostring(path) .. ":" .. tostring(lnum))
  local p2, l2 = errors.location("\27[31m" .. file .. ": line 3: foo: command not found\27[0m")
  assert(p2 == file and l2 == 3, tostring(p2) .. ":" .. tostring(l2))
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
  vim.fn.writefile({ "def main(): pass", 'if __name__ == "__main__":', "    main()" }, root .. "/tools/report.py")
  vim.fn.writefile({ "def helper(): pass" }, root .. "/lib.py")
  vim.fn.writefile({ "# readme" }, root .. "/README.md")
  vim.fn.writefile({ "echo nested" }, root .. "/src/deep.sh")
  local found = vim.tbl_map(function(p) return p:sub(#root + 2) end, runner.project_scripts(root))
  assert(vim.deep_equal(found, { "launch.sh", "scripts/run_e2e.sh", "tools/report.py" }), vim.inspect(found))
  runner.run_script(root .. "/launch.sh", false, root)
  local task = tasks.state.last
  assert(wait(10000, function() return task:is_complete() end), "did not finish")
  assert(task_out(task):find("ROOT=" .. root, 1, true), task_out(task))
end)

test("Debug: a bash script stops at a breakpoint (bashdb)", function()
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
  assert(wait(40000, function() return find("dbg? ") ~= nil end), "no prompt in a terminal")
  vim.fn.chansend(vim.bo[find("dbg? ")].channel, "sir\r")
  assert(wait(20000, function() return find("dbg hello sir") ~= nil end), "input() did not get the answer")
  wait(10000, function() return ended end)
  dap.listeners.after.event_terminated["gk_smoke"] = nil
end)

for _, flavor in ipairs({ "ipython", "python" }) do
test("REPL (" .. flavor .. "): block with blank lines, then input()", function()
  if flavor == "ipython" and vim.fn.executable("ipython3") == 0 then H.skip("ipython3 not installed - the REPL uses python3 then") end
  local repl = require("devsuite.repl")
  local command = repl.command
  local exe = flavor == "ipython" and "ipython3 --no-autoindent --no-confirm-exit --no-banner" or "python3"
  repl.command = function() return exe, flavor end
  local old = require("toggleterm.terminal").get(repl.IDS.python, true)
  if old then old:shutdown() end
  scratch("python")
  repl.send({ "def greet():", "    a = 'hel'", "", "    return a + 'lo'", "", "print(greet() * 2)" })
  local term = require("toggleterm.terminal").get(repl.IDS.python, true)
  assert(term, "no REPL terminal")
  assert(wait(20000, function() return text(term.bufnr):find("hellohello", 1, true) end), "block did not run: " .. text(term.bufnr))
  repl.send({ "x = input('v' + 'al? ')", "print('val=' + x)" })
  assert(wait(10000, function() return text(term.bufnr):find("val? ", 1, true) end), "no input prompt: " .. text(term.bufnr))
  vim.fn.chansend(term.job_id, "7\r")
  assert(wait(10000, function() return text(term.bufnr):find("val=7", 1, true) end), "input() got the wrong line: " .. text(term.bufnr))
  repl.send({ "for i in range(2): print('loop', i)" })
  assert(wait(10000, function() return text(term.bufnr):find("loop 1", 1, true) end), "one-line block did not run: " .. text(term.bufnr))
  term:shutdown()
  repl.command = command
end)
end

test("Qwen: ask/edit prompts reference the file", function()
  local qwen = require("integrations.qwen")
  local p = qwen.prompt("edit", { rel = "src/my file.py", ft = "python", sel = { text = "x = 1", first = 3, last = 3 } }, "rename x to y")
  assert(p:find("@src/my\\ file.py", 1, true) and p:find("lines 3-3", 1, true) and p:find("rename x to y", 1, true), p)
end)

test("Qwen: new agent gets -i, a running agent one bracketed paste", function()
  local qwen = require("integrations.qwen")
  local T = require("toggleterm.terminal")
  local fake = vim.fn.tempname() .. "-qwen"
  vim.fn.writefile({ "#!/bin/sh", 'printf "ARGV:%s\\n" "$*"', "exec cat -v" }, fake)
  vim.fn.setfperm(fake, "rwx------")
  local saved = vim.env.QWEN_BIN
  vim.env.QWEN_BIN = fake
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
  vim.env.QWEN_BIN = saved
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
  local qwen = require("integrations.qwen")
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
  assert(#own == 1 and own[1].filename == py and own[1].lnum == 7, vim.inspect(lib))
  assert(kinds(errors.parse({ sh .. ": line 4: TARGET: unbound variable", sh .. ": 6: nmapx: not found" }, {})) == "E4 E6", "bash / dash")
  assert(kinds(errors.parse({ py .. ":2: DeprecationWarning: old api" }, {})) == "W2", "warning")
  local noise = errors.parse({ "Error: 404: Not Found", "10.10.10.5:8080 open", "HTTP/1.1 200 OK", "line 3: nothing", "E   not pytest" }, {})
  assert(#noise == 0, "noise matched: " .. vim.inspect(noise))
end)

test("Tasks: stop, hide/show the output, status bar, watch, restart", function()
  local tasks = require("devsuite.tasks")
  vim.cmd.edit(H.file("loop.sh", { "#!/bin/bash", "echo started", "sleep 30" }))
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
  assert(got.py == "/usr/bin/env -S python3 -u" and got.sh == "bash" and got.dash == "/bin/sh", vim.inspect(got))
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
    local task = tasks.run({ key = "test:guard", name = "guard", cmd = "true", cwd = "/tmp", focus = false })
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
  local qwen = require("integrations.qwen")
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode({ model_path = "/m/Fake-27B-Q6_K.gguf", default_generation_settings = { n_ctx = 4096 } }) }, dir .. "/props")
  local port = 18000 + vim.uv.hrtime() % 1000
  local base = ("http://127.0.0.1:%d"):format(port)
  local server = vim.fn.jobstart({ "python3", "-m", "http.server", tostring(port), "--bind", "127.0.0.1", "--directory", dir })
  local saved = vim.env.QWEN_BASE_URL
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
    assert(H.wait(5000, function() return got end) and got:find("No model is running", 1, true), tostring(got))
  end)
  vim.fn.jobstop(server)
  vim.env.QWEN_BASE_URL = saved
  assert(ok, err)
end)

H.report("Dev Suite Test Results")
