-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Dev suite helpers: interpreters, virtualenvs, snippets,    ║
-- ║  "# %%" cells, pytest node ids                              ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

M.WIN = vim.fn.has("win32") == 1

--- root_dir for vim.lsp.config(name, ...): nvim-lspconfig's own way to the project (its root_dir function, else its
--- root_markers) - but never for a buffer without a file. vim.lsp.enable() starts servers for every buffer of their
--- filetype, a scratch buffer (:enew, filetype set) too, which nvim-lspconfig's old setup never did; and as files
--- outside any project share one client, bashls marked nothing more after one (2026-10-22). folder: a file outside
--- any project gets its folder as the workspace (lua_ls marks nothing without one). Read before vim.lsp.config(name)
--- gets this function, else it would find itself.
function M.lsp_root(name, folder)
  local cfg = vim.lsp.config[name] or {}
  local own, markers = cfg.root_dir, cfg.root_markers
  return function(buf, on_dir)
    local file = vim.api.nvim_buf_get_name(buf)
    if file == "" then return end
    if type(own) == "function" then return own(buf, on_dir) end
    if type(own) == "string" then return on_dir(own) end
    on_dir((markers and vim.fs.root(buf, markers)) or (folder and vim.fs.dirname(file)) or nil)
  end
end

--- A program in a virtualenv: bin/<name> (Linux), Scripts\<name>.exe (Windows).
function M.venv_bin(venv, name)
  return M.WIN and (venv .. "/Scripts/" .. name .. ".exe") or (venv .. "/bin/" .. name)
end

--- The python of a virtualenv.
function M.venv_python(venv) return M.venv_bin(venv, "python") end

