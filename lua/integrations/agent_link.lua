-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Agents reach into this Neovim. The MCP server they start    ║
-- ║  (agent_server.lua, run by nvim -l) relays to here:          ║
-- ║  - every agent gets the editor's tools (agent_tools.lua):    ║
-- ║    show in the file tree, open at a line, LSP, diagnostics;  ║
-- ║  - Qwen Code also its IDE mode (agent_ide.lua): its edits as ║
-- ║    diffs to accept or reject, the open files as context.     ║
-- ║  Only agents started here: their terminals get the settings  ║
-- ║  in their environment - the agents' own settings files stay  ║
-- ║  as they are (Qwen Code: system defaults, the lowest level;  ║
-- ║  OpenCode: inline config; Claude Code: --mcp-config and      ║
-- ║  --settings, next to its own).                               ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local WIN = vim.fn.has("win32") == 1
M.IDE_INFO = { name = "neovim", displayName = "Neovim (GreyKnight)" }

--- The agents' servers attached now: channel -> { role = "tools" | "ide", pid = n }
M.clients = {}

-- ── The server agents start ────────────────────────────────────

--- agent_server.lua, the script agents run with nvim -l
function M.script()
  return vim.api.nvim_get_runtime_file("lua/integrations/agent_server.lua", false)[1]
end

--- Where this Neovim listens (its RPC socket or named pipe) - the server connects there
function M.address()
  if vim.v.servername == "" then vim.fn.serverstart() end
  return vim.v.servername
end

--- The command line of the server: nvim -l agent_server.lua <role> <address>
function M.server_command(role)
  return { vim.v.progpath, "-l", M.script(), role, M.address() }
end

