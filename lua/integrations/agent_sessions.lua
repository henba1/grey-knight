-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Agent sessions: every conversation with an agent - the ones ║
-- ║  running in this Neovim (the pane's tabs) and the past ones  ║
-- ║  on disk (Claude Code's, OpenCode's) - in one list           ║
-- ║  (<leader>as): switch to one, resume one where it worked, or ║
-- ║  carry it over to another agent; start a new one next to the ║
-- ║  others (<leader>ao). Alt+, / Alt+. go through the tabs.     ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 2026-10-28: there was one agent pane and one conversation in it - another one ended it (/clear), a past one could
-- not be found again from the editor. The agent's terminals are integrations/agent.lua's; this is the list and the
-- tabs on top of them.
local agent = require("integrations.agent")
local M = {}

-- Each agent's color in the list and on the tabs (Claude Code's own orange; OpenCode, Qwen Code in the theme's)
M.COLORS = { claude = "#d97757", opencode = "#5ea1ff", qwen = "#bd5eff" }
M.HL = { claude = "GkAgentClaude", opencode = "GkAgentOpenCode", qwen = "GkAgentQwen" }

-- How much of a Claude Code transcript the list reads: its head (the folder, the first prompt) and its tail (the
-- title Claude Code gave it). A transcript is tens of MB at times; the list reads a few KB of each.
M.HEAD, M.TAIL = 32 * 1024, 64 * 1024
-- How much of a transcript the preview and a carry-over render (its end: what was said last)
M.RENDER_MAX = 400 * 1024

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Agent sessions" }) end

function M.colors()
  for id, color in pairs(M.COLORS) do vim.api.nvim_set_hl(0, M.HL[id], { fg = color, bold = true }) end
  vim.api.nvim_set_hl(0, "GkAgentTab", { link = "TabLine", default = true })
  vim.api.nvim_set_hl(0, "GkAgentTabActive", { link = "TabLineSel", default = true })
end

-- ── Reading what the agents keep on disk ────────────────────

--- Claude Code's folder ($CLAUDE_CONFIG_DIR, else ~/.claude)
function M.claude_root()
  local own = vim.env.CLAUDE_CONFIG_DIR
  return (own and own ~= "") and own or vim.fn.expand("~/.claude")
end

--- The folder of a project's sessions: its path with every character but letters, digits and - as - (Claude Code's)
function M.claude_slug(dir) return (vim.fs.normalize(dir):gsub("[^%w%-]", "-")) end

local function read_part(path, offset, length)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then return "" end
  local data = vim.uv.fs_read(fd, length, offset) or ""
  vim.uv.fs_close(fd)
  return data
end

