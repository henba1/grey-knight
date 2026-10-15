-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Qwen Code agent: the local Qwen Code CLI in toggleterm     ║
-- ║  A new agent gets its first prompt with `qwen -i`; a running ║
-- ║  one gets it as one bracketed paste + Enter (multi-line     ║
-- ║  safe). Ask/edit capture file + selection before the agent  ║
-- ║  window opens and reference the file as @path.              ║
-- ╚══════════════════════════════════════════════════════════════╝
local util = require("devsuite.util")
local M = {}

-- toggleterm ids: 1 = main agent, 11-13 = agents #1-#3 with their own sessions
-- (2 = the shell of <leader>ts/tl, 91/92 = REPLs)
M.AGENTS = { agent = 1, agent1 = 11, agent2 = 12, agent3 = 13 }

--- The Qwen Code binary: $QWEN_BIN, ~/.local/bin/qwen (the current release), else qwen on the PATH.
function M.bin()
  for _, candidate in ipairs({ vim.env.QWEN_BIN, vim.fn.expand("~/.local/bin/qwen") }) do
    if candidate and candidate ~= "" and vim.fn.executable(candidate) == 1 then return candidate end
  end
  return "qwen"
end

local function running(term)
  return term ~= nil and term.job_id ~= nil and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
end

local function size(direction)
  if direction == "vertical" then return math.floor(vim.o.columns / 2) end
  if direction == "horizontal" then return 15 end
end

-- The agent's terminal, and whether its process is new. A process starts when there is none
-- (or it exited); `first_prompt` goes to that new process with -i.
local function agent(name, direction, first_prompt)
  local T = require("toggleterm.terminal")
  local id = M.AGENTS[name] or M.AGENTS.agent
  local term = T.get(id, true)
  if running(term) then
    if term.qwen_agent or (term.cmd or ""):find("qwen", 1, true) then return term, false end
    vim.notify(("Qwen: terminal %d is not an agent - close it first"):format(id), vim.log.levels.WARN)
    return nil
  end
  if term then pcall(term.shutdown, term) end
  local cmd = vim.fn.shellescape(M.bin())
  if first_prompt then cmd = cmd .. " -i " .. vim.fn.shellescape(first_prompt) end
  term = T.Terminal:new({
    id = id,
    cmd = cmd,
    direction = direction,
    display_name = name == "agent" and "Qwen Code" or ("Qwen Code #" .. name:sub(-1)),
    close_on_exit = false, -- keep the transcript when the CLI exits
  })
  term.qwen_agent = true
  return term, true
end

local function show(term, direction)
  direction = direction or term.direction
  if term:is_open() and term.direction ~= direction then term:close() end
  if term:is_open() then
    term:focus()
  else
    term:open(size(direction), direction)
  end
  vim.cmd("startinsert!")
end

-- One bracketed paste, then Enter as a keypress of its own once the TUI has taken the paste
local function submit(term, text)
  vim.fn.chansend(term.job_id, "\27[200~" .. text .. "\27[201~")
  vim.defer_fn(function()
    if running(term) then vim.fn.chansend(term.job_id, "\r") end
  end, 150)
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

--- Prompt for an "ask" or "edit" request. @path makes Qwen Code read the file itself.
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
  if not new then submit(term, text) end
end

--- Ask about the file or the selection (read-only); asks for the question first.
function M.ask()
  local ctx = M.context()
  local prompt = ctx.sel and "Ask Qwen about the selection: " or "Ask Qwen about this file: "
  vim.ui.input({ prompt = prompt }, function(request)
    if request == nil then return end
    if vim.trim(request) == "" then request = ctx.sel and "Explain this code." or "Explain what this file does." end
    M.send(M.prompt("ask", ctx, request))
  end)
end

--- Let the agent change the selected lines; asks for the instruction first.
function M.edit()
  local ctx = M.context()
  if not ctx.sel then return vim.notify("Qwen: select the lines to edit first", vim.log.levels.WARN) end
  vim.ui.input({ prompt = "Qwen, change the selection: " }, function(request)
    if request == nil or vim.trim(request) == "" then return end
    M.send(M.prompt("edit", ctx, request))
  end)
end

--- Fresh conversation in the main agent (/clear), or a new agent.
function M.new_session()
  local term, new = agent("agent", "vertical")
  if not term then return end
  show(term, "vertical")
  if not new then
    vim.fn.chansend(term.job_id, "/clear")
    vim.defer_fn(function()
      if running(term) then vim.fn.chansend(term.job_id, "\r") end
    end, 150)
  end
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