--- Virtualenv for a file or directory: $VIRTUAL_ENV, else the nearest .venv/ or venv/ walking upwards,
--- below $HOME only: a venv in the home directory (~/.venv, ~/venv) is a toolbox, not the project's
--- environment - activate it before starting Neovim to use it everywhere.
---@param path string? file or directory (default: the current directory)
---@return string? venv the virtualenv directory
function M.find_venv(path)
  local active = vim.env.VIRTUAL_ENV
  if active and active ~= "" and vim.fn.executable(M.venv_python(active)) == 1 then return active end
  if not path or path == "" then path = vim.fn.getcwd() end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local dirs = vim.fn.isdirectory(path) == 1 and { path } or {}
  for dir in vim.fs.parents(path) do dirs[#dirs + 1] = dir end
  local home = vim.env.HOME and vim.env.HOME ~= "" and vim.fs.normalize(vim.env.HOME) or nil
  for _, dir in ipairs(dirs) do
    if dir == home then break end
    for _, name in ipairs({ ".venv", "venv" }) do
      local venv = vim.fs.joinpath(dir, name)
      if vim.fn.executable(M.venv_python(venv)) == 1 then return venv end
    end
  end
end

-- The node a shim's script runs on: the one next to the shim, else the node on the PATH - and behind Volta's node.exe
-- the real one (volta which node): Volta's launcher hands the arguments to cmd.exe, which split one with an & and no
-- space at the & (angularls in R&D got the probe path "...\R", 2026-10-21). Asked once per session.
local path_node
local function node_for(dir)
  local beside = vim.uv.fs_realpath(dir .. "/node.exe")
  if beside then return beside end
  if path_node == nil then
    path_node = vim.fn.exepath("node")
    if path_node:lower():find("volta", 1, true) and vim.fn.executable("volta") == 1 then
      local ok, res = pcall(function() return vim.system({ "volta", "which", "node" }, { text = true }):wait(5000) end)
      local real = ok and res.code == 0 and vim.trim(res.stdout or "") or ""
      if real ~= "" and vim.uv.fs_stat(real) then path_node = real end
    end
  end
  return path_node ~= "" and path_node or nil
end

--- argv with a .cmd shim - npm's and Mason's (cmd-shim), node_modules/.bin and mason/bin - replaced by what the
--- shim runs: the program, or node and the script. Windows runs a .cmd through cmd.exe, which splits and changes the
--- arguments: at an & (a file in R&D), a ^ dropped, and a quoted shim with another quoted argument lost its quotes -
--- ruff did not format a file in R&D, a project's prettier in "C:\my projects" never ran (2026-10-21). A shim that
--- adds arguments of its own, one of another kind, and every argv elsewhere stay as they are.
---@param argv string[]
---@return string[]
function M.unshim(argv, depth)
  depth = depth or 0
  if not M.WIN or type(argv) ~= "table" or type(argv[1]) ~= "string" or depth > 4 then return argv end
  local shim = argv[1]
  if not shim:lower():match("%.cmd$") and not shim:lower():match("%.bat$") then
    shim = vim.fn.exepath(shim)
    if not (shim:lower():match("%.cmd$") or shim:lower():match("%.bat$")) then return argv end
  end
  local ok, lines = pcall(vim.fn.readfile, shim)
  if not ok then return argv end
  local dir = vim.fs.dirname(vim.fs.normalize(shim))
  for i = #lines, 1, -1 do
    -- the line that runs it: ... ["%_prog%" | "<node.exe>"] "%dp0%\<target>" %*  - nothing between the target and %*
    local before, quoted = lines[i]:match('^(.-)"([^"]*)"%s*%%%*%s*$')
    if quoted then
      local rest = quoted:match("^%%dp0%%(.*)$") or quoted:match("^%%~dp0(.*)$")
      local target = rest and vim.uv.fs_realpath(dir .. "/" .. (rest:gsub("\\", "/")))
      if not target then return argv end
      local args = vim.list_slice(argv, 2)
      local lower = target:lower()
      if before:match('"%%_prog%%"%s*$') or before:match('node%.exe"%s*$') or before:match("node%s*$")
        or lower:match("%.[cm]?js$") then
        local node = node_for(dir)
        if not node then return argv end
        return vim.list_extend({ node, target }, args)
      end
      if lower:match("%.cmd$") or lower:match("%.bat$") then return M.unshim(vim.list_extend({ target }, args), depth + 1) end
      if lower:match("%.exe$") or lower:match("%.com$") then return vim.list_extend({ target }, args) end
      return argv
    end
  end
  return argv
end

--- The Python on the PATH: python3, else python. Windows: python, else the py launcher - python3 there is
--- usually the Microsoft Store's placeholder (WindowsApps), which only points at the Store.
function M.system_python()
  if not M.WIN then return vim.fn.executable("python3") == 1 and "python3" or "python" end
  for _, exe in ipairs({ "python", "py" }) do
    local path = vim.fn.exepath(exe)
    if path ~= "" and not path:lower():find("\\windowsapps\\", 1, true) then return exe end
  end
  return "python"
end

--- Python for a file: its virtualenv's python, else the system one.
function M.python(path)
  local venv = M.find_venv(path)
  if venv then return M.venv_python(venv) end
  return M.system_python()
end

--- The #! line of a buffer as argv ({ "/usr/bin/env", "bash" }), or nil.
function M.shebang(bufnr)
  local first = vim.api.nvim_buf_get_lines(bufnr or 0, 0, 1, false)[1] or ""
  local cmd = first:match("^#!%s*(%S.*)$")
  return cmd and vim.split(vim.trim(cmd), "%s+") or nil
end

local SHELLS = { sh = true, bash = true, zsh = true }
local BY_FILETYPE = { javascript = { "node" }, perl = { "perl" }, ruby = { "ruby" } }

--- Extension of snippet files by filetype (some interpreters look at it).
M.EXT = { python = ".py", sh = ".sh", bash = ".sh", zsh = ".zsh", lua = ".lua", javascript = ".js", perl = ".pl", ruby = ".rb" }

--- Interpreter argv for a buffer, and its kind. Python: the project's virtualenv beats the #! line
--- (as in VS Code), then python3; Windows has no /usr/bin/env, so there the #! line of a Python file is
--- ignored. Shell scripts: the #! line, else bash. Others: the #! line.
---@return string[]? argv
---@return "python"|"shell"|"other"|nil kind
function M.interpreter(bufnr, path)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  local shebang = M.shebang(bufnr)
  if ft == "python" then
    local venv = M.find_venv(path)
    if venv then return { M.venv_python(venv) }, "python" end
    return (not M.WIN and shebang) or { M.python(path) }, "python"
  end
  if SHELLS[ft] then return shebang or { ft == "zsh" and "zsh" or "bash" }, "shell" end
  if shebang then return shebang, "other" end
  if ft == "lua" then return vim.fn.executable("lua") == 1 and { "lua" } or { "nvim", "-l" }, "other" end
  if BY_FILETYPE[ft] then return BY_FILETYPE[ft], "other" end
end

--- Interpreter argv for a script file that is not open: like interpreter(), from the file itself.
--- {} = run the file directly (an executable without a known interpreter).
function M.file_interpreter(path)
  local head = vim.fn.readfile(path, "", 5)
  local shebang = (head[1] or ""):match("^#!%s*(%S.*)$")
  local ft = vim.filetype.match({ filename = path, contents = head }) or ""
  if ft == "python" then
    local venv = M.find_venv(path)
    if venv then return { M.venv_python(venv) } end
    if M.WIN then return { M.python(path) } end -- no /usr/bin/env for a #! line
  end
  if shebang then return vim.split(vim.trim(shebang), "%s+") end
  if ft == "python" then return { M.python(path) } end
  if SHELLS[ft] then return { ft == "zsh" and "zsh" or "bash" } end
  if vim.fn.executable(path) == 1 then return {} end
  return BY_FILETYPE[ft]
end

--- Remove the indentation all non-blank lines share, so a block copied out of a function runs on its own.
function M.dedent(lines)
  local prefix
  for _, line in ipairs(lines) do
    if line:find("%S") then
      local indent = line:match("^%s*")
      if not prefix then
        prefix = indent
      else
        local n = 0
        while n < #prefix and n < #indent and prefix:byte(n + 1) == indent:byte(n + 1) do n = n + 1 end
        prefix = prefix:sub(1, n)
      end
    end
  end
  if not prefix or prefix == "" then return lines end
  return vim.tbl_map(function(line)
    if not line:find("%S") then return "" end
    return line:sub(#prefix + 1)
  end, lines)
end

--- "# %%" starts a cell (the marker of VS Code, Jupytext and Spyder).
M.CELL = "^%s*#%s*%%%%"

--- The "# %%" cell around line `row`: its first and last line (1-based) and its lines; nil without cells.
function M.cell_range(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  local first, last, found = 1, #lines, false
  for i = row, 1, -1 do
    if lines[i]:match(M.CELL) then
      first, found = i + 1, true
      break
    end
  end
  for i = row + 1, #lines do
    if lines[i]:match(M.CELL) then
      last, found = i - 1, true
      break
    end
  end
  if not found then return nil end
  return first, last, vim.list_slice(lines, first, last)
end

--- Lines of the visual selection (leaves visual mode), and its first and last line.
function M.visual_lines()
  local mode = vim.fn.mode()
  local from, to
  if mode == "v" or mode == "V" or mode == "\22" then
    from, to = vim.fn.getpos("v"), vim.fn.getpos(".")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  else -- visual mode already ended: the last selection
    from, to = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    mode = vim.fn.visualmode()
    if mode == "" then mode = "V" end
  end
  if from[2] > to[2] or (from[2] == to[2] and from[3] > to[3]) then from, to = to, from end
  return vim.fn.getregion(from, to, { type = mode }), from[2], to[2]
end

--- pytest node id of the test at the cursor ("TestClass::test_name"), or nil.
function M.pytest_node(bufnr, row, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not row then
    local cursor = vim.api.nvim_win_get_cursor(0)
    row, col = cursor[1], cursor[2]
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "python")
  if not ok or not parser then return nil end
  parser:parse()
  local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row - 1, col or 0 }, ignore_injections = true })
  local names = {}
  while node do
    local kind = node:type()
    if kind == "function_definition" or kind == "class_definition" then
      local id = node:field("name")[1]
      local name = id and vim.treesitter.get_node_text(id, bufnr) or ""
      if name:match(kind == "class_definition" and "^Test" or "^test") then table.insert(names, 1, name) end
    end
    node = node:parent()
  end
  return #names > 0 and table.concat(names, "::") or nil
end

return M
