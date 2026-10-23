-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Qwen Code's IDE mode, with this Neovim as the IDE:          ║
-- ║  - each edit it proposes opens as a diff in a tab of its     ║
-- ║    own: the file now | the change. ga or :w accepts, q       ║
-- ║    rejects; the change can be edited first, do takes one     ║
-- ║    change back. Qwen Code writes the file once accepted.     ║
-- ║  - the files open here, the cursor and the selection go to   ║
-- ║    it as context.                                            ║
-- ║  Through agent_link.lua (the server's role "ide").           ║
-- ╚══════════════════════════════════════════════════════════════╝
local link = require("integrations.agent_link")
local M = {}

local WIN = vim.fn.has("win32") == 1

--- The diffs open now: file path -> { chan, path, tab, orig, prop, eol, nl, done, final }
M.views = {}

local function rel(path)
  local cwd = vim.fs.normalize(vim.fn.getcwd(-1, -1))
  local p = vim.fs.normalize(path)
  local k = function(s) return WIN and s:lower() or s end
  if vim.startswith(k(p), k(cwd) .. "/") then return p:sub(#cwd + 2) end
  return p
end

-- Lines of a text, whether it ends with a newline, and its newline (\r\n kept as it came)
local function split(text)
  local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
  local lines = vim.split(text, nl, { plain = true })
  local eol = #lines > 1 and lines[#lines] == ""
  if eol then table.remove(lines) end
  return lines, eol, nl
end

local function content_of(view)
  local lines = vim.api.nvim_buf_is_valid(view.prop) and vim.api.nvim_buf_get_lines(view.prop, 0, -1, false) or view.lines
  return table.concat(lines, view.nl) .. (view.eol and view.nl or "")
end

local function tell(view, method, params) link.send(view.chan, "notify", { method = method, params = params }) end

-- ── Colors: the old side red, the new side green ───────────────
-- As VS Code's and GitHub's reviews show it: removed red, added green, the changed words within a line in a stronger
-- shade of it. Vim colors both sides alike (DiffChange, DiffText); the windows of a review get colors of their own,
-- tinted from the colorscheme's red and green (and again when it changes).

local function rgb(n) return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256 end
local function pack(r, g, b)
  local function c(x) return math.max(0, math.min(255, math.floor(x + 0.5))) end
  return c(r) * 65536 + c(g) * 256 + c(b)
end
local function mix(a, b, t) -- t of the way from a to b
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  return pack(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
end
local function bg(name) return vim.api.nvim_get_hl(0, { name = name, link = false }).bg end

--- The review's colors from the colorscheme's: tints of its bright red and green (Removed / Added), so they show on
--- true black (OLED) too - DiffDelete / DiffAdd there are all but black
function M.colors()
  local base = bg("Normal") or 0x16181a -- a transparent background: cyberdream's
  local function fg(name) return vim.api.nvim_get_hl(0, { name = name, link = false }).fg end
  local red = fg("Removed") or fg("DiffDelete") or bg("DiffDelete") or 0xff6e5e
  local green = fg("Added") or fg("DiffAdd") or bg("DiffAdd") or 0x5eff6c
  local function set(name, spec) vim.api.nvim_set_hl(0, name, spec) end
  set("GreyKnightDiffRemoved", { bg = mix(base, red, 0.26) })
  set("GreyKnightDiffChangedOld", { bg = mix(base, red, 0.2) })
  set("GreyKnightDiffTextOld", { bg = mix(base, red, 0.5) })
  set("GreyKnightDiffAdded", { bg = mix(base, green, 0.24) })
  set("GreyKnightDiffChangedNew", { bg = mix(base, green, 0.18) })
  set("GreyKnightDiffTextNew", { bg = mix(base, green, 0.45) })
  set("GreyKnightDiffFiller", { fg = vim.api.nvim_get_hl(0, { name = "LineNr", link = false }).fg, bg = base })
  -- the review's buttons (agent_review.lua): keep / revert, the color itself
  set("GreyKnightDiffKeep", { fg = base, bg = green, bold = true })
  set("GreyKnightDiffRevert", { fg = base, bg = red, bold = true })
end

--- Each side's colors ('winhighlight'): on the old side DiffAdd is what only it has - removed lines
M.WINHL = {
  old = "DiffAdd:GreyKnightDiffRemoved,DiffChange:GreyKnightDiffChangedOld,DiffText:GreyKnightDiffTextOld,"
    .. "DiffTextAdd:GreyKnightDiffTextOld,DiffDelete:GreyKnightDiffFiller",
  new = "DiffAdd:GreyKnightDiffAdded,DiffChange:GreyKnightDiffChangedNew,DiffText:GreyKnightDiffTextNew,"
    .. "DiffTextAdd:GreyKnightDiffTextNew,DiffDelete:GreyKnightDiffFiller",
}

local colored = false
--- The colors made (once; again with each colorscheme) - the changes list's diffs use them too (agent_changes.lua)
function M.ensure_colors()
  if colored then return end
  colored = true
  M.colors()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("greyknight_agent_diff_colors", { clear = true }),
    callback = function() M.colors() end,
  })
end
local colors = M.ensure_colors

-- The view's tab goes (scheduled: an autocmd may not change the windows); its buffers with it
local function close(view)
  vim.schedule(function()
    if vim.api.nvim_tabpage_is_valid(view.tab) and #vim.api.nvim_list_tabpages() > 1 then
      pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(view.tab))
    end
    for _, buf in ipairs({ view.orig, view.prop }) do
      if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    end
  end)
