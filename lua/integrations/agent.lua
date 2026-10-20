-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Coding agent in toggleterm: Qwen Code or OpenCode          ║
-- ║  Per machine: $GREYKNIGHT_AGENT = qwen | opencode; unset =  ║
-- ║  Qwen Code where it is installed, else OpenCode.            ║
-- ║  A new agent gets its first prompt on start (qwen -i) or    ║
-- ║  pasted once its TUI is up (opencode); a running one gets   ║
-- ║  it as one bracketed paste + Enter (multi-line safe).       ║
-- ║  Ask/edit capture file + selection before the agent window  ║
-- ║  opens and reference the file as @path (both CLIs read it). ║
-- ╚══════════════════════════════════════════════════════════════╝
local util = require("devsuite.util")
local M = {}

-- toggleterm ids: 1 = main agent, 11-13 = agents #1-#3 with their own sessions
-- (2 = the shell of <leader>ts/tl, 91/92 = REPLs)
M.AGENTS = { agent = 1, agent1 = 11, agent2 = 12, agent3 = 13 }

-- ms between a new OpenCode TUI's first output and the paste of the first prompt (it sets up its input)
M.READY_DELAY = 1500

local function executable(path) return path ~= nil and path ~= "" and vim.fn.executable(path) == 1 end

M.BACKENDS = {
  qwen = {
    name = "Qwen Code",
    short = "Qwen",
    --- $QWEN_BIN, ~/.local/bin/qwen (the current release), else qwen on the PATH
    -- (one check after the other: in a list, an unset $QWEN_BIN is nil and ipairs stopped before ~/.local/bin)
    bin = function()
      if executable(vim.env.QWEN_BIN) then return vim.env.QWEN_BIN end
      local own = vim.fn.expand("~/.local/bin/qwen")
      if executable(own) then return own end
      return "qwen"
    end,
    first_prompt = "-i", -- a new agent takes its first prompt as an argument
    new_session = "/clear",
  },
  opencode = {
    name = "OpenCode",
    short = "OpenCode",
    --- $OPENCODE_BIN, else opencode on the PATH
    bin = function() return executable(vim.env.OPENCODE_BIN) and vim.env.OPENCODE_BIN or "opencode" end,
    first_prompt = nil, -- pasted once the TUI is up: multi-line prompts survive every shell, cmd.exe too
    new_session = "/new",
  },
}

--- The agent of this machine: $GREYKNIGHT_AGENT (or vim.g.greyknight_agent), else Qwen Code where it is
--- installed, else OpenCode where that is - kali and the pi keep Qwen Code without any setting.
function M.backend_id()
  local wanted = vim.g.greyknight_agent or vim.env.GREYKNIGHT_AGENT
  if wanted and wanted ~= "" then
    if M.BACKENDS[wanted] then return wanted end
    vim.notify_once(("GREYKNIGHT_AGENT=%s is not an agent (qwen, opencode) - choosing by what is installed"):format(wanted),
      vim.log.levels.WARN)
  end
  if executable(M.BACKENDS.qwen.bin()) then return "qwen" end
  if executable(M.BACKENDS.opencode.bin()) then return "opencode" end
  return "qwen"
end

function M.backend() return M.BACKENDS[M.backend_id()] end

--- The agent's binary.
function M.bin() return M.backend().bin() end

local function running(term)
  return term ~= nil and term.job_id ~= nil and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
end

local function size(direction)
  if direction == "vertical" then return math.floor(vim.o.columns / 2) end
  if direction == "horizontal" then return 15 end
end

-- The agent's terminal, and whether its process is new. A process starts when there is none
-- (or it exited); `first_prompt` goes to that new process as an argument when the CLI takes one.
--- The command line that starts the agent. The binary by its full path: cmd.exe gives a quoted .cmd it found on
--- the PATH the current directory as its own folder (%~dp0), so on Windows opencode.cmd did not find its launcher.
function M.command(first_prompt)
  local backend = M.backend()
  local bin = backend.bin()
  local cmd = vim.fn.shellescape(vim.fn.exepath(bin) ~= "" and vim.fn.exepath(bin) or bin)
  if first_prompt and backend.first_prompt then
    cmd = cmd .. " " .. backend.first_prompt .. " " .. vim.fn.shellescape(first_prompt)
  end
  return cmd
end

