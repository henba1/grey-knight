-- ╔══════════════════════════════════════════════════════════════╗
-- ║  scrubjay: the sessions of every machine and every agent in  ║
-- ║  the agent's session list (<leader>as) - tagged by agent and ║
-- ║  machine, resumed in the agent you pick (sj-resume); the     ║
-- ║  archive searched for words, the hits as a list (<leader>aS).║
-- ║  Nothing without scrubjay installed: the list stays this     ║
-- ║  machine's.                                                  ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 2026-10-28: scrubjay (~/.scrubjay/scrubjay) relays every session of Claude Code, OpenCode and Codex on every machine
-- into one archive, with a catalogue of them. GreyKnight reads that catalogue through scrubjay's own scripts - never
-- its files directly: `sj-resume.sh --list --json` lists it, `sj-resume.sh <id> --json` stages a session (another
-- machine's paths rewritten to this one's) or renders it for another agent, `sj-grep.sh --json` searches it.
local M = {}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "scrubjay" }) end

--- scrubjay's folder: vim.g.greyknight_scrubjay, $SCRUBJAY_APP, else ~/.scrubjay/scrubjay - when it is installed
function M.app()
  -- one after the other: in a list an unset vim.g.greyknight_scrubjay is nil, and ipairs stopped before the rest
  local candidates = { vim.g.greyknight_scrubjay or "", vim.env.SCRUBJAY_APP or "", vim.fn.expand("~/.scrubjay/scrubjay") }
  for _, dir in ipairs(candidates) do
    if type(dir) == "string" and dir ~= "" and vim.fn.filereadable(dir .. "/bin/sj-resume.sh") == 1 then return dir end
  end
end

-- What the last load found: this machine's name in scrubjay, the archive's folder when this machine can read it (the
-- NAS mounted, or the git clone), the catalogue's rows
M.state = { host = nil, root = nil, items = nil }

-- One bash: the settings, then the catalogue as JSON lines (an older scrubjay without --json: its catalogue as TSV,
-- after a line "#TSV")
local LOAD = [[
. "$1/bin/lib.sh" >/dev/null 2>&1 || exit 3
sj_load_config
b="${SCRUBJAY_TRANSCRIPT_BACKEND:-git}"; r=""
[ "$b" = local ] && r="${SCRUBJAY_LOCAL_CHATS:-}"
[ "$b" = git ] && r="$(sj_chats)"
printf '%s\t%s\n' "$(sj_host)" "$r"
bash "$1/bin/sj-resume.sh" --list --json 2>/dev/null || { echo "#TSV"; sj_log_catalogue; }
]]

local function epoch(ts)
  local y, mo, d, h, mi = (ts or ""):match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+)")
  return y and os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi) }) or 0
end

--- The 8 characters a session is known by in the archive (its readable file ends with them): OpenCode's after ses_
function M.handle(sid) return ((sid or ""):gsub("^ses_", "")):sub(1, 8) end

--- A catalogue row as an item of the session list
function M.item(row, host)
  local here = row.host == host
  local topic = vim.trim(row.topic or "")
  return {
    harness = (row.harness and row.harness ~= "" and row.harness ~= "-") and row.harness or "claude",
    sid = row.sid, dir = row.cwd, time = epoch(row.ts),
    title = topic ~= "" and topic or "(no topic)",
    host = not here and row.host or nil, -- shown in the list: another machine's
    origin = row.host, scrubjay = true,
    render = M.render, resume = M.resume,
  }
end

