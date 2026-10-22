-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The editor's tools for a coding agent (MCP, both agents):   ║
-- ║  show the user a file in the tree (or a search there), open  ║
-- ║  code at a line, list places in the quickfix list; what is   ║
-- ║  open and selected; diagnostics, symbols, definitions and    ║
-- ║  references from Neovim's language servers; a message.       ║
-- ║  They show and read - no file changes, nothing runs.         ║
-- ║  Called through agent_link.lua; each answers when done.      ║
-- ╚══════════════════════════════════════════════════════════════╝
local link = require("integrations.agent_link")
local M = {}

local WIN = vim.fn.has("win32") == 1

M.INSTRUCTIONS = table.concat({
  "These tools work in the user's editor, Neovim (GreyKnight); you run in a terminal next to the code.",
  "When the user asks where something is, find it, then show it: show_in_file_tree reveals a file or folder in the",
  "file tree, highlighted (or runs a search there); open_file shows code at a line; show_locations lists several",
  "places (hits, usages, errors) in the quickfix list. editor_state tells what the user has open and selected.",
  "diagnostics, find_symbol, goto_definition and find_references ask the language servers running in Neovim.",
}, " ")

-- ── Paths ──────────────────────────────────────────────────────

local function key(path) return WIN and path:lower() or path end