local function agent(name, direction, first_prompt)
  local T = require("toggleterm.terminal")
  local backend = M.backend()
  local id = M.AGENTS[name] or M.AGENTS.agent
  local term = T.get(id, true)
  if running(term) then
    if term.gk_agent then return term, false end
    vim.notify(("%s: terminal %d is not an agent - close it first"):format(backend.short, id), vim.log.levels.WARN)
    return nil
  end
  if term then pcall(term.shutdown, term) end
  term = T.Terminal:new({
    id = id,
    cmd = M.command(first_prompt),
    direction = direction,
    display_name = name == "agent" and backend.name or (backend.name .. " #" .. name:sub(-1)),
    close_on_exit = false, -- keep the transcript when the CLI exits
  })
  term.gk_agent = true
  return term, true
end

-- ── Its window takes keys (2026-10-20) ─────────────────────────────────────
-- Going to the agent's window (<C-l>, a click, <leader>tt) means typing there: insert (terminal) mode. Before,
-- <C-h> left the window in normal mode (<C-\><C-n> first) and toggleterm brought that mode back on the way in
-- (persist_mode), so every return started with i. Not when the agent has exited: a key would close its
-- transcript. <Esc><Esc> still gives normal mode inside the window (scroll, copy).

--- Marks a buffer as an agent's terminal (show() does it for every agent window).
function M.mark(buf) vim.b[buf].greyknight_agent = true end

local function job_running(buf)
  local job = vim.b[buf].terminal_job_id
  return job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("greyknight.agent_insert", { clear = true }),
  pattern = "term://*",
  callback = function(ev)
    if not vim.b[ev.buf].greyknight_agent then return end
    -- scheduled twice: after toggleterm's restore of the old mode, which it schedules once from its own BufEnter
    vim.schedule(function()
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == ev.buf and job_running(ev.buf) and vim.api.nvim_get_mode().mode:sub(1, 1) == "n" then
          vim.cmd("startinsert")
        end
      end)
    end)
  end,
})

local function show(term, direction)
  direction = direction or term.direction
  if term:is_open() and term.direction ~= direction then term:close() end
  if term:is_open() then
    term:focus()
  else
    term:open(size(direction), direction)
  end
  if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then M.mark(term.bufnr) end
  vim.cmd("startinsert!")
end

-- One bracketed paste, then Enter as a keypress of its own once the TUI has taken the paste
local function submit(term, text)
  vim.fn.chansend(term.job_id, "\27[200~" .. text .. "\27[201~")
  vim.defer_fn(function()
    if running(term) then vim.fn.chansend(term.job_id, "\r") end
  end, 150)
end

-- fn() once a new agent's TUI has drawn something, plus READY_DELAY for it to set up its input
local function when_ready(term, fn)
  local waited = 0
  local function poll()
    if not running(term) then return end
    local lines = vim.api.nvim_buf_is_valid(term.bufnr) and vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false) or {}
    for _, line in ipairs(lines) do
      if vim.trim(line) ~= "" then
        return vim.defer_fn(function() if running(term) then fn() end end, M.READY_DELAY)
      end
    end
    waited = waited + 200
    if waited >= 30000 then
      return vim.notify(M.backend().short .. ": the agent did not start within 30 s", vim.log.levels.WARN)
    end
    vim.defer_fn(poll, 200)
  end
  vim.defer_fn(poll, 200)
end

--- What a prompt needs from the editor; call it before any window changes.
function M.context()
  local file = vim.api.nvim_buf_get_name(0)
  local ctx = { ft = vim.bo.filetype, rel = file ~= "" and vim.fn.fnamemodify(file, ":.") or nil }
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local lines, first, last = util.visual_lines()
    ctx.sel = { text = table.concat(lines, "\n"), first = first, last = last }
  end
  return ctx
end

--- Prompt for an "ask" or "edit" request. @path makes the agent read the file itself.
function M.prompt(kind, ctx, request)
  local ref = "the current buffer"
  if ctx.rel then
    local escaped = ctx.rel:gsub(" ", "\\ ")
    ref = "@" .. escaped
  end
  local block = ctx.sel and ("lines %d-%d:\n```%s\n%s\n```"):format(ctx.sel.first, ctx.sel.last, ctx.ft or "", ctx.sel.text)
  if kind == "edit" then
    return ("Edit %s, %s\n\nInstruction: %s\n\nChange only these lines unless the instruction needs more, then stop.")
      :format(ref, block, request)
  end
  if block then
    return ("In %s, %s\n\n%s\n\nAnswer only - do not modify any files."):format(ref, block, request)
  end
  return ("%s\n\n%s\n\nAnswer only - do not modify any files."):format(ref, request)
