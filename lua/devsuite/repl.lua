-- ╔══════════════════════════════════════════════════════════════╗
-- ║  REPL next to the code: IPython / Python, or the shell      ║
-- ║  Python code arrives as one bracketed paste: blank lines in ║
-- ║  blocks are fine, and input() waits for you instead of      ║
-- ║  swallowing the next line of the snippet                    ║
-- ╚══════════════════════════════════════════════════════════════╝
local util = require("devsuite.util")
local M = {}

local WARN = vim.log.levels.WARN
-- toggleterm ids (1 = Qwen agent, 2 = <leader>ts/tl shell, 11-13 = extra agents)
M.IDS = { python = 91, shell = 92 }
local SHELLS = { sh = true, bash = true, zsh = true }

local function kind(ft)
  if ft == "python" then return "python" end
  if SHELLS[ft] then return "shell" end
end

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "REPL" }) end

local function running(term)
  return term ~= nil and term.job_id ~= nil and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
end

--- REPL command and flavor: IPython (from the project's virtualenv if it has one), else that venv's /
--- the system python3 (3.13+ takes bracketed paste); the shell for shell scripts.
---@return string cmd
---@return "ipython"|"python"|"shell" flavor
function M.command(k, path)
  if k == "shell" then return vim.o.shell, "shell" end
  local flags = " --no-autoindent --no-confirm-exit --no-banner"
  local venv = util.find_venv(path)
  if venv then
    if vim.fn.executable(venv .. "/bin/ipython") == 1 then return vim.fn.shellescape(venv .. "/bin/ipython") .. flags, "ipython" end
    return vim.fn.shellescape(venv .. "/bin/python"), "python"
  end
  for _, exe in ipairs({ "ipython3", "ipython" }) do
    if vim.fn.executable(exe) == 1 then return exe .. flags, "ipython" end
  end
  return "python3", "python"
end

-- The REPL terminal of a kind; a new one (not open yet) when there is none or its process ended
local function terminal(k, path)
  local T = require("toggleterm.terminal")
  local term = T.get(M.IDS[k], true)
  if running(term) then return term, false end
  if term then pcall(term.shutdown, term) end
  local cmd, flavor = M.command(k, path)
  term = T.Terminal:new({
    id = M.IDS[k],
    cmd = cmd,
    direction = "vertical",
    display_name = "REPL " .. k,
    hidden = true, -- not part of :ToggleTerm
    close_on_exit = true,
  })
  term.repl_flavor = flavor
  return term, true
end

local function width() return math.floor(vim.o.columns * 0.4) end

--- Show or hide the REPL of the current buffer's language.
function M.toggle()
  local k = kind(vim.bo.filetype)
  if not k then return notify("REPL: for Python and shell buffers", WARN) end
  local term = terminal(k, vim.api.nvim_buf_get_name(0))
  if term:is_open() then
    term:close()
  else
    term:open(width())
    vim.schedule(function() vim.cmd("startinsert") end)
  end
end

local COMPOUND = { "if", "elif", "else", "for", "while", "try", "except", "finally", "with", "def", "class", "async", "match", "case" }

-- Does the code end inside a block (indented last line, or a one-line "for x in y: f(x)")?
local function block_open(lines)
  local last, top
  for i = #lines, 1, -1 do
    if lines[i]:find("%S") then
      last = last or lines[i]
      if not lines[i]:match("^%s") then
        top = lines[i]
        break
      end
    end
  end
  if not last then return false end
  if last:match("^%s") then return true end
  local word = top:match("^([%a_]+)")
  return word ~= nil and vim.tbl_contains(COMPOUND, word) and top:find(":", 1, true) ~= nil and not top:match("^[%a_]+%s*=")
end

--- What to type into the REPL for these lines. Python gets one bracketed paste, then Enter:
--- IPython runs complete code on the first Enter (a second one would answer the next input());
--- the Python 3.13 REPL wants an empty line after more than one line, both after an open block.
function M.payload(flavor, lines)
  if flavor == "shell" then return table.concat(lines, "\n") .. "\n" end
  local code = vim.tbl_filter(function(line) return line:find("%S") ~= nil end, lines)
  local second = block_open(lines) or (flavor == "python" and #code > 1)
  return "\27[200~" .. table.concat(lines, "\n") .. "\27[201~" .. (second and "\r\r" or "\r")
end

-- Calls `done` once the REPL shows its prompt (after 10 s at the latest)
local function when_ready(term, k, done)
  local prompts = k == "python" and { "In %[%d+%]:%s*$", "^>>>%s*$" } or { "[%$#>%%]%s*$" }
  local deadline = vim.uv.now() + 10000
  local function poll()
    if not (term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)) then return end
    local lines = vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false)
    for i = #lines, 1, -1 do
      if lines[i]:find("%S") then
        for _, prompt in ipairs(prompts) do
          if lines[i]:match(prompt) then return done() end
        end
        break
      end
    end
    if vim.uv.now() >= deadline then return done() end
    vim.defer_fn(poll, 100)
  end
  poll()
end

--- Send lines to the REPL of the buffer's language (started and shown when needed); the cursor stays in the code.
function M.send(lines, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local k = kind(vim.bo[bufnr].filetype)
  if not k then return notify("REPL: for Python and shell buffers", WARN) end
  lines = util.dedent(lines)
  local term, new = terminal(k, vim.api.nvim_buf_get_name(bufnr))
  if not term:is_open() then
    local code = vim.api.nvim_get_current_win()
    term:open(width())
    if vim.api.nvim_win_is_valid(code) then vim.api.nvim_set_current_win(code) end
    -- toggleterm schedules startinsert for the terminal it opened: stay in normal mode in the code
    vim.schedule(function() vim.cmd("stopinsert") end)
  end
  local data = M.payload(term.repl_flavor or (k == "shell" and "shell" or "python"), lines)
  local function send()
    if running(term) then
      vim.fn.chansend(term.job_id, data)
      term:scroll_bottom()
    end
  end
  if new then when_ready(term, k, send) else send() end
end

function M.send_line() M.send({ vim.api.nvim_get_current_line() }) end

function M.send_selection() M.send((util.visual_lines())) end

function M.send_cell()
  local first, _, lines = util.cell_range(0, vim.api.nvim_win_get_cursor(0)[1])
  if not first then return notify("REPL: no '# %%' cells in this file", WARN) end
  M.send(lines)
end

return M
