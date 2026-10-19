-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Runner: what to run for files, snippets, cells, project    ║
-- ║  scripts and tests - each run is a task (devsuite.tasks)    ║
-- ║  in a real pty: input(), read, getpass and sudo prompts     ║
-- ║  work (:!python3 % has none: input() raises EOFError)       ║
-- ╚══════════════════════════════════════════════════════════════╝
local util = require("devsuite.util")
local tasks = require("devsuite.tasks")
local M = {}

local WARN = vim.log.levels.WARN

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Run" }) end

local function quote(argv) return table.concat(vim.tbl_map(vim.fn.shellescape, argv), " ") end

-- "python3" for { "/usr/bin/env", "python3" }
local function program(argv)
  for i = #argv, 1, -1 do
    if not argv[i]:match("^%-") then return vim.fn.fnamemodify(argv[i], ":t") end
  end
  return argv[1] or ""
end

local function no_interpreter(what)
  notify(("Run: nothing runs %s (add a #! line)"):format(what), WARN)
end

--- Run the current file (saved first) with its remembered arguments.
--- opts.args: new arguments (remembered for this file); opts.flags: interpreter flags (-x); opts.sudo
function M.run_file(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= "" then return notify("Run: not a file", WARN) end
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then return M.run_lines(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "buffer", 1) end
  local argv = util.interpreter(bufnr, file)
  if not argv then return no_interpreter("'" .. vim.bo[bufnr].filetype .. "' files") end
  vim.cmd("silent! update")
  if opts.args then tasks.set_args(file, opts.args) end
  local args = tasks.get_args(file)
  local cmd = quote(vim.list_extend(vim.deepcopy(argv), opts.flags or {})) .. " " .. vim.fn.shellescape(file)
  if args ~= "" then cmd = cmd .. " " .. args end
  if opts.sudo then cmd = "sudo " .. cmd end
  tasks.run({
    key = "file:" .. file,
    file = file,
    name = vim.trim(("%s%s %s %s"):format(opts.sudo and "sudo " or "", program(argv), vim.fn.fnamemodify(file, ":."), args)),
    cmd = cmd,
    cwd = vim.fn.getcwd(),
  })
end

--- Edit the arguments of the current file (shell syntax: quotes, globs, "< input.txt"), then run it.
function M.run_file_args()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then return M.run_file() end
  vim.ui.input({ prompt = "Args for " .. vim.fn.fnamemodify(file, ":t") .. ": ", default = tasks.get_args(file) }, function(input)
    if input ~= nil then M.run_file({ args = input }) end
  end)
end

--- Run the current file as root (sudo asks for the password in the output window).
function M.run_sudo()
  if util.WIN then return notify("Run: sudo runs are for Linux", WARN) end
  M.run_file({ sudo = true })
end

--- Run lines as a script of their own (dedented, from a temp file) with the buffer's interpreter.
--- `first` = line number of the first line in the buffer, so errors point at the right lines.
function M.run_lines(lines, label, first, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  local argv, kind = util.interpreter(bufnr, file)
  if not argv then return no_interpreter("'" .. vim.bo[bufnr].filetype .. "' code") end
  lines = util.dedent(lines)
  if not vim.iter(lines):any(function(line) return line:find("%S") ~= nil end) then
    return notify("Run: nothing to run", WARN)
  end
  local script = vim.fn.tempname() .. "-snippet" .. (util.EXT[vim.bo[bufnr].filetype] or "")
  vim.fn.writefile(lines, script)
  local env
  if kind == "python" then
    -- The snippet runs from a temp dir: keep "import my_module" (next to the file) working
    local dir = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
    local path = vim.env.PYTHONPATH
    local sep = util.WIN and ";" or ":"
    env = { PYTHONPATH = (path and path ~= "") and (dir .. sep .. path) or dir }
  end
  tasks.run({
    key = "snippet:" .. (file ~= "" and file or tostring(bufnr)),
    file = file ~= "" and file or nil,
    name = ("%s %s"):format(file ~= "" and vim.fn.fnamemodify(file, ":t") or "[No Name]", label),
    cmd = quote(argv) .. " " .. vim.fn.shellescape(script),
    cwd = vim.fn.getcwd(),
    env = env,
    map = file ~= "" and { [script] = { file = file, offset = (first or 1) - 1 } } or nil,
  })
end

--- Run the visual selection as a script.
function M.run_selection()
  local lines, first, last = util.visual_lines()
  M.run_lines(lines, ("L%d-%d"):format(first, last), first)
end

--- Run the "# %%" cell at the cursor (the whole file when it has no cells).
function M.run_cell()
  local first, last, lines = util.cell_range(0, vim.api.nvim_win_get_cursor(0)[1])
  if not first then
    notify("Run: no '# %%' cells here - running the whole file")
    return M.run_file()
  end
  M.run_lines(lines, ("cell L%d-%d"):format(first, last), first)
end

--- Run a shell script with -x: every command is printed before it runs.
function M.run_trace()
  local _, kind = util.interpreter(0, vim.api.nvim_buf_get_name(0))
  if kind ~= "shell" then return notify("Run: trace (-x) is for shell scripts", WARN) end
  M.run_file({ flags = { "-x" } })
end

-- ── Project scripts ─────────────────────────────────────────
local SCRIPT_DIRS = { "", "scripts", "bin", "tools" }

local function is_script(path, name)
  if name:match("%.sh$") or name:match("%.bash$") then return true end
  if name:match("%.py$") then
    local head = vim.fn.readfile(path, "", 300)
    if (head[1] or ""):match("^#!") then return true end
    for _, line in ipairs(head) do
      if line:find("__main__", 1, true) then return true end
    end
    return false
  end
  return vim.fn.executable(path) == 1
end

--- The project of the current file (git root), else Neovim's directory.
function M.project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = (file ~= "" and vim.bo.buftype == "") and vim.fs.dirname(file) or vim.fn.getcwd()
  return vim.fs.root(start, { ".git" }) or vim.fn.getcwd()
end

--- Scripts of a project: *.sh, executables and runnable *.py in ./, scripts/, bin/ and tools/.
function M.project_scripts(root)
  local found = {}
  for _, sub in ipairs(SCRIPT_DIRS) do
    local dir = sub == "" and root or (root .. "/" .. sub)
    if vim.fn.isdirectory(dir) == 1 then
      for name, kind in vim.fs.dir(dir) do
        local path = dir .. "/" .. name
        if (kind == "file" or kind == "link") and not name:match("^%.") and vim.fn.isdirectory(path) == 0 and is_script(path, name) then
          found[#found + 1] = path
        end
      end
    end
  end
  table.sort(found)
  return found
end

--- Run a project script from the project root with its remembered arguments (ask_args: edit them first).
function M.run_script(path, ask_args, root)
  root = root or M.project_root()
  local function go(args)
    if args then tasks.set_args(path, args) end
    args = tasks.get_args(path)
    local argv = util.file_interpreter(path)
    if not argv then return no_interpreter(vim.fn.fnamemodify(path, ":t")) end
    local rel = path:sub(1, #root + 1) == root .. "/" and path:sub(#root + 2) or path
    local cmd = (#argv > 0 and (quote(argv) .. " ") or "") .. vim.fn.shellescape(path)
    if args ~= "" then cmd = cmd .. " " .. args end
    tasks.run({ key = "script:" .. path, file = path, name = vim.trim(rel .. " " .. args), cmd = cmd, cwd = root })
  end
  if not ask_args then return go() end
  vim.ui.input({ prompt = "Args for " .. vim.fn.fnamemodify(path, ":t") .. ": ", default = tasks.get_args(path) }, function(input)
    if input ~= nil then go(input) end
  end)
end

--- Pick a project script and run it (ask_args: edit its arguments first).
function M.pick_script(ask_args)
  local root = M.project_root()
  local scripts = M.project_scripts(root)
  if #scripts == 0 then
    return notify("Run: no scripts in " .. vim.fn.fnamemodify(root, ":~") .. " (looked in ./, scripts/, bin/, tools/)", WARN)
  end
  local running = {}
  for _, task in ipairs(require("overseer").list_tasks({ status = "RUNNING" })) do
    if task.metadata.gk_key then running[task.metadata.gk_key] = true end
  end
  local items = vim.tbl_map(function(path)
    local args = tasks.get_args(path)
    return {
      path = path,
      label = path:sub(#root + 2) .. (args ~= "" and ("   " .. args) or "") .. (running["script:" .. path] and "   (running)" or ""),
    }
  end, scripts)
  vim.ui.select(items, {
    prompt = (ask_args and "Run with args" or "Run") .. " (" .. vim.fn.fnamemodify(root, ":t") .. ")",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then M.run_script(choice.path, ask_args, root) end
  end)
end

-- ── Tests ───────────────────────────────────────────────────
local function pytest(nearest)
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "python" then return notify("Run: pytest needs a Python file", WARN) end
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then return notify("Run: save the file first", WARN) end
  vim.cmd("silent! update")
  local target = vim.fn.fnamemodify(file, ":.")
  if nearest then
    local node = util.pytest_node(bufnr)
    if node then
      target = target .. "::" .. node
    else
      notify("Run: no test at the cursor - running the file")
    end
  end
  tasks.run({
    key = "pytest:" .. file,
    file = file,
    name = "pytest " .. target,
    cmd = ("%s -m pytest %s"):format(vim.fn.shellescape(util.python(file)), vim.fn.shellescape(target)),
    cwd = vim.fn.getcwd(),
  })
end

--- pytest the current file / the test at the cursor (with the project's virtualenv).
function M.test_file() pytest(false) end
function M.test_nearest() pytest(true) end

-- ── Task controls (devsuite.tasks) ──────────────────────────
M.rerun = tasks.rerun
M.stop = tasks.stop
M.toggle = tasks.toggle
M.list = tasks.list
M.toggle_watch = tasks.toggle_watch
M.fix_with_qwen = tasks.fix_with_qwen

return M
