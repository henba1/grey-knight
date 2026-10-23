-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The agent's edits, reviewed where they are: in the file's   ║
-- ║  own buffer, as Zed and Cursor show them. Before an edit the ║
-- ║  agent's hook notes the file; after it, the buffer shows the ║
-- ║  change - the old lines in red above, the new ones green,    ║
-- ║  the changed words stronger - until each change is kept or   ║
-- ║  reverted: <leader>ay / <leader>an (the file: aY / aN) or a  ║
-- ║  click on the Accept / Reject bar under each change,         ║
-- ║  ]c / [c between them, <leader>ar lists all of them.         ║
-- ║  A window following the agent (<leader>af) goes to each edit ║
-- ║  as it lands - the file tree, when open, shows the file too. ║
-- ║  Both agents: Qwen Code's PreToolUse / PostToolUse hooks,    ║
-- ║  OpenCode's plugin (agent_link.lua).                         ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local WIN = vim.fn.has("win32") == 1
local ns = vim.api.nvim_create_namespace("greyknight_agent_review")

--- The files under review: key -> { path, ref = the lines to compare with (the file before the agent's first edit,
--- with what the user kept since), new = the file did not exist, agent = who edited it, edits = how many edits came }
M.files = {}
--- The windows that follow the agent: window -> its winbar before
M.followers = {}
--- What the user reverted, newest last (at most 20): { path, lines, time } - the agent reads it (editor_state)
M.reverted = {}
--- Content of a Qwen Code diff the user accepted (agent_ide.lua): key -> lines - that edit needs no second review
M.accepted = {}
--- Off: the agent's edits are not shown for review (vim.g.greyknight_agent_review = false as well)
M.enabled = true

local function key(path) return WIN and path:lower() or path end
local function norm(path)
  local p = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  if #p > 1 and not p:match("^%a:/$") then p = p:gsub("/$", "") end
  return p
end
local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "The agent's edits" }) end