--- The text of a message's content: a string, or the text parts of a list
local function content_text(content)
  if type(content) == "string" then return content end
  local parts = {}
  for _, c in ipairs(type(content) == "table" and content or {}) do
    if type(c) == "table" and c.type == "text" and type(c.text) == "string" then parts[#parts + 1] = c.text end
  end
  return table.concat(parts, "\n")
end

--- A prompt the user typed: not a command's record (<command-name>, <local-command-...>), not Claude Code's own
local function typed_prompt(rec)
  if type(rec) ~= "table" or rec.type ~= "user" or rec.isMeta or type(rec.message) ~= "table" then return nil end
  local text = vim.trim(content_text(rec.message.content))
  if text == "" or text:match("^<") or text:match("^%[Request interrupted") then return nil end
  return text
end

local function one_line(text, max)
  text = vim.trim((text or ""):gsub("%s+", " "))
  if #text > (max or 80) then text = text:sub(1, (max or 80) - 1) .. "…" end
  return text
end

local claude_cache = {} -- path -> { mtime, size, item }

--- A Claude Code transcript as a list item: its id, folder, title (the one it gave it, else the first prompt), time
function M.claude_item(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.size == 0 then return nil end
  local hit = claude_cache[path]
  if hit and hit.mtime == stat.mtime.sec and hit.size == stat.size then return hit.item end
  local item = { harness = "claude", sid = vim.fn.fnamemodify(path, ":t:r"), path = path, time = stat.mtime.sec }
  local head = read_part(path, 0, M.HEAD)
  for line in head:gmatch("[^\n]+") do
    local ok, rec = pcall(vim.json.decode, line)
    if ok and type(rec) == "table" then
      item.dir = item.dir or (type(rec.cwd) == "string" and rec.cwd or nil)
      item.prompt = item.prompt or typed_prompt(rec)
      if item.dir and item.prompt then break end
    end
  end
  local tail = stat.size > M.HEAD and read_part(path, math.max(0, stat.size - M.TAIL), M.TAIL) or head
  for line in tail:gmatch("[^\n]+") do -- the last title wins: /rename's over the one Claude Code made
    if line:find('"custom-title"', 1, true) or line:find('"ai-title"', 1, true) then
      local ok, rec = pcall(vim.json.decode, line)
      if ok and type(rec) == "table" then
        if rec.type == "custom-title" and type(rec.customTitle) == "string" then item.custom = rec.customTitle end
        if rec.type == "ai-title" and type(rec.aiTitle) == "string" then item.ai = rec.aiTitle end
      end
    end
  end
  if not item.prompt and not item.custom and not item.ai then return nil end -- opened and closed: nothing said
  item.title = one_line(item.custom or item.ai or item.prompt)
  item.custom, item.ai = nil, nil
  claude_cache[path] = { mtime = stat.mtime.sec, size = stat.size, item = item }
  return item
end

--- Claude Code's sessions of a project (`dir`), or of all projects (nil); newest first. Not its subagents' (those
--- are in a folder per session).
function M.claude_sessions(dir)
  local projects = M.claude_root() .. "/projects"
  local folders = {}
  if dir then
    folders[1] = projects .. "/" .. M.claude_slug(dir)
  else
    for name, kind in vim.fs.dir(projects) do
      if kind == "directory" then folders[#folders + 1] = projects .. "/" .. name end
    end
  end
  local items = {}
  for _, folder in ipairs(folders) do
    for name, kind in vim.fs.dir(folder) do
      if kind == "file" and name:match("%.jsonl$") then
        local item = M.claude_item(folder .. "/" .. name)
        if item then items[#items + 1] = item end
      end
    end
  end
  table.sort(items, function(a, b) return a.time > b.time end)
  return items
end

--- OpenCode's sessions (all projects; it keeps them in its database): `done(items)`, later - its list takes seconds
function M.opencode_sessions(done)
  local bin = agent.BACKENDS.opencode.bin()
  if vim.fn.executable(bin) ~= 1 then return done({}) end
  vim.system({ bin, "session", "list", "--format", "json" }, { text = true }, function(res)
    local ok, list = pcall(vim.json.decode, res.stdout or "")
    local items = {}
    for _, s in ipairs(ok and type(list) == "table" and list or {}) do
      if type(s) == "table" and type(s.id) == "string" then
        local title = type(s.title) == "string" and s.title or ""
        if title:match("^New session %- ") then title = "" end -- nothing said yet
        items[#items + 1] = { harness = "opencode", sid = s.id, dir = s.directory, title = one_line(title ~= "" and title or "(untitled)"),
          time = math.floor((tonumber(s.updated) or 0) / 1000) }
      end
    end
    vim.schedule(function() done(items) end)
  end)
end

-- ── Rendering a past session (the preview, a carry-over to another agent) ──

--- A Claude Code transcript as Markdown - ## User / ## Assistant, the tools it used as a line each. `max`: only the
--- end of a longer transcript (bytes).
function M.render_claude(path, max)
  local stat = vim.uv.fs_stat(path)
  if not stat then return {} end
  local from = max and stat.size > max and stat.size - max or 0
  local data = read_part(path, from, stat.size - from)
  local out = {}
  if from > 0 then out[#out + 1] = "_(earlier turns left out)_" end
  for line in data:gmatch("[^\n]+") do
    local ok, rec = pcall(vim.json.decode, line)
    if ok and type(rec) == "table" and type(rec.message) == "table" then
      local prompt = typed_prompt(rec)
      if prompt then
        vim.list_extend(out, { "", "## User", "", prompt })
      elseif rec.type == "assistant" then
        local text = vim.trim(content_text(rec.message.content))
        local tools = {}
        for _, c in ipairs(type(rec.message.content) == "table" and rec.message.content or {}) do
          if type(c) == "table" and c.type == "tool_use" then tools[#tools + 1] = c.name end
        end
        if text ~= "" then vim.list_extend(out, { "", "## Assistant", "", text }) end
        if #tools > 0 then vim.list_extend(out, { "", "_(tools: " .. table.concat(tools, ", ") .. ")_" }) end
      end
    end
  end
  return vim.split(table.concat(out, "\n"), "\n", { plain = true })
end

--- An OpenCode session as Markdown (opencode export): `done(lines)`
function M.render_opencode(sid, done)
  vim.system({ agent.BACKENDS.opencode.bin(), "export", sid }, { text = true }, function(res)
    local ok, data = pcall(vim.json.decode, res.stdout or "")
    local out = {}
    for _, msg in ipairs(ok and type(data) == "table" and data.messages or {}) do
      local texts = {}
      for _, part in ipairs(msg.parts or {}) do
        if part.type == "text" and type(part.text) == "string" and not part.synthetic then texts[#texts + 1] = part.text end
      end
      local role = (msg.info or {}).role
      if #texts > 0 and (role == "user" or role == "assistant") then
        vim.list_extend(out, { "", role == "user" and "## User" or "## Assistant", "", table.concat(texts, "\n") })
      end
    end
    vim.schedule(function() done(vim.split(table.concat(out, "\n"), "\n", { plain = true })) end)
  end)
end

--- A past session's conversation as Markdown: `done(lines)` (Claude Code's at once, OpenCode's when it exported it)
function M.render(item, done, max)
  if item.harness == "claude" and item.path then return done(M.render_claude(item.path, max)) end
  if item.harness == "opencode" then return M.render_opencode(item.sid, done) end
  done({})
end

-- ── The list ─────────────────────────────────────────────────

local function age(t)
  local d = os.time() - (t or 0)
  if d < 3600 then return math.max(1, math.floor(d / 60)) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  if d < 86400 * 60 then return math.floor(d / 86400) .. "d" end
  return os.date("%Y-%m", t)
end

--- A running session's title: the one it was given, else its Claude Code transcript's, else "new"
function M.title(term)
  if term.gk_title then return term.gk_title end
  if term.gk_backend == "claude" and term.gk_session and term.dir then
    local path = ("%s/projects/%s/%s.jsonl"):format(M.claude_root(), M.claude_slug(term.dir), term.gk_session)
    local item = vim.uv.fs_stat(path) and M.claude_item(path)
    if item then return item.title end
  end
  return "new"
end

--- The running sessions as list items
function M.running_items()
  local items = {}
  for _, s in ipairs(agent.running()) do
    items[#items + 1] = { running = true, name = s.name, term = s.term, harness = s.term.gk_backend or agent.backend_id(),
      sid = s.term.gk_session, dir = s.term.dir, title = M.title(s.term), time = s.term.gk_started or os.time() }
  end
  return items
end

--- Whether `dir` is the project `root` or in it
local function in_project(dir, root)
  if not dir or dir == "" then return false end
  dir, root = vim.fs.normalize(dir), vim.fs.normalize(root)
  return dir == root or vim.startswith(dir, root:gsub("/$", "") .. "/")
end

-- OpenCode's list, kept between two opens of the list (it takes seconds): nil until it came once
M.opencode_cache = nil

--- Every session to list: the running ones first, then the past ones, newest first - those of the project (Neovim's
--- folder), or of all (`all`). Past sessions that run here are the running ones.
function M.items(all)
  local cwd = vim.fn.getcwd(-1, -1)
  local items, seen = M.running_items(), {}
  for _, item in ipairs(items) do
    if item.sid then seen[item.sid] = true end
  end
  local past = M.claude_sessions(not all and cwd or nil)
  vim.list_extend(past, M.opencode_cache or {})
  vim.list_extend(past, M.extra_items(all) or {})
  table.sort(past, function(a, b) return (a.time or 0) > (b.time or 0) end)
  for _, item in ipairs(past) do
    local key = item.sid and (item.sid .. (item.host or ""))
    if not (item.sid and seen[item.sid]) and not (key and seen[key]) and (all or in_project(item.dir, cwd)) then
      if key then seen[key] = true end
      items[#items + 1] = item
    end
  end
  for i, item in ipairs(items) do
    item.idx = i
    item.text = table.concat({ item.harness, item.title or "", item.dir or "", item.host or "", item.sid or "" }, " ")
  end
  return items
end

--- More past sessions from elsewhere (integrations that add a source replace it): items as above, with a `host`
function M.extra_items() return {} end

local function format(item)
  local backend = agent.BACKENDS[item.harness] or {}
  local parts = {
    { item.running and "● " or "  ", item.running and "DiagnosticOk" or "Comment" },
    { ("%-9s"):format(backend.short or item.harness), M.HL[item.harness] or "Normal" },
    { ("%5s  "):format(item.running and "now" or age(item.time)), "Comment" },
  }
  if item.host then parts[#parts + 1] = { item.host .. "  ", "Special" } end
  if item.dir and not in_project(item.dir, vim.fn.getcwd(-1, -1)) then
    parts[#parts + 1] = { vim.fn.fnamemodify(item.dir, ":t") .. "  ", "Directory" }
  end
  parts[#parts + 1] = { item.title or "" }
  return parts
end

local function preview(ctx)
  local item = ctx.item
  local function show(lines, ft)
    if not vim.api.nvim_buf_is_valid(ctx.buf) then return end
    ctx.preview:set_lines(lines)
    ctx.preview:highlight({ ft = ft or "markdown" })
  end
  local head = {
    ("# %s"):format(item.title or ""), "",
    ("_%s · %s%s%s_"):format((agent.BACKENDS[item.harness] or {}).name or item.harness, item.running and "running here" or os.date("%Y-%m-%d %H:%M", item.time),
      item.host and (" · " .. item.host) or "", item.dir and (" · " .. vim.fn.fnamemodify(item.dir, ":~")) or ""),
  }
  if item.running then
    local lines = vim.api.nvim_buf_get_lines(item.term.bufnr, 0, -1, false)
    while #lines > 0 and vim.trim(lines[#lines]) == "" do lines[#lines] = nil end
    return show(vim.list_extend(vim.list_extend(head, { "" }), vim.list_slice(lines, math.max(1, #lines - 300))), "text")
  end
  show(vim.list_extend(vim.deepcopy(head), { "", "_(reading the conversation …)_" }))
  local want = item
  M.render(item, function(lines)
    if ctx.item ~= want then return end
    show(vim.list_extend(head, #lines > 0 and lines or { "", "_(nothing to show)_" }))
  end, 64 * 1024)
end

-- ── Resuming, carrying over ──────────────────────────────────

--- The folder a past session goes on in: where it worked, when that is on this machine; else Neovim's
local function workdir(item)
  if item.dir and vim.fn.isdirectory(item.dir) == 1 then return item.dir end
  if item.dir then
    notify(("%s worked in %s - not on this machine; it goes on in %s"):format(item.title or item.sid, item.dir,
      vim.fn.fnamemodify(vim.fn.getcwd(-1, -1), ":~")), vim.log.levels.WARN)
  end
  return vim.fn.getcwd(-1, -1)
end

-- How each agent goes on with a session of its own
M.RESUME_ARGS = {
  claude = function(sid) return { "--resume", sid } end,
  opencode = function(sid) return { "--session", sid } end,
}

--- Go on with a past session in its own agent, in the pane next to the others
function M.resume(item)
  if item.running then return agent.switch(item.name) end
  local args = M.RESUME_ARGS[item.harness]
  if not args or vim.fn.executable(agent.BACKENDS[item.harness].bin()) ~= 1 then
    return M.carry_over(item)
  end
  agent.open_session({ backend = item.harness, args = args(item.sid), sid = item.harness == "claude" and item.sid or nil,
    dir = workdir(item), title = item.title })
end

--- The folder a carried-over conversation is written to (Neovim's state folder: no project's)
function M.carry_dir() return vim.fn.stdpath("state") .. "/agent-sessions" end

--- The prompt that hands a past conversation (written to `file`) to a new session of another agent
function M.carry_prompt(item, file)
  return ("Continue the %s session \"%s\"%s. Read the conversation so far in %s first, then pick up where it left off.")
    :format((agent.BACKENDS[item.harness] or {}).name or item.harness, item.title or item.sid or "",
      item.host and (" from " .. item.host) or "", file)
end

--- Go on with a past session in another agent (`target`; asked when nil): there is no session of its own to resume -
--- the conversation goes over as a file the new session reads first. The tools it used and their output stay behind.
function M.carry_over(item, target)
  local choices = vim.tbl_filter(function(id) return id ~= item.harness end, agent.installed())
  if target == nil then
    if #choices == 0 then return notify("No other agent is installed here", vim.log.levels.WARN) end
    return vim.ui.select(choices, {
      prompt = "Go on with it in:",
      format_item = function(id) return agent.BACKENDS[id].name end,
    }, function(choice) if choice then M.carry_over(item, choice) end end)
  end
  M.render(item, function(lines)
    if #lines == 0 then return notify("Nothing to carry over from " .. (item.title or item.sid), vim.log.levels.WARN) end
    vim.fn.mkdir(M.carry_dir(), "p")
    local file = ("%s/%s-%s.md"):format(M.carry_dir(), item.harness, (item.sid or tostring(os.time())):gsub("[^%w%-_]", "_"))
    vim.fn.writefile(vim.list_extend({ "# " .. (item.title or ""), "" }, lines), file)
    agent.open_session({ backend = target, dir = workdir(item), title = item.title, prompt = M.carry_prompt(item, file) })
  end, M.RENDER_MAX)
end

--- A new session next to the others: in `backend` (asked when nil and more than one agent is installed)
function M.new(backend)
  local list = agent.installed()
  if backend or #list <= 1 then return agent.open_session({ backend = backend or list[1] }) end
  vim.ui.select(list, { prompt = "New session with:", format_item = function(id) return agent.BACKENDS[id].name end },
    function(choice) if choice then agent.open_session({ backend = choice }) end end)
end

--- <leader>as: the sessions - running ones, past ones of the project (Ctrl+A: of all projects)
function M.pick(opts)
  opts = opts or {}
  local all = opts.all or false
  local picker
  picker = Snacks.picker.pick({
    title = all and "Agent sessions (all projects)" or "Agent sessions",
    finder = function() return M.items(all) end,
    format = format,
    preview = preview,
    sort = { fields = { "idx" } },
    matcher = { sort_empty = false },
    confirm = function(p, item)
      p:close()
      if item then vim.schedule(function() M.resume(item) end) end
    end,
    actions = {
      gk_carry = function(p, item)
        if not item or item.running then return end
        p:close()
        vim.schedule(function() M.carry_over(item) end)
      end,
      gk_new = function(p)
        p:close()
        vim.schedule(function() M.new() end)
      end,
      gk_stop = function(p, item)
        if not item or not item.running then return end
        Snacks.picker.util.confirm("End the session " .. (item.title or "") .. "?", function()
          agent.stop(item.name)
          p:refresh()
        end)
      end,
      gk_all = function(p)
        p:close()
        vim.schedule(function() M.pick({ all = not all }) end)
      end,
    },
    win = {
      input = { keys = {
        ["<c-o>"] = { "gk_carry", mode = { "n", "i" }, desc = "Go on with it in another agent" },
        ["<c-e>"] = { "gk_new", mode = { "n", "i" }, desc = "New session" }, -- Ctrl+N stays the picker's next item
        ["<c-x>"] = { "gk_stop", mode = { "n", "i" }, desc = "End the running session" },
        ["<c-a>"] = { "gk_all", mode = { "n", "i" }, desc = "All projects / this project" },
      } },
      list = { keys = { ["dd"] = { "gk_stop", desc = "End the running session" } } },
    },
  })
  -- OpenCode's list and other sources come later: the list again when they are there
  local function again()
    if picker and not picker.closed then picker:refresh() end
  end
  M.opencode_sessions(function(items)
    M.opencode_cache = items
    again()
  end)
  M.refresh_extra(again)
  return picker
end

--- Sources that load in the background (integrations replace it): `done()` when there is more to list
function M.refresh_extra(done) end

-- ── The tabs on the pane ─────────────────────────────────────

--- The winbar of the pane: a tab per running session (a click shows it, a middle click ends it), + a new one,
--- ☰ the list
function M.tabline()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local shown = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
  local parts = {}
  for i, s in ipairs(agent.running()) do
    local backend = agent.BACKENDS[s.term.gk_backend] or agent.backend()
    local title = one_line(M.title(s.term), 24):gsub("%%", "%%%%")
    local active = s.term.bufnr == shown
    parts[#parts + 1] = ("%%%d@v:lua.GkAgentTab@%%#%s# %d %%#%s#%s%%#%s# %s %%X"):format(s.term.id,
      active and "GkAgentTabActive" or "GkAgentTab", i, M.HL[s.term.gk_backend] or "Normal", backend.short,
      active and "GkAgentTabActive" or "GkAgentTab", title)
  end
  parts[#parts + 1] = "%#GkAgentTab#%0@v:lua.GkAgentNew@ + %X%=%0@v:lua.GkAgentList@ ☰ %X"
  return table.concat(parts, "%#Normal# ")
end

M.BAR = "%{%v:lua.require'integrations.agent_sessions'.tabline()%}"

--- The tabs on the pane's window `win`
function M.decorate(win)
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
    vim.wo[win].winbar = M.BAR
  end
end

-- the tabs' clicks (a winbar calls a global function: minwid, clicks, button, modifiers)
_G.GkAgentTab = function(id, _, button)
  for _, s in ipairs(agent.running()) do
    if s.term.id == id then
      if button == "m" then return agent.stop(s.name) end
      return agent.switch(s.name)
    end
  end
end
_G.GkAgentNew = function() vim.schedule(function() M.new() end) end
_G.GkAgentList = function() vim.schedule(function() M.pick() end) end

function M.setup()
  M.colors()
  local group = vim.api.nvim_create_augroup("greyknight.agent_sessions", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.colors })
  -- a session that ends or starts: the tabs drawn again
  vim.api.nvim_create_autocmd({ "TermOpen", "TermClose" }, { group = group, callback = function()
    vim.schedule(function() pcall(vim.cmd.redrawstatus, { bang = true }) end)
  end })
end

return M