end

--- The end of a review: "accepted", "rejected", "closed" (closeDiff; quiet: no notification), nil (the agent is
--- gone). Returns the content of the change as it was then.
local function finish(view, outcome, quiet)
  if view.done then return view.final end
  view.done = true
  view.final = content_of(view)
  if M.views[view.path] == view then M.views[view.path] = nil end
  if outcome == "accepted" then
    tell(view, "ide/diffAccepted", { filePath = view.path, content = view.final })
  elseif outcome == "rejected" then
    tell(view, "ide/diffRejected", { filePath = view.path })
  elseif outcome == "closed" and not quiet then
    tell(view, "ide/diffClosed", { filePath = view.path, content = view.final })
  end
  close(view)
  if outcome == "accepted" then
    -- reviewed here: the edit needs no second review in its buffer (agent_review.lua)
    pcall(function() require("integrations.agent_review").accept_content(view.path, view.final) end)
    -- Qwen Code writes the file now: a buffer of it takes the new text (autoread)
    for _, ms in ipairs({ 500, 2000, 5000 }) do vim.defer_fn(function() pcall(vim.cmd, "checktime") end, ms) end
  end
  return view.final
end

function M.accept(view) finish(view, "accepted") end
function M.reject(view) finish(view, "rejected") end

--- The view of the current tab, if it is one
function M.current()
  local tab = vim.api.nvim_get_current_tabpage()
  for _, view in pairs(M.views) do
    if view.tab == tab then return view end
  end
end

local function open_diff(chan, args, reply)
  local path, text = args.filePath, args.newContent
  if type(path) ~= "string" or path == "" or type(text) ~= "string" then
    return reply(link.result("openDiff needs filePath and newContent", true))
  end
  if M.views[path] then finish(M.views[path], nil) end -- an older one of the same file: replaced
  local lines, eol, nl = split(text)
  local name, ft = rel(path), vim.filetype.match({ filename = path }) or ""
  local exists = vim.fn.filereadable(path) == 1

  vim.cmd("tabnew")
  local tab, left, empty = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()

  local orig = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(orig, 0, -1, false, exists and vim.fn.readfile(path) or {})
  vim.api.nvim_buf_set_name(orig, "agent-diff://now/" .. name)
  vim.bo[orig].modifiable = false
  vim.bo[orig].bufhidden = "wipe"

  local prop = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(prop, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(prop, "agent-diff://change/" .. name)
  vim.bo[prop].buftype = "acwrite"
  vim.bo[prop].bufhidden = "wipe"
  vim.bo[prop].swapfile = false
  vim.bo[prop].modified = false

  vim.api.nvim_win_set_buf(left, orig)
  vim.cmd("rightbelow vsplit")
  local right = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right, prop)
  if vim.api.nvim_buf_is_valid(empty) and empty ~= orig and empty ~= prop then
    pcall(vim.api.nvim_buf_delete, empty, { force = true })
  end
  if ft ~= "" then
    vim.bo[orig].filetype = ft
    vim.bo[prop].filetype = ft
  end

  local view = { chan = chan, path = path, tab = tab, orig = orig, prop = prop, lines = lines, eol = eol, nl = nl }
  M.views[path] = view
  colors()
  for _, win in ipairs({ left, right }) do
    vim.api.nvim_win_call(win, function() vim.cmd("diffthis") end)
    vim.wo[win].foldenable = true
    vim.wo[win].fillchars = "diff:╱" -- lines only the other side has: hatched, as VS Code does
    vim.wo[win].winhighlight = win == left and M.WINHL.old or M.WINHL.new
  end
  local esc = name:gsub("%%", "%%%%")
  vim.wo[left].winbar = ("%%#DiffDelete# Now %%* %s%s"):format(esc, exists and "" or " (a new file)")
  vim.wo[right].winbar = ("%%#DiffAdd# Qwen's change %%* %s   ga or :w accepts · q rejects · do takes one change back · ]c next"):format(esc)

  for _, buf in ipairs({ orig, prop }) do
    vim.keymap.set("n", "ga", function() M.accept(view) end, { buffer = buf, desc = "Agent diff: Accept the change" })
    vim.keymap.set("n", "q", function() M.reject(view) end, { buffer = buf, desc = "Agent diff: Reject the change" })
  end
  local group = vim.api.nvim_create_augroup("greyknight_agent_diff_" .. prop, { clear = true })
  vim.api.nvim_create_autocmd("BufWriteCmd", { group = group, buffer = prop, callback = function() M.accept(view) end })
  -- closing it another way (:q, :tabclose, a deleted buffer) is a no
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    buffer = prop,
    callback = function() M.reject(view) end,
  })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    buffer = orig,
    callback = function() M.reject(view) end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(left), tostring(right) },
    callback = function() M.reject(view) end,
  })
  vim.api.nvim_set_current_win(right)
  vim.cmd("normal! gg") -- to the first change (]c from line 1 skips one there)
  if vim.fn.diff_hlID(1, 1) == 0 then pcall(vim.cmd, "normal! ]c") end
  vim.notify(("Qwen proposes a change to %s - ga accepts, q rejects"):format(name), vim.log.levels.INFO, { title = "Qwen" })
  reply({ content = {} }) -- opened; the outcome follows as a notification