--- An absolute, normalized path: ~ and paths relative to the project (Neovim's working directory) resolved
function M.resolve(path)
  if type(path) ~= "string" or vim.trim(path) == "" then return nil end
  path = vim.trim(path)
  if path:sub(1, 1) == "~" then path = vim.uv.os_homedir() .. path:sub(2) end
  if not (path:match("^/") or path:match("^%a:[/\\]") or path:match("^[/\\][/\\]")) then
    path = vim.fn.getcwd(-1, -1) .. "/" .. path
  end
  path = vim.fs.normalize(path)
  if #path > 1 and not path:match("^%a:/$") then path = path:gsub("/$", "") end
  return path
end

local function rel(path)
  local cwd = vim.fs.normalize(vim.fn.getcwd(-1, -1))
  local p = vim.fs.normalize(path)
  if vim.startswith(key(p), key(cwd) .. "/") then return p:sub(#cwd + 2) end
  return p
end

local function same(a, b) return a and b and key(vim.fs.normalize(a)) == key(vim.fs.normalize(b)) end

-- Wait without blocking Neovim: done(true) once cond() is true, done(false) after `ms`
local function when(cond, ms, done)
  local start = vim.uv.now()
  local function poll()
    local ok, v = pcall(cond)
    if ok and v then return done(true) end
    if vim.uv.now() - start >= ms then return done(false) end
    vim.defer_fn(poll, 50)
  end
  poll()
end

local function text_result(text) return link.result(text) end
local function error_result(text) return link.result(text, true) end

local function explorer()
  for _, p in ipairs(Snacks.picker.get({ source = "explorer" })) do
    if not p.closed and p.list.win:valid() then return p end
  end
end

-- ── Showing ────────────────────────────────────────────────────

local T = {}

function T.show_in_file_tree(args, reply)
  local search = type(args.search) == "string" and vim.trim(args.search) or ""
  if search ~= "" then
    if not explorer() then Snacks.explorer() end
    return when(explorer, 5000, function(ok)
      local picker = explorer()
      if not (ok and picker) then return reply(error_result("The file tree did not open")) end
      local ex = require("config.explorer")
      ex.search_for(picker, search, { regex = args.regex == true, folders = args.folders == true }, function(p)
        local hits = ex.matches(p)
        local kind = args.folders and "folder" or "file"
        local how = args.regex and (ex.is_glob(search) and "glob" or "regex") or "fuzzy"
        if #hits == 0 then
          return reply(text_result(("The file tree's %s search (%s) for %q found nothing"):format(kind, how, search)))
        end
        local lines = { ("The file tree shows %d %s match%s of a %s search for %q:"):format(#hits, kind, #hits == 1 and "" or "es", how, search) }
        for i, path in ipairs(hits) do
          if i > 100 then
            lines[#lines + 1] = ("... and %d more"):format(#hits - 100)
            break
          end
          lines[#lines + 1] = rel(path)
        end
        reply(text_result(table.concat(lines, "\n")))
      end)
    end)
  end
  local path = M.resolve(args.path)
  if not path then return reply(error_result("show_in_file_tree needs a path or a search")) end
  if not vim.uv.fs_stat(path) then return reply(error_result("No such file or folder: " .. path)) end
  require("config.explorer").show(path)
  when(function()
    local p = explorer()
    local item = p and p:current()
    return item and same(item.file, path)
  end, 8000, function(ok)
    local p = explorer()
    if p then p:focus("list") end
    if ok then return reply(text_result(("The file tree shows %s, the cursor on it"):format(rel(path)))) end
    reply(error_result(("The file tree opened but did not get to %s"):format(rel(path))))
  end)
end

local ns = vim.api.nvim_create_namespace("greyknight_agent_show")
vim.api.nvim_set_hl(0, "GreyKnightAgentShow", { default = true, link = "IncSearch" })

-- Lines `first`..`last` of `buf` lit up for a few seconds
local function light(buf, first, last)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  last = math.min(math.max(first, last or first), vim.api.nvim_buf_line_count(buf))
  vim.hl.range(buf, ns, "GreyKnightAgentShow", { first - 1, 0 }, { last - 1, -1 }, { regtype = "V", timeout = 4000 })
end

function T.open_file(args, reply)
  local path = M.resolve(args.path)
  if not path then return reply(error_result("open_file needs a path")) end
  if vim.fn.filereadable(path) ~= 1 then return reply(error_result("No such file: " .. path)) end
  local win = link.code_window()
  if not win then
    vim.cmd("leftabove vsplit") -- only terminals and the tree here: a window for the code next to them
    win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_current_win(win)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  local line = tonumber(args.line)
  if line then
    line = math.max(1, math.min(math.floor(line), vim.api.nvim_buf_line_count(buf)))
    local col = math.max(0, (tonumber(args.column) or 1) - 1)
    pcall(vim.api.nvim_win_set_cursor, win, { line, col })
    vim.cmd("normal! zvzz")
    light(buf, line, tonumber(args.end_line))
  end
  reply(text_result(("Opened %s%s in the editor"):format(rel(path), line and (" at line " .. line) or "")))
end

function T.show_locations(args, reply)
  local items = {}
  for _, l in ipairs(type(args.locations) == "table" and args.locations or {}) do
    local path = type(l) == "table" and M.resolve(l.path)
    if path then
      items[#items + 1] = { filename = path, lnum = tonumber(l.line) or 1, col = tonumber(l.column) or 1, text = l.text or "" }
    end
  end
  if #items == 0 then return reply(error_result("show_locations needs locations: { path, line, column?, text? }")) end
  vim.fn.setqflist({}, " ", { title = type(args.title) == "string" and args.title or "From the agent", items = items })
  vim.cmd("botright copen")
  reply(text_result(("The quickfix list shows %d place%s; the user goes through them with Enter, ]q / [q"):format(#items, #items == 1 and "" or "s")))
end

function T.notify(args, reply)
  local levels = { error = vim.log.levels.ERROR, warn = vim.log.levels.WARN, warning = vim.log.levels.WARN }
  local who = require("integrations.agent").backend().short
  vim.notify(tostring(args.message or ""), levels[tostring(args.level or ""):lower()] or vim.log.levels.INFO, { title = who })
  reply(text_result("Shown"))
end

-- ── Reading ────────────────────────────────────────────────────

function T.editor_state(_, reply)
  local active = link.active()
  local state = { project = vim.fn.getcwd(-1, -1), open_files = {} }
  for _, f in ipairs(link.recent_files(20)) do state.open_files[#state.open_files + 1] = rel(f.path) end
  if active then
    state.current_file = rel(active.path)
    if active.cursor then state.cursor = { line = active.cursor[1], column = active.cursor[2] + 1 } end
    if active.win then
      state.visible_lines = { first = vim.fn.line("w0", active.win), last = vim.fn.line("w$", active.win) }
    end
    state.selected_text = link.selection(active.buf)
    state.unsaved_changes = vim.bo[active.buf].modified
  end
  reply(text_result(vim.json.encode(state)))
end

local SEVERITY = { "error", "warning", "info", "hint" }

-- A buffer with the file loaded (its language server attaches as when the user opens it); nil when there is none
local function load(path)
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local buf = vim.fn.bufadd(path)
  if not vim.api.nvim_buf_is_loaded(buf) then
    vim.bo[buf].buflisted = false -- loaded for a tool: not one of the user's buffers
    vim.fn.bufload(buf)
  end
  return buf
end

local function diagnostics_text(list, limit)
  local lines = {}
  for i, d in ipairs(list) do
    if i > limit then
      lines[#lines + 1] = ("... and %d more"):format(#list - limit)
      break
    end
    local name = vim.api.nvim_buf_is_valid(d.bufnr) and rel(vim.api.nvim_buf_get_name(d.bufnr)) or "?"
    lines[#lines + 1] = ("%s:%d:%d %s: %s%s"):format(name, d.lnum + 1, d.col + 1, SEVERITY[d.severity] or "?",
      d.message:gsub("\n", " "), d.source and (" [" .. d.source .. "]") or "")
  end
  return table.concat(lines, "\n")
end

function T.diagnostics(args, reply)
  local path = M.resolve(args.path)
  if not path then
    local list = vim.diagnostic.get(nil)
    table.sort(list, function(a, b) return a.severity < b.severity end)
    if #list == 0 then return reply(text_result("No diagnostics in the files open in Neovim")) end
    return reply(text_result(diagnostics_text(list, 200)))
  end
  local was_loaded = vim.fn.bufloaded(path) == 1
  local buf = load(path)
  if not buf then return reply(error_result("No such file: " .. path)) end
  local function answer()
    local list = vim.diagnostic.get(buf)
    if #list == 0 then return reply(text_result("No diagnostics in " .. rel(path))) end
    reply(text_result(diagnostics_text(list, 200)))
  end
  if was_loaded and vim.lsp.get_clients({ bufnr = buf })[1] then return answer() end
  -- just loaded: its language server needs a moment to attach and check it (a clean file stays without any)
  when(function() return #vim.diagnostic.get(buf) > 0 end, 4000, answer)
end

-- Locations of an LSP answer (Location, Location[], LocationLink[]) as { path, line, column }
local function locations(result)
  local list = {}
  if type(result) ~= "table" then return list end
  if result.uri or result.targetUri then result = { result } end
  for _, loc in ipairs(result) do
    local uri = loc.uri or loc.targetUri
    local range = loc.range or loc.targetSelectionRange or loc.targetRange
    if uri and range then
      local path = uri:match("^file:") and vim.uri_to_fname(uri) or uri
      list[#list + 1] = { path = path, line = range.start.line + 1, column = range.start.character + 1 }
    end
  end
  return list
end

local function line_of(path, line)
  local buf = vim.fn.bufnr(path)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    return (vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or "")
  end
  if vim.fn.filereadable(path) == 1 then return vim.fn.readfile(path, "", line)[line] or "" end
  return ""
end

local function locations_text(list, limit)
  local lines = {}
  for i, l in ipairs(list) do
    if i > limit then
      lines[#lines + 1] = ("... and %d more"):format(#list - limit)
      break
    end
    lines[#lines + 1] = ("%s:%d:%d: %s"):format(rel(l.path), l.line, l.column, vim.trim(line_of(l.path, l.line)))
  end
  return table.concat(lines, "\n")
end

-- A language server of `buf` that does `method`, once one attached (a big one, jdtls, takes a while)
local function client_for(buf, method, done)
  local function find()
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      if c:supports_method(method, buf) then return c end
    end
  end
  when(find, 30000, function() done(find()) end)
end

-- The position of `symbol` in line `line` of `buf` (or `column`), in the server's encoding
local function position(buf, client, line, symbol, column)
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
  if not text then return nil, ("%s has no line %d"):format(rel(vim.api.nvim_buf_get_name(buf)), line) end
  local byte
  if type(symbol) == "string" and symbol ~= "" then
    local s = text:find(symbol, 1, true)
    if not s then return nil, ("%q is not in line %d: %s"):format(symbol, line, vim.trim(text)) end
    byte = s - 1
  else
    byte = math.max(0, (tonumber(column) or 1) - 1)
  end
  byte = math.min(byte, #text)
  return { line = line - 1, character = vim.str_utfindex(text, client.offset_encoding, byte, false) }
end

local function at_symbol(name, method, args, reply, handle)
  local path = M.resolve(args.path)
  local line = tonumber(args.line)
  if not path or not line then return reply(error_result(name .. " needs path and line (and symbol or column)")) end
  local buf = load(path)
  if not buf then return reply(error_result("No such file: " .. path)) end
  client_for(buf, method, function(client)
    if not client then
      return reply(error_result(("No language server for %s does %s (none attached in 30 s)"):format(rel(path), method)))
    end
    local pos, why = position(buf, client, math.floor(line), args.symbol, args.column)
    if not pos then return reply(error_result(why)) end
    local params = { textDocument = { uri = vim.uri_from_bufnr(buf) }, position = pos }
    if method == "textDocument/references" then params.context = { includeDeclaration = true } end
    client:request(method, params, function(err, result)
      if err then return reply(error_result(("%s: %s"):format(client.name, err.message or vim.inspect(err)))) end
      handle(locations(result), client)
    end, buf)
  end)
end

function T.goto_definition(args, reply)
  at_symbol("goto_definition", "textDocument/definition", args, reply, function(list)
    if #list == 0 then return reply(text_result("The language server knows no definition there")) end
    if args.show and vim.fn.filereadable(list[1].path) == 1 then -- not a library's jdt:// class
      return T.open_file({ path = list[1].path, line = list[1].line, column = list[1].column }, function()
        reply(text_result("Shown in the editor:\n" .. locations_text(list, 20)))
      end)
    end
    reply(text_result(locations_text(list, 20)))
  end)
end

function T.find_references(args, reply)
  at_symbol("find_references", "textDocument/references", args, reply, function(list)
    if #list == 0 then return reply(text_result("The language server knows no references there")) end
    table.sort(list, function(a, b) return a.path == b.path and a.line < b.line or a.path < b.path end)
    if args.show then
      local items = {}
      for _, l in ipairs(list) do
        items[#items + 1] = { filename = l.path, lnum = l.line, col = l.column, text = vim.trim(line_of(l.path, l.line)) }
      end
      vim.fn.setqflist({}, " ", { title = "References (from the agent)", items = items })
      vim.cmd("botright copen")
    end
    reply(text_result(("%d reference%s%s:\n%s"):format(#list, #list == 1 and "" or "s", args.show and ", shown in the quickfix list" or "",
      locations_text(list, 200))))
  end)
end

local KINDS = vim.lsp.protocol.SymbolKind

function T.find_symbol(args, reply)
  local query = type(args.query) == "string" and vim.trim(args.query) or ""
  if query == "" then return reply(error_result("find_symbol needs a query")) end
  local clients = vim.tbl_filter(function(c) return c:supports_method("workspace/symbol") end, vim.lsp.get_clients())
  if #clients == 0 then
    return reply(error_result("No language server runs in Neovim yet (they start with the first file of their language)"))
  end
  local pending, found = #clients, {}
  local function finish()
    if #found == 0 then return reply(text_result(("No symbol matches %q"):format(query))) end
    local lines = {}
    for i, s in ipairs(found) do
      if i > 100 then
        lines[#lines + 1] = ("... and %d more"):format(#found - 100)
        break
      end
      lines[#lines + 1] = ("%s %s%s - %s:%d"):format(KINDS[s.kind] or "?", s.name, s.container and (" in " .. s.container) or "", rel(s.path), s.line)
    end
    reply(text_result(table.concat(lines, "\n")))
  end
  local timer = vim.defer_fn(function()
    if pending > 0 then
      pending = 0
      finish()
    end
  end, 15000)
  for _, client in ipairs(clients) do
    client:request("workspace/symbol", { query = query }, function(_, result)
      if pending <= 0 then return end -- answered already (the time was up)
      for _, s in ipairs(type(result) == "table" and result or {}) do
        local loc = s.location and locations(s.location)[1]
        if loc then
          found[#found + 1] = { name = s.name, kind = s.kind, container = s.containerName ~= "" and s.containerName or nil, path = loc.path, line = loc.line }
        end
      end
      pending = pending - 1
      if pending == 0 then
        timer:stop()
        finish()
      end
    end)
  end
end

-- ── What the agent sees ────────────────────────────────────────

local function schema(props, required) return { type = "object", properties = props, required = required } end
local str = function(d) return { type = "string", description = d } end
local int = function(d) return { type = "integer", description = d } end
local bool = function(d) return { type = "boolean", description = d } end

local DEFS = {
  { name = "show_in_file_tree", impl = T.show_in_file_tree,
    description = "Show the user a file or folder in Neovim's file tree: the tree opens, the item is revealed and highlighted. Or search the tree with `search`: it shows the matches (fuzzy by name; with regex=true a regex or a glob like '.*\\.sh$' or '*.sh', matched against the name - or the path below the project when it contains a /). Returns what the tree shows.",
    inputSchema = schema({
      path = str("File or folder to reveal - absolute, or relative to the project"),
      search = str("Text to search the tree for, instead of a path"),
      regex = bool("search is a regex or glob (default: fuzzy)"),
      folders = bool("Search folders instead of files"),
    }) },
  { name = "open_file", impl = T.open_file,
    description = "Open a file in the user's editor window, at a line, and light up lines line..end_line - to show the user the code you talk about.",
    inputSchema = schema({
      path = str("The file - absolute, or relative to the project"),
      line = int("Line to go to (1-based)"),
      end_line = int("Last line to light up"),
      column = int("Column (1-based)"),
    }, { "path" }) },
  { name = "show_locations", impl = T.show_locations,
    description = "List several places for the user - search hits, usages, errors - in Neovim's quickfix list, which opens; the user jumps through them.",
    inputSchema = schema({
      title = str("Title of the list"),
      locations = { type = "array", description = "The places", items = schema({
        path = str("File - absolute, or relative to the project"), line = int("Line (1-based)"),
        column = int("Column (1-based)"), text = str("What is there"),
      }, { "path", "line" }) },
    }, { "locations" }) },
  { name = "editor_state", impl = T.editor_state,
    description = "What the user has open in Neovim: the current file, cursor, visible lines, selected text, unsaved changes, the open files (most recent first), the project folder.",
    inputSchema = { type = "object" } },
  { name = "diagnostics", impl = T.diagnostics,
    description = "Errors and warnings from Neovim's language servers and linters - of one file (it is loaded and checked), or of all files open in Neovim.",
    inputSchema = schema({ path = str("The file (absolute, or relative to the project); none: all open files") }) },
  { name = "find_symbol", impl = T.find_symbol,
    description = "Where a class, function, method or variable is defined, by name, from the language servers running in Neovim (workspace symbols).",
    inputSchema = schema({ query = str("The name, or part of it") }, { "query" }) },
  { name = "goto_definition", impl = T.goto_definition,
    description = "The definition of the symbol at a place, from the language server (precise where text search is not: overloads, imports, libraries). With show=true it opens in the user's editor.",
    inputSchema = schema({
      path = str("The file - absolute, or relative to the project"), line = int("Line (1-based)"),
      symbol = str("The symbol's name as written in that line"), column = int("Instead of symbol: column (1-based)"),
      show = bool("Open it in the user's editor"),
    }, { "path", "line" }) },
  { name = "find_references", impl = T.find_references,
    description = "Every use of the symbol at a place, from the language server. With show=true they go into the user's quickfix list.",
    inputSchema = schema({
      path = str("The file - absolute, or relative to the project"), line = int("Line (1-based)"),
      symbol = str("The symbol's name as written in that line"), column = int("Instead of symbol: column (1-based)"),
      show = bool("Show them in the user's quickfix list"),
    }, { "path", "line" }) },
  { name = "notify", impl = T.notify,
    description = "Show the user a short message in Neovim (a notification) - e.g. that a long task is done.",
    inputSchema = schema({ message = str("The message"), level = str("info, warn or error") }, { "message" }) },
}

function M.definitions()
  local list = {}
  for _, d in ipairs(DEFS) do list[#list + 1] = { name = d.name, description = d.description, inputSchema = d.inputSchema } end
  return list
end

function M.call(name, args, reply)
  for _, d in ipairs(DEFS) do
    if d.name == name then return d.impl(args, reply) end
  end
  reply(error_result("No such tool: " .. tostring(name)))
end

return M
