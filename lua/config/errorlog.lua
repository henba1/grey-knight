-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Error log: the warnings and errors of every session on     ║
-- ║  disk - ~/.local/state/nvim/greyknight.log                  ║
-- ║  <leader>ue opens it; readable over SSH after a crash too   ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

M.path = vim.fn.stdpath("state") .. "/greyknight.log"
local MAX_BYTES = 512 * 1024 -- trimmed to the last KEEP_LINES lines at startup when bigger
local KEEP_LINES = 2000
local NAMES = { [vim.log.levels.WARN] = "WARN", [vim.log.levels.ERROR] = "ERROR" }

local session_started = false

-- Warnings that tell what was done on purpose, not that something went wrong: shown, not logged. Each big file opened
-- put snacks' "Big file detected" into the log, between the errors it is there for (2026-10-22).
M.HARMLESS = {
  { title = "Big File", text = "Big file detected" },
}
local function harmless(title, msg)
  for _, h in ipairs(M.HARMLESS) do
    if title == h.title and tostring(msg):find(h.text, 1, true) then return true end
  end
  return false
end

local function append(lines)
  -- plain io: works in fast event contexts too, where vim.fn is not allowed
  local file = io.open(M.path, "a")
  if not file then return end
  file:write(table.concat(lines, "\n"), "\n")
  file:close()
end

--- Log an entry; continuation lines of multi-line messages are indented.
function M.write(level, source, msg)
  local lines = vim.split(tostring(msg), "\n", { trimempty = true })
  if #lines == 0 then return end
  local stamp = os.date("%Y-%m-%d %H:%M:%S")
  local out = {}
  if not session_started then
    session_started = true
    out[1] = ("%s ----- session pid %d, cwd %s"):format(stamp, vim.fn.getpid(), vim.fn.getcwd())
  end
  out[#out + 1] = ("%s %-5s [%s] %s"):format(stamp, level, source, lines[1])
  for i = 2, #lines do out[#out + 1] = "      " .. lines[i] end
  append(out)
end

--- The errors in :messages output, each whole: { "Error in User Autocommands for ...\nLua callback: ...\n..." }.
--- Neovim 0.12 writes a callback's error as "vim.schedule callback: <error>" and an autocommand's under its header as
--- "Lua callback: <error>" with the traceback below: the first was not seen at all, the second kept only its header
--- (2026-10-22 - "Error in BufEnter Autocommands for "<buffer=25>":" and nothing else in the Kali log).
function M.parse_messages(output)
  local blocks, block = {}, {}
  local function flush()
    if #block > 0 then blocks[#blocks + 1] = table.concat(block, "\n") end
    block = {}
  end
  for _, line in ipairs(vim.split(output or "", "\n")) do
    local starts = line:match("^E%d+:") or line:match("^Error") or line:match("^%S+%.lua:%d+:")
      or line:match("^[%w%._]+ callback: ")
    local continues = #block > 0 and line ~= "" and (line:match("^%s") or line:match("^stack traceback")
      or line:match("^Lua callback: ") or line:match("^Lua function: ") or line:match("^line%s+%d+:")
      or block[#block]:match(":$")) -- after a header ("Error in ... Autocommands for ...:", "Error detected while ...:")
    if continues then
      block[#block + 1] = line
    elseif starts then
      flush()
      block[1] = line
    else
      flush()
    end
  end
  flush()
  return blocks
end

-- Lua errors of mappings, callbacks and autocommands only reach :messages - keep them when Neovim exits
function M.log_messages()
  local ok, result = pcall(vim.api.nvim_exec2, "messages", { output = true })
  if not ok or not result.output or result.output == "" then return end
  for _, block in ipairs(M.parse_messages(result.output)) do M.write("ERROR", "messages", block) end
end

function M.setup()
  local stat = vim.uv.fs_stat(M.path)
  if stat and stat.size > MAX_BYTES then
    local lines = vim.fn.readfile(M.path)
    vim.fn.writefile(vim.list_slice(lines, math.max(1, #lines - KEEP_LINES + 1)), M.path)
  end

  -- Wrap vim.notify. snacks' notifier installs a stub that replaces vim.notify with
  -- Snacks.notifier.notify on its first call: call that notifier directly, so nothing swaps this
  -- wrapper out. (Never adopt whatever vim.notify becomes later: a plugin that wraps vim.notify
  -- and calls the previous one would then call us back endlessly.)
  local inner = vim.notify
  local snacks = rawget(_G, "Snacks")
  local ok, enabled = pcall(function() return snacks.config.notifier.enabled end)
  if snacks and ok and enabled then
    inner = function(msg, level, opts) return snacks.notifier.notify(msg, level, opts) end
  end
  vim.notify = function(msg, level, opts)
    local title = type(opts) == "table" and opts.title or "notify"
    if level and level >= vim.log.levels.WARN and not harmless(title, msg) then
      pcall(M.write, NAMES[level] or "ERROR", title, msg)
    end
    return inner(msg, level, opts)
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("greyknight_errorlog", { clear = true }),
    callback = function() M.log_messages() end,
  })
end

--- Open the log at its end.
function M.open()
  if vim.fn.filereadable(M.path) == 0 then
    return vim.notify("No warnings or errors logged yet (" .. M.path .. ")", vim.log.levels.INFO)
  end
  vim.cmd.split({ args = { M.path }, mods = { split = "botright" }, magic = { file = false } }) -- the path as it is
  vim.bo.readonly = true
  vim.bo.bufhidden = "wipe"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, desc = "Close error log" })
  vim.cmd("normal! G")
end

return M