end

local function close_diff(args, reply)
  local view = M.views[args.filePath]
  if not view then return reply(link.result(vim.json.encode({ content = vim.NIL }))) end
  local content = finish(view, "closed", args.suppressNotification == true)
  reply(link.result(vim.json.encode({ content = content })))
end

-- ── Context: the open files, the cursor, the selection ─────────

--- What Qwen Code gets as context (its IdeContext): the 10 files used last, the active one with cursor and selection
function M.context()
  local files, active = {}, link.active()
  local recent = link.recent_files(10)
  local newest = recent[1] and recent[1].time or 0
  for _, f in ipairs(recent) do
    local file = { path = f.path, timestamp = f.time }
    if active and f.buf == active.buf then
      file.timestamp = math.max(f.time, newest) -- Qwen Code takes the newest for the active one
      file.isActive = true
      if active.cursor then file.cursor = { line = active.cursor[1], character = active.cursor[2] + 1 } end
      file.selectedText = link.selection(f.buf)
    end
    files[#files + 1] = file
  end
  return { workspaceState = { openFiles = files } }
end

local timer
--- Something changed (agent_link.lua follows it): the context goes to Qwen Code a moment later, once
function M.context_changed()
  if not link.has("ide") then return end
  timer = timer or vim.uv.new_timer()
  timer:stop()
  timer:start(100, 0, vim.schedule_wrap(function() link.notify("ide", "ide/contextUpdate", M.context()) end))
end

-- ── The server's calls (agent_link.lua) ────────────────────────

function M.definitions()
  return {
    { name = "openDiff", description = "Open a diff of a proposed change to a file for the user to accept or reject",
      inputSchema = { type = "object", required = { "filePath", "newContent" },
        properties = { filePath = { type = "string" }, newContent = { type = "string" } } } },
    { name = "closeDiff", description = "Close the diff of a file; returns the change's content",
      inputSchema = { type = "object", required = { "filePath" },
        properties = { filePath = { type = "string" }, suppressNotification = { type = "boolean" } } } },
  }
end

function M.call(name, args, reply, chan)
  if name == "openDiff" then return open_diff(chan, args, reply) end
  if name == "closeDiff" then return close_diff(args, reply) end
  reply(link.result("No such tool: " .. tostring(name), true))
end

--- Qwen Code connected: the context at once
function M.ready(chan) link.send(chan, "notify", { method = "ide/contextUpdate", params = M.context() }) end

--- Its server is gone (Qwen Code quit): its diffs close without a word
function M.detached(chan)
  for _, view in pairs(M.views) do
    if view.chan == chan then finish(view, nil) end
  end
end

return M
