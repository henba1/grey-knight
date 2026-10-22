-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The MCP server a coding agent starts - Neovim runs it:      ║
-- ║    nvim -l agent_server.lua <role> <address of a Neovim>     ║
-- ║  stdio, one JSON-RPC message per line. Every request goes to ║
-- ║  the Neovim that started the agent (agent_link.lua); its     ║
-- ║  answers and notifications come back as calls in here.       ║
-- ║  role "tools": the editor's tools for the model (any agent); ║
-- ║  role "ide": Qwen Code's IDE companion (diffs, context).     ║
-- ╚══════════════════════════════════════════════════════════════╝
-- A script for nvim -l only: required as a module (a test, a plugin listing modules) it does nothing.
if not (_G.arg and type(_G.arg[0]) == "string" and _G.arg[0]:find("agent_server", 1, true)) then return {} end

local uv = vim.uv
local role, address = _G.arg[1], _G.arg[2]

local stdout = uv.new_pipe(false)
stdout:open(1)
local function send(msg)
  msg.jsonrpc = "2.0"
  stdout:write(vim.json.encode(msg) .. "\n")
end
local function log(text) io.stderr:write("greyknight agent server: " .. text .. "\n") end

local ok, chan = pcall(vim.fn.sockconnect, "pipe", address or "", { rpc = true })
if not ok or type(chan) ~= "number" or chan <= 0 then
  log(("no Neovim at %s (%s) - the agent runs without GreyKnight's tools"):format(tostring(address), tostring(chan)))
  os.exit(1)
end
local me = vim.rpcrequest(chan, "nvim_get_api_info")[1] -- this process, as that Neovim numbers its channels

local function call(fn, ...)
  return vim.rpcrequest(chan, "nvim_exec_lua", "return require('integrations.agent_link')." .. fn .. "(...)", { ... })
end
local function cast(fn, ...)
  vim.rpcnotify(chan, "nvim_exec_lua", "require('integrations.agent_link')." .. fn .. "(...)", { ... })
end

-- What that Neovim sends: the answer to a tool call, or a notification for the agent (agent_link.lua, send)
_G.gk_link = function(kind, payload)
  if kind == "reply" then
    send({ id = payload.id, result = payload.result })
  elseif kind == "notify" then
    send({ method = payload.method, params = payload.params })
  end
end

local function handle(line)
  local okj, msg = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
  if not okj or type(msg) ~= "table" or type(msg.method) ~= "string" then return end -- not a request: nothing asked
  local id, method, params = msg.id, msg.method, msg.params or {}
  if method == "initialize" then
    return send({ id = id, result = {
      protocolVersion = params.protocolVersion or "2025-06-18",
      capabilities = { tools = { listChanged = false } },
      serverInfo = { name = "greyknight", version = "1.0.0" },
      instructions = call("instructions", role),
    } })
  elseif method == "notifications/initialized" then
    return cast("ready", me, role)
  elseif method == "ping" then
    return send({ id = id, result = vim.empty_dict() })
  elseif method == "tools/list" then
    return send({ id = id, result = { tools = call("tools", role) } })
  elseif method == "tools/call" then
    -- answered when the tool is done (it may wait for a language server, the user's review): gk_link above
    return cast("call", me, role, id, params.name, params.arguments or vim.empty_dict())
  end
  if id ~= nil then send({ id = id, error = { code = -32601, message = "Method not found: " .. method } }) end
end

local done, pending = false, ""
local stdin = uv.new_pipe(false)
stdin:open(0)
stdin:read_start(function(err, data)
  if err or not data then -- the agent closed stdin: it ended
    done = true
    return
  end
  pending = pending .. data
  while true do
    local nl = pending:find("\n", 1, true)
    if not nl then break end
    local line = pending:sub(1, nl - 1):gsub("\r$", "")
    pending = pending:sub(nl + 1)
    if line ~= "" then vim.schedule(function() handle(line) end) end
  end
end)

cast("attach", me, role, uv.os_getpid())
while not done do
  vim.wait(1000, function() return done end, 10)
  -- that Neovim is gone (it quit; its terminals took the agent along, but not always at once): end too
  if next(vim.api.nvim_get_chan_info(chan)) == nil then done = true end
end
pcall(cast, "detach", me)
vim.wait(1000, function() return stdout:get_write_queue_size() == 0 end, 10)