end

--- Send a prompt to an agent (default: the main one, vertical split).
function M.send(text, name, direction)
  direction = direction or "vertical"
  local term, new = agent(name or "agent", direction, text)
  if not term then return end
  show(term, direction)
  if not new then return submit(term, text) end
  if not M.backend().first_prompt then when_ready(term, function() submit(term, text) end) end
end

--- Ask about the file or the selection (read-only); asks for the question first.
function M.ask()
  local ctx = M.context()
  local who = M.backend().short
  local prompt = ctx.sel and ("Ask %s about the selection: "):format(who) or ("Ask %s about this file: "):format(who)
  vim.ui.input({ prompt = prompt }, function(request)
    if request == nil then return end
    if vim.trim(request) == "" then request = ctx.sel and "Explain this code." or "Explain what this file does." end
    M.send(M.prompt("ask", ctx, request))
  end)
end

--- Let the agent change the selected lines; asks for the instruction first.
function M.edit()
  local ctx = M.context()
  local who = M.backend().short
  if not ctx.sel then return vim.notify(who .. ": select the lines to edit first", vim.log.levels.WARN) end
  vim.ui.input({ prompt = who .. ", change the selection: " }, function(request)
    if request == nil or vim.trim(request) == "" then return end
    M.send(M.prompt("edit", ctx, request))
  end)
end

--- Fresh conversation in the main agent (/clear for Qwen Code, /new for OpenCode), or a new agent.
function M.new_session()
  local term, new = agent("agent", "vertical")
  if not term then return end
  show(term, "vertical")
  if not new then
    vim.fn.chansend(term.job_id, M.backend().new_session)
    vim.defer_fn(function()
      if running(term) then vim.fn.chansend(term.job_id, "\r") end
    end, 150)
  end
end

--- Base URL of Qwen Code's model server: $QWEN_BASE_URL, else the default model of ~/.qwen/settings.json.
function M.base_url()
  if vim.env.QWEN_BASE_URL and vim.env.QWEN_BASE_URL ~= "" then return vim.env.QWEN_BASE_URL end
  local ok, settings = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(vim.fn.expand("~/.qwen/settings.json")), "\n"))
  end)
  local url = ok and type(settings) == "table" and type(settings.model) == "table" and settings.model.baseUrl
  return url or "http://192.168.2.173:8000/v1"
end

--- Which model the server runs right now (llama-server /props): name and context size.
--- Several launchers share the port, so this is how you know who Qwen Code talks to.
--- OpenCode picks its model itself (/models in the agent).
function M.model_info(done)
  if M.backend_id() ~= "qwen" then
    local msg = M.backend().name .. " picks its model itself: /models in the agent shows and switches it"
    vim.notify(msg, vim.log.levels.INFO, { title = M.backend().short })
    if done then done(msg) end
    return
  end
  local url = M.base_url():gsub("/v1/?$", "") .. "/props"
  vim.system({ "curl", "-s", "--max-time", "3", url }, { text = true }, function(res)
    vim.schedule(function()
      local ok, props = pcall(vim.json.decode, res.stdout or "")
      local msg, level
      if res.code ~= 0 or not ok or type(props) ~= "table" or not props.model_path then
        msg, level = ("No model is running at %s - start a launcher on the AI Dashboard (Models)"):format(url), vim.log.levels.WARN
      else
        local settings = type(props.default_generation_settings) == "table" and props.default_generation_settings or {}
        msg = ("Model: %s\nContext: %s tokens"):format(vim.fn.fnamemodify(props.model_path, ":t:r"), tostring(settings.n_ctx or "?"))
        level = vim.log.levels.INFO
      end
      vim.notify(msg, level, { title = "Qwen" })
      if done then done(msg) end
    end)
  end)
end

--- Open (or focus) an agent.
function M.launch(name, direction)
  local term = agent(name or "agent", direction)
  if term then show(term, direction) end
end

--- Open or hide an agent; its process keeps running while hidden.
function M.toggle(name, direction)
  local term = agent(name or "agent", direction)
  if not term then return end
  if term:is_open() then
    term:close()
  else
    show(term, direction)
  end
end

return M
