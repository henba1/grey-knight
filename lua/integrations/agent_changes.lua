-- ╔══════════════════════════════════════════════════════════════╗
-- ║  What changed since the agent started (<leader>ad). When the ║
-- ║  first agent starts in a project - and with a new session    ║
-- ║  (<leader>aC) - the project is noted: a git snapshot of its  ║
-- ║  tracked files (the user's index and HEAD stay untouched),   ║
-- ║  the names of its untracked ones. The list shows each file   ║
-- ║  changed since, its diff in the preview; Enter shows it side ║
-- ║  by side, dd / Ctrl+x take it back. Git projects only.       ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

--- A project's state when the agent started: root -> { commit, untracked = { path = true }, time (seconds since 1970) }
M.starts = {}

--- Noting the project (off in test runs: their agents start in GreyKnight's own repository - tests/harness.lua)
M.enabled = true

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Agent's changes" }) end

-- the snapshot's commit needs an author: GreyKnight's, not the user's settings (they may have none)
local IDENTITY = { GIT_AUTHOR_NAME = "GreyKnight", GIT_AUTHOR_EMAIL = "greyknight@localhost",
  GIT_COMMITTER_NAME = "GreyKnight", GIT_COMMITTER_EMAIL = "greyknight@localhost" }

-- git in `root`; done(result) later, or the result now
local function git(root, args, env, done)
  local cmd = vim.list_extend({ "git", "-C", root }, args)
  if done then
    return vim.system(cmd, { text = true, env = env }, function(res) vim.schedule(function() done(res) end) end)
  end
  return vim.system(cmd, { text = true, env = env }):wait()
end

local function now()
  local sec, usec = vim.uv.gettimeofday()
  return sec + usec / 1e6
end

--- The git repository of `dir`: its root, or nil
function M.root(dir)
  if vim.fn.executable("git") ~= 1 then return nil end
  local res = git(dir, { "rev-parse", "--show-toplevel" })
  if res.code ~= 0 then return nil end
  return vim.fs.normalize(vim.trim(res.stdout))
end

--- Note the project of `dir` as it is now - once (the first agent), again with `again` (a new session). The
--- tracked files go into a commit of their own through a copy of the index: the user's index, HEAD and branches stay
--- as they are (the commit is in no branch; git removes it in a few weeks). done(start) when it is noted.
function M.start(dir, again, done)
  if not M.enabled then
    if done then done(nil) end
    return
  end
  local root = M.root(dir or vim.fn.getcwd())
  if not root or (M.starts[root] and not again) then
    if done then done(root and M.starts[root]) end
    return
  end
  local time = now()
  local index = vim.fn.tempname() .. "-index"
  local real = vim.trim(git(root, { "rev-parse", "--git-path", "index" }).stdout or "")
  if real ~= "" and not (real:match("^/") or real:match("^%a:")) then real = root .. "/" .. real end
  if real ~= "" and vim.uv.fs_stat(real) then vim.uv.fs_copyfile(real, index) end
  local env = vim.tbl_extend("force", IDENTITY, { GIT_INDEX_FILE = index })
  local function fail() os.remove(index); if done then done(nil) end end
  git(root, { "add", "-u" }, env, function(added)
    if added.code ~= 0 then return fail() end
    git(root, { "write-tree" }, env, function(tree)
      os.remove(index)
      if tree.code ~= 0 then return fail() end
      git(root, { "commit-tree", vim.trim(tree.stdout), "-m", "GreyKnight: the project when the agent started" }, IDENTITY, function(commit)
        if commit.code ~= 0 then return fail() end
        git(root, { "ls-files", "--others", "--exclude-standard", "-z" }, nil, function(others)
          local untracked = {}
          for name in (others.stdout or ""):gmatch("[^%z]+") do untracked[name] = true end
          M.starts[root] = { commit = vim.trim(commit.stdout), untracked = untracked, time = time }
          if done then done(M.starts[root]) end
        end)
      end)
    end)
  end)
end

--- What changed in `root` since the agent started: { status = "M" | "A" | "D", path, untracked = true when the file
--- was untracked then (no snapshot of it) }, sorted by path; nil when no agent started there
function M.changes(root)
  local start = M.starts[root]
  if not start then return nil end
  local list = {}
  local fields = vim.split(git(root, { "diff", "--name-status", "--no-renames", "-z", start.commit }).stdout or "", "\0", { plain = true })
  for i = 1, #fields - 1, 2 do
    if fields[i] ~= "" and fields[i + 1] ~= "" then list[#list + 1] = { status = fields[i]:sub(1, 1), path = fields[i + 1] } end
  end
  for name in (git(root, { "ls-files", "--others", "--exclude-standard", "-z" }).stdout or ""):gmatch("[^%z]+") do
    if not start.untracked[name] then
      list[#list + 1] = { status = "A", path = name }
    else
      local stat = vim.uv.fs_stat(root .. "/" .. name)
      if stat and stat.mtime.sec + stat.mtime.nsec / 1e9 > start.time then
        list[#list + 1] = { status = "M", path = name, untracked = true }
      end
    end
  end
  table.sort(list, function(a, b) return a.path < b.path end)
  return list
end

--- The file's content when the agent started (lines), or nil when it was not there
function M.before(root, path)
  local res = git(root, { "show", M.starts[root].commit .. ":" .. path })
  if res.code ~= 0 then return nil end
  local lines = vim.split(res.stdout, "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  return lines
end

--- The diff of a change, as lines (the preview)
function M.diff(root, change)
  if change.untracked then
    return { "# " .. change.path .. ": untracked when the agent started - no snapshot of it to compare with" }
  end
  if change.status == "A" and not M.before(root, change.path) then
    local lines = { "# " .. change.path .. ": new since the agent started", "" }
    if vim.fn.filereadable(root .. "/" .. change.path) == 1 then vim.list_extend(lines, vim.fn.readfile(root .. "/" .. change.path, "", 500)) end
    return lines
  end
  local out = git(root, { "diff", "--no-color", "--no-ext-diff", M.starts[root].commit, "--", change.path }).stdout or ""
  local lines = vim.split(out, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then table.remove(lines) end
  return lines
end

--- Take a change back: the file as it was when the agent started; a new file goes. The user's index stays.
function M.revert(root, change)
  if change.untracked then return false, "it was untracked when the agent started - there is no snapshot to take it back to" end
  local path = root .. "/" .. change.path
  if M.before(root, change.path) then
    local res = git(root, { "restore", "--source=" .. M.starts[root].commit, "--worktree", "--", change.path })
    if res.code ~= 0 then return false, vim.trim(res.stderr or "") end
  else
    local buf = vim.fn.bufnr(path)
    if buf ~= -1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    local ok, err = os.remove(path)
    if not ok then return false, tostring(err) end
  end
  vim.cmd("checktime")
  return true
end

--- A change side by side: the file when the agent started | the file now (the real one, to edit), in the agent
--- diff's colors (agent_ide.lua). q in the old side closes it.
function M.show(root, change)
  local path = root .. "/" .. change.path
  local before = not change.untracked and M.before(root, change.path) or nil
  if not before then -- new (or no snapshot): the file itself
    if vim.fn.filereadable(path) == 1 then vim.cmd.edit(vim.fn.fnameescape(path)) end
    return
  end
  local ide = require("integrations.agent_ide")
  ide.ensure_colors()
  vim.cmd("tabnew")
  local left = vim.api.nvim_get_current_win()
  local empty = vim.api.nvim_get_current_buf()
  local old = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(old, 0, -1, false, before)
  vim.api.nvim_buf_set_name(old, "agent-before://" .. change.path)
  vim.bo[old].modifiable = false
  vim.bo[old].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(left, old)
  if empty ~= old then pcall(vim.api.nvim_buf_delete, empty, { force = true }) end
  local ft = vim.filetype.match({ filename = path })
  if ft then vim.bo[old].filetype = ft end
  local right
  if vim.fn.filereadable(path) == 1 then
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(path))
    right = vim.api.nvim_get_current_win()
  else -- deleted since: the old side alone
    right = nil
  end
  for _, win in ipairs({ left, right }) do
    vim.api.nvim_win_call(win, function() vim.cmd("diffthis") end)
    vim.wo[win].fillchars = "diff:╱"
    vim.wo[win].winhighlight = win == left and ide.WINHL.old or ide.WINHL.new
  end
  local esc = change.path:gsub("%%", "%%%%")
  vim.wo[left].winbar = ("%%#DiffDelete# When the agent started %%* %s   q closes"):format(esc)
  if right then vim.wo[right].winbar = ("%%#DiffAdd# Now %%* %s"):format(esc) end
  vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = old, desc = "Agent's changes: Close the diff" })
end

local HL = { A = "Added", M = "Changed", D = "Removed" }

--- <leader>ad: the list of what changed since the agent started
function M.pick()
  local root = M.root(vim.fn.getcwd())
  if not root then return notify("The project is no git repository - there is no list of what changed") end
  local list = M.changes(root)
  if not list then return notify("No agent started in this project yet (<leader>tt starts one)") end
  if #list == 0 then return notify("Nothing changed since the agent started") end
  local items = {}
  for _, change in ipairs(list) do
    items[#items + 1] = {
      text = change.status .. " " .. change.path, file = root .. "/" .. change.path, change = change, root = root,
      preview = { text = table.concat(M.diff(root, change), "\n"), ft = "diff" },
    }
  end
  Snacks.picker.pick({
    title = "Changed since the agent started",
    items = items,
    preview = "preview",
    format = function(item)
      return { { item.change.status, HL[item.change.status] or "Normal" }, { " " }, { item.change.path },
        item.change.untracked and { "  (untracked then)", "Comment" } or nil }
    end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() M.show(item.root, item.change) end) end
    end,
    actions = {
      gk_take_back = function(picker, item)
        if not item then return end
        local what = item.change.status == "A" and not item.change.untracked and "Delete the new file " or "Take back the changes of "
        Snacks.picker.util.confirm(what .. item.change.path .. "?", function()
          local ok, err = M.revert(item.root, item.change)
          if not ok then return notify(item.change.path .. ": " .. tostring(err), vim.log.levels.WARN) end
          notify("Taken back: " .. item.change.path)
          picker:close()
          vim.schedule(M.pick)
        end)
      end,
    },
    win = {
      input = { keys = { ["<c-x>"] = { "gk_take_back", mode = { "n", "i" }, desc = "Take the change back" } } },
      list = { keys = { ["<c-x>"] = { "gk_take_back", desc = "Take the change back" }, ["dd"] = { "gk_take_back", desc = "Take the change back" } } },
    },
  })
end

return M