--- The command of an agent's hook: it says the agent is done ("stop") or waits for the user ("permission")
function M.hook_command(event)
  local cmd = M.server_command("hook")
  cmd[#cmd + 1] = event
  return cmd
end

local function module(role)
  return require(role == "ide" and "integrations.agent_ide" or "integrations.agent_tools")
end

-- ── Calls from the server (agent_server.lua: nvim_exec_lua) ────

function M.instructions(role) return module(role).INSTRUCTIONS or "" end

function M.tools(role) return module(role).definitions() end

function M.attach(chan, role, pid)
  M.clients[chan] = { role = role, pid = pid }
  M.track()
end

function M.ready(chan, role)
  local mod = module(role)
  if mod.ready then mod.ready(chan) end
end

--- An agent's hook (agent_server.lua, role "hook"): before / after an edit - its review in the buffer
--- (agent_review.lua); done or waiting - a word unless the user looks at that agent
function M.hook(event, agent_id, payload)
  if event == "before" or event == "after" then
    return require("integrations.agent_review").hook(event, tonumber(agent_id), payload)
  end
  require("integrations.agent").attention(event, tonumber(agent_id), payload)
end

function M.detach(chan)
  local client = M.clients[chan]
  M.clients[chan] = nil
  if client then
    local mod = module(client.role)
    if mod.detached then mod.detached(chan) end
  end
end

--- The servers still there: one that ended without its detach coming through (its last message went with its
--- channel - Neovim waiting in jobwait() meanwhile, 2026-10-22, Windows) is dropped. Returns the channels.
function M.attached(role)
  local list = {}
  for chan, c in pairs(M.clients) do
    if next(vim.api.nvim_get_chan_info(chan)) == nil then
      M.detach(chan)
    elseif not role or c.role == role then
      list[#list + 1] = chan
    end
  end
  return list
end

--- Whether a server of this role is attached
function M.has(role) return #M.attached(role) > 0 end

--- To the server on `chan`: "reply" { id, result } or "notify" { method, params }. A server that is gone is dropped.
function M.send(chan, kind, payload)
  if not pcall(vim.rpcnotify, chan, "nvim_exec_lua", "return _G.gk_link(...)", { kind, payload }) then M.detach(chan) end
end

--- A notification to every server of `role`
function M.notify(role, method, params)
  for _, chan in ipairs(M.attached(role)) do M.send(chan, "notify", { method = method, params = params }) end
end

--- A text result of a tool call (MCP's CallToolResult)
function M.result(text, is_error)
  return { content = { { type = "text", text = text } }, isError = is_error or false }
end

--- A tool call: the tool answers when it is done; an error in it is the agent's to read, not a Neovim error
function M.call(chan, role, id, name, args)
  local answered = false
  local function reply(result)
    if answered then return end
    answered = true
    M.send(chan, "reply", { id = id, result = result })
  end
  local ok, err = pcall(module(role).call, name, args or {}, reply, chan)
  if not ok then reply(M.result("GreyKnight: " .. tostring(err), true)) end
end

-- ── What the user has open (both roles: editor_state, Qwen's context) ──

local entered = {} -- buffer -> when it was last entered (ms)
local selection -- the last visual selection: { buf, text, cursor } - kept while the cursor stays where it ended
local tracking = false

-- Milliseconds since 1970, as Neovim's own lastused (seconds) times 1000: one order for both
local function now_ms()
  local sec, usec = vim.uv.gettimeofday()
  return sec * 1000 + math.floor(usec / 1000)
end

--- A buffer of a file on disk (not a terminal, a picker, a diff of agent_ide.lua)
function M.is_file(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and not name:match("^%a[%w+.-]+://") and vim.fn.filereadable(name) == 1
end

local function changed()
  local ok, ide = pcall(require, "integrations.agent_ide")
  if ok then ide.context_changed() end
end

--- Follow what the user does: the file entered last, the selection. From the first agent server on.
function M.track()
  if tracking then return end
  tracking = true
  local group = vim.api.nvim_create_augroup("greyknight_agent_link", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(ev)
      if M.is_file(ev.buf) then
        entered[ev.buf] = now_ms()
        changed()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      if entered[ev.buf] then
        entered[ev.buf] = nil
        if selection and selection.buf == ev.buf then selection = nil end
        changed()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      if not M.is_file(ev.buf) then return end
      local mode = vim.fn.mode()
      if mode == "v" or mode == "V" or mode == "\22" then
        local text = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
        selection = { buf = ev.buf, text = text }
      elseif selection and selection.buf == ev.buf and selection.cursor then
        local pos = vim.api.nvim_win_get_cursor(0)
        if pos[1] ~= selection.cursor[1] or pos[2] ~= selection.cursor[2] then selection = nil end
      end
      changed()
    end,
  })
  -- leaving visual mode: the selection (its marks are set now) stays the context while the cursor stays there - the
  -- user went to the agent with it
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "[vV\22]*:*",
    callback = function(ev)
      if not M.is_file(ev.buf) then return end
      local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
      if ok and #region > 0 then
        selection = { buf = ev.buf, text = table.concat(region, "\n"), cursor = vim.api.nvim_win_get_cursor(0) }
      end
      changed()
    end,
  })
  entered[vim.api.nvim_get_current_buf()] = M.is_file(vim.api.nvim_get_current_buf()) and now_ms() or nil
end

--- The files open in buffers, the one entered last first: { buf, path, time } (at most `max`)
function M.recent_files(max)
  local list = {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if M.is_file(info.bufnr) then
      -- not entered since the tracking began: when Neovim last used it (seconds)
      local time = entered[info.bufnr] or (info.lastused * 1000)
      list[#list + 1] = { buf = info.bufnr, path = vim.fn.fnamemodify(info.name, ":p"), time = time }
    end
  end
  table.sort(list, function(a, b) return a.time > b.time end)
  while max and #list > max do table.remove(list) end
  return list
end

--- The window with code in it: the current one if it shows a file, else the one used last of the tab
function M.code_window()
  local function usable(win)
    return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
  end
  local cur = vim.api.nvim_get_current_win()
  if usable(cur) then return cur end
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and usable(prev) then return prev end
  local best, best_time
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if usable(win) then
      local time = entered[vim.api.nvim_win_get_buf(win)] or 0
      if not best or time > best_time then best, best_time = win, time end
    end
  end
  return best
end

--- The file the user works in: the code window's, or the file entered last
function M.active()
  local win = M.code_window()
  if win and M.is_file(vim.api.nvim_win_get_buf(win)) then
    local buf = vim.api.nvim_win_get_buf(win)
    return { buf = buf, win = win, path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p"), cursor = vim.api.nvim_win_get_cursor(win) }
  end
  local last = M.recent_files(1)[1]
  if last then return { buf = last.buf, path = last.path } end
end

--- The text selected in a file (also right after the user left visual mode for the agent), or nil
function M.selection(buf)
  if selection and selection.buf == buf and selection.text ~= "" then return selection.text end
end

-- ── Settings for the agents started here ───────────────────────

--- Qwen Code's own folder (~/.qwen, or $QWEN_HOME as Qwen Code takes it)
function M.qwen_home()
  local home = vim.env.QWEN_HOME
  if home and home ~= "" then return vim.fs.normalize(home) end
  return vim.fs.normalize(vim.uv.os_homedir() .. "/.qwen")
end

local lock -- this Neovim's lock file for Qwen Code: { n, path }
local dirs = {} -- the folders agents were started in: Qwen Code connects when it runs inside one of them

local function write_json(path, data)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(data) }, path)
end

--- The folders a Qwen Code started from here may run in (the working directory, where agents were started)
function M.workspaces()
  local list, seen = {}, {}
  for _, dir in ipairs(vim.list_extend({ vim.fn.getcwd(-1, -1) }, dirs)) do
    local key = WIN and dir:lower() or dir
    if not seen[key] then
      seen[key] = true
      list[#list + 1] = dir
    end
  end
  return table.concat(list, WIN and ";" or ":")
end

local function write_lock()
  if not lock then return end
  write_json(lock.path, {
    workspacePath = M.workspaces(),
    ideInfo = M.IDE_INFO,
    ideName = M.IDE_INFO.displayName,
    ppid = vim.uv.os_getpid(),
    -- no port: Qwen Code starts the server itself and talks to it over stdio (no web server in Neovim)
    stdio = { command = vim.v.progpath, args = vim.list_slice(M.server_command("ide"), 2) },
  })
end

--- Lock files of Neovims that are gone (they crashed): Qwen Code would try to start their servers
local function sweep(dir)
  for name, kind in vim.fs.dir(dir) do
    if kind == "file" and name:match("^%d+%.lock$") then
      local path = dir .. "/" .. name
      local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
      if ok and type(data) == "table" and type(data.ideInfo) == "table" and data.ideInfo.name == M.IDE_INFO.name
        and type(data.ppid) == "number" and data.ppid ~= vim.uv.os_getpid() and vim.uv.kill(data.ppid, 0) ~= 0 then
        os.remove(path)
      end
    end
  end
end

--- This Neovim's lock file in Qwen Code's ide folder (made once; gone when Neovim quits)
function M.lock_file()
  if lock then return lock end
  local dir = M.qwen_home() .. "/ide"
  vim.fn.mkdir(dir, "p")
  pcall(sweep, dir)
  local n = 20000 + vim.uv.os_getpid() % 40000
  for _ = 1, 1000 do
    if not vim.uv.fs_stat(("%s/%d.lock"):format(dir, n)) then break end
    n = n % 65535 + 1
  end
  lock = { n = n, path = ("%s/%d.lock"):format(dir, n) }
  write_lock()
  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("greyknight_agent_lock", { clear = true }),
    callback = function() write_lock() end,
  })
  return lock
end

local function private_dir() return vim.fn.fnamemodify(vim.fn.tempname(), ":h") end -- this Neovim's, gone when it quits

local function read_json_file(path)
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
  return ok and type(data) == "table" and data or nil
end

--- The hooks of a Qwen Code or Claude Code started here, after the user's own in `data.hooks`: done (Stop), waiting
--- for the user (PermissionRequest), its edits (`edit_tools`) before - the file as it is: the review compares with
--- it - and after (the buffer shows the change)
local function add_hooks(data, edit_tools)
  data.hooks = type(data.hooks) == "table" and data.hooks or {}
  local function add(event, what, matcher)
    local list = type(data.hooks[event]) == "table" and data.hooks[event] or {}
    local shell = table.concat(vim.tbl_map(function(a) return vim.fn.shellescape(a) end, M.hook_command(what)), " ")
    list[#list + 1] = { matcher = matcher, hooks = { { type = "command", command = shell } } }
    data.hooks[event] = list
  end
  add("Stop", "stop")
  add("PermissionRequest", "permission")
  add("PreToolUse", "before", edit_tools)
  add("PostToolUse", "after", edit_tools)
end

--- Settings for a Qwen Code started here (its "system defaults": its own settings files win). A system defaults file
--- of the user's ($QWEN_CODE_SYSTEM_DEFAULTS_PATH) stays: these go on top of a copy.
function M.qwen_settings()
  local own = vim.env.QWEN_CODE_SYSTEM_DEFAULTS_PATH
  local data = own and own ~= "" and read_json_file(own) or {}
  data.ide = type(data.ide) == "table" and data.ide or {}
  if data.ide.enabled == nil then data.ide.enabled = true end
  data.mcpServers = type(data.mcpServers) == "table" and data.mcpServers or {}
  local cmd = M.server_command("tools")
  data.mcpServers.greyknight = {
    command = cmd[1],
    args = vim.list_slice(cmd, 2),
    -- the tools show things in the editor and read what it knows; they change no file and run nothing
    trust = true,
    description = "GreyKnight: show files in the user's Neovim (file tree, editor, quickfix), its language servers",
  }
  -- done (Stop: after it answered) or waiting for the user (PermissionRequest: its question shows): a word in Neovim.
  -- Hooks of every settings level run, these after the user's own
  add_hooks(data, M.EDIT_TOOLS)
  return data
end

--- Qwen Code's tools that change files (its runtime ids)
M.EDIT_TOOLS = "^(edit|write_file|notebook_edit)$"

--- Claude Code's tools that change files
M.CLAUDE_EDIT_TOOLS = "^(Edit|MultiEdit|Write|NotebookEdit)$"

--- Settings for a Claude Code started here (--settings: on top of the user's own, whose hooks run as well): the
--- hooks as Qwen Code's - their JSON has the same tool_input.file_path - and its GreyKnight tools allowed without a
--- question each time (they show things in the editor and read what it knows; they change no file and run nothing)
function M.claude_settings()
  local data = { permissions = { allow = { "mcp__greyknight" } } }
  add_hooks(data, M.CLAUDE_EDIT_TOOLS)
  return data
end

--- Claude Code's MCP servers for one started here (--mcp-config: next to the user's own)
function M.claude_mcp()
  local cmd = M.server_command("tools")
  return { mcpServers = { greyknight = { type = "stdio", command = cmd[1], args = vim.list_slice(cmd, 2) } } }
end

--- OpenCode's word when it is done or waits for the user: a plugin of GreyKnight's, in a config folder of this
--- Neovim's own ($OPENCODE_CONFIG_DIR adds its plugins to the user's - a user's own folder there stays: no plugin then)
local PLUGIN = [==[
// GreyKnight: tells the Neovim that started this OpenCode when it is done or waits for an answer, and about its
// edits - before one (the file as it is: the review in Neovim compares with it) and after (the buffer shows it)
// (lua/integrations/agent_link.lua wrote this file into that Neovim's temp folder; it goes when Neovim quits)
import { spawn } from "node:child_process"
const COMMAND = %s
const EDITS = new Set(["edit", "write", "patch", "apply_patch", "multiedit"])
// The hook (nvim -l agent_server.lua hook ...) with its JSON on stdin - a pipe, not /dev/null (see agent_server.lua).
// Ends when the hook does, at most after 3 s: an edit never waits longer.
function tell(event, payload) {
  return new Promise((resolve) => {
    try {
      const timer = setTimeout(resolve, 3000)
      const done = () => { clearTimeout(timer); resolve() }
      const child = spawn(COMMAND[0], [...COMMAND.slice(1), event], { stdio: ["pipe", "ignore", "ignore"], windowsHide: true })
      child.on("error", done)
      child.on("exit", done)
      child.stdin.on("error", () => {})
      child.stdin.end(payload ? JSON.stringify(payload) : "")
    } catch (e) { resolve() }
  })
}
// The files of an edit: its filePath, or the paths of a patch (*** Add File: / Update File: / Delete File: / Move to:)
// (not exported: OpenCode calls every export of a plugin file as a plugin)
function files(args) {
  if (!args) return []
  if (typeof args.filePath === "string") return [args.filePath]
  const text = [args.patchText, args.patch, args.input].find((t) => typeof t === "string")
  if (!text) return []
  const out = []
  for (const m of text.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)) out.push(m[1].trim())
  return out
}
const pending = new Map() // callID -> its files, from before to after
export const GreyKnight = async ({ directory }) => ({
  event: async ({ event }) => {
    if (event.type === "session.idle") tell("stop")
    else if (event.type === "permission.asked" || event.type === "permission.updated") tell("permission")
    else if (event.type === "file.edited" && event.properties && typeof event.properties.file === "string") {
      tell("after", { files: [event.properties.file], cwd: directory })
    }
  },
  "tool.execute.before": async (input, output) => {
    if (!EDITS.has(input.tool)) return
    const list = files(output && output.args)
    if (list.length === 0) return
    pending.set(input.callID, list)
    await tell("before", { files: list, cwd: directory })
  },
  "tool.execute.after": async (input) => {
    const list = pending.get(input.callID)
    if (!list) return
    pending.delete(input.callID)
    await tell("after", { files: list, cwd: directory })
  },
})
]==]

function M.opencode_dir()
  local dir = private_dir() .. "/opencode"
  vim.fn.mkdir(dir .. "/plugins", "p")
  local cmd = M.server_command("hook")
  vim.fn.writefile(vim.split(PLUGIN:format(vim.json.encode(cmd)), "\n"), dir .. "/plugins/greyknight.js")
  return dir
end

--- OpenCode's inline config for one started here ($OPENCODE_CONFIG_CONTENT; one the user set stays, extended)
function M.opencode_config()
  local own = vim.env.OPENCODE_CONFIG_CONTENT
  local data = {}
  if own and own ~= "" then
    local ok, d = pcall(vim.json.decode, own)
    if ok and type(d) == "table" then data = d end
  end
  data.mcp = type(data.mcp) == "table" and data.mcp or {}
  data.mcp.greyknight = { type = "local", command = M.server_command("tools"), enabled = true }
  return vim.json.encode(data)
end

--- The environment of an agent's terminal: what connects it to this Neovim. `backend`: "qwen" | "opencode" |
--- "claude"; `dir`: where it starts; `id`: its terminal (the hooks name it). Only the backend's own: no ~/.qwen folder
--- on a machine with OpenCode only. Claude Code gets the rest as arguments (M.args).
function M.env(backend, dir, id)
  if dir and dir ~= "" then dirs[#dirs + 1] = vim.fn.fnamemodify(dir, ":p"):gsub("[/\\]$", "") end
  local env = { GREYKNIGHT_AGENT_ID = id and tostring(id) or nil }
  if backend == "claude" then return env end
  if backend == "opencode" then
    env.OPENCODE_CONFIG_CONTENT = M.opencode_config()
    local own = vim.env.OPENCODE_CONFIG_DIR
    if not own or own == "" then env.OPENCODE_CONFIG_DIR = M.opencode_dir() end
    return env
  end
  local l = M.lock_file()
  write_lock() -- with the folder this agent starts in
  local settings = private_dir() .. "/qwen-system-defaults.json"
  write_json(settings, M.qwen_settings())
  env.QWEN_CODE_IDE_SERVER_PORT = tostring(l.n)
  env.QWEN_CODE_IDE_WORKSPACE_PATH = M.workspaces()
  env.QWEN_CODE_SYSTEM_DEFAULTS_PATH = settings
  return env
end

--- The arguments of an agent's command line that connect it to this Neovim: Claude Code's --mcp-config and
--- --settings (files in this Neovim's temp folder); none for the others.
function M.args(backend)
  if backend ~= "claude" then return {} end
  local mcp, settings = private_dir() .. "/claude-mcp.json", private_dir() .. "/claude-settings.json"
  write_json(mcp, M.claude_mcp())
  write_json(settings, M.claude_settings())
  return { "--mcp-config", mcp, "--settings", settings }
end

--- The lock file goes with Neovim
function M.cleanup()
  if lock then
    os.remove(lock.path)
    lock = nil
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("greyknight_agent_link_exit", { clear = true }),
  callback = function() M.cleanup() end,
})

return M
