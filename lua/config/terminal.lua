-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Terminal mode: a shell in the agent's pane. Alt+T (the      ║
-- ║  settings' terminal.key) flips the pane between the agent    ║
-- ║  and the shell - in the code, the agent and the shell alike; ║
-- ║  the layout stays. No pane open: the shell opens as one, on  ║
-- ║  the right. The shell is a tab on the pane's bar, by the     ║
-- ║  agent's sessions; it keeps running while the agent shows.   ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

-- toggleterm's id of the shell (1, 11-13, 21+: the agent's sessions; 2: <leader>ts; 91/92: the REPLs)
M.ID = 31

--- The keys that flip the pane: the agent's window lets them through (integrations/agent.lua, own_keys) - keys of the
--- terminal, as notation
M.keys = {}

local function running(term)
  return term ~= nil and term.job_id ~= nil and vim.fn.jobwait({ term.job_id }, 0)[1] == -1
end

local function agent() return require("integrations.agent") end

-- The shell's terminal, kept here: toggleterm forgets a terminal the moment its program ends (TermClose), and the
-- pane still shows it until M.exited has put the agent back
local shell

--- The shell's terminal while it runs (create: a new one when none does - not yet started, no window)
function M.term(create)
  local T = require("toggleterm.terminal")
  local term = shell or T.get(M.ID, true)
  if running(term) then return term end
  if not create then return nil end
  if term then pcall(term.shutdown, term) end
  local cmd = require("config.settings").get("terminal.shell")
  term = T.Terminal:new({
    id = M.ID,
    cmd = cmd,
    hidden = true, -- not one of :ToggleTerm's
    display_name = "Terminal",
    direction = "vertical",
    close_on_exit = false, -- M.exited below: the pane goes back to the agent instead of closing
    on_exit = function(t) vim.schedule(function() M.exited(t) end) end,
  })
  term.gk_shell = true
  shell = term
  return term
end

--- The shell's terminal, also once its program has ended (its transcript may still be on the screen)
function M.current() return shell end

--- Whether `buf` is the shell's
function M.is_shell(buf)
  return shell ~= nil and shell.bufnr ~= nil and shell.bufnr == buf
end

local function width()
  local w = require("config.settings").get("landing.right_width") or 0.4
  return math.max(20, math.floor(w < 1 and vim.o.columns * w or w))
end

local function decorate(win) pcall(function() require("integrations.agent_sessions").decorate(win) end) end

--- The shell in the agent's pane - in place of the session it shows; without a pane on the right, as one
function M.show()
  local term = M.term(true)
  local pane, shown = agent().pane()
  if pane and shown and shown.shell then
    vim.api.nvim_set_current_win(pane)
  elseif pane then
    if not (term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) and term.job_id) then term:spawn() end
    vim.api.nvim_win_set_buf(pane, term.bufnr)
    vim.api.nvim_set_current_win(pane)
    term.window, term.direction = pane, "vertical"
  else
    term:open(width(), "vertical")
  end
  decorate(term.window)
  vim.cmd("startinsert!")
end

--- The pane back to the agent (the session it showed); none running: the shell's window closes
function M.back()
  local term = M.term(false)
  local list = agent().running()
  if #list > 0 then return agent().switch(agent().current()) end
  if term and term.window and vim.api.nvim_win_is_valid(term.window) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    pcall(vim.api.nvim_win_close, term.window, false)
  end
end

--- Alt+T: in the shell back to the agent; elsewhere the shell - where the pane shows it, that window
function M.toggle()
  if M.is_shell(vim.api.nvim_get_current_buf()) then return M.back() end
  M.show()
end

--- The shell ended (exit, Ctrl+D): the pane back to the agent - a new shell with the next Alt+T
function M.exited(term)
  local win = term.window
  local shown = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == term.bufnr
  if shown and #agent().running() > 0 then agent().switch(agent().current()) end
  pcall(term.shutdown, term)
  if shell == term then shell = nil end
end

--- End the shell; shown in the pane, the pane goes back to the agent (none running: it closes)
function M.stop()
  local term = shell
  if not term then return end
  local win = term.window
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == term.bufnr and #agent().running() > 0 then
    agent().switch(agent().current())
  end
  pcall(term.shutdown, term)
  shell = nil
end

--- The shell's tab on the pane's bar (integrations/agent_sessions.lua): running, and whether it is the one `buf` shows
function M.tab(buf)
  local term = M.term(false)
  if not term then return nil end
  return { active = term.bufnr == buf }
end

_G.GkPaneShell = function() vim.schedule(M.show) end

--- The key of the settings (terminal.key), in the code, typing and terminals
function M.setup()
  local key = require("config.settings").get("terminal.key")
  if key then
    M.keys[#M.keys + 1] = key
    vim.keymap.set({ "n", "i", "t" }, key, M.toggle, { desc = "Terminal: the shell in the agent's pane (again: the agent)" })
  end
  vim.api.nvim_create_user_command("GreyKnightTerminal", function() M.toggle() end,
    { desc = "Terminal: the shell in the agent's pane (again: the agent)" })
end

return M