local function rel(path)
  local cwd = vim.fs.normalize(vim.fn.getcwd(-1, -1))
  if vim.startswith(key(path), key(cwd) .. "/") then return path:sub(#cwd + 2) end
  return vim.fn.fnamemodify(path, ":~")
end

local function on() return M.enabled and vim.g.greyknight_agent_review ~= false end

--- The loaded buffer of a file, or nil
local function buf_of(path)
  local k = key(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" and key(norm(name)) == k then return b end
    end
  end
end

--- The review of a buffer's file, or nil (one the agent edited: a note before an edit alone is none)
local function file_of(buf)
  if buf == 0 then buf = vim.api.nvim_get_current_buf() end
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return nil end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return nil end
  local f = M.files[key(norm(name))]
  return f and f.edits > 0 and f or nil
end

local function read(path)
  if not vim.uv.fs_stat(path) then return nil end
  return vim.fn.readfile(path)
end

local function text(lines) return #lines == 0 and "" or table.concat(lines, "\n") .. "\n" end
local diff = (vim.text and vim.text.diff) or vim.diff

--- The changes from `ref` to `lines`: { { ref_start, ref_count, start, count } ... } - vim.diff's indices
function M.hunks(ref, lines)
  return diff(text(ref), text(lines), { result_type = "indices", algorithm = "histogram", linematch = 60 }) or {}
end

-- Words, runs of spaces, single other characters (a multibyte one whole): what a line's change is measured in
local function tokens(s)
  local list, pos, i = {}, {}, 1
  while i <= #s do
    local a, b = s:find("^[%w_]+", i)
    if not a then a, b = s:find("^%s+", i) end
    if not a then
      local c = s:byte(i)
      a, b = i, i + (c >= 0xF0 and 3 or c >= 0xE0 and 2 or c >= 0xC0 and 1 or 0)
    end
    list[#list + 1], pos[#pos + 1] = s:sub(a, b), a - 1
    i = b + 1
  end
  pos[#pos + 1] = #s
  return list, pos
end

--- The changed parts of a line: byte ranges { from, to } (to exclusive) in the old line and in the new one
function M.spans(old, new)
  if old == new or #old > 500 or #new > 500 then return {}, {} end
  local ta, pa = tokens(old)
  local tb, pb = tokens(new)
  local a, b = {}, {}
  for _, h in ipairs(diff(text(ta), text(tb), { result_type = "indices", algorithm = "minimal" }) or {}) do
    if h[2] > 0 then a[#a + 1] = { pa[h[1]], pa[h[1] + h[2]] } end
    if h[4] > 0 then b[#b + 1] = { pb[h[3]], pb[h[3] + h[4]] } end
  end
  return a, b
end

-- ── Colors ─────────────────────────────────────────────────────

local function colors()
  pcall(function() require("integrations.agent_ide").ensure_colors() end) -- the diffs' greens and reds
  local function set(name, link) vim.api.nvim_set_hl(0, name, { link = link, default = true }) end
  set("GreyKnightReviewAdd", "GreyKnightDiffAdded")
  set("GreyKnightReviewChange", "GreyKnightDiffChangedNew")
  set("GreyKnightReviewText", "GreyKnightDiffTextNew")
  set("GreyKnightReviewDelete", "GreyKnightDiffRemoved")
  set("GreyKnightReviewDeleteText", "GreyKnightDiffTextOld")
  set("GreyKnightReviewAddSign", "Added")
  set("GreyKnightReviewChangeSign", "Changed")
  set("GreyKnightReviewDeleteSign", "Removed")
  set("GreyKnightReviewHint", "Comment")
  set("GreyKnightReviewAccept", "GreyKnightDiffKeep")
  set("GreyKnightReviewReject", "GreyKnightDiffRevert")
  set("GreyKnightFollow", "IncSearch")
end

-- ── Showing a review ───────────────────────────────────────────

-- The width of the text area of the windows showing `buf`: the widest (the old lines' red runs across it), the
-- narrowest (the bar under a change fits it)
local function width(buf)
  local w, narrow = 0, math.huge
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    local info = vim.fn.getwininfo(win)[1]
    if info then
      w = math.max(w, info.width - info.textoff)
      narrow = math.min(narrow, info.width - info.textoff)
    end
  end
  return w > 0 and w or 100, narrow < math.huge and math.max(narrow, 1) or 100
end

--- The lines of a change in the buffer: first, last (a change that only removed lines: the line its old ones show at)
local function span_of(h)
  if h[4] > 0 then return h[3], h[3] + h[4] - 1 end
  local l = math.max(h[3], 1)
  return l, l
end
M.span_of = span_of

local function leader()
  local l = vim.g.mapleader
  return (l == nil or l == "") and "\\" or l == " " and "␣" or l
end

--- The bar under a change, fitted to `w` columns: the buttons, then who made it and the keys - on lines of their own
--- when the window is narrow, never cut off. Returns its virtual lines and the buttons' columns { from, to }
function M.bar(agent, w)
  local lead = leader()
  local dw = vim.fn.strdisplaywidth
  local accept, reject -- the widest that fits: with the keys, without, the marks alone
  for _, b in ipairs({ { (" ✓ Accept %say "):format(lead), (" ✗ Reject %san "):format(lead) },
    { " ✓ Accept ", " ✗ Reject " }, { " ✓ ", " ✗ " } }) do
    accept, reject = b[1], b[2]
    if dw(accept .. " " .. reject) <= w then break end
  end
  local aw, rw = dw(accept), dw(reject)
  local lines = { { { accept, "GreyKnightReviewAccept" }, { " " }, { reject, "GreyKnightReviewReject" } } }
  local cols = { accept = { 0, aw }, reject = { aw + 1, aw + 1 + rw } }
  -- then who made it and the keys: a part that does not fit goes on a line of its own, one longer than the window in
  -- pieces of its width
  local used, sep = aw + 1 + rw, "   "
  for _, part in ipairs({ agent or "agent", "]c next", lead .. "ar lists all" }) do
    if used > 0 and used + dw(sep .. part) > w then
      lines[#lines + 1] = {}
      used, sep = 0, ""
    end
    while dw(part) > w - used do
      local piece = vim.fn.strcharpart(part, 0, math.max(w - used, 1))
      table.insert(lines[#lines], { piece, "GreyKnightReviewHint" })
      lines[#lines + 1] = {}
      part, used = vim.fn.strcharpart(part, vim.fn.strchars(piece)), 0
    end
    table.insert(lines[#lines], { sep .. part, "GreyKnightReviewHint" })
    used, sep = used + dw(sep .. part), " · "
  end
  return lines, cols
end

--- Draws the review of `buf`; returns its changes (none: nothing drawn)
function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return {} end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local f = file_of(buf)
  if not f then return {} end
  colors()
  local cur = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = M.hunks(f.ref, cur)
  f.hunks, f.bars = hunks, {}
  local w, narrow = width(buf)
  local ts, count = vim.bo[buf].tabstop, #cur
  local function expand(s) return (s:gsub("\t", string.rep(" ", ts))) end
  local from -- the first line of the changes one after the other: one bar under them all
  for i, h in ipairs(hunks) do
    local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
    local paired = math.min(ca, cb) -- old and new lines side by side: a changed line, its words compared
    local bar, cols = M.bar(f.agent, narrow)
    local first, last = span_of(h)
    from = from or first
    local nxt = hunks[i + 1]
    local block = not nxt or span_of(nxt) > last + 1 -- the last of them: the bar goes here
    local on_old = false -- the bar goes with the old lines when they show under the same line
    if ca > 0 then
      local virt = {}
      for i = 0, ca - 1 do
        local old = f.ref[sa + i] or ""
        local olds = i < paired and M.spans(old, cur[sb + i] or "") or {}
        local chunks, at = {}, 0
        for _, s in ipairs(olds) do
          if s[1] > at then chunks[#chunks + 1] = { expand(old:sub(at + 1, s[1])), "GreyKnightReviewDelete" } end
          chunks[#chunks + 1] = { expand(old:sub(s[1] + 1, s[2])), "GreyKnightReviewDeleteText" }
          at = s[2]
        end
        if at < #old then chunks[#chunks + 1] = { expand(old:sub(at + 1)), "GreyKnightReviewDelete" } end
        local used = vim.fn.strdisplaywidth(expand(old))
        if used < w then chunks[#chunks + 1] = { string.rep(" ", w - used), "GreyKnightReviewDelete" } end
        virt[#virt + 1] = chunks
      end
      local row, above
      if cb > 0 then
        row, above = sb - 1, true
      elseif sb == 0 then
        row, above = 0, true
      else
        row, above = math.min(sb, count) - 1, false
      end
      if block and not above and row == last - 1 then
        f.bars[#f.bars + 1] = { line = last, offset = #virt, first = from, last = last, cols = cols }
        vim.list_extend(virt, bar)
        on_old = true
      end
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { virt_lines = virt, virt_lines_above = above, priority = 200 })
      if cb == 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { sign_text = "-", sign_hl_group = "GreyKnightReviewDeleteSign", priority = 200 })
      end
    end
    for i = 0, cb - 1 do
      local row, added = sb - 1 + i, i >= paired
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        line_hl_group = added and "GreyKnightReviewAdd" or "GreyKnightReviewChange",
        sign_text = added and "+" or "~",
        sign_hl_group = added and "GreyKnightReviewAddSign" or "GreyKnightReviewChangeSign",
        priority = 200,
      })
      if not added then
        local _, news = M.spans(f.ref[sa + i] or "", cur[sb + i] or "")
        for _, s in ipairs(news) do
          if s[2] > s[1] then
            vim.api.nvim_buf_set_extmark(buf, ns, row, s[1], { end_col = s[2], hl_group = "GreyKnightReviewText", priority = 201 })
          end
        end
      end
    end
    if block and not on_old and last <= count then
      f.bars[#f.bars + 1] = { line = last, offset = 0, first = from, last = last, cols = cols }
      vim.api.nvim_buf_set_extmark(buf, ns, last - 1, 0, { virt_lines = bar, priority = 199 })
    end
    if block then from = nil end
  end
  return hunks
end

local function hunk_at(f, first, last)
  local list = {}
  for _, h in ipairs(f.hunks or {}) do
    local a, b = span_of(h)
    if a <= last and b >= first then list[#list + 1] = h end
  end
  return list
end

--- The bar's button under the mouse: "accept" / "reject", its window's buffer and the bar ({ first, last }) - or nil
function M.button_at(pos)
  pos = pos or vim.fn.getmousepos()
  local win = pos.winid
  if not win or win == 0 or not vim.api.nvim_win_is_valid(win) then return nil end
  local buf = vim.api.nvim_win_get_buf(win)
  local f = file_of(buf)
  if not f or not f.bars or #f.bars == 0 then return nil end
  local info = vim.fn.getwininfo(win)[1]
  local col = pos.wincol - 1 - info.textoff -- 0-based, in the text area (where virtual lines start)
  for _, b in ipairs(f.bars) do
    local at = vim.fn.screenpos(win, b.line, 1).row
    if at > 0 then
      -- the line's own screen rows: from its first column to its end, not the virtual lines around it
      local eol = vim.api.nvim_win_call(win, function() return vim.fn.virtcol({ b.line, "$" }) end) - 1
      local rows = vim.api.nvim_win_text_height(win, { start_row = b.line - 1, end_row = b.line - 1, start_vcol = 0, end_vcol = eol }).all
      if pos.screenrow == at + math.max(rows, 1) + b.offset then
        for which, c in pairs(b.cols) do
          if col >= c[1] and col < c[2] then return which, buf, b end
        end
        return nil
      end
    end
  end
end

-- ]c / [c in a buffer under review where gitsigns has none (a file outside git): the review's own
local mapped = {}
local function map(buf)
  if mapped[buf] or not vim.api.nvim_buf_is_valid(buf) then return end
  local own = {}
  vim.api.nvim_buf_call(buf, function()
    for _, lhs in ipairs({ "]c", "[c" }) do
      if vim.fn.maparg(lhs, "n", false, true).buffer ~= 1 then -- gitsigns' (plugins/editor.lua) asks the review first
        vim.keymap.set("n", lhs, function()
          if not M.jump(lhs == "]c" and 1 or -1) then vim.cmd.normal({ lhs, bang = true }) end
        end, { buffer = buf, desc = lhs == "]c" and "Agent: next change" or "Agent: previous change" })
        own[#own + 1] = lhs
      end
    end
  end)
  mapped[buf] = own
end
local function unmap(buf)
  local own = mapped[buf]
  mapped[buf] = nil
  if not own or not vim.api.nvim_buf_is_valid(buf) then return end
  for _, lhs in ipairs(own) do pcall(vim.keymap.del, "n", lhs, { buffer = buf }) end
end

--- Whether `buf` (0: the current one) shows a review
function M.active(buf) return file_of(buf or 0) ~= nil end

--- The review of a file by its path (on Windows any case), or nil
function M.entry(path) return type(path) == "string" and M.files[key(norm(path))] or nil end

--- To the next (dir 1) or previous (-1) change of the review in the current buffer; false: there is none
function M.jump(dir)
  local buf = vim.api.nvim_get_current_buf()
  if not file_of(buf) then return false end
  local hunks = M.render(buf)
  if #hunks == 0 then return false end
  local line, target = vim.fn.line("."), nil
  if dir > 0 then
    for _, h in ipairs(hunks) do
      local a = span_of(h)
      if a > line then target = a break end
    end
    target = target or span_of(hunks[1])
  else
    for i = #hunks, 1, -1 do
      local a = span_of(hunks[i])
      if a < line then target = a break end
    end
    target = target or span_of(hunks[#hunks])
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zv")
  return true
end

--- The review of a file ends: its marks go
function M.stop(path)
  path = norm(path)
  M.files[key(path)] = nil
  local buf = buf_of(path)
  if buf then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    unmap(buf)
  end
end

-- ── Following the agent ────────────────────────────────────────

local FOLLOW_BAR = "%#GreyKnightFollow# ◉ follows the agent %* %f %m   <leader>af stops"

local function follow_bar(win)
  colors()
  vim.wo[win].winbar = FOLLOW_BAR
end

--- The window follows the agent (or stops). The agent's terminal or the tree current: the window with code next
--- to them; none there: one is made.
function M.toggle_follow()
  local win = vim.api.nvim_get_current_win()
  if M.followers[win] ~= nil then return M.unfollow(win) end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.api.nvim_win_get_config(win).relative ~= "" or vim.bo[buf].buftype ~= "" then
    win = require("integrations.agent_link").code_window()
    if win and M.followers[win] ~= nil then return M.unfollow(win) end
    if not win then
      vim.cmd("leftabove vnew")
      win = vim.api.nvim_get_current_win()
    end
  end
  M.followers[win] = vim.wo[win].winbar
  follow_bar(win)
  notify("This window follows the agent: each of its edits shows here as it lands - <leader>af again stops")
end

function M.unfollow(win)
  local bar = M.followers[win]
  M.followers[win] = nil
  if vim.api.nvim_win_is_valid(win) then
    vim.wo[win].winbar = bar or ""
    -- the file window's own bar again (config/winbar.lua) - also when the window had none before it followed
    pcall(function() require("config.winbar").update(win) end)
  end
  notify("This window no longer follows the agent")
end

--- Whether `win` follows the agent
function M.following(win) return M.followers[win or vim.api.nvim_get_current_win()] ~= nil end

-- The file tree, when it is open and not in a search: the file revealed - the user's window stays current
local function tree_show(path)
  local ok, p = pcall(function() return Snacks.picker.get({ source = "explorer" })[1] end)
  if not ok or not p or p.closed or not p.list.win:valid() then return end
  local f = p.input and p.input.filter or {}
  if (f.pattern or "") ~= "" or (f.search or "") ~= "" then return end
  local cur = vim.api.nvim_get_current_win()
  pcall(Snacks.explorer.reveal, { file = path })
  if vim.api.nvim_win_is_valid(cur) and vim.api.nvim_get_current_win() ~= cur then vim.api.nvim_set_current_win(cur) end
end

--- The windows following the agent show `path` at `line` (the user stays in their window); the tree shows it too
local function follow(path, line)
  local any = false
  for win in pairs(M.followers) do
    if not vim.api.nvim_win_is_valid(win) then
      M.followers[win] = nil
    else
      any = true
      local buf = buf_of(path)
      if not buf then
        buf = vim.fn.bufadd(path)
        vim.bo[buf].buflisted = true
        vim.fn.bufload(buf)
      end
      if vim.api.nvim_win_get_buf(win) ~= buf then vim.api.nvim_win_set_buf(win, buf) end
      follow_bar(win) -- the winbar comes with the buffer in that window: again after the swap
      local l = math.max(1, math.min(line or 1, vim.api.nvim_buf_line_count(buf)))
      pcall(vim.api.nvim_win_set_cursor, win, { l, 0 })
      vim.api.nvim_win_call(win, function() vim.cmd("normal! zvzz") end)
      M.render(buf)
    end
  end
  if any then tree_show(path) end
end

-- ── The agent's edits come in ──────────────────────────────────

-- The file as the agent found it when it started (agent_changes.lua noted the project): { lines, new }, or nil
-- (no project noted, or the file was untracked then - no snapshot of it)
local function baseline(path)
  local ok, res = pcall(function()
    local changes = require("integrations.agent_changes")
    local root = changes.root(vim.fs.dirname(path))
    local start = root and changes.starts[root]
    if not start or not vim.startswith(key(path), key(root) .. "/") then return nil end
    local name = path:sub(#root + 2)
    local lines = changes.before(root, name)
    if lines then return { lines = lines, new = false } end
    if start.untracked[name] then return nil end
    return { lines = {}, new = true } -- not there when the agent started
  end)
  if ok and type(res) == "table" then return res end
end

--- Before the agent edits `path`: the file as it is now is what the review compares with - unless it is under
--- review already, then that stays (the file before the agent's first edit)
function M.before(path, agent)
  if not on() or type(path) ~= "string" or path == "" then return end
  path = norm(path)
  local k = key(path)
  local lines = read(path)
  if M.files[k] then
    M.files[k].disk = lines -- the file just before this edit (after(): unsaved changes that are none)
    return
  end
  M.files[k] = { path = path, ref = lines or {}, new = lines == nil, agent = agent, edits = 0, disk = lines }
end

local last_word = {} -- key -> when the user last heard of an edit of that file (ms)

-- A word about an edit the user does not see: in no window of this tab
local function announce(f, buf, hunks)
  if buf and #vim.fn.win_findbuf(buf) > 0 then return end
  local k = key(f.path)
  if last_word[k] and vim.uv.now() - last_word[k] < 5000 then return end
  last_word[k] = vim.uv.now()
  local add, del = 0, 0
  for _, h in ipairs(hunks) do add, del = add + h[4], del + h[2] end
  notify(("%s edited %s (+%d -%d) - <leader>ar lists the changes to keep or revert"):format(f.agent or "The agent", rel(f.path), add, del))
end

--- After the agent edited `path`: its buffer takes the new text (unless the user has unsaved changes in it) and
--- shows the change; the windows following the agent go there
function M.after(path, agent)
  if not on() or type(path) ~= "string" or path == "" then return end
  path = norm(path)
  local k = key(path)
  local f = M.files[k]
  if not f then
    local base = baseline(path) -- no word before the edit (a shell command, a hook that did not run)
    if not base then return end
    f = { path = path, ref = base.lines or {}, new = base.new == true, agent = agent, edits = 0 }
    M.files[k] = f
  end
  f.agent = agent or f.agent
  f.edits = f.edits + 1
  local accepted = M.accepted[k]
  M.accepted[k] = nil
  local disk = f.disk
  f.disk = nil
  local now = read(path)
  if now == nil and f.new then return M.stop(path) end -- made and gone again
  now = now or {}
  local buf = buf_of(path)
  local shown = buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or f.last or f.ref
  if buf then
    -- "modified", yet the text is the file's as it was before this edit: edits undone by hand (a typed letter
    -- deleted again) leave the flag. Those are no changes to keep - the agent's text comes in. It stayed out, the
    -- buffer showed the file without the agent's edit and "unsaved changes" (CHEATSHEET.md, 2026-10-23).
    if vim.bo[buf].modified and disk and vim.deep_equal(shown, disk) then vim.bo[buf].modified = false end
    if vim.bo[buf].modified then
      notify(("%s changed %s while you have unsaved changes in it - :e! takes its version, :w keeps yours")
        :format(f.agent or "The agent", rel(path)), vim.log.levels.WARN)
    else
      pcall(vim.cmd, "checktime " .. buf)
      if not vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), now) then
        vim.api.nvim_buf_call(buf, function() pcall(vim.cmd, "silent edit!") end)
      end
    end
  end
  f.last = now
  -- accepted in Qwen Code's diff, nothing before it waits: reviewed already. Or the agent put it back as it was.
  if (accepted and f.edits == 1 and vim.deep_equal(accepted, now)) or vim.deep_equal(f.ref, now) then
    return M.stop(path)
  end
  local hunks = M.hunks(f.ref, now)
  local moved = M.hunks(shown, now)[1] -- where this edit changed the file: a following window goes there
  local line = moved and span_of(moved) or (hunks[1] and span_of(hunks[1])) or 1
  -- the buffer took the agent's text: its review shows (with the user's unsaved changes in it: once they take the
  -- agent's version, :e! - BufReadPost below)
  if buf and not vim.bo[buf].modified then
    M.render(buf)
    map(buf)
  end
  follow(path, line)
  announce(f, buf_of(path), hunks)
end

--- Qwen Code's diff (agent_ide.lua) accepted with this content: the edit that writes it is reviewed already
function M.accept_content(path, content)
  if type(path) ~= "string" or type(content) ~= "string" then return end
  M.accepted[key(norm(path))] = content == "" and {} or vim.split((content:gsub("\r?\n$", "")), "\r?\n")
end

--- An agent's hook (agent_link.lua): "before" / "after" an edit - Qwen Code's tool_input.file_path, the files of
--- OpenCode's plugin; relative paths below the agent's folder (cwd)
function M.hook(event, id, payload)
  payload = type(payload) == "table" and payload or {}
  local input = type(payload.tool_input) == "table" and payload.tool_input or {}
  local list = {}
  for _, p in ipairs({ input.file_path, input.notebook_path, input.filePath }) do
    if type(p) == "string" and p ~= "" then list[#list + 1] = p end
  end
  for _, p in ipairs(type(payload.files) == "table" and payload.files or {}) do
    if type(p) == "string" and p ~= "" then list[#list + 1] = p end
  end
  local cwd = type(payload.cwd) == "string" and payload.cwd ~= "" and payload.cwd or vim.fn.getcwd(-1, -1)
  local who
  pcall(function()
    local term = id and require("toggleterm.terminal").get(id, true)
    who = term and term.display_name or require("integrations.agent").backend().name
  end)
  for _, p in ipairs(list) do
    if not (p:match("^/") or p:match("^%a:[/\\]") or p:match("^[/\\][/\\]")) then p = cwd .. "/" .. p end
    if event == "before" then M.before(p, who) else M.after(p, who) end
  end
end

-- ── Keeping and reverting ──────────────────────────────────────

local function keep(f, buf, h)
  local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
  local new = cb > 0 and vim.api.nvim_buf_get_lines(buf, sb - 1, sb - 1 + cb, false) or {}
  local p = ca > 0 and sa or sa + 1
  for _ = 1, ca do table.remove(f.ref, p) end
  for i, line in ipairs(new) do table.insert(f.ref, p + i - 1, line) end
end

local function revert(f, buf, h)
  local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
  local old = ca > 0 and vim.list_slice(f.ref, sa, sa + ca - 1) or {}
  local start = cb > 0 and sb - 1 or sb
  vim.api.nvim_buf_set_lines(buf, start, start + cb, false, old)
  local a, b = span_of(h)
  table.insert(M.reverted, { path = f.path, lines = a == b and tostring(a) or (a .. "-" .. b), time = os.time() })
  while #M.reverted > 20 do table.remove(M.reverted, 1) end
end

-- After a revert the file on disk is as the buffer: the agent works on the disk. Not when the user had unsaved
-- changes in it - they are the user's to save. No autocmds: no formatter rewrites what came back.
local function save(buf, had_changes)
  if had_changes then
    return notify("Reverted in the buffer - it has unsaved changes of yours: :w saves", vim.log.levels.WARN)
  end
  vim.api.nvim_buf_call(buf, function() vim.cmd("silent noautocmd keepalt update") end)
end

--- Keep (true) or revert (false) the agent's changes in `buf` (0: current) - those touching lines first..last
--- (default: the cursor's line), or all of the file. Returns how many.
function M.act(keep_it, all, first, last, buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local f = file_of(buf)
  if not f then
    notify("No edit of the agent to review here", vim.log.levels.WARN)
    return 0
  end
  M.render(buf)
  local chosen
  if all then
    chosen = vim.list_slice(f.hunks or {})
  else
    local at_cursor = first == nil
    first = first or vim.fn.line(".")
    chosen = hunk_at(f, first, last or first)
    -- The cursor off the changed lines - on the line under the bar, or elsewhere in the file. The keys did nothing
    -- but a warning, the user took it for keys that do not work (2026-10-23). One bar in the file: the keys are its
    -- buttons. More: the cursor goes to the nearest change, the same keys again act on it.
    if #chosen == 0 and at_cursor and #(f.bars or {}) == 1 then
      chosen = hunk_at(f, f.bars[1].first, f.bars[1].last)
    elseif #chosen == 0 and at_cursor and #(f.hunks or {}) > 0 and buf == vim.api.nvim_get_current_buf() then
      local best, dist
      for _, h in ipairs(f.hunks) do
        local a, b = span_of(h)
        local d = first < a and a - first or first - b
        if not dist or d < dist then best, dist = a, d end
      end
      vim.cmd("normal! m'")
      vim.api.nvim_win_set_cursor(0, { best, 0 })
      vim.cmd("normal! zv")
      notify(("Not on a change of the agent's - the cursor went to the nearest (line %d): %s again %s it")
        :format(best, keep_it and "<leader>ay" or "<leader>an", keep_it and "keeps" or "reverts"), vim.log.levels.WARN)
      return 0
    end
  end
  if #chosen == 0 then
    notify("No change of the agent's here - ]c goes to the next", vim.log.levels.WARN)
    return 0
  end
  local had_changes = vim.bo[buf].modified
  if not keep_it and f.new and all then -- a file the agent made, reverted whole: it goes
    table.insert(M.reverted, { path = f.path, lines = "all (a new file, deleted)", time = os.time() })
    M.stop(f.path)
    os.remove(f.path)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    notify(("Reverted %s: the agent made it - it is deleted"):format(rel(f.path)))
    return #chosen
  end
  for i = #chosen, 1, -1 do -- from the bottom: the changes above keep their lines
    if keep_it then keep(f, buf, chosen[i]) else revert(f, buf, chosen[i]) end
  end
  if not keep_it then save(buf, had_changes) end
  local left = M.render(buf)
  local word = ("%s %d change%s"):format(keep_it and "Kept" or "Reverted", #chosen, #chosen == 1 and "" or "s")
  if #left == 0 then
    M.stop(f.path)
    notify(word .. (" - %s is reviewed"):format(rel(f.path)))
  else
    notify(("%s - %d more in %s (]c)"):format(word, #left, rel(f.path)))
  end
  return #chosen
end

-- ── The list of all of them ────────────────────────────────────

--- Every change of the agent's waiting for review: { path, hunk, lines (the file now) }
function M.pending()
  local list = {}
  for _, f in pairs(M.files) do
    if f.edits > 0 then
      local buf = buf_of(f.path)
      local lines = buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or read(f.path) or {}
      for _, h in ipairs(M.hunks(f.ref, lines)) do list[#list + 1] = { path = f.path, hunk = h, lines = lines, ref = f.ref } end
    end
  end
  table.sort(list, function(a, b)
    if a.path ~= b.path then return a.path < b.path end
    return a.hunk[3] < b.hunk[3]
  end)
  return list
end

-- The buffer of a file, loaded (a change kept or reverted from the list)
local function load(path)
  local buf = buf_of(path)
  if buf then return buf end
  buf = vim.fn.bufadd(path)
  vim.bo[buf].buflisted = true
  vim.fn.bufload(buf)
  return buf
end

--- <leader>ar: every change of the agent's to review - Enter goes there; <c-y> keeps it, <c-x> reverts it
function M.pick()
  local function items()
    local list = {}
    for _, p in ipairs(M.pending()) do
      local h = p.hunk
      local first = span_of(h)
      local preview = {}
      for i = 0, h[2] - 1 do preview[#preview + 1] = "-" .. (p.ref[h[1] + i] or "") end
      for i = 0, h[4] - 1 do preview[#preview + 1] = "+" .. (p.lines[h[3] + i] or "") end
      list[#list + 1] = {
        file = p.path, pos = { first, 0 }, text = rel(p.path) .. ":" .. first .. " " .. table.concat(preview, " "),
        gk_line = first, gk_add = h[4], gk_del = h[2],
        preview = { text = table.concat(preview, "\n"), ft = "diff" },
      }
    end
    return list
  end
  if #items() == 0 then return notify("Nothing of the agent's waits for review") end
  local function act(picker, item, keep_it)
    if not item then return end
    local buf = load(item.file)
    if not file_of(buf) then return end
    M.render(buf)
    M.act(keep_it, false, item.gk_line, item.gk_line, buf)
    if #items() == 0 then return picker:close() end
    picker:find({ refresh = true })
  end
  Snacks.picker.pick({
    title = "The agent's edits to review",
    finder = function() return items() end,
    format = function(item)
      return {
        { rel(item.file), "SnacksPickerFile" }, { ":" .. item.gk_line, "SnacksPickerRow" }, { "  " },
        { "+" .. item.gk_add, "Added" }, { " -" .. item.gk_del, "Removed" },
      }
    end,
    preview = "preview",
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      local win = require("integrations.agent_link").code_window()
      if win then vim.api.nvim_set_current_win(win) end
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      pcall(vim.api.nvim_win_set_cursor, 0, { item.gk_line, 0 })
      vim.cmd("normal! zvzz")
      M.render(vim.api.nvim_get_current_buf())
    end,
    actions = {
      gk_keep = { action = function(picker, item) act(picker, item, true) end, desc = "Keep this change" },
      gk_revert = { action = function(picker, item) act(picker, item, false) end, desc = "Revert this change" },
    },
    win = {
      input = { keys = {
        ["<c-y>"] = { "gk_keep", mode = { "n", "i" }, desc = "Keep this change" },
        ["<c-x>"] = { "gk_revert", mode = { "n", "i" }, desc = "Revert this change" },
      } },
      list = { keys = { ["<c-y>"] = { "gk_keep", desc = "Keep this change" }, ["<c-x>"] = { "gk_revert", desc = "Revert this change" } } },
    },
  })
end

--- For the agent (editor_state): the files waiting for review and what the user reverted lately
function M.state()
  local files = {}
  for _, p in ipairs(M.pending()) do
    local r = rel(p.path)
    files[r] = (files[r] or 0) + 1
  end
  local reverted = {}
  for i = #M.reverted, math.max(1, #M.reverted - 9), -1 do
    local r = M.reverted[i]
    reverted[#reverted + 1] = { file = rel(r.path), lines = r.lines, seconds_ago = os.time() - r.time }
  end
  return { changes_waiting = next(files) and files or vim.empty_dict(), reverted_by_user = reverted }
end

-- ── Buffers ────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup("greyknight_agent_review", { clear = true })
-- a file under review opened (again), reloaded: its review shows
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
  group = group,
  callback = function(ev)
    if file_of(ev.buf) then
      M.render(ev.buf)
      map(ev.buf)
    end
    local win = vim.api.nvim_get_current_win()
    if M.followers[win] ~= nil and vim.api.nvim_win_get_buf(win) == ev.buf then follow_bar(win) end
  end,
})
-- the user edits it: the review follows
local timers = {}
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(ev)
    if not file_of(ev.buf) then return end
    if timers[ev.buf] then timers[ev.buf]:stop() end
    timers[ev.buf] = vim.defer_fn(function()
      timers[ev.buf] = nil
      if vim.api.nvim_buf_is_valid(ev.buf) then
        local left = M.render(ev.buf)
        local f = file_of(ev.buf)
        if f and #left == 0 then M.stop(f.path) end -- the user's own edit made it as it was
      end
    end, 150)
  end,
})
-- a window resized: the old lines' red and the bars fitted again
vim.api.nvim_create_autocmd("WinResized", {
  group = group,
  callback = function()
    local seen = {}
    for _, win in ipairs(vim.v.event.windows or {}) do
      local buf = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win)
      if buf and not seen[buf] and file_of(buf) then
        seen[buf] = true
        M.render(buf)
      end
    end
  end,
})
-- a click on a bar's Accept / Reject: that change kept / reverted (after the click: no edits in a mapping's <expr>)
vim.keymap.set("n", "<LeftMouse>", function()
  local which, buf, bar = M.button_at()
  if not which then return "<LeftMouse>" end
  vim.schedule(function() M.act(which == "accept", false, bar.first, bar.last, buf) end)
  return ""
end, { expr = true, desc = "Agent review: a click on Accept / Reject" })
vim.api.nvim_create_autocmd("WinClosed", {
  group = group,
  callback = function(ev) M.followers[tonumber(ev.match)] = nil end,
})

return M