--- Parse what LOAD printed
function M.parse(out)
  local lines = vim.split(out or "", "\n", { trimempty = true })
  if #lines == 0 then return nil end
  local host, root = lines[1]:match("^([^\t]*)\t(.*)$")
  local items, tsv = {}, false
  for i = 2, #lines do
    local line = lines[i]
    if line == "#TSV" then
      tsv = true
    elseif tsv then
      local ts, h, sid, cwd, topic, harness = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?([^\t]*)$")
      if sid and sid ~= "" then items[#items + 1] = M.item({ ts = ts, host = h, sid = sid, cwd = cwd, topic = topic, harness = harness }, host) end
    else
      local ok, row = pcall(vim.json.decode, line)
      if ok and type(row) == "table" and type(row.sid) == "string" then
        if row.harness == vim.NIL then row.harness = nil end
        items[#items + 1] = M.item(row, host)
      end
    end
  end
  return { host = host, root = root ~= "" and root or nil, items = items }
end

--- Read the catalogue again (in the background): `done()` once it is there
function M.load(done)
  local app = M.app()
  if not app then return end
  vim.system({ "bash", "-c", LOAD, "_", app }, { text = true }, function(res)
    local state = res.code ~= 3 and M.parse(res.stdout) or nil
    vim.schedule(function()
      if state then M.state = state end
      if done then done() end
    end)
  end)
end

-- ── A session from the archive ──────────────────────────────

--- Its readable Markdown in the archive (<root>/<host>/readable/<project>/<date>_<topic>__<handle>.md), when this
--- machine can read the archive
function M.readable(item)
  local root = M.state.root
  if not root or not item.origin then return nil end
  local found = vim.fn.glob(("%s/%s/readable/*/*__%s.md"):format(vim.fn.escape(root, "*?[]"), item.origin, M.handle(item.sid)), false, true)
  table.sort(found)
  return found[#found]
end

--- Its conversation (the preview, a carry-over, Ctrl+Y): the readable copy in the archive - its end when longer than
--- `max` bytes
function M.render(item, done, max)
  local file = M.readable(item)
  if not file then
    return done({ "", "_(not in an archive this machine can read - Enter fetches it with scrubjay's sj-resume)_" })
  end
  local lines = vim.fn.readfile(file)
  local size, keep = 0, #lines + 1
  for i = #lines, 1, -1 do
    size = size + #lines[i] + 1
    if max and size > max then break end
    keep = i
  end
  done(vim.list_slice(lines, keep))
end

--- Go on with it in `target` (an agent): sj-resume stages it here - another machine's paths rewritten to this one's -
--- and the agent resumes it; for another agent than its own it renders the conversation, and a new session of
--- `target` reads that first.
function M.resume(item, target)
  local app = M.app()
  if not app then return notify("scrubjay is not installed here", vim.log.levels.WARN) end
  local sessions, agent = require("integrations.agent_sessions"), require("integrations.agent")
  target = target or item.harness
  local dir = sessions.workdir(item)
  notify(("Fetching %s from %s …"):format(item.title or item.sid, item.origin or "the archive"))
  vim.system({ "bash", app .. "/bin/sj-resume.sh", item.sid, "--into", dir, "--json" },
    { text = true, env = { SCRUBJAY_HARNESS = target } }, function(res)
      vim.schedule(function()
        local out = vim.split(res.stdout or "", "\n", { trimempty = true })
        local ok, r = pcall(vim.json.decode, out[#out] or "")
        if not ok or type(r) ~= "table" then
          if (res.stderr or ""):find("unknown flag '--json'", 1, true) then
            return notify("This scrubjay is too old for GreyKnight (no sj-resume --json): update it", vim.log.levels.WARN)
          end
          return notify("sj-resume failed:\n" .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
        end
        if not r.ok then return notify("sj-resume: " .. tostring(r.error), vim.log.levels.WARN) end
        if r.mode == "native" then
          local args = sessions.RESUME_ARGS[target]
          if not args then return notify(("Staged - %s resumes it with: %s"):format(target, r.cmd)) end
          agent.open_session({ backend = target, args = args(r.sid), sid = target == "claude" and r.sid or nil, dir = r.cwd,
            title = item.title })
        else -- context: another agent's session, its conversation rendered (r.primer)
          agent.open_session({ backend = target, dir = r.cwd, title = item.title, prompt = sessions.carry_prompt(item, r.primer) })
        end
      end)
    end)
end

-- ── Searching the archive (sj-grep) ─────────────────────────

--- Words as arguments: "a phrase" stays one, host=… since=… scope it (sj-grep's filters)
function M.words(text)
  local args = {}
  local rest = text or ""
  while true do
    rest = rest:gsub("^%s+", "")
    if rest == "" then break end
    local q, after = rest:match('^"([^"]*)"()')
    if q then
      args[#args + 1] = q
      rest = rest:sub(after)
    else
      local w = rest:match("^%S+")
      args[#args + 1] = w
      rest = rest:sub(#w + 1)
    end
  end
  return args
end

--- sj-grep's sessions as list items: one per place a word is
function M.hits(out)
  local items = {}
  for _, line in ipairs(vim.split(out or "", "\n", { trimempty = true })) do
    local ok, s = pcall(vim.json.decode, line)
    if ok and type(s) == "table" and s.type == "session" then
      for _, snip in ipairs(s.snippets or {}) do
        items[#items + 1] = {
          text = table.concat({ s.topic or "", s.host or "", s.harness or "", s.project or "", snip.text or "" }, " "),
          file = s.path, pos = { tonumber(snip.line) or 1, 0 }, session = s, snip = snip,
        }
      end
    end
  end
  return items
end

--- <leader>aS: search every session of every machine for words (sj-grep): the places as a list, the conversation
--- around each in the preview. Enter reads it there, Ctrl+O goes on with that session, Ctrl+Y hands it to the agent.
function M.search(text)
  local app = M.app()
  if not app then return notify("scrubjay is not installed here", vim.log.levels.WARN) end
  local grep = app .. "/bin/sj-grep.sh"
  if vim.fn.filereadable(grep) ~= 1 then return notify("This scrubjay has no sj-grep yet: update it", vim.log.levels.WARN) end
  if not text then
    return vim.ui.input({ prompt = "Search past sessions (words; \"a phrase\", host= since= harness=): " }, function(t)
      if t and vim.trim(t) ~= "" then M.search(t) end
    end)
  end
  local args = { "bash", grep, "--json", "--limit=40", "--max-snippets=5", "--context=3", "--color=never" }
  vim.list_extend(args, M.words(text))
  notify("Searching the archive for " .. text .. " …")
  vim.system(args, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 3 then
        return notify("This machine cannot read the archive (relay only) - /sjgrep in Claude Code searches it over MCP", vim.log.levels.WARN)
      end
      local items = M.hits(res.stdout)
      if #items == 0 then return notify("No session mentions " .. text) end
      M.pick_hits(items, text)
    end)
  end)
end

local function session_item(s)
  return M.item({ ts = s.ts, host = s.host, sid = s.sid, cwd = nil, topic = s.topic, harness = s.harness }, M.state.host)
end

function M.pick_hits(items, text)
  local sessions = require("integrations.agent_sessions")
  Snacks.picker.pick({
    title = "Past sessions: " .. text,
    items = items,
    preview = "file",
    format = function(item)
      local s, snip = item.session, item.snip
      local first = vim.trim(((snip.text or ""):match("[^\n]*" .. vim.pesc(vim.split(text, " ")[1] or "") .. "[^\n]*") or (snip.text or "")):gsub("%s+", " "))
      return {
        { ("%-9s"):format((require("integrations.agent").BACKENDS[s.harness] or {}).short or s.harness or ""), sessions.HL[s.harness] or "Normal" },
        { (s.date or "") .. "  ", "Comment" }, { (s.host or "") .. "  ", "Special" },
        { (s.topic or ""):sub(1, 40) .. "  " }, { "turn " .. tostring(snip.turn or "?") .. "  ", "Number" },
        { first:sub(1, 120), "Comment" },
      }
    end,
    confirm = function(p, item)
      p:close()
      if not item then return end
      vim.schedule(function()
        vim.cmd.split({ args = { item.file }, magic = { file = false } })
        pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], 0 })
        vim.cmd("normal! zz")
        pcall(function() require("config.mdlinks").read_only(0) end)
      end)
    end,
    actions = {
      gk_resume = function(p, item)
        if not item then return end
        p:close()
        local it = session_item(item.session)
        local agent = require("integrations.agent")
        vim.schedule(function()
          vim.ui.select(agent.installed(), {
            prompt = "Go on with it in:",
            format_item = function(id) return agent.BACKENDS[id].name .. (id == it.harness and " (its own)" or "") end,
          }, function(choice) if choice then M.resume(it, choice) end end)
        end)
      end,
      gk_mention = function(p, item)
        if not item then return end
        p:close()
        vim.schedule(function() require("integrations.agent").mention({ item.file }) end)
      end,
    },
    win = { input = { keys = {
      ["<c-o>"] = { "gk_resume", mode = { "n", "i" }, desc = "Go on with that session (its agent or another)" },
      ["<c-y>"] = { "gk_mention", mode = { "n", "i" }, desc = "Hand the conversation to the agent (@file)" },
    } } },
  })
end

--- Plug into the session list: the catalogue's sessions next to this machine's, loaded when the list opens
function M.setup()
  if not M.app() then return end
  local sessions = require("integrations.agent_sessions")
  sessions.extra_items = function() return M.state.items or {} end
  sessions.refresh_extra = function(done) M.load(done) end
  vim.api.nvim_create_user_command("SjGrep", function(o) M.search(o.args ~= "" and o.args or nil) end,
    { nargs = "*", desc = "scrubjay: search every past session for words" })
end

return M
