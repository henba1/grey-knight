-- ╔══════════════════════════════════════════════════════════════╗
-- ║  LaTeX: latexmk builds the document of the current file -   ║
-- ║  once, or on every save (latexmk -pvc) - and its errors     ║
-- ║  go to the quickfix list and onto the lines that failed     ║
-- ╚══════════════════════════════════════════════════════════════╝
local errors = require("devsuite.errors")
local util = require("devsuite.util")
local M = {}

local WARN = vim.log.levels.WARN

-- one notification that each round replaces (snacks.notifier's id), not one per save
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "LaTeX", id = "greyknight_latex" })
end

M.state = { job = nil, main = nil, items = {}, preview = nil, preview_url = nil }

-- The preview a watch starts: the PDF as pictures on http://localhost:<port> (resources/latex_preview.py); 0 takes
-- a free port (the tests)
M.preview_port = 8000
M.PREVIEW = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/resources/latex_preview.py"

--- latexmk: on the PATH, else TeX Live's own install folders (~/texlive/<year>, /usr/local/texlive/<year>) - the
--- newest year. TeX Live's installer leaves the PATH to you, and a Neovim started from a desktop or an SSH command
--- does not read the shell's rc files.
function M.latexmk()
  if vim.fn.executable("latexmk") == 1 then return vim.fn.exepath("latexmk") end
  local found = {}
  for _, base in ipairs({ vim.fn.expand("~/texlive"), "/usr/local/texlive" }) do
    vim.list_extend(found, vim.fn.glob(base .. "/*/bin/*/latexmk", false, true))
  end
  table.sort(found)
  return found[#found]
end

--- A latexmkrc that applies to the document: in its folder, or the user's own.
function M.has_rc(main)
  local dir = vim.fn.fnamemodify(main, ":h")
  local xdg = vim.env.XDG_CONFIG_HOME and vim.env.XDG_CONFIG_HOME ~= "" and vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")
  for _, rc in ipairs({ dir .. "/latexmkrc", dir .. "/.latexmkrc", vim.fn.expand("~/.latexmkrc"), xdg .. "/latexmk/latexmkrc" }) do
    if vim.fn.filereadable(rc) == 1 then return true end
  end
  return false
end

local function is_absolute(path) return path:match("^/") ~= nil or path:match("^%a:[/\\]") ~= nil end

local function head(path, n)
  local ok, lines = pcall(vim.fn.readfile, path, "", n)
  return ok and lines or {}
end

local function has_documentclass(path)
  for _, line in ipairs(head(path, 200)) do
    if line:match("^%s*\\documentclass") then return true end
  end
  return false
end

--- The document a .tex file belongs to: its "% !TEX root = ..." line, else the file itself when it has a
--- \documentclass, else the main.tex (with a \documentclass) of the nearest folder above - a section file of
--- a thesis builds the thesis.
function M.main(file)
  if file == "" then return nil end
  local dir = vim.fn.fnamemodify(file, ":p:h")
  for _, line in ipairs(head(file, 20)) do
    local root = line:match("^%%%s*!%s*[Tt][Ee][Xx]%s+root%s*=%s*(.-)%s*$")
    if root and root ~= "" then
      return vim.fs.normalize(is_absolute(root) and root or (dir .. "/" .. root))
    end
  end
  if has_documentclass(file) then return vim.fs.normalize(vim.fn.fnamemodify(file, ":p")) end
  local home = vim.fs.normalize(vim.fn.expand("~"))
  for parent in vim.fs.parents(file) do
    local main = parent .. "/main.tex"
    if vim.fn.filereadable(main) == 1 and has_documentclass(main) then return vim.fs.normalize(main) end
    if parent == home then break end
  end
end

-- What TeX says after "file:line:" that is not the error itself
local NOISE = { "^Emergency stop", "^%s*==> Fatal error occurred" }

--- Errors of one latexmk round: "./sections/x.tex:12: Undefined control sequence." (-file-line-error).
--- A round runs pdflatex several times and an early run can fail for reasons the next one fixes (aux folders
--- not made yet, 2026-10-25) - only the last LaTeX run of the round counts. Each error once: beamer typesets a
--- frame once per overlay (\pause) and reports its errors each time.
---@param lines string[] latexmk's output of one round
---@param root string folder latexmk ran in (TeX prints paths relative to it)
function M.parse(lines, root)
  local items = {}
  local undefined -- the item of an "Undefined control sequence": TeX's next line ends with the command
  for _, raw in ipairs(lines) do
    local line = errors.clean(raw)
    if undefined and line:find("%S") then
      -- beamer reports every error of a frame at its \end{frame}: the name says which line it was
      local cs = line:match("(\\[%a@]+)%s*$")
      if cs then undefined.text = undefined.text .. " " .. cs end
      undefined = nil
    end
    local rule = line:match("^Run number %d+ of rule '(.-)'")
    if rule and rule:match("latex") then
      items = {}
    else
      local file, lnum, msg = line:match("^(.-%.%a+):(%d+): (.+)$")
      if file and not file:find("%s") then
        local noise = false
        for _, pattern in ipairs(NOISE) do noise = noise or msg:match(pattern) ~= nil end
        if not noise then
          local path = vim.fs.normalize(is_absolute(file) and file or (root .. "/" .. file))
          items[#items + 1] = { filename = path, lnum = tonumber(lnum), text = msg, type = "E" }
          if msg:match("^Undefined control sequence") then undefined = items[#items] end
        end
      end
    end
  end
  local out, seen = {}, {}
  for _, item in ipairs(items) do
    local key = item.filename .. ":" .. item.lnum .. ":" .. item.text
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = item
    end
  end
  return out
end

-- A round is over: its errors in the quickfix list and on their lines, a word on how it went
local function finish(main, lines, failed)
  local items = M.parse(lines, vim.fn.fnamemodify(main, ":h"))
  M.state.items = items
  local name = vim.fn.fnamemodify(main, ":t")
  if #items == 0 then
    errors.clear("latex")
    -- no error on a line, and yet no document: biber failed, a file could not be written, ...
    for _, line in ipairs(lines) do failed = failed or line:match("^Latexmk: Errors, so I did not complete") ~= nil end
    if failed then return notify(("LaTeX: %s did not build - its .log says why"):format(name), WARN) end
    return notify(("LaTeX: %s built"):format(name))
  end
  errors.publish("latex", "LaTeX: " .. name, items)
  notify(("LaTeX: %d error%s in %s - <leader>le lists %s"):format(
    #items, #items == 1 and "" or "s", name, #items == 1 and "it" or "them"), WARN)
end

--- Start the preview of a watched document's PDF; the watch stops it. Over SSH the browser of your own machine
--- shows it: ssh -L 8000:localhost:8000 <host>, then http://localhost:8000.
function M.start_preview(pdf)
  if M.state.preview then return end
  if vim.fn.executable("pdftoppm") == 0 then
    return notify("LaTeX: no preview - it needs pdftoppm (poppler-utils)", WARN)
  end
  local err = {}
  local job = vim.fn.jobstart({ util.system_python(), M.PREVIEW, pdf, "--port", tostring(M.preview_port) }, {
    on_stdout = function(id, data)
      local port = table.concat(data):match("http://localhost:(%d+)")
      if port and M.state.preview == id then
        M.state.preview_url = "http://localhost:" .. port
        vim.notify(("LaTeX: preview on %s - over SSH: ssh -L %s:localhost:%s <host>"):format(M.state.preview_url, port, port),
          vim.log.levels.INFO, { title = "LaTeX", id = "greyknight_latex_preview" })
      end
    end,
    on_stderr = function(_, data) vim.list_extend(err, data) end,
    on_exit = function(id, code)
      if M.state.preview == id then M.state.preview, M.state.preview_url = nil, nil end
      -- 143: stopped (SIGTERM) - anything else is a preview that did not start: the port taken, ...
      if code ~= 0 and code ~= 143 then
        local msg = vim.trim(table.concat(err, " "))
        notify("LaTeX: preview stopped - " .. (msg ~= "" and msg or ("exit " .. code)), WARN)
      end
    end,
  })
  if job > 0 then M.state.preview = job end
end

local function stop_preview()
  if M.state.preview then vim.fn.jobstop(M.state.preview) end
  M.state.preview, M.state.preview_url = nil, nil
end

local function start(main, watch)
  local latexmk = M.latexmk()
  if not latexmk then return notify("LaTeX: no latexmk - install TeX Live, or put its bin folder on the PATH", WARN) end
  local argv = { latexmk, "-interaction=nonstopmode", "-file-line-error" }
  -- latexmk makes a DVI unless told otherwise: a PDF, unless a latexmkrc says how (lualatex, xelatex, $out_dir ...)
  if not M.has_rc(main) then argv[#argv + 1] = "-pdf" end
  -- -view=none: latexmk -pvc would start a PDF viewer (there is none over SSH); the document is yours to show
  if watch then vim.list_extend(argv, { "-pvc", "-view=none" }) end
  argv[#argv + 1] = vim.fn.fnamemodify(main, ":t")
  local lines, partial = {}, ""
  local root = vim.fn.fnamemodify(main, ":h")
  local pdf = root .. "/" .. vim.fn.fnamemodify(main, ":t:r") .. ".pdf" -- unless latexmk says where (latexmkrc's $out_dir)
  local job = vim.fn.jobstart(argv, {
    cwd = root,
    env = {
      -- TeX wraps its messages at 79 columns: a long path or message came in two lines and was not found
      max_print_line = "10000",
      -- latexmk starts pdflatex and biber: from the same TeX Live as itself
      PATH = vim.fn.fnamemodify(latexmk, ":h") .. (util.WIN and ";" or ":") .. (vim.env.PATH or ""),
    },
    on_stdout = function(_, data)
      data[1] = partial .. data[1]
      partial = table.remove(data)
      for _, line in ipairs(data) do
        -- where the PDF is: said when pdflatex ran, else listed when everything was up to date already
        local out = line:match("^Latexmk: Log file says output to '(.-)'")
          or (line:match("^Latexmk: All targets %((.-)%) are up%-to%-date") or ""):match("(%S+%.pdf)")
        if out and out:match("%.pdf$") then pdf = vim.fs.normalize(is_absolute(out) and out or (root .. "/" .. out)) end
        if watch and line:match("^=== Watching for updated files") then
          finish(main, lines)
          lines = {}
          if M.state.job and vim.fn.filereadable(pdf) == 1 then M.start_preview(pdf) end
        else
          lines[#lines + 1] = line
        end
      end
    end,
    on_exit = function(id, code)
      if M.state.job == id then
        M.state.job, M.state.main = nil, nil
        stop_preview() -- latexmk ended on its own: nothing builds the PDF the preview shows
      end
      -- a watch ends when it is stopped (its rounds reported themselves); a single build when it is done
      if not watch then
        if partial ~= "" then lines[#lines + 1] = partial end
        finish(main, lines, code ~= 0)
      end
    end,
  })
  if job <= 0 then return notify("LaTeX: latexmk did not start", WARN) end
  if watch then M.state.job, M.state.main = job, main end
  return job
end

--- The file the keys act on: the current buffer's; in the file tree the item under its cursor (a folder: its
--- main.tex); in a terminal or another window without a file, the file used before it. <leader>lw in the tree
--- said "no document here" (2026-10-25): the tree's buffer has no file name.
function M.current_file()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype == "" and name ~= "" then return name end
  if vim.bo[buf].filetype:match("^snacks_picker") then
    local ok, item = pcall(function()
      for _, p in ipairs(Snacks.picker.get({ source = "explorer" })) do
        if not p.closed then return p:current() end
      end
    end)
    if ok and item and item.file then
      if vim.fn.isdirectory(item.file) == 0 then return item.file end
      return vim.fs.normalize(item.file) .. "/main.tex"
    end
  end
  local alt = vim.fn.bufnr("#")
  if alt > 0 and vim.bo[alt].buftype == "" then return vim.api.nvim_buf_get_name(alt) end
  return name
end

local function current_main()
  local main = M.main(M.current_file())
  if not main then notify("LaTeX: no document here - a .tex file with \\documentclass, or a main.tex above it", WARN) end
  return main
end

--- Build the document of the current file once (saved first).
function M.build()
  local main = current_main()
  if not main then return end
  vim.cmd("silent! update")
  notify("LaTeX: building " .. vim.fn.fnamemodify(main, ":t"))
  return start(main, false)
end

--- Watch: latexmk -pvc builds the document again whenever one of its files changes (toggle). Each round's errors
--- replace the last round's; after the first round the preview starts (M.start_preview).
function M.toggle_watch()
  if M.state.job then
    local main = M.state.main
    M.stop()
    notify("LaTeX: watch of " .. vim.fn.fnamemodify(main, ":t") .. " stopped")
    return
  end
  local main = current_main()
  if not main then return end
  vim.cmd("silent! update")
  notify("LaTeX: watching " .. vim.fn.fnamemodify(main, ":t") .. " - building on every save")
  return start(main, true)
end

--- Stop the watch and its preview (Neovim ends the job's process group: latexmk and the pdflatex it runs).
function M.stop()
  stop_preview()
  if M.state.job then vim.fn.jobstop(M.state.job) end
  M.state.job, M.state.main = nil, nil
end

--- The last round's errors in the quickfix window.
function M.show_errors()
  if #M.state.items == 0 then return notify("LaTeX: no errors in the last build") end
  vim.fn.setqflist({}, " ", { title = "LaTeX", items = M.state.items })
  vim.cmd("botright copen")
end

return M
