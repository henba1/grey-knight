-- Grey Knight smoke tests: config, plugins, parsers, tools. Run all suites with tests/run.sh
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/harness.lua")
local test = H.test

-- T1: Config loads
test("Config loads without errors", function()
  assert(vim.g.mapleader == " ", "leader not space")
end)

-- T2: All plugins registered
test("Plugins registered", function()
  local count = #require("lazy").plugins()
  assert(count >= 35, "only " .. count .. " plugins")
end)

-- T3: Colorscheme
test("Cyberdream colorscheme active", function()
  assert(vim.g.colors_name == "cyberdream", "colorscheme is " .. tostring(vim.g.colors_name))
end)

-- T4: Language toggles
test("Language toggles defined", function()
  local lang = vim.g.lang
  assert(lang.python == true, "python not enabled")
  assert(lang.bash == true, "bash not enabled")
  assert(lang.typescript == true, "typescript not enabled")
  assert(lang.lua == true, "lua not enabled")
  assert(lang.c == true, "c not enabled")
  assert(lang.java == true, "java not enabled")
  assert(lang.angular == true, "angular not enabled")
end)

-- T5: Treesitter parsers (language.add returns false for a missing parser, it does not raise: 2026-10-19)
test("Markdown parser available", function()
  local ok, added = pcall(vim.treesitter.language.add, "markdown")
  assert(ok and added, "markdown parser missing")
end)

test("Python parser available", function()
  local ok, added = pcall(vim.treesitter.language.add, "python")
  assert(ok and added, "python parser missing")
end)

test("Lua parser available", function()
  local ok, added = pcall(vim.treesitter.language.add, "lua")
  assert(ok and added, "lua parser missing")
end)

test("Bash parser available", function()
  local ok, added = pcall(vim.treesitter.language.add, "bash")
  assert(ok and added, "bash parser missing")
end)

test("TypeScript parser available", function()
  local ok, added = pcall(vim.treesitter.language.add, "typescript")
  assert(ok and added, "typescript parser missing")
end)

-- T6: Core plugins loadable
test("blink.cmp loads", function()
  assert(pcall(require, "blink.cmp"), "blink.cmp failed to load")
end)

test("snacks loads", function()
  assert(pcall(require, "snacks"), "snacks failed to load")
end)

test("Coding agent available (Qwen Code or OpenCode)", function()
  local agent = require("integrations.agent")
  assert(vim.fn.executable(agent.bin()) == 1, agent.backend().name .. " not found: " .. agent.bin())
end)

test("flash loads", function()
  assert(pcall(require, "flash"), "flash failed to load")
end)

test("trouble loads", function()
  assert(pcall(require, "trouble"), "trouble failed to load")
end)

test("oil loads", function()
  assert(pcall(require, "oil"), "oil failed to load")
end)

test("grug-far loads", function()
  assert(pcall(require, "grug-far"), "grug-far failed to load")
end)

test("harpoon loads", function()
  assert(pcall(require, "harpoon"), "harpoon failed to load")
end)

test("gitsigns loads", function()
  assert(pcall(require, "gitsigns"), "gitsigns failed to load")
end)

test("render-markdown loads", function()
  assert(pcall(require, "render-markdown"), "render-markdown failed to load")
end)

test("persisted loads", function()
  assert(pcall(require, "persisted"), "persisted failed to load")
end)

test("conform loads", function()
  assert(pcall(require, "conform"), "conform failed to load")
end)

test("mini.surround loads", function()
  assert(pcall(require, "mini.surround"), "mini.surround failed to load")
end)

test("mini.ai loads", function()
  assert(pcall(require, "mini.ai"), "mini.ai failed to load")
end)

-- T7: Qwen Code agent keymaps registered
test("AI keymaps present", function()
  local maps = vim.api.nvim_get_keymap("n")
  local found = {}
  for _, m in ipairs(maps) do
    if m.lhs:match("^ ") then found[m.lhs] = true end
  end
  assert(found[" tt"], "leader-tt (AI toggle) missing")
  assert(found[" ac"], "leader-ac (AI new) missing")
  assert(found[" aa"], "leader-aa (AI ask) missing")
end)

-- T8: Keymaps registered
test("Leader keymaps exist", function()
  local maps = vim.api.nvim_get_keymap("n")
  local found = {}
  for _, m in ipairs(maps) do
    if m.lhs:match("^ ") then found[m.lhs] = true end
  end
  assert(found[" w"], "leader-w missing")
  assert(found[" q"], "leader-q missing")
  assert(found[" ;"], "leader-; (dashboard) missing")
end)

-- T9: System tools
test("ripgrep available", function()
  assert(vim.fn.executable("rg") == 1, "rg not found")
end)

test("fd available", function()
  assert(vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1, "fd not found")
end)

test("lazygit available", function()
  assert(vim.fn.executable("lazygit") == 1, "lazygit not found")
end)

test("gcc available", function()
  assert(vim.fn.executable("gcc") == 1, "gcc not found")
end)

test("tree-sitter CLI available", function()
  -- installed by install.sh into ~/.cargo/bin, which non-interactive shells do not have on the PATH
  local cargo = vim.fn.expand("~/.cargo/bin/tree-sitter")
  assert(vim.fn.executable("tree-sitter") == 1 or vim.fn.executable(cargo) == 1, "tree-sitter not found")
end)

-- T10: Project files
test("CHEATSHEET.md exists", function()
  assert(vim.fn.filereadable(vim.fn.stdpath("config") .. "/CHEATSHEET.md") == 1, "missing")
end)

-- 2026-10-19: the guide for the G3 work - in the docs picker (<leader>gd) and under Config on the start screen
test("Docs: the G3 guide is in the docs picker and under Config on the start screen", function()
  local config = vim.fn.stdpath("config")
  assert(vim.fn.filereadable(config .. "/G3-DEVELOPMENT.md") == 1, "G3-DEVELOPMENT.md missing")
  local select, offered = vim.ui.select, nil
  vim.ui.select = function(items, _, cb) offered = items; cb(nil) end
  local ok, err = pcall(vim.api.nvim_feedkeys, " gd", "x", false)
  vim.ui.select = select
  assert(ok, err)
  assert(offered and vim.tbl_contains(offered, "G3-DEVELOPMENT.md"), "docs picker: " .. vim.inspect(offered))
  local snacks = require("lazy.core.config").plugins["snacks.nvim"]
  local keys = require("lazy.core.plugin").values(snacks, "opts", false).dashboard.preset.keys
  local entry = vim.tbl_filter(function(k) return k.key == "c" end, keys)[1]
  assert(entry and entry.desc == "Config" and tostring(entry.action):find("stdpath('config')", 1, true), vim.inspect(entry))
end)

-- T11: AI Dashboard bridge — loads anywhere, active only inside the dashboard's Dev Environment
test("Dashboard bridge only inside the dashboard", function()
  local aidash = require("integrations.aidash")
  local inside = (vim.env.AIDASH_URL or "") ~= "" and (vim.env.AIDASH_TOKEN or "") ~= ""
  assert(aidash.active() == inside, "active() disagrees with the environment")
  assert((vim.fn.exists(":AidashPreview") == 2) == inside, ":AidashPreview defined outside the dashboard")
end)

-- T13: Keys that once misbehaved (2026-10-19)
test("Terminal: Ctrl+L goes to the program (clears a shell), Ctrl+h/j/k still move", function()
  assert(vim.fn.maparg("<C-l>", "t") == "", "<C-l> is mapped in terminal mode: " .. vim.fn.maparg("<C-l>", "t"))
  for _, k in ipairs({ "<C-h>", "<C-j>", "<C-k>" }) do
    assert(vim.fn.maparg(k, "t") ~= "", k .. " no longer moves to the next window")
  end
end)

-- The real explorer in tests (2026-10-21). snacks shows a picker once it has listed - on a slow moment (Windows: a
-- test window that stalled for seconds) only after the test gave up waiting. Snacks.picker.get() without tab = false
-- leaves out a picker not shown yet, so the test's cleanup missed it; it showed afterwards, and the next test's
-- Snacks.explorer() closed it (a toggle) instead of opening one - one slow explorer failed the tests after it too.
local OPEN_MS = 10000 -- the explorer shown and listed (usually well under a second)
local function explorers() return Snacks.picker.get({ source = "explorer", tab = false }) end -- shown or not
local function close_explorers() -- all of them: no explorer outlives its test, nor its windows (closed scheduled)
  for _, p in ipairs(explorers()) do p:close() end
  H.wait(2000, function()
    if #explorers() > 0 then return false end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if ft == "snacks_picker_list" or ft == "snacks_picker_input" or ft == "snacks_layout_box" then return false end
    end
    return true
  end)
end

test("Explorer: . = cd here, <BS> / - = cd .. (tree and working directory)", function()
  local before = vim.fn.getcwd()
  -- the real path with / (on Windows tempname() is an 8.3 short name with \, getcwd() has \ too)
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/a/b", "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local function cwd() return vim.fs.normalize(vim.fn.getcwd()) end
  vim.fn.chdir(root .. "/a")
  Snacks.explorer()
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local ok, err = pcall(function()
    assert(H.wait(OPEN_MS, picker), "explorer did not open")
    local p = picker()
    -- like a user: act once the first listing is there (a cd while snacks still lists shows entries twice,
    -- with its own keys too)
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() > 0 end), "explorer did not list")
    for key, action in pairs({ ["."] = "gk_cd_here", ["<BS>"] = "gk_cd_up", ["-"] = "gk_cd_up", ["C"] = "gk_copy_to" }) do
      local m = vim.api.nvim_buf_call(p.list.win.buf, function() return vim.fn.maparg(key, "n", false, true) end)
      assert(m.desc == action, key .. " runs " .. tostring(m.desc) .. ", not " .. action)
    end
    -- 2026-10-20: m / c / r / a / d keep snacks' action names, the actions are GreyKnight's (config/explorer.lua)
    for _, name in ipairs({ "explorer_move", "explorer_copy", "explorer_rename", "explorer_add", "explorer_del" }) do
      local a = Snacks.picker.config.action(p, name)
      local where = type(a) == "table" and type(a.action) == "function" and debug.getinfo(a.action, "S").source or ""
      assert(where:find("plugins[/\\]snacks%.lua"), name .. " is not GreyKnight's: " .. where)
    end
    p:action("gk_cd_up")
    assert(H.wait(3000, function() return not p:is_active() and cwd() == root and p:cwd() == root end), "cd ..: " .. cwd() .. " / " .. tostring(p:cwd()))
    -- the tree is listed again after a cd: wait for the new listing, where a is an entry (not the old root)
    local function folder_a()
      if p:is_active() then return nil end
      for i = 1, p.list:count() do
        local it = p.list:get(i)
        if it.file == root .. "/a" and it.parent then return i end
      end
    end
    assert(H.wait(5000, folder_a), "folder a not in the tree")
    local shown = {}
    for i = 1, p.list:count() do
      local file = p.list:get(i).file
      assert(not shown[file], "shown twice: " .. file)
      shown[file] = true
    end
    -- the explorer sets its own cursor target after a listing: put the cursor on a until it stays there
    assert(H.wait(3000, function()
      local cur = p:current()
      if cur and cur.file == root .. "/a" then return true end
      p.list:view(folder_a())
    end), "the cursor does not stay on folder a")
    p:action("gk_cd_here")
    assert(H.wait(2000, function() return cwd() == root .. "/a" and p:cwd() == root .. "/a" end), "cd here: " .. cwd() .. " / " .. tostring(p:cwd()))
  end)
  close_explorers() -- gone, so no later test starts in its window
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- T20: Moving and copying in the explorer (2026-10-20). snacks' m fell back to a rename prompt when nothing was
-- marked, and its prompts put every answer below a folder, absolute paths too: C:\dev\files became
-- <cwd>\C\dev\files on Windows, /home/nix0/x.py <cwd>/home/nix0/x.py on Linux (config/explorer.lua).
test("Explorer: typed paths - absolute ones as typed (also ~, C:\\ and \\\\server), relative ones below the folder", function()
  local ex = require("config.explorer")
  -- the real path: Windows' temp directory comes as an 8.3 short name, which ".." resolves to the long one
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local base = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  vim.fn.delete(tmp, "d")
  local function r(v)
    local p, folder = ex.resolve(base, v)
    return p .. (folder and " (folder)" or "")
  end
  assert(r("sub/x.py") == base .. "/sub/x.py", r("sub/x.py"))
  assert(r("../y.py") == vim.fs.dirname(base) .. "/y.py", r("../y.py"))
  assert(r("~/x.py") == vim.fs.normalize("~") .. "/x.py", r("~/x.py"))
  assert(r("dir/") == base .. "/dir (folder)", r("dir/"))
  if vim.fn.has("win32") == 1 then
    assert(r([[C:\dev\files\]]) == "C:/dev/files (folder)", r([[C:\dev\files\]]))
    assert(r("D:/x.py") == "D:/x.py", r("D:/x.py"))
    assert(r([[\\server\share\x]]) == "//server/share/x", r([[\\server\share\x]]))
    assert(r("/x.py") == vim.fn.getcwd():sub(1, 2) .. "/x.py", "/x.py is on the current drive: " .. r("/x.py"))
    assert(r([[dir\]]) == base .. "/dir (folder)", r([[dir\]]))
  else
    assert(r("/home/nix0/some dir/x.py") == "/home/nix0/some dir/x.py", r("/home/nix0/some dir/x.py"))
    assert(r("/tmp/x/") == "/tmp/x (folder)", r("/tmp/x/"))
  end
end)

-- The explorer's picker as config/explorer.lua uses it, on two temp folders: root (the tree, the working
-- directory: a.txt, b.txt, sub/b.txt, other/) and far (somewhere else). Prompts answer w.answer, the
-- confirmation says yes, notifications land in w.notes, the tree's cursor targets in w.targets.
local function explorer_world(fn)
  local function tmpdir()
    local t = vim.fn.tempname()
    vim.fn.mkdir(t, "p")
    return vim.fs.normalize(assert(vim.uv.fs_realpath(t)))
  end
  local root, far = tmpdir(), tmpdir()
  local function file(path, text)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({ text or vim.fs.basename(path) }, path)
  end
  file(root .. "/a.txt")
  file(root .. "/b.txt")
  file(root .. "/sub/b.txt", "sub's b")
  vim.fn.mkdir(root .. "/other", "p")
  local w = { root = root, far = far, notes = {}, targets = {}, file = file }
  local p = { selection = {} }
  p.list = {
    select = function(_, item) -- toggles, like snacks'
      for i, s in ipairs(p.selection) do
        if s.file == item.file then return table.remove(p.selection, i) end
      end
      table.insert(p.selection, item)
    end,
    set_selected = function(_, items) p.selection = items or {} end,
  }
  function p:selected() return self.selection end
  function p:current() return self.cur end
  function p:cwd() return root end
  function p:dir() return vim.fn.isdirectory(self.cur.file) == 1 and self.cur.file or vim.fs.dirname(self.cur.file) end
  w.picker = p
  function w.at(path) -- the cursor on path
    p.cur = { file = path }
    return p.cur
  end
  local actions, util = require("snacks.explorer.actions"), Snacks.picker.util
  local saved = { update = actions.update, confirm = util.confirm, input = Snacks.input, notify = vim.notify, cwd = vim.fn.getcwd() }
  actions.update = function(_, opts) w.targets[#w.targets + 1] = opts.target end
  util.confirm = function(_, yes) yes() end
  Snacks.input = function(_, answer) answer(w.answer) end
  vim.notify = function(msg) w.notes[#w.notes + 1] = msg end
  vim.fn.chdir(root)
  local ok, err = pcall(fn, require("config.explorer"), w)
  actions.update, util.confirm, Snacks.input, vim.notify = saved.update, saved.confirm, saved.input, saved.notify
  vim.fn.chdir(saved.cwd)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do -- the fixture's files the test opened
    local name = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
    if name:find(root .. "/", 1, true) == 1 or name:find(far .. "/", 1, true) == 1 then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  vim.fn.delete(root, "rf")
  vim.fn.delete(far, "rf")
  assert(ok, err)
end

local function exists(path) return vim.uv.fs_stat(path) ~= nil end

test("Explorer: m / c move and copy the marked into the folder under the cursor, nothing marked marks this", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    ex.move(p, w.at(R .. "/a.txt")) -- nothing marked: m marks a.txt
    assert(#p.selection == 1 and p.selection[1].file == R .. "/a.txt", vim.inspect(p.selection))
    assert(last():find("a.txt marked", 1, true), last())
    ex.move(p, w.at(R .. "/other")) -- on the target folder: there it goes
    assert(exists(R .. "/other/a.txt") and not exists(R .. "/a.txt"), "a.txt not moved into other/")
    assert(#p.selection == 0 and w.targets[#w.targets] == R .. "/other/a.txt", vim.inspect({ p.selection, w.targets }))
    ex.copy(p, w.at(R .. "/b.txt")) -- c marks as well; on a file the target is its folder
    ex.copy(p, w.at(R .. "/other/a.txt"))
    assert(exists(R .. "/other/b.txt") and exists(R .. "/b.txt") and #p.selection == 0, "b.txt not copied into other/")
    -- nothing is overwritten: sub/ has a b.txt of its own
    ex.move(p, w.at(R .. "/b.txt"))
    ex.move(p, w.at(R .. "/sub"))
    assert(vim.fn.readfile(R .. "/sub/b.txt")[1] == "sub's b" and exists(R .. "/b.txt"), "sub/b.txt overwritten")
    assert(last():find("exists", 1, true) and #p.selection == 0, last())
    -- m in the item's own folder unmarks it; a folder does not go into itself
    ex.move(p, w.at(R .. "/b.txt"))
    ex.move(p, w.at(R .. "/b.txt"))
    assert(#p.selection == 0 and exists(R .. "/b.txt") and last():find("Nothing moved", 1, true), last())
    ex.move(p, w.at(R .. "/sub"))
    ex.move(p, w.at(R .. "/sub"))
    assert(exists(R .. "/sub/b.txt") and last():find("not into itself", 1, true), last())
  end)
end)

test("Explorer: r / C / a take typed paths - absolute ones as typed, an existing folder takes the item", function()
  explorer_world(function(ex, w)
    local p, R, F = w.picker, w.root, w.far
    local WIN = vim.fn.has("win32") == 1
    local function typed(path) return WIN and (path:gsub("/", "\\")) or path end -- as the OS writes paths
    local function last() return tostring(w.notes[#w.notes]) end
    -- r with an absolute path: there - not below the working directory
    w.answer = typed(F .. "/deep/renamed.txt")
    ex.rename(p, w.at(R .. "/a.txt"))
    assert(exists(F .. "/deep/renamed.txt") and not exists(R .. "/a.txt"), "not moved to the absolute path: " .. last())
    local top = (vim.split(F, "/", { trimempty = true })[1]):gsub(":", "") -- "C" (Windows) / "tmp" (Linux)
    assert(not exists(R .. "/" .. top), "the absolute path was put below the working directory: " .. R .. "/" .. top)
    -- relative: from the working directory, as the prompt shows it
    w.answer = "renamed-here.txt"
    ex.rename(p, w.at(R .. "/b.txt"))
    assert(exists(R .. "/renamed-here.txt"), "relative path not from the working directory")
    -- an existing folder, or a path typed with a trailing separator, takes the item under its own name (mv)
    w.answer = typed(F .. "/deep")
    ex.rename(p, w.at(R .. "/renamed-here.txt"))
    assert(exists(F .. "/deep/renamed-here.txt"), "not moved into the existing folder")
    w.answer = typed(F .. "/new-folder/")
    ex.rename(p, w.at(R .. "/sub/b.txt"))
    assert(exists(F .. "/new-folder/b.txt"), "not moved into the new folder")
    -- nothing is overwritten
    w.file(R .. "/c.txt")
    w.answer = typed(F .. "/deep/renamed.txt")
    ex.rename(p, w.at(R .. "/c.txt"))
    assert(exists(R .. "/c.txt") and last():find("exists", 1, true), "overwritten: " .. last())
    -- C copies to a typed path
    w.answer = typed(F .. "/copies/")
    ex.copy_to(p, w.at(R .. "/c.txt"))
    assert(exists(F .. "/copies/c.txt") and exists(R .. "/c.txt"), "C did not copy into the folder: " .. last())
    -- a creates at an absolute path (a trailing separator: a folder), relative ones in the folder under the cursor
    w.answer = typed(F .. "/made/new.txt")
    ex.add(p)
    assert(vim.fn.filereadable(F .. "/made/new.txt") == 1, "a: no file at the absolute path")
    w.answer = typed(F .. "/made/dir/")
    ex.add(p)
    assert(vim.fn.isdirectory(F .. "/made/dir") == 1, "a: no folder at the absolute path")
    w.answer = "rel/x.txt"
    ex.add(p)
    assert(vim.fn.filereadable(R .. "/rel/x.txt") == 1, "a: relative path not in the folder under the cursor")
  end)
end)

-- 2026-10-20: d keeps the cursor on its item (snacks kept only the row: marked items above it moved another item
-- under the cursor); when the item itself went, the next one below takes it, else the one above. The real explorer,
-- with the file in the editor deleted too; the answer to "Delete ...?" is yes, deleted for good (no trash: gio
-- refuses to trash files in /tmp).
test("Explorer: d keeps the cursor on its item, else on the next one (also for the file in the editor)", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/sub", "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  for i = 1, 9 do vim.fn.writefile({ "f" }, ("%s/f%d.txt"):format(root, i)) end
  local before, editor = vim.fn.getcwd(), vim.api.nvim_get_current_win()
  local util, config = Snacks.picker.util, Snacks.explorer.config
  local saved = { confirm = util.confirm, trash = config.trash }
  util.confirm = function(_, yes) yes() end
  config.trash = false
  vim.fn.chdir(root)
  vim.cmd.edit(vim.fn.fnameescape(root .. "/f4.txt"))
  Snacks.explorer()
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local ok, err = pcall(function()
    assert(H.wait(OPEN_MS, picker), "explorer did not open")
    local p = picker()
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() >= 10 end), "explorer did not list")
    local function index(file)
      for i = 1, p.list:count() do
        if p.list:get(i).file == file then return i end
      end
    end
    local function on(file) -- the cursor there (the explorer sets its own target after a listing: until it stays)
      assert(H.wait(3000, function()
        local cur = p:current()
        if cur and cur.file == file then return true end
        if index(file) then p.list:view(index(file)) end
      end), "cursor not on " .. file)
    end
    local function current() return p:current() and p:current().file:sub(#root + 2) or "nil" end
    local function delete(want)
      p:focus("list")
      p:action("explorer_del")
      assert(H.wait(3000, function() return not p:is_active() and current() == want end),
        "after d the cursor is on " .. current() .. ", not " .. want)
    end
    on(root .. "/f2.txt")
    p.list:select(p:current())
    on(root .. "/f3.txt")
    p.list:select(p:current())
    on(root .. "/f6.txt")
    delete("f6.txt") -- f2 and f3 marked above: the cursor stays on f6
    assert(not vim.uv.fs_stat(root .. "/f2.txt") and not vim.uv.fs_stat(root .. "/f3.txt"), "the marked were not deleted")
    delete("f7.txt") -- f6 itself: the next one
    on(root .. "/f4.txt")
    delete("f5.txt") -- the file in the editor: the next one, and the editor shows something else
    assert(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(editor)) ~= root .. "/f4.txt", "f4.txt still in the editor")
    on(root .. "/f9.txt")
    delete("f8.txt") -- the last one: the one above
  end)
  util.confirm, config.trash = saved.confirm, saved.trash
  close_explorers()
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: three searches in the explorer (config/explorer.lua). / files as snacks searched (paths), D folders by
-- name only (no file shown), S only the rows the tree shows (closed folders not looked into) - in the list, and in the
-- search box when not typing; during a search they switch with the same text, <a-s> does it while typing. The box's
-- title names the search. <CR> goes back to the tree on the match, <Esc> steps back (box, list, the tree as before the
-- search, closed); the next search starts as a file search again. The real explorer, on alpha/ (open), beta/, zeta/.
test("Explorer: / D S search files, folders by name, the current view, switch with the same text; <Esc> steps back", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  for _, rel in ipairs({ "alpha/beta/gamma/keep.txt", "alpha/beta/needle-deep.txt", "alpha/needle-a.txt", "zeta/needle-z.txt", "needle-root.txt" }) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. rel), "p")
    vim.fn.writefile({ "x" }, root .. "/" .. rel)
  end
  vim.fn.mkdir(root .. "/NeedleDir", "p")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  require("snacks.explorer.tree"):open(root .. "/alpha") -- the tree shows alpha's contents, not beta's or zeta's
  close_explorers() -- Snacks.explorer() would close one left open instead of opening
  Snacks.explorer()
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local ok, err = pcall(function()
    assert(H.wait(OPEN_MS, picker), "explorer did not open")
    local p = picker()
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() >= 7 end), "explorer did not list")
    local function key(win, lhs, mode)
      return vim.api.nvim_buf_call(win.buf, function() return vim.fn.maparg(lhs, mode, false, true) end)
    end
    local keys = { ["/"] = "gk_search_files", D = "gk_search_folders", S = "gk_search_view" }
    for lhs, action in pairs(vim.tbl_extend("force", keys, { ["<Esc>"] = "gk_search_leave" })) do
      assert(key(p.list.win, lhs, "n").desc == action, "list: " .. lhs .. " runs " .. tostring(key(p.list.win, lhs, "n").desc))
    end
    for lhs, action in pairs(vim.tbl_extend("force", keys, { ["<Esc>"] = "gk_search_back" })) do -- not while typing
      assert(key(p.input.win, lhs, "n").desc == action, "search box: " .. lhs .. " runs " .. tostring(key(p.input.win, lhs, "n").desc))
    end
    assert(tostring(key(p.input.win, "<a-s>", "i").desc):find("Next search", 1, true), "<a-s> while typing")
    assert(vim.tbl_isempty(key(p.input.win, "<Esc>", "i")), "<Esc> while typing is Vim's: typing ends")
    -- what a search found (the folders above a match, only there for context, left out), sorted
    local function found()
      local r = {}
      for i = 1, p.list:count() do
        local it = p.list:get(i)
        if not it.child_match_only then r[#r + 1] = it.file:sub(#root + 2) .. (it.dir and "/" or "") end
      end
      table.sort(r)
      return table.concat(r, " ")
    end
    local function expect(title, want)
      assert(H.wait(5000, function() return not p:is_active() and p.title == title and found() == want end),
        ("%q (%s): %q, not %q (%s)"):format(p.input.filter.pattern, p.title, found(), want, title))
    end
    local function search_for(text) -- as the search box does with typed text
      p.input:set(text)
      p:find({ refresh = false })
    end
    local function in_box() return vim.api.nvim_get_current_win() == p.input.win.win end

    p:action("gk_search_view") -- S
    assert(in_box() and p.title == "Search current view", "S: " .. p.title)
    search_for("needle")
    expect("Search current view", "NeedleDir/ alpha/needle-a.txt needle-root.txt") -- not in closed beta / zeta
    p:action("gk_search_next") -- <a-s>: the same text, all files
    expect("Search files", "NeedleDir/ alpha/beta/needle-deep.txt alpha/needle-a.txt needle-root.txt zeta/needle-z.txt")
    p:action("gk_search_next")
    expect("Search folders", "NeedleDir/")
    search_for("alpha")
    expect("Search folders", "alpha/") -- the name: not alpha/beta, alpha/beta/gamma
    search_for("gamma")
    expect("Search folders", "alpha/beta/gamma/") -- everywhere, closed folders too
    p:action("gk_search_next")
    expect("Search current view", "") -- gamma is in closed beta
    p:action("gk_search_next")
    expect("Search files", "alpha/beta/gamma/ alpha/beta/gamma/keep.txt") -- the path, as snacks matches it
    -- <Esc> in the box (not typing): to the list, the search and its results stay
    p:action("gk_search_back")
    assert(vim.api.nvim_get_current_win() == p.list.win.win, "<Esc> in the search box: not in the list")
    expect("Search files", "alpha/beta/gamma/ alpha/beta/gamma/keep.txt")
    -- / D S in the list: that search with the same text, typing in the box again
    p:action("gk_search_folders")
    expect("Search folders", "alpha/beta/gamma/")
    assert(in_box(), "D: the search box does not have the cursor")
    p.list.win:focus()
    p:action("gk_search_files")
    expect("Search files", "alpha/beta/gamma/ alpha/beta/gamma/keep.txt")
    assert(in_box(), "/: the search box does not have the cursor")
    -- the same in the box (after <Esc>, not typing): D switches, the box keeps the cursor
    p:action("gk_search_folders")
    expect("Search folders", "alpha/beta/gamma/")
    assert(in_box(), "D in the search box: it lost the cursor")
    -- <CR>: the tree, the cursor on the match, the explorer's title
    local gamma = root .. "/alpha/beta/gamma"
    assert(H.wait(3000, function() return p:current() and p:current().file == gamma end), "cursor not on gamma")
    p:action("confirm")
    -- right then the watcher's refresh (a change on disk; batched, it came 100 ms later): its find replaced the one
    -- that was to put the cursor on the match - it stayed on the match's row number in the search list, on beta
    -- (2026-10-21, 1 in 5 runs on Kali)
    p.list:set_target()
    p:find()
    assert(H.wait(3000, function()
      return not p:is_active() and p.input.filter:is_empty() and p.title == "Explorer" and p:current() and p:current().file == gamma
    end), "<CR>: " .. p.title .. ", on " .. tostring(p:current() and p:current().file))
    -- beta is open now (gamma was revealed in it): the current view has its contents, still not zeta's
    p:action("gk_search_view")
    search_for("needle")
    expect("Search current view", "NeedleDir/ alpha/beta/needle-deep.txt alpha/needle-a.txt needle-root.txt")
    -- <Esc> <Esc>: the box, the list - and the search is over: the tree, the cursor where it was before it (gamma)
    p:action("gk_search_back")
    p:action("gk_search_leave")
    p.list:set_target() -- the watcher's refresh again
    p:find()
    assert(H.wait(3000, function()
      return not p:is_active() and p.input.filter:is_empty() and p.title == "Explorer" and p:current() and p:current().file == gamma
    end), "<Esc> in the list: " .. p.title .. ", on " .. tostring(p:current() and p:current().file))
    -- the next search is a file search again; out of the box with no text: no search
    p:action("gk_search_files")
    assert(in_box() and p.title == "Search files", "/: " .. p.title)
    p:action("gk_search_back")
    assert(H.wait(2000, function() return p.title == "Explorer" end), "no text, out of the box: " .. p.title)
    -- no search: <Esc> in the list closes the explorer, as snacks' did
    H.wait(3000, function() return not p:is_active() end) -- done with its finds, as before closing it by hand
    p:action("gk_search_leave")
    assert(H.wait(3000, function() return #explorers() == 0 end), "<Esc> without a search: the explorer is still open")
  end)
  close_explorers()
  vim.cmd("stopinsert") -- the box's typing, started for the test's keys, would wait for the end of the script
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: the explorer closed right after a find (a refresh, a cd, typed text): snacks' cleanup put a new task in
-- place of the finder's last one, which still ran once, and snacks then resumed the matcher, gone by then - "attempt
-- to index field 'matcher' (a nil value)", a prompt that kept the test window from quitting (config/explorer.lua,
-- setup). Without the fix in 6 of 10 tries.
test("Explorer: closed right after a find - no error from the finder that still runs once", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/a", "p")
  vim.fn.writefile({ "x" }, tmp .. "/a/x.txt")
  local before = vim.fn.getcwd()
  vim.fn.chdir(tmp)
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local function errors() -- the finder's error comes from snacks' async loop: in :messages, not raised here
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    return select(2, messages:gsub("index field 'matcher'", ""))
  end
  local ok, err = pcall(function()
    local had = errors()
    for _ = 1, 6 do
      close_explorers() -- Snacks.explorer() would close one left open instead of opening
      Snacks.explorer()
      assert(H.wait(OPEN_MS, picker), "explorer did not open")
      local p = picker()
      assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() > 0 end), "explorer did not list")
      p:find() -- a refresh: its finder task has not run yet
      p:close()
      vim.wait(300)
    end
    assert(errors() == had, (errors() - had) .. " times: attempt to index field 'matcher' (a nil value)")
  end)
  close_explorers()
  vim.fn.chdir(before)
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

-- ── Workflows (2026-10-21): what a user does in a row - the explorer, the pickers, sessions ──────────────────────
-- with_explorer: the real explorer on a tree of `paths` (folders end in /) in a temp folder that is the working
-- directory; fn(p, root, x) works it like a user, x has the helpers. opts.open: folders open in the tree. Afterwards
-- the explorer is closed, the fixture's buffers are gone and the working directory is the old one.
local function with_explorer(paths, fn, opts)
  opts = opts or {}
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  for _, rel in ipairs(paths) do
    if rel:sub(-1) == "/" then
      vim.fn.mkdir(root .. "/" .. rel, "p")
    else
      vim.fn.mkdir(vim.fs.dirname(root .. "/" .. rel), "p")
      vim.fn.writefile({ rel }, root .. "/" .. rel)
    end
  end
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  for _, rel in ipairs(opts.open or {}) do require("snacks.explorer.tree"):open(root .. "/" .. rel) end
  close_explorers() -- Snacks.explorer() would close one left open instead of opening
  Snacks.explorer()
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local ok, err = pcall(function()
    assert(H.wait(OPEN_MS, picker), "explorer did not open")
    local p = picker()
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() > 0 end), "explorer did not list")
    local x = {}
    function x.rel(file) return file == root and "." or file:sub(#root + 2) end
    function x.found() -- what the list shows (the folders above a match, only there for context, left out), sorted
      local r = {}
      for i = 1, p.list:count() do
        local it = p.list:get(i)
        if not it.child_match_only then r[#r + 1] = x.rel(it.file) .. (it.dir and "/" or "") end
      end
      table.sort(r)
      return table.concat(r, " ")
    end
    function x.expect(title, want)
      assert(H.wait(5000, function() return not p:is_active() and p.title == title and x.found() == want end),
        ("%q (%s): %q, not %q (%s)"):format(p.input.filter.pattern, p.title, x.found(), want, title))
    end
    function x.search_for(text) -- as the search box does with typed text
      p.input:set(text)
      p:find({ refresh = false })
    end
    function x.item(rel)
      for i = 1, p.list:count() do
        if p.list:get(i).file == root .. "/" .. rel then return p.list:get(i) end
      end
      error("not in the list: " .. rel .. " (" .. x.found() .. ")")
    end
    function x.on(rel) -- the cursor there (the explorer sets its own target after a listing: until it stays)
      local file = rel == "." and root or root .. "/" .. rel
      assert(H.wait(3000, function()
        local cur = p:current()
        if cur and cur.file == file then return true end
        for i = 1, p.list:count() do
          if p.list:get(i).file == file then p.list:view(i) end
        end
      end), "cursor not on " .. rel .. ", on " .. tostring(p:current() and x.rel(p:current().file)))
    end
    function x.at(rel) -- the tree (no search), the cursor on rel
      local file = rel == "." and root or root .. "/" .. rel
      assert(H.wait(5000, function()
        return not p:is_active() and p.input.filter:is_empty() and p.title == "Explorer" and p:current() and p:current().file == file
      end), "not the tree on " .. rel .. ": " .. p.title .. ", on " .. tostring(p:current() and x.rel(p:current().file)))
    end
    fn(p, root, x)
    if not p.closed then H.wait(3000, function() return not p:is_active() end) end -- done with its finds
  end)
  close_explorers()
  vim.cmd("stopinsert") -- typing in the search box, started by the test's keys, would wait for the end of the script
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):find(root .. "/", 1, true) == 1 then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

test("Explorer workflow: D finds a folder, Enter and . root the tree there, / searches in it, <BS> widens, <Esc> leaves", function()
  with_explorer({ "apps/web/src/main.ts", "apps/web/package.json", "apps/api/src/main.go", "docs/web-guide.md" }, function(p, root, x)
    p:action("gk_search_folders")
    x.search_for("web")
    x.expect("Search folders", "apps/web/") -- by name: docs/web-guide.md is a file
    x.on("apps/web")
    p:action("confirm") -- Enter: the tree, the cursor on the folder
    x.at("apps/web")
    p:action("gk_cd_here") -- .: the tree's root and the working directory
    assert(H.wait(3000, function()
      return p:cwd() == root .. "/apps/web" and vim.fs.normalize(vim.fn.getcwd()) == root .. "/apps/web" and not p:is_active()
    end), "cd here: " .. p:cwd())
    p:action("gk_search_files")
    x.search_for("main")
    x.expect("Search files", "apps/web/src/main.ts") -- below the new root only
    p:action("gk_search_back") -- <Esc>: the list
    p:action("gk_cd_up") -- <BS>: one folder up, the same search there
    assert(H.wait(3000, function() return p:cwd() == root .. "/apps" end), "cd ..: " .. p:cwd())
    x.expect("Search files", "apps/api/src/main.go apps/web/src/main.ts")
    p:action("gk_search_leave") -- <Esc>: the tree of apps
    assert(H.wait(5000, function() return not p:is_active() and p.input.filter:is_empty() and p.title == "Explorer" end), "<Esc>: " .. p.title)
  end)
end)

test("Explorer workflow: / finds files, <Tab> marks them, D finds the target folder, m moves them there", function()
  local util = Snacks.picker.util
  local confirm = util.confirm
  util.confirm = function(_, yes) yes() end -- "Move 2 items to ...?": yes
  local ok, err = pcall(with_explorer, { "inbox/report-1.txt", "inbox/report-2.txt", "inbox/notes.txt", "archive/2025/" }, function(p, root, x)
    p:action("gk_search_files")
    x.search_for("report")
    x.expect("Search files", "inbox/report-1.txt inbox/report-2.txt")
    p.list:select(x.item("inbox/report-1.txt")) -- <Tab> on each
    p.list:select(x.item("inbox/report-2.txt"))
    -- the marks stay while the search changes: the target folder by its name
    p:action("gk_search_back")
    p:action("gk_search_folders")
    x.search_for("2025")
    x.expect("Search folders", "archive/2025/")
    assert(#p:selected() == 2, "marks after the search changed: " .. #p:selected())
    x.on("archive/2025")
    p:action("explorer_move") -- m: the marked into the folder under the cursor
    x.at("archive/2025/report-2.txt") -- the search is over: the tree, on what moved last
    for _, name in ipairs({ "report-1.txt", "report-2.txt" }) do
      assert(vim.uv.fs_stat(root .. "/archive/2025/" .. name) and not vim.uv.fs_stat(root .. "/inbox/" .. name), name .. " not moved")
    end
    assert(vim.uv.fs_stat(root .. "/inbox/notes.txt"), "notes.txt moved too")
    assert(#p:selected() == 0, "marks left: " .. #p:selected())
  end)
  util.confirm = confirm
  assert(ok, err)
end)

-- snacks keyed a mark by the item's text: the full path in the tree, the path below the root in file search, the name
-- in folder and view search (config/explorer.lua, setup)
test("Explorer workflow: a file marked in a search is marked in the tree too - <Tab> there unmarks it, no second mark", function()
  with_explorer({ "inbox/report-1.txt", "inbox/notes.txt" }, function(p, root, x)
    p:action("gk_search_files")
    x.search_for("report")
    x.expect("Search files", "inbox/report-1.txt")
    p.list:select(x.item("inbox/report-1.txt"))
    p:action("gk_search_back")
    p:action("gk_search_leave") -- <Esc> <Esc>: the tree, inbox open
    assert(H.wait(5000, function() return not p:is_active() and p.input.filter:is_empty() end), "still a search")
    x.on("inbox/report-1.txt")
    assert(p.list:is_selected(p:current()), "marked in the search, not in the tree")
    p.list:select(p:current()) -- <Tab>
    assert(#p:selected() == 0, "<Tab> in the tree marked it again: " .. #p:selected() .. " marks")
  end, { open = { "inbox" } })
end)

test("Explorer workflow: Enter twice opens a match in the editor, the explorer stays; a file opened elsewhere shows in the tree", function()
  -- text files: no language server starts for them
  with_explorer({ "src/app/main.txt", "src/lib/util.txt", "notes/todo.txt" }, function(p, root, x)
    local editor = p.main
    local function shown() return vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(editor))) end
    p:action("gk_search_files")
    x.search_for("main")
    x.expect("Search files", "src/app/main.txt")
    x.on("src/app/main.txt")
    p:action("confirm") -- the tree, on the match
    x.at("src/app/main.txt")
    p:action("confirm") -- the file, in the editor
    assert(H.wait(3000, function() return shown() == root .. "/src/app/main.txt" end), "not in the editor: " .. shown())
    assert(not p.closed, "the explorer closed")
    -- a file opened in the editor some other way: the tree opens its folder and goes to it
    vim.api.nvim_set_current_win(editor)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes/todo.txt"))
    assert(H.wait(3000, function() return p:current() and p:current().file == root .. "/notes/todo.txt" end),
      "the tree did not follow: on " .. tostring(p:current() and x.rel(p:current().file)))
  end)
end)

test("Explorer workflow: r renames a match, d deletes one - each search ends in the tree on the result, every row once", function()
  local util, config = Snacks.picker.util, Snacks.explorer.config
  local saved = { confirm = util.confirm, trash = config.trash, input = Snacks.input }
  local answer
  util.confirm = function(_, yes) yes() end
  config.trash = false -- gone for good: no trash for temp folders everywhere
  Snacks.input = function(_, done) done(answer) end
  local ok, err = pcall(with_explorer, { "src/old-name.lua", "src/keep.lua", "tmp/scratch-1.txt", "tmp/scratch-2.txt" }, function(p, root, x)
    p:action("gk_search_files")
    x.search_for("old-name")
    x.expect("Search files", "src/old-name.lua")
    x.on("src/old-name.lua")
    answer = "src/new-name.lua" -- from the working directory, as the prompt shows it
    p:action("explorer_rename") -- r
    x.at("src/new-name.lua")
    assert(vim.uv.fs_stat(root .. "/src/new-name.lua") and not vim.uv.fs_stat(root .. "/src/old-name.lua"), "not renamed")
    p:action("gk_search_files")
    x.search_for("scratch")
    x.expect("Search files", "tmp/scratch-1.txt tmp/scratch-2.txt")
    x.on("tmp/scratch-1.txt")
    p:action("explorer_del") -- d
    x.at("tmp/scratch-2.txt") -- the next one below
    assert(not vim.uv.fs_stat(root .. "/tmp/scratch-1.txt") and vim.uv.fs_stat(root .. "/tmp/scratch-2.txt"), "deleted the wrong one")
    local seen = {}
    for i = 1, p.list:count() do
      local file = p.list:get(i).file
      assert(not seen[file], "shown twice: " .. x.rel(file))
      seen[file] = true
    end
  end)
  util.confirm, config.trash, Snacks.input = saved.confirm, saved.trash, saved.input
  assert(ok, err)
end)

-- 2026-10-21: once loaded (- or <leader>o once) oil took every folder buffer - the same :e opened the explorer or oil
test("Explorer: a folder opened as a file (nvim <folder>, :e <folder>) opens the explorer there, also once oil is loaded", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/sub", "p")
  vim.fn.writefile({ "x" }, tmp .. "/sub/x.txt")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local function name() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
  close_explorers()
  local ok, err = pcall(function()
    require("oil") -- as after - or <leader>o
    vim.cmd.edit(vim.fn.fnameescape(root))
    assert(H.wait(OPEN_MS, function() local p = explorers()[1]; return p and p:cwd() == root end),
      "no explorer on the folder: " .. tostring(explorers()[1] and explorers()[1]:cwd()) .. ", the buffer: " .. name())
    assert(H.wait(2000, function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local raw = vim.api.nvim_buf_get_name(buf) -- oil://C:/... as it is (vim.fs.normalize makes it oil:/C/...)
        if vim.api.nvim_buf_is_loaded(buf) and (vim.fs.normalize(raw) == root or raw:find("^oil://")) then return false end
      end
      return true
    end), "a buffer of the folder (or oil's) is still there")
    -- oil still opens on its own command
    close_explorers()
    vim.cmd("Oil " .. vim.fn.fnameescape(root))
    assert(H.wait(3000, function() return vim.api.nvim_buf_get_name(0):find("^oil://") ~= nil end), "oil did not open: " .. name())
    require("oil").close()
  end)
  close_explorers()
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- ── Edges (2026-10-21): names as people write them, another case of a name, unsaved changes, folders with open files ──
test("Explorer: a creates names with spaces, umlauts, #, %, &, ' and [ ] exactly as typed", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    w.at(R .. "/a.txt")
    w.answer = "Grüße & Co/100% #1 'quoted' [draft].txt"
    ex.add(p)
    local listed = vim.fn.isdirectory(R .. "/Grüße & Co") == 1 and vim.fn.readdir(R .. "/Grüße & Co") or {}
    assert(vim.deep_equal(listed, { "100% #1 'quoted' [draft].txt" }),
      "in Grüße & Co/: " .. vim.inspect(listed) .. ", in the folder: " .. vim.inspect(vim.fn.readdir(R)) .. " - " .. last())
    w.answer = "Ördner ß/"
    ex.add(p)
    assert(vim.fn.isdirectory(R .. "/Ördner ß") == 1, "no folder Ördner ß: " .. vim.inspect(vim.fn.readdir(R)))
  end)
end)

test("Explorer: r, m and c with spaces, umlauts, #, %, &, ' and [ ] in names - the open buffer goes along", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    local function shown() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
    local from = R .. "/100% #1 'quoted' [draft].txt"
    w.file(from, "content")
    vim.cmd.edit(vim.fn.fnameescape(from))
    w.answer = "Grüße & Co (2) [final].txt" -- r: from the working directory
    ex.rename(p, w.at(from))
    local renamed = R .. "/Grüße & Co (2) [final].txt"
    assert(exists(renamed) and not exists(from), "r: " .. vim.inspect(vim.fn.readdir(R)) .. " - " .. last())
    assert(shown() == renamed, "the buffer did not go along with r: " .. shown())
    vim.fn.mkdir(R .. "/Ördner #2 & ß", "p")
    ex.move(p, w.at(renamed)) -- m on it, m on the folder
    ex.move(p, w.at(R .. "/Ördner #2 & ß"))
    local moved = R .. "/Ördner #2 & ß/Grüße & Co (2) [final].txt"
    assert(exists(moved) and not exists(renamed), "m: " .. last())
    assert(shown() == moved, "the buffer did not go along with m: " .. shown())
    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "content" and not vim.bo.modified, "the buffer's text changed")
    ex.copy(p, w.at(moved)) -- c on it, c on a file in the root: into the root
    ex.copy(p, w.at(R .. "/a.txt"))
    assert(exists(renamed) and exists(moved), "c: " .. last())
  end)
end)

-- On Windows the case of a name is to read, not to tell files apart: readme.txt -> README.txt did nothing (the paths
-- compared equal, so the rename was taken for no change)
test("Explorer: r to another case of the name renames it (Windows too) - the open buffer goes along", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    w.file(R .. "/readme.txt", "read me")
    vim.cmd.edit(vim.fn.fnameescape(R .. "/readme.txt"))
    w.answer = "README.txt"
    ex.rename(p, w.at(R .. "/readme.txt"))
    local names = vim.fn.readdir(R)
    assert(vim.tbl_contains(names, "README.txt") and not vim.tbl_contains(names, "readme.txt"), vim.inspect(names) .. " - " .. last())
    assert(vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "README.txt", "the buffer: " .. vim.api.nvim_buf_get_name(0))
    assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "read me", "the buffer's text changed")
  end)
end)

-- snacks moved the file, opened the new path from disk and threw the old buffer away: its unsaved changes were gone
test("Explorer: r and m leave a file with unsaved changes where it is - nothing of them lost", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    vim.cmd.edit(vim.fn.fnameescape(R .. "/sub/b.txt"))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "not saved yet" })
    local function intact(what)
      assert(vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified, what .. ": the buffer lost its changes")
      local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert(text[1] == "not saved yet", what .. ": the buffer has " .. vim.inspect(text))
    end
    w.answer = "b-renamed.txt"
    ex.rename(p, w.at(R .. "/sub/b.txt"))
    intact("r")
    assert(exists(R .. "/sub/b.txt") and not exists(R .. "/b-renamed.txt"), "r: renamed anyway")
    assert(last():find("unsaved", 1, true), "r: no word why: " .. last())
    ex.move(p, w.at(R .. "/sub/b.txt"))
    ex.move(p, w.at(R .. "/other"))
    intact("m")
    assert(exists(R .. "/sub/b.txt") and not exists(R .. "/other/b.txt"), "m: moved anyway")
    w.answer = "sub-renamed" -- its folder stays too
    ex.rename(p, w.at(R .. "/sub"))
    intact("r of its folder")
    assert(exists(R .. "/sub/b.txt") and not exists(R .. "/sub-renamed"), "r of its folder: renamed anyway")
    vim.bo[buf].modified = false
  end)
end)

-- snacks moved only a buffer named like the folder itself: the buffers of the files in it stayed at the old paths (and
-- :w put a file back where the folder had been)
test("Explorer: m and r of a folder take its open files along", function()
  explorer_world(function(ex, w)
    local p, R = w.picker, w.root
    local function last() return tostring(w.notes[#w.notes]) end
    local function shown() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
    w.file(R .. "/proj/src/main.txt", "main")
    vim.cmd.edit(vim.fn.fnameescape(R .. "/proj/src/main.txt"))
    ex.move(p, w.at(R .. "/proj"))
    ex.move(p, w.at(R .. "/other"))
    assert(exists(R .. "/other/proj/src/main.txt"), "m: " .. last())
    assert(shown() == R .. "/other/proj/src/main.txt", "m: the buffer stayed at " .. shown())
    w.answer = "renamed-proj"
    ex.rename(p, w.at(R .. "/other/proj"))
    assert(exists(R .. "/renamed-proj/src/main.txt"), "r: " .. last())
    assert(shown() == R .. "/renamed-proj/src/main.txt", "r: the buffer stayed at " .. shown())
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      local name = vim.fs.normalize(vim.api.nvim_buf_get_name(b))
      assert(not (name:find("/proj/src/", 1, true) and vim.api.nvim_buf_is_loaded(b)), "a buffer at an old path: " .. name)
    end
  end)
end)

-- The real explorer, the folders open in it (so watched). snacks closed only a buffer named like the deleted path: the
-- buffers of the files in a deleted folder stayed. On Windows the explorer's watchers held the open subfolders: d on
-- such a folder failed, now and then (as soon as they were watched), m too.
test("Explorer: m and d on a folder open in the tree with open subfolders - its open files go along / are closed", function()
  local util, config = Snacks.picker.util, Snacks.explorer.config
  local saved = { confirm = util.confirm, trash = config.trash }
  util.confirm = function(_, yes) yes() end
  config.trash = false -- gone for good: no trash for temp folders everywhere
  local fixture = { "old/notes.txt", "old/deep/todo.txt", "proj/sub/x.txt", "dest/", "keep.txt" }
  local ok, err = pcall(with_explorer, fixture, function(p, root, x)
    local function loaded(dir) -- the loaded buffers of files in dir
      local found = {}
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.fs.normalize(vim.api.nvim_buf_get_name(b))
        if name:find(dir .. "/", 1, true) == 1 and vim.api.nvim_buf_is_loaded(b) then found[#found + 1] = x.rel(name) end
      end
      return found
    end
    local notes, notify = {}, vim.notify
    vim.notify = function(msg, ...) notes[#notes + 1] = tostring(msg); return notify(msg, ...) end
    local function said() return table.concat(notes, " | ") end
    vim.api.nvim_set_current_win(p.main)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/proj/sub/x.txt"))
    vim.cmd.edit(vim.fn.fnameescape(root .. "/old/deep/todo.txt"))
    vim.cmd.edit(vim.fn.fnameescape(root .. "/old/notes.txt"))
    -- the tree follows the file in the editor: done with that before the keys
    assert(H.wait(3000, function() return not p:is_active() and p:current() and p:current().file == root .. "/old/notes.txt" end),
      "the tree did not follow: on " .. tostring(p:current() and x.rel(p:current().file)))
    p:focus("list")
    x.on("proj")
    p:action("explorer_move") -- m: marks proj
    x.on("dest")
    p:action("explorer_move") -- m on dest: proj goes there
    local ok, err = pcall(function()
      assert(H.wait(3000, function() return vim.uv.fs_stat(root .. "/dest/proj/sub/x.txt") ~= nil end), "proj/ not moved: " .. said())
      assert(#loaded(root .. "/proj") == 0, "buffers at the old paths: " .. table.concat(loaded(root .. "/proj"), ", "))
      assert(vim.fn.bufexists(root .. "/dest/proj/sub/x.txt") == 1, "x.txt's buffer did not go along")
      x.on("old")
      p:action("explorer_del")
      assert(H.wait(3000, function() return not vim.uv.fs_stat(root .. "/old") end), "old/ not deleted: " .. said())
      assert(#loaded(root .. "/old") == 0, "buffers of deleted files: " .. table.concat(loaded(root .. "/old"), ", "))
    end)
    vim.notify = notify
    assert(ok, err)
  end, { open = { "old", "old/deep", "proj", "proj/sub" } })
  util.confirm, config.trash = saved.confirm, saved.trash
  assert(ok, err)
end)

-- vim.cmd("vsplit " .. path): a space split the path in two, # and % stood for the alternate and the current file
test("Docs: <leader>gd opens a doc also when the config's path has spaces, # and %", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/my config #1 100%", "p")
  local config = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp .. "/my config #1 100%")))
  vim.fn.writefile({ "# test readme" }, config .. "/README.md")
  local stdpath, select = vim.fn.stdpath, vim.ui.select
  vim.fn.stdpath = function(what) return what == "config" and config or stdpath(what) end
  vim.ui.select = function(_, _, choose) choose("README.md") end
  local win = vim.api.nvim_get_current_win()
  local ok, err = pcall(function()
    vim.fn.maparg("<leader>gd", "n", false, true).callback()
    local name = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
    assert(name == config .. "/README.md", "opened " .. name)
    assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "# test readme", "not the readme")
  end)
  vim.fn.stdpath, vim.ui.select = stdpath, select
  if vim.api.nvim_get_current_win() ~= win then pcall(vim.cmd, "close") end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):find(config, 1, true) == 1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

-- One session per folder and git branch (persisted): a branch with a / in it (feature/login), a folder with spaces,
-- an umlaut and a # - each branch gets its own session file and back on the branch its own files come back
test("Session: one per git branch, also feature/login, in a folder with spaces, ä and # - each loads its own", function()
  if vim.fn.executable("git") == 0 then H.skip("git not installed") end
  local persisted, config = require("persisted"), require("persisted.config")
  local saved_dir = config.save_dir
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/sessions", "p")
  vim.fn.mkdir(tmp .. "/my project ä #1", "p")
  config.save_dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp .. "/sessions"))) .. "/"
  local project = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp .. "/my project ä #1")))
  local before = vim.fn.getcwd()
  local function git(...) vim.fn.system(vim.list_extend({ "git" }, { ... })); return vim.v.shell_error == 0 end
  local function shown() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
  local ok, err = pcall(function()
    vim.fn.chdir(project)
    assert(git("init", "-q") and git("symbolic-ref", "HEAD", "refs/heads/feature/login"), "git init")
    assert(persisted.branch() == "feature/login", "branch: " .. tostring(persisted.branch()))
    vim.fn.writefile({ "login" }, project .. "/login.txt")
    vim.fn.writefile({ "main" }, project .. "/main.txt")
    vim.cmd("silent! %bwipeout!")
    vim.cmd.edit(vim.fn.fnameescape(project .. "/login.txt"))
    persisted.save({ force = true })
    local login = persisted.current()
    assert(vim.fn.filereadable(login) == 1, "no session file: " .. login)
    assert(git("symbolic-ref", "HEAD", "refs/heads/main") and persisted.branch() == "main", "branch main")
    vim.cmd("silent! %bwipeout!")
    vim.cmd.edit(vim.fn.fnameescape(project .. "/main.txt"))
    persisted.save({ force = true })
    local main = persisted.current()
    assert(main ~= login and vim.fn.filereadable(main) == 1, "main's session: " .. main)
    assert(git("symbolic-ref", "HEAD", "refs/heads/feature/login"), "back to feature/login")
    vim.cmd("silent! %bwipeout!")
    persisted.load()
    assert(H.wait(3000, function() return shown() == project .. "/login.txt" end), "feature/login's session brought back " .. shown())
  end)
  config.save_dir = saved_dir
  pcall(persisted.stop) -- load() starts recording: this test run saves no session
  vim.g.persisting_session, vim.g.persisted_loaded_session = nil, nil
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

test("Pickers: <leader>ff finds a file by name and opens it, <leader>fg finds a line and jumps to it (fd, rg)", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/src/deep", "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  vim.fn.writefile({ "alpha", "beta needle_4711 gamma", "delta" }, root .. "/src/deep/target.txt")
  vim.fn.writefile({ "nothing here" }, root .. "/src/other.txt")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  local function picker(source) return Snacks.picker.get({ source = source })[1] end
  local function current() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) end
  local ok, err = pcall(function()
    Snacks.picker.files() -- <leader>ff: fd lists the files, the typed text narrows them, Enter opens one
    assert(H.wait(OPEN_MS, function() return picker("files") end), "the files picker did not open")
    local p = picker("files")
    p.input:set("target")
    p:find({ refresh = false })
    assert(H.wait(5000, function() return not p:is_active() and p.list:count() == 1 end), "files: " .. p.list:count() .. " found")
    p:action("confirm")
    assert(H.wait(3000, function() return current() == root .. "/src/deep/target.txt" end), "not opened: " .. current())
    Snacks.picker.grep() -- <leader>fg: rg finds the line (live: the text goes to rg), Enter jumps there
    assert(H.wait(OPEN_MS, function() return picker("grep") end), "the grep picker did not open")
    local g = picker("grep")
    g.input:set(nil, "needle_4711")
    g:find({ refresh = false })
    assert(H.wait(5000, function() return not g:is_active() and g.list:count() == 1 end), "grep: " .. g.list:count() .. " found")
    g:action("confirm")
    assert(H.wait(3000, function() return current() == root .. "/src/deep/target.txt" and vim.api.nvim_win_get_cursor(0)[1] == 2 end),
      "not at the line: " .. current() .. ":" .. vim.api.nvim_win_get_cursor(0)[1])
  end)
  for _, source in ipairs({ "files", "grep" }) do
    if picker(source) then picker(source):close() end
  end
  vim.cmd("stopinsert")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):find(root .. "/", 1, true) == 1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: sessions (plugins/session.lua). persisted 2 ignored version 1's options: sessions for ~ and /, quitting
-- from the start screen overwrote a session with an empty one, a restored session brought the explorer's frame back
-- as an empty window and the terminals as new shells. And test runs saved theirs over the real one (tests/harness.lua).
-- ── Dev workflows (2026-10-21): search & replace over a project, git ──────────────────────────────────────────────
test("Search & replace: <leader>sr (grug-far) renames a name in every file of a folder - files elsewhere and other text stay", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/proj/sub", "p")
  vim.fn.mkdir(tmp .. "/other", "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local files = {
    ["proj/a.py"] = { "old_name = 1", "print(old_name)", "keep = 'unrelated'" },
    ["proj/sub/b.py"] = { "from a import old_name", "print(old_name + 1)" },
    ["other/c.py"] = { "old_name = 3" }, -- outside the folder searched
  }
  for rel, lines in pairs(files) do vim.fn.writefile(lines, root .. "/" .. rel) end
  local gf = require("grug-far")
  local ok, err = pcall(function()
    gf.open({ instanceName = "gk-test", prefills = { search = "old_name", replacement = "new_name", paths = root .. "/proj" } })
    local inst = gf.get_instance("gk-test")
    local ready = false
    inst:when_ready(function() ready = true end)
    assert(H.wait(10000, function() return ready end), "grug-far did not get ready")
    inst:replace()
    local function text(rel) return table.concat(vim.fn.readfile(root .. "/" .. rel), "\n") end
    assert(H.wait(10000, function() return text("proj/a.py"):find("new_name", 1, true) and text("proj/sub/b.py"):find("new_name", 1, true) end),
      "not replaced: " .. text("proj/a.py") .. " | " .. text("proj/sub/b.py"))
    assert(text("proj/a.py") == "new_name = 1\nprint(new_name)\nkeep = 'unrelated'", text("proj/a.py"))
    assert(text("proj/sub/b.py") == "from a import new_name\nprint(new_name + 1)", text("proj/sub/b.py"))
    assert(text("other/c.py") == "old_name = 3", "a file outside the folder changed: " .. text("other/c.py"))
    H.wait(5000, function() -- done replacing: closing asks while a replace still runs
      for _, task in ipairs(inst._context.state.tasks) do if not task.isFinished then return false end end
      return true
    end)
    inst:close()
  end)
  if gf.has_instance("gk-test") then pcall(gf.kill_instance, "gk-test") end
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Git: added, changed and deleted lines get their signs; the explorer's ]g / [g go from changed file to changed file", function()
  if vim.fn.executable("git") == 0 then H.skip("git not installed") end
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local function git(...)
    local out = vim.fn.system(vim.list_extend({ "git", "-C", root, "-c", "user.name=gk", "-c", "user.email=gk@example.invalid" }, { ... }))
    assert(vim.v.shell_error == 0, "git " .. table.concat({ ... }, " ") .. ": " .. out)
  end
  local lines = { "one", "two", "three", "four", "five", "six", "seven", "eight" }
  for _, name in ipairs({ "a.txt", "b.txt", "c.txt", "d.txt" }) do vim.fn.writefile(lines, root .. "/" .. name) end
  git("init", "-q")
  git("add", ".")
  git("commit", "-q", "-m", "init")
  -- a.txt: line 2 changed, a line after 4, line 8 gone; c.txt changed; b.txt and d.txt as committed
  vim.fn.writefile({ "one", "TWO", "three", "four", "four and a half", "five", "six", "seven" }, root .. "/a.txt")
  vim.fn.writefile({ "one", "two", "three", "four", "five", "six", "seven", "EIGHT" }, root .. "/c.txt")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    local buf = vim.api.nvim_get_current_buf()
    local gs = require("gitsigns")
    local function kinds()
      local seen = {}
      for _, h in ipairs(gs.get_hunks(buf) or {}) do seen[#seen + 1] = h.type end
      table.sort(seen)
      return table.concat(seen, " ")
    end
    assert(H.wait(10000, function() return kinds() == "add change delete" end), "hunks: " .. kinds())
    -- the hunk keys: ]c to a change, <leader>gs stages it, <leader>gr undoes the next, <leader>gp shows one, <leader>gb
    local function key(lhs) return vim.fn.maparg(lhs, "n", false, true) end
    local function line() return vim.api.nvim_win_get_cursor(0)[1] end
    local function has_float(text)
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(win).relative ~= "" and H.text(vim.api.nvim_win_get_buf(win)):find(text, 1, true) then return win end
      end
    end
    assert(key("]c").buffer == 1 and key("<leader>gs").buffer == 1, "no hunk keys in a file of the repository")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    key("]c").callback()
    assert(H.wait(3000, function() return line() == 2 end), "]c: line " .. line())
    key("<leader>gs").callback()
    local function staged() return vim.fn.system({ "git", "-C", root, "diff", "--cached" }) end
    assert(H.wait(5000, function() return staged():find("+TWO", 1, true) ~= nil end), "<leader>gs did not stage: " .. staged())
    key("]c").callback()
    assert(H.wait(3000, function() return line() == 5 end), "]c to the added line: line " .. line())
    key("<leader>gr").callback()
    assert(H.wait(3000, function() return not vim.tbl_contains(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "four and a half") end),
      "<leader>gr did not undo the added line")
    key("]c").callback() -- the last change: eight deleted
    key("<leader>gp").callback()
    local preview = H.wait(5000, function() return has_float("eight") end)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then pcall(vim.api.nvim_win_close, win, true) end
    end
    assert(preview, "<leader>gp showed no change with eight")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    key("<leader>gb").callback()
    local blame = H.wait(5000, function() return has_float("gk") end)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then pcall(vim.api.nvim_win_close, win, true) end
    end
    assert(blame, "<leader>gb showed no author")
    -- the explorer: ]g / [g between the changed files a.txt and c.txt
    close_explorers()
    Snacks.explorer()
    assert(H.wait(OPEN_MS, function() return explorers()[1] end), "explorer did not open")
    local p = explorers()[1]
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() >= 5 end), "explorer did not list")
    local function on(file)
      return H.wait(3000, function() return not p:is_active() and p:current() and p:current().file == root .. "/" .. file end)
    end
    assert(H.wait(5000, function() -- git status comes after the listing
      for i = 1, p.list:count() do
        local it = p.list:get(i)
        if it.file == root .. "/c.txt" and it.status then return true end
      end
    end), "no git status in the tree")
    assert(H.wait(3000, function() -- the cursor there (the tree follows the file in the editor: until it stays)
      local cur = p:current()
      if cur and cur.file == root .. "/b.txt" and not p:is_active() then return true end
      for i = 1, p.list:count() do if p.list:get(i).file == root .. "/b.txt" then p.list:view(i) end end
    end), "cursor not on b.txt")
    p:action("explorer_git_next") -- ]g
    assert(on("c.txt"), "]g from b.txt: " .. tostring(p:current() and p:current().file))
    p:action("explorer_git_prev") -- [g
    assert(on("a.txt"), "[g from c.txt: " .. tostring(p:current() and p:current().file))
  end)
  close_explorers()
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- 2026-10-21: one git run that could not start (its folder gone: vim.system threw) inside gitsigns' repository lock
-- kept the lock taken - no file got signs any more for the rest of the session (the full suite on Kali, after the
-- explorer's moves). Here the folder is there when gitsigns looks and gone when git starts.
test("Git: a git run that cannot start (its folder just gone) does not stop gitsigns - the next file still gets its signs", function()
  if vim.fn.executable("git") == 0 then H.skip("git not installed") end
  local missing = vim.fs.normalize(vim.fn.tempname() .. "-gone")
  local stat = vim.uv.fs_stat
  vim.uv.fs_stat = function(path, ...) -- "there" for gitsigns' check, so git starts in it - and cannot
    if type(path) == "string" and vim.fs.normalize(path) == missing then return { type = "directory" } end
    return stat(path, ...)
  end
  local ok, err = pcall(function()
    local task = require("gitsigns.async").run(function() return require("gitsigns.git.repo").get(missing) end)
    task:pwait(5000)
  end)
  vim.uv.fs_stat = stat
  assert(ok, err)
  -- the lock is free: a file of a real repository gets its signs
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local function git(...) vim.fn.system(vim.list_extend({ "git", "-C", root, "-c", "user.name=gk", "-c", "user.email=gk@example.invalid" }, { ... })) end
  vim.fn.writefile({ "one", "two" }, root .. "/a.txt")
  git("init", "-q")
  git("add", ".")
  git("commit", "-q", "-m", "init")
  vim.fn.writefile({ "one", "TWO" }, root .. "/a.txt")
  vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
  local buf = vim.api.nvim_get_current_buf()
  local got = H.wait(10000, function() return #(require("gitsigns").get_hunks(buf) or {}) == 1 end)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(root, "rf")
  assert(got, "no signs after the failed run: gitsigns' lock stayed taken")
end)

test("Session: a file, the explorer, a terminal and help - back are the file and help, no empty window, no new shell", function()
  local persisted, config = require("persisted"), require("persisted.config")
  assert(vim.g.persisting == false, "this test run records a session")
  assert(not persisted.allowed_dir({ dir = vim.fn.expand("~") }) and not persisted.allowed_dir({ dir = "/" }), "a session for ~ or /")
  assert(persisted.allowed_dir({ dir = vim.fn.expand("~") .. "/projects/x" }), "no session for a project below ~")
  assert(not vim.o.sessionoptions:find("blank") and not vim.o.sessionoptions:find("terminal"), vim.o.sessionoptions)
  -- quitting with no file open keeps the old session; with a file open it is saved
  local listed = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      listed[#listed + 1] = buf
      vim.bo[buf].buflisted = false
    end
  end
  local saves_none = config.should_save()
  local file = H.file("kept.txt", { "kept" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local saves_file = config.should_save()
  -- nor in an ignored folder Neovim moved to (persisted checks them when it starts only: :cd ~ and quit saved one)
  local cwd = vim.fn.getcwd()
  vim.fn.chdir(vim.fn.expand("~"))
  local saves_home = config.should_save()
  vim.fn.chdir(cwd)
  for _, buf in ipairs(listed) do
    if vim.api.nvim_buf_is_valid(buf) then vim.bo[buf].buflisted = true end
  end
  assert(saves_none == false, "no file open: the session would be overwritten")
  assert(saves_file == true, "a file open: no session saved")
  assert(saves_home == false, "a :cd ~ before quitting saved a session for ~")
  -- a session saved with the file, the explorer, a terminal and help open; all of it gone; the session back
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(vim.fs.dirname(file))))
  local session = dir .. "/session.vim"
  local before = vim.fn.getcwd()
  vim.fn.chdir(dir)
  local term
  local ok, err = pcall(function()
    close_explorers()
    Snacks.explorer()
    assert(H.wait(OPEN_MS, function() return Snacks.picker.get({ source = "explorer" })[1] end), "explorer did not open")
    vim.cmd("wincmd l")
    term = require("toggleterm.terminal").Terminal:new({ direction = "horizontal" }) -- a shell
    term:toggle()
    assert(H.wait(5000, function() return vim.bo.buftype == "terminal" end), "no terminal")
    vim.cmd("wincmd k")
    vim.cmd("help")
    vim.cmd("mksession! " .. vim.fn.fnameescape(session))
    close_explorers()
    term:shutdown()
    vim.cmd("silent! %bwipeout!")
    vim.cmd("silent source " .. vim.fn.fnameescape(session))
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative == "" then -- notifications float
        local buf = vim.api.nvim_win_get_buf(win)
        wins[#wins + 1] = vim.bo[buf].buftype .. ":" .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      end
    end
    table.sort(wins)
    assert(vim.deep_equal(wins, { ":kept.txt", "help:help.txt" }), "restored: " .. table.concat(wins, " "))
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      assert(vim.bo[buf].buftype ~= "terminal", "a terminal came back: " .. vim.api.nvim_buf_get_name(buf))
    end
  end)
  if term and term:is_open() then pcall(function() term:shutdown() end) end
  close_explorers()
  vim.cmd("silent! only")
  vim.cmd("enew")
  vim.fn.chdir(before)
  assert(ok, err)
end)

-- 2026-10-21: the clipboard (config/clipboard.lua). Locally Neovim picks the tool - the hand-made choice took xclip
-- wherever DISPLAY was set, installed or not. Over SSH OSC 52 copies and p pastes the last copy: a terminal that cannot
-- answer an OSC 52 read (Windows Terminal) made every p wait 10 s.
test("Clipboard: over SSH OSC 52 copies, p pastes the last copy; locally Neovim picks the tool", function()
  local clip = require("config.clipboard")
  local function env(vars) return function(name) return vars[name] end end
  assert(clip.provider(env({ DISPLAY = ":0", WAYLAND_DISPLAY = "wayland-0" })) == nil, "locally a hand-made choice")
  assert(clip.provider(env({ SSH_TTY = "" })) == nil, "an empty SSH_TTY is no SSH session")
  local p = clip.provider(env({ SSH_TTY = "/dev/pts/1", DISPLAY = ":0" }))
  assert(p and p.name:find("OSC 52", 1, true), "over SSH: " .. tostring(p and p.name))
  -- a copy goes out with OSC 52 (a stand-in: no escape sequence for this terminal), a paste is the last copy
  local sent, real = {}, package.loaded["vim.ui.clipboard.osc52"]
  package.loaded["vim.ui.clipboard.osc52"] = {
    copy = function(reg) return function(lines) sent[#sent + 1] = reg .. ":" .. table.concat(lines, "\n") end end,
  }
  local ok, err = pcall(function()
    assert(vim.deep_equal(p.paste["+"](), { { "" }, "v" }), "before a copy: " .. vim.inspect(p.paste["+"]()))
    p.copy["+"]({ "one", "two" }, "V")
    assert(sent[1] == "+:one\ntwo", "not sent with OSC 52: " .. vim.inspect(sent))
    assert(vim.deep_equal(p.paste["+"](), { { "one", "two" }, "V" }), "p: " .. vim.inspect(p.paste["+"]()))
    assert(vim.deep_equal(p.paste["*"](), { { "" }, "v" }), "* has a last copy of its own")
  end)
  package.loaded["vim.ui.clipboard.osc52"] = real
  assert(ok, err)
  if (vim.env.SSH_TTY or "") == "" and (vim.env.AIDASH_TOKEN or "") == "" then -- this run: no SSH, no dashboard
    assert(vim.g.clipboard == nil, "a hand-made clipboard: " .. vim.inspect(vim.g.clipboard))
  end
end)

test("Providers: Node, Perl, Ruby and Python are off - no plugin here uses them, :checkhealth stays quiet", function()
  for _, name in ipairs({ "node", "perl", "ruby", "python3" }) do
    assert(vim.g["loaded_" .. name .. "_provider"] == 0, name .. " provider on")
  end
end)

-- 2026-10-20: input dialogs (rename, copy to, the agent's questions: every vim.ui.input) edit like a shell prompt
test("Input dialogs: <C-a> <C-e> <C-b> <C-f> <C-d> <C-k> edit like a shell prompt, <CR> still confirms", function()
  local got
  local win = Snacks.input({ prompt = "Rename", default = "src/foo/bar.py" }, function(value) got = value end)
  local function line() return vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)[1] end
  -- A types at the end; <C-\><C-n> leaves insert mode without <Esc>, which closes the dialog in normal mode
  local function typed(keys)
    vim.api.nvim_feedkeys(vim.keycode("A" .. keys .. "<C-\\><C-n>"), "x", false)
    return line()
  end
  local ok, err = pcall(function()
    vim.cmd("stopinsert") -- the dialog's own startinsert waits for the end of this script: the keys below type
    assert(typed("<C-a>X<C-e>Y") == "Xsrc/foo/bar.pyY", "<C-a> / <C-e>: " .. line())
    assert(typed("<C-a><C-f><C-f><C-f><C-k>") == "Xsr", "<C-f> / <C-k>: " .. line())
    assert(typed("<C-a><C-d>") == "sr", "<C-d>: " .. line())
    assert(typed("<C-b><C-b>Z") == "Zsr", "<C-b>: " .. line())
    vim.api.nvim_feedkeys(vim.keycode("A<CR>"), "x", false)
    H.wait(5000, function() return got ~= nil end) -- snacks hands the answer over in a scheduled callback
    assert(got == "Zsr", "<CR> did not confirm: " .. tostring(got))
  end)
  if win:valid() then win:close() end
  assert(ok, err)
end)

-- T14: Markdown links (2026-10-19)
test("Markdown: anchors like GitLab (and GitHub)", function()
  local md = require("config.mdlinks")
  assert(md.slug("Running Scripts & REPL") == "running-scripts-repl", md.slug("Running Scripts & REPL"))
  assert(md.slug("Running Scripts & REPL", true) == "running-scripts--repl")
  assert(md.slug("Debugging (DAP)") == "debugging-dap")
  assert(md.slug("AI (Qwen Code) — `<leader>a`") == "ai-qwen-code-leadera", md.slug("AI (Qwen Code) — `<leader>a`"))
  local a = md.anchors({ "# Top", "```", "# not a heading", "```", "## Top", "## Über uns" })
  assert(a["top"] == 1 and a["top-1"] == 5 and a["not-a-heading"] == nil and a["über-uns"] == 6, vim.inspect(a))
  local links = md.links({ "[a](#x) `[b](#code)` [c](b.md#y \"title\")" })
  assert(#links == 2 and links[1].target == "#x" and links[2].target == "b.md#y", vim.inspect(links))
end)

test("Markdown: gd / Enter follow links, Ctrl+o comes back", function()
  local dir = vim.fn.resolve(vim.fn.tempname())
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ "# Top", "", "See [part two](#part-two-more) and [b](b.md#target-here).", "", "plain line", "", "## Part Two & More", "text" }, dir .. "/a.md")
  vim.fn.writefile({ "# B", "", "## Target Here", "x" }, dir .. "/b.md")
  local ok, err = pcall(function()
    vim.cmd.edit(dir .. "/a.md")
    assert(vim.bo.filetype == "markdown", "filetype " .. vim.bo.filetype)
    for _, key in ipairs({ "gd", "<CR>" }) do
      local m = vim.fn.maparg(key, "n", false, true)
      assert(m.buffer == 1 and m.desc == "Follow link", key .. " does not follow links")
    end
    local line = vim.fn.getline(3)
    vim.api.nvim_win_set_cursor(0, { 3, (line:find("part two", 1, true)) })
    vim.api.nvim_feedkeys(vim.keycode("gd"), "x", false)
    assert(vim.fn.line(".") == 7, "gd went to line " .. vim.fn.line("."))
    vim.api.nvim_feedkeys(vim.keycode("<C-o>"), "x", false)
    assert(vim.fn.line(".") == 3, "Ctrl+o went to line " .. vim.fn.line("."))
    vim.api.nvim_win_set_cursor(0, { 3, (line:find("[b]", 1, true)) })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert(vim.fn.expand("%:t") == "b.md" and vim.fn.line(".") == 3, "Enter went to " .. vim.fn.expand("%:t") .. ":" .. vim.fn.line("."))
    vim.cmd.edit(dir .. "/a.md")
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert(vim.fn.line(".") == 6, "Enter off a link: line " .. vim.fn.line("."))
  end)
  for _, f in ipairs({ "a.md", "b.md" }) do vim.cmd("silent! bwipeout! " .. vim.fn.fnameescape(dir .. "/" .. f)) end
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- 2026-10-21: a file with spaces in its name, linked as CommonMark has it - <my notes.md> or my%20notes.md (and
-- %C3%BC for ü): the target ended at the first space, %20 stayed as it was - "No file my"
test("Markdown: links to files with spaces and umlauts - <my notes.md>, my%20notes.md, Gr%C3%BC%C3%9Fe.md - are followed", function()
  local md = require("config.mdlinks")
  local links = md.links({ '[a](<my notes.md>) [b](my%20notes.md#teil-zwei "t") [c](Gr%C3%BC%C3%9Fe.md) [d](https://x.org/a%20b)' })
  local targets = vim.tbl_map(function(l) return l.target end, links)
  assert(vim.deep_equal(targets, { "my notes.md", "my notes.md#teil-zwei", "Grüße.md", "https://x.org/a%20b" }), vim.inspect(targets))
  local dir = vim.fs.normalize(vim.fn.resolve(vim.fn.tempname()))
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ "[a](<my notes.md>) [b](my%20notes.md#teil-zwei) [c](Gr%C3%BC%C3%9Fe.md)" }, dir .. "/index.md")
  vim.fn.writefile({ "# Notes", "", "## Teil zwei", "x" }, dir .. "/my notes.md")
  vim.fn.writefile({ "# Grüße" }, dir .. "/Grüße.md")
  local ok, err = pcall(function()
    local function follow(link, want, lnum)
      vim.cmd.edit(vim.fn.fnameescape(dir .. "/index.md"))
      vim.api.nvim_win_set_cursor(0, { 1, (vim.fn.getline(1):find(link, 1, true)) })
      vim.api.nvim_feedkeys(vim.keycode("gd"), "x", false)
      local name = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
      assert(name == dir .. "/" .. want and vim.fn.line(".") == lnum, link .. " went to " .. name .. ":" .. vim.fn.line("."))
    end
    follow("[a]", "my notes.md", 1)
    follow("[b]", "my notes.md", 3)
    follow("[c]", "Grüße.md", 1)
  end)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):find(dir, 1, true) == 1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- 2026-10-19: <leader>d was an operator and the start of 14 debug keys - debug always won
test("Keys: no <leader> key is both an action and the start of others", function()
  local bad = {}
  for _, mode in ipairs({ "n", "x" }) do
    local keys = {}
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local k = m.lhs:gsub("^ ", "<leader>")
      if k:match("^<leader>") then keys[#keys + 1] = k end
    end
    for _, a in ipairs(keys) do
      for _, b in ipairs(keys) do
        if b ~= a and b:sub(1, #a) == a then bad[#bad + 1] = mode .. " " .. a .. " (also starts " .. b .. ")"; break end
      end
    end
  end
  assert(#bad == 0, "keys that wait or are shadowed: " .. table.concat(bad, ", "))
end)

-- T15: Fresh installs (2026-10-19)
-- <C-Space> / <BS> called nvim-treesitter's incremental_selection module, which its main branch no longer has:
-- every press was an error. They run Neovim's own node selection now; its keys an / in are mini.ai's "next"
-- textobjects here, so the test loads mini.ai as an interactive start does.
test("Keys: <C-Space> selects the node at the cursor and grows it, <BS> shrinks it back", function()
  require("lazy").load({ plugins = { "mini.ai" } })
  vim.cmd("tabnew") -- a plain window of its own: a picker window can keep its buffer against set_current_buf
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local total = add(first, second)" })
  vim.cmd("noautocmd setlocal filetype=lua")
  local function selected() return { vim.fn.getpos("'<")[3], vim.fn.getpos("'>")[3] } end
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 1, 20 }) -- on "first" (columns 19-23)
    vim.api.nvim_feedkeys(vim.keycode("<C-Space><Esc>"), "x", false)
    local node = selected()
    assert(node[1] == 19 and node[2] == 23, "<C-Space> selected " .. vim.inspect(node) .. ", not first (19-23)")
    vim.api.nvim_feedkeys(vim.keycode("gv<C-Space><Esc>"), "x", false)
    local grown = selected()
    assert(grown[1] <= node[1] and grown[2] >= node[2] and grown[2] - grown[1] > node[2] - node[1],
      "<C-Space> did not grow " .. vim.inspect(node) .. ": " .. vim.inspect(grown))
    vim.api.nvim_feedkeys(vim.keycode("gv<BS><Esc>"), "x", false)
    assert(vim.deep_equal(selected(), node), "<BS> left " .. vim.inspect(selected()) .. ", not " .. vim.inspect(node))
  end)
  vim.cmd("tabclose")
  vim.api.nvim_buf_delete(buf, { force = true })
  assert(ok, err)
end)

-- mason-nvim-dap wants nvim-dap's adapter names ("python") and drops anything else without a word: "debugpy"
-- was in the list, so a fresh machine never got the Python debugger.
test("Debug: every adapter for Mason is one mason-nvim-dap knows", function()
  local plugin = require("lazy.core.config").plugins["mason-nvim-dap.nvim"]
  assert(plugin, "mason-nvim-dap is not set up")
  local wanted = require("lazy.core.plugin").values(plugin, "opts", false).ensure_installed or {}
  assert(#wanted > 0, "no debug adapters to install")
  local known = require("mason-nvim-dap.mappings.source").nvim_dap_to_package
  for _, name in ipairs(wanted) do
    assert(known[name], name .. " is not an nvim-dap adapter name (mason-nvim-dap would skip it)")
  end
end)

-- T16: IntelliJ's settings (2026-10-19): GreyKnight works on an IntelliJ project the way IntelliJ does - the JDK
-- and Maven IntelliJ uses (no drift), its Actions on Save and its Reformat Code - and finds its Remote JVM Debug
-- configurations. A complete IntelliJ world in a temp dir ($GREYKNIGHT_INTELLIJ_CONFIG points at its settings).
local function intellij_world()
  local base = vim.fs.normalize(vim.fn.tempname())
  local w = { base = base, config = base .. "/config", a = base .. "/projects/a", b = base .. "/projects/b" }
  local function write(path, lines)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(type(lines) == "table" and lines or { lines }, path)
  end
  write(base .. "/jdk17/release", 'JAVA_VERSION="17.0.19"')
  write(base .. "/jdk21/release", 'JAVA_VERSION="21.0.12"')
  write(w.config .. "/options/jdk.table.xml", {
    '<application><component name="ProjectJdkTable">',
    '<jdk version="2"><name value="17" /><type value="JavaSDK" /><version value="Temurin 17" /><homePath value="' .. base .. '/jdk17" /></jdk>',
    '<jdk version="2"><name value="temurin-21" /><type value="JavaSDK" /><version value="Temurin 21" /><homePath value="' .. base .. '/jdk21" /></jdk>',
    '<jdk version="2"><name value="Python 3" /><type value="Python SDK" /><homePath value="/usr/bin/python3" /></jdk>',
    "</component></application>",
  })
  write(w.config .. "/options/recentProjects.xml", {
    '<application><component name="RecentProjectsManager"><option name="additionalInfo"><map>',
    '<entry key="' .. w.b .. '"><value /></entry>', "</map></option></component></application>",
  })
  write(w.a .. "/.idea/misc.xml", {
    '<project version="4"><component name="ProjectRootManager" version="2" languageLevel="JDK_17" default="true" project-jdk-name="17" project-jdk-type="JavaSDK">',
    '<output url="file://$PROJECT_DIR$/out" /></component></project>',
  })
  write(w.a .. "/.idea/workspace.xml", {
    '<project version="4">',
    '<component name="MavenImportPreferences"><option name="generalSettings"><MavenGeneralSettings>',
    '<option name="customMavenHome" value="' .. base .. '/maven" />',
    '<option name="localRepository" value="$PROJECT_DIR$/repo" />',
    '<option name="mavenHomeTypeForPersistence" value="CUSTOM" />',
    '<option name="userSettingsFile" value="$USER_HOME$/my-settings.xml" />',
    "</MavenGeneralSettings></option></component>",
    '<component name="RunManager">',
    '<configuration default="true" type="Remote"><option name="HOST" value="localhost" /><option name="PORT" value="5005" /></configuration>',
    '<configuration name="myVM" type="Remote" factoryName="Remote"><option name="SERVER_MODE" value="false" /><option name="HOST" value="dev.example" /><option name="PORT" value="8000" /></configuration>',
    '<configuration name="listen" type="Remote"><option name="SERVER_MODE" value="true" /><option name="HOST" value="localhost" /><option name="PORT" value="9000" /></configuration>',
    "</component></project>",
  })
  write(w.a .. "/.idea/prettier.xml", '<project version="4"><component name="PrettierConfiguration"><option name="myConfigurationMode" value="AUTOMATIC" /></component></project>')
  write(w.a .. "/node_modules/prettier/package.json", "{}")
  write(w.b .. "/.idea/workspace.xml", {
    '<project version="4"><component name="RunManager">',
    '<configuration name="nebula" type="Remote"><option name="HOST" value="qa.example" /><option name="PORT" value="8000" /></configuration>',
    '<configuration name="myVM again" type="Remote"><option name="HOST" value="dev.example" /><option name="PORT" value="8000" /></configuration>',
    "</component>",
    '<component name="FormatOnSaveOptions"><option name="myRunOnSave" value="true" /><option name="myAllFileTypesSelected" value="false" />',
    '<option name="mySelectedFileTypes"><set><option value="JAVA" /></set></option></component>',
    '<component name="OptimizeOnSaveOptions"><option name="myRunOnSave" value="true" /></component>',
    "</project>",
  })
  for _, f in ipairs({ w.a .. "/src/Main.java", w.a .. "/src/app.ts", w.a .. "/src/app.html", w.b .. "/src/Main.java",
    w.b .. "/src/app.ts", base .. "/plain/x.lua", base .. "/plain/X.java" }) do
    write(f, "")
  end
  return w
end

-- Runs fn(ij, w) in an IntelliJ world; buffers it opened are wiped afterwards
local function in_intellij_world(fn)
  local w = intellij_world()
  local saved = vim.env.GREYKNIGHT_INTELLIJ_CONFIG
  local before = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do before[b] = true end
  vim.env.GREYKNIGHT_INTELLIJ_CONFIG = w.config
  local ok, err = pcall(fn, require("integrations.intellij"), w)
  vim.env.GREYKNIGHT_INTELLIJ_CONFIG = saved
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if not before[b] then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end
  vim.fn.delete(w.base, "rf")
  assert(ok, err)
end

test("IntelliJ: its JDKs, a project's JDK and Maven settings", function()
  in_intellij_world(function(ij, w)
    assert(ij.config_dir() == w.config, tostring(ij.config_dir()))
    local jdks = ij.jdks()
    assert(#jdks == 2 and jdks[1].name == "17" and jdks[1].major == 17 and jdks[2].major == 21, vim.inspect(jdks))
    local p = ij.project(ij.project_root(w.a .. "/src/Main.java"))
    assert(p and p.root == w.a and p.jdk and p.jdk.home == w.base .. "/jdk17" and p.language_level == 17, vim.inspect(p))
    local home = vim.fs.normalize((vim.fn.has("win32") == 1 and vim.env.USERPROFILE) or vim.env.HOME)
    assert(p.maven.home == w.base .. "/maven" and p.maven.local_repository == w.a .. "/repo"
      and p.maven.user_settings == home .. "/my-settings.xml", vim.inspect(p.maven))
    assert(not p.save.format and not p.save.optimize_imports and p.prettier.mode == "AUTOMATIC" and not p.prettier.on_save, vim.inspect(p))
  end)
end)

test("IntelliJ: saving and <leader>fm do what IntelliJ's Actions on Save and Reformat Code do", function()
  in_intellij_world(function(ij, w)
    local function at(file) -- no FileType event: no jdtls start, no server install as a side effect
      vim.cmd("noautocmd edit " .. vim.fn.fnameescape(file))
      vim.cmd("noautocmd setlocal filetype=" .. (vim.filetype.match({ filename = file }) or ""))
      return ij.save_actions(0), ij.reformat_options(0)
    end
    local save, reformat = at(w.a .. "/src/app.ts") -- Automatic Prettier: on reformat, not on save
    assert(not save.format and reformat.formatters[1] == "prettier", vim.inspect({ save, reformat }))
    save, reformat = at(w.a .. "/src/app.html") -- not in Prettier's "Run for files": IntelliJ's formatter
    assert(not save.format and reformat.lsp_format == "prefer" and not reformat.formatters, vim.inspect({ save, reformat }))
    save = at(w.b .. "/src/Main.java") -- Format on Save for Java only, Optimize Imports for all types
    assert(save.format and save.organize_imports and not save.prettier and not save.changed_lines, vim.inspect(save))
    save = at(w.b .. "/src/app.ts")
    assert(not save.format and save.organize_imports, vim.inspect(save))
    assert(at(w.base .. "/plain/x.lua") == nil, "outside IntelliJ projects GreyKnight's own behavior")
    save = at(w.base .. "/plain/X.java")
    assert(save and not save.format, "Java gets IntelliJ's default everywhere: nothing on save")
    -- conform's format_on_save follows it
    local conform = require("lazy.core.config").plugins["conform.nvim"]
    local format_on_save = require("lazy.core.plugin").values(conform, "opts", false).format_on_save
    at(w.a .. "/src/app.ts")
    assert(format_on_save(0) == nil, "formats on save in an IntelliJ project that does not")
    at(w.base .. "/plain/x.lua")
    assert(type(format_on_save(0)) == "table", "no longer formats on save outside IntelliJ projects")
  end)
end)

test("IntelliJ: Remote JVM Debug configurations - this project's first, each host:port once", function()
  in_intellij_world(function(ij, w)
    local names = vim.tbl_map(function(r) return r.name .. "=" .. r.host .. ":" .. r.port end, ij.remote_debug(w.a))
    assert(vim.deep_equal(names, { "myVM=dev.example:8000", "nebula=qa.example:8000" }), vim.inspect(names))
  end)
end)

-- T17: Java (2026-10-19): jdtls the way IntelliJ has the project; the test and debug keys in Java files
test("Java: jdtls runs on IntelliJ's JDK 21, gets the project's JDK and IntelliJ's Maven settings", function()
  require("lazy").load({ plugins = { "nvim-jdtls" } })
  in_intellij_world(function(ij, w)
    for _, jdk in ipairs({ "jdk17", "jdk21" }) do -- the fake JDKs get a java executable
      local java = ij.java_bin(w.base .. "/" .. jdk)
      vim.fn.mkdir(vim.fs.dirname(java), "p")
      vim.fn.writefile({ "" }, java)
      vim.fn.setfperm(java, "rwx------")
    end
    local jdtls = require("integrations.jdtls")
    assert(jdtls.server_java() == ij.java_bin(w.base .. "/jdk21"), tostring(jdtls.server_java()))
    local project = ij.project(w.a)
    local runtimes = vim.tbl_map(function(r) return r.name .. (r.default and "*" or "") .. "=" .. r.path end, jdtls.runtimes(project))
    assert(vim.deep_equal(runtimes, { "JavaSE-17*=" .. w.base .. "/jdk17", "JavaSE-21=" .. w.base .. "/jdk21" }), vim.inspect(runtimes))
    local settings = jdtls.settings(project)
    local java = settings.java
    assert(java.import.gradle.enabled == false and java.import.maven.enabled == true, "not Maven-only")
    -- 2026-10-20: jdtls wrote .project / .classpath / .settings into a G3 checkout: its metadata stays in its workspace
    assert(java.import.generatesMetadataFilesAtProjectRoot == false, "jdtls writes Eclipse files into the repository")
    local home = vim.fs.normalize((vim.fn.has("win32") == 1 and vim.env.USERPROFILE) or vim.env.HOME)
    assert(java.configuration.maven.globalSettings == home .. "/my-settings.xml", tostring(java.configuration.maven.globalSettings))
    local user = table.concat(vim.fn.readfile(java.configuration.maven.userSettings), "\n")
    assert(user:find("<localRepository>" .. w.a .. "/repo</localRepository>", 1, true), user)
    assert(not java.saveActions.organizeImports, "organizes imports on save although IntelliJ does not")
    -- 2026-10-19: without the settings in the initialization jdtls imported G3 with its defaults (Gradle)
    assert(jdtls.init_options(settings).settings == settings, "the settings are not in the initialization")
    assert(vim.fn.filereadable(jdtls.FORMAT_PROFILE) == 1, "no format profile: " .. jdtls.FORMAT_PROFILE)
    -- Optimize Imports on save in IntelliJ (project b): jdtls organizes them on save too
    assert(jdtls.settings(ij.project(w.b)).java.saveActions.organizeImports, "IntelliJ's Optimize Imports on save not taken")
  end)
end)

test("Java: <leader>rt / rT / dt run tests through jdtls, <leader>da offers IntelliJ's remote configs", function()
  in_intellij_world(function(_, w)
    local calls, chosen = {}, nil
    local saved = { package.loaded["jdtls.dap"], vim.lsp.get_clients, vim.ui.select, require("dap").run }
    package.loaded["jdtls.dap"] = {
      test_class = function(opts) calls[#calls + 1] = { "class", opts } end,
      test_nearest_method = function(opts) calls[#calls + 1] = { "nearest", opts } end,
    }
    vim.lsp.get_clients = function(f) return f and f.name == "jdtls" and { {} } or saved[2](f) end
    vim.ui.select = function(items, _, cb) chosen = items; cb(items[1]) end
    local ran
    require("dap").run = function(config) ran = config end
    local ok, err = pcall(function()
      vim.cmd("noautocmd edit " .. vim.fn.fnameescape(w.a .. "/src/Main.java")) -- no FileType: no real jdtls
      vim.cmd("noautocmd setlocal filetype=java")
      vim.api.nvim_feedkeys(" rt", "x", false)
      vim.api.nvim_feedkeys(" rT", "x", false)
      vim.api.nvim_feedkeys(" dt", "x", false)
      assert(#calls == 3, vim.inspect(calls))
      assert(calls[1][1] == "class" and calls[1][2].config_overrides.noDebug, "rt: " .. vim.inspect(calls[1]))
      assert(calls[2][1] == "nearest" and calls[2][2].config_overrides.noDebug, "rT: " .. vim.inspect(calls[2]))
      assert(calls[3][1] == "nearest" and not calls[3][2].config_overrides.noDebug, "dt runs without the debugger: " .. vim.inspect(calls[3]))
      -- 2026-10-19: a G3 module's classpath is longer than Windows' command line ("E903: name too long"): every
      -- launch shortens it (the overrides replace nvim-jdtls' defaults, so they must carry it). java-debug
      -- itself knows no "auto": an @argfile for the project's JDK 17
      for _, call in ipairs(calls) do
        assert(call[2].config_overrides.shortenCommandLine == "argfile", "long command line: " .. vim.inspect(call))
        assert(call[2].config_overrides.console == "internalConsole", "test output not in the debug REPL: " .. vim.inspect(call))
      end
      vim.api.nvim_feedkeys(" da", "x", false)
      assert(chosen and chosen[1].name:find("myVM", 1, true) and chosen[#chosen].name:find("Other", 1, true), vim.inspect(chosen))
      assert(ran and ran.request == "attach" and ran.hostName == "dev.example" and ran.port == 8000, vim.inspect(ran))
    end)
    package.loaded["jdtls.dap"], vim.lsp.get_clients, vim.ui.select, require("dap").run = saved[1], saved[2], saved[3], saved[4]
    assert(ok, err)
  end)
end)

-- 2026-10-19: on Windows java-test's TestNG runner ends its result lines with \r\n; nvim-jdtls cut its frame off
-- with the \r still in, no line decoded (in a window: an error prompt that blocked Neovim), no test got a mark
test("Java: TestNG results with Windows line ends mark the tests (passed: a mark, failed: a diagnostic)", function()
  require("lazy").load({ plugins = { "nvim-jdtls" } })
  require("integrations.jdtls").patch_testng()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "class T {", "  @Test void ok() {}", "  @Test void bad() {}", "}" })
  local function frame(name, test, extra)
    return "@@<TestRunner-" .. vim.json.encode({ name = name, attributes = vim.tbl_extend("force", { name = test }, extra or {}) }) .. "-TestRunner>\r\n"
  end
  local ok, err = pcall(function()
    local results = require("jdtls.testng").mk_test_results(buf)
    local reader = results.mk_reader({ close = function() end })
    reader(nil, frame("testStarted", "p.T#ok()") .. frame("testFinished", "p.T#ok()", { duration = "1" })
      .. frame("testFailed", "p.T#bad()", { message = "expected 1", trace = "at p.T.bad" }))
    reader(nil, nil) -- the runner closed the socket
    vim.wait(200)
    results.show({ { fullName = "p.T#ok()", range = { start = { line = 1 } } }, { fullName = "p.T#bad()", range = { start = { line = 2 } } } })
    local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })
    local passed = vim.tbl_filter(function(m) return m[2] == 1 and m[4].virt_text end, marks)
    assert(#passed == 1, "no mark on the passed test: " .. vim.inspect(marks))
    local failed = vim.diagnostic.get(buf)
    assert(#failed == 1 and failed[1].lnum == 2 and failed[1].message == "expected 1", vim.inspect(failed))
  end)
  vim.diagnostic.reset(nil, buf)
  vim.api.nvim_buf_delete(buf, { force = true })
  assert(ok, err)
end)

-- T18: Angular (2+) and AngularJS (2026-10-19)
test("Angular: *.component.html of an Angular workspace is htmlangular, other HTML stays html", function()
  local root = vim.fs.normalize(vim.fn.tempname())
  vim.fn.mkdir(root .. "/ws/src/app", "p")
  vim.fn.mkdir(root .. "/legacy/src", "p")
  vim.fn.writefile({ "{}" }, root .. "/ws/angular.json")
  local function ft(path)
    vim.fn.writefile({ "<p>{{ x }}</p>" }, path)
    return vim.filetype.match({ filename = path })
  end
  local ok, err = pcall(function()
    assert(ft(root .. "/ws/src/app/app.component.html") == "htmlangular", "template: " .. tostring(ft(root .. "/ws/src/app/app.component.html")))
    assert(ft(root .. "/ws/src/index.html") == "html", "index.html")
    assert(ft(root .. "/legacy/src/list.component.html") == "html", "AngularJS template outside an Angular workspace")
  end)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

test("Angular: angularls in Angular workspaces, eslint where its config is, html and css servers by filetype", function()
  local web = require("integrations.web")
  local root = vim.fs.normalize(vim.fn.tempname())
  for _, dir in ipairs({ "/ws/src/app", "/legacy/src", "/plain" }) do vim.fn.mkdir(root .. dir, "p") end
  vim.fn.writefile({ "{}" }, root .. "/ws/nx.json")
  vim.fn.writefile({ "module.exports = []" }, root .. "/ws/eslint.config.cjs")
  vim.fn.writefile({ "module.exports = {}" }, root .. "/legacy/.eslintrc.js")
  local bufs = {}
  local function needed(path, filetype) -- no FileType event: nothing gets installed or started
    vim.cmd("noautocmd edit " .. vim.fn.fnameescape(root .. path))
    vim.cmd("noautocmd setlocal filetype=" .. filetype)
    bufs[#bufs + 1] = vim.api.nvim_get_current_buf()
    return table.concat(web.needed(0), " ")
  end
  local ok, err = pcall(function()
    assert(needed("/ws/src/app/app.component.ts", "typescript") == "angularls eslint", needed("/ws/src/app/app.component.ts", "typescript"))
    assert(needed("/ws/src/app/app.component.html", "htmlangular") == "angularls eslint", "template")
    assert(needed("/ws/src/styles.scss", "scss") == "cssls", "scss")
    assert(needed("/legacy/src/app.ts", "typescript") == "eslint", "AngularJS code: " .. needed("/legacy/src/app.ts", "typescript"))
    assert(needed("/legacy/src/list.html", "html") == "html", "AngularJS template")
    assert(needed("/plain/x.ts", "typescript") == "", "no workspace, no eslint config")
    -- 2026-10-19: lspconfig's own angularls root was angular.json only - it never started in Nx workspaces
    -- (ngx-his has nx.json and no angular.json)
    local file = root .. "/ws/src/app/app.component.ts"
    assert(web.angular_root(file) == root .. "/ws", "angularls' root: " .. tostring(web.angular_root(file)))
    local angularls = require("lspconfig").angularls
    if angularls.get_root_dir then -- set up where angularls is installed: lspconfig uses that root
      assert(vim.fs.normalize(angularls.get_root_dir(file) or "") == root .. "/ws", "lspconfig: " .. tostring(angularls.get_root_dir(file)))
    end
  end)
  for _, b in ipairs(bufs) do pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- T19: Java without IntelliJ (2026-10-19): GreyKnight needs no IntelliJ - on Linux, or on a machine without it, it
-- takes the JDKs and the Maven of the machine, as the mvn command line does. Before, it knew only $JAVA_HOME and
-- the java on the PATH: with both 17 (the work laptop) jdtls did not start although a JDK 21 sat next to them.
-- A machine in a temp dir: JDKs 17 and 21 side by side (and a folder that is none), a JDK 11 named in
-- $GREYKNIGHT_JDK_DIRS, a JDK 8 where nothing looks, a Maven; IntelliJ hidden, $JAVA_HOME and the java on the PATH
-- the 17, the machine's real JDK places left out.
local function without_intellij(fn)
  local WIN = vim.fn.has("win32") == 1
  local ij, jdtls = require("integrations.intellij"), require("integrations.jdtls")
  local base = vim.fs.normalize(vim.fn.tempname())
  local m = {
    base = base, jdk17 = base .. "/jdks/jdk-17.0.2", jdk21 = base .. "/jdks/jdk-21.0.1", jdk11 = base .. "/extra/jdk-11",
    jdk8 = base .. "/old/jdk8", maven = base .. "/maven", empty = base .. "/empty-bin",
  }
  local function write(path, lines)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(lines, path)
  end
  local function exe(path)
    write(path, { "" })
    vim.fn.setfperm(path, "rwx------")
  end
  for home, version in pairs({ [m.jdk17] = "17.0.2", [m.jdk21] = "21.0.1", [m.jdk11] = "11.0.25", [m.jdk8] = "1.8.0_402" }) do
    write(home .. "/release", { 'JAVA_VERSION="' .. version .. '"' })
    exe(ij.java_bin(home))
  end
  vim.fn.mkdir(base .. "/jdks/not-a-jdk/bin", "p")
  write(m.maven .. "/conf/settings.xml", { "<settings/>" })
  exe(m.maven .. "/bin/" .. (WIN and "mvn.cmd" or "mvn"))
  vim.fn.mkdir(m.empty, "p")
  write(base .. "/plain/X.java", { "class X {}" })
  write(base .. "/committed/.idea/misc.xml", { -- an .idea from git: IntelliJ never opened it on this machine
    '<project version="4"><component name="ProjectRootManager" version="2" languageLevel="JDK_17" project-jdk-name="17" project-jdk-type="JavaSDK" /></project>',
  })
  -- opened in IntelliJ, never imported as a Maven project: a workspace.xml without Maven settings
  write(base .. "/unimported/.idea/workspace.xml", { '<project version="4"><component name="RunManager" /></project>' })
  local function native(p) return WIN and (p:gsub("/", "\\")) or p end
  local sep = WIN and ";" or ":"
  local names = { "GREYKNIGHT_INTELLIJ_CONFIG", "JAVA_HOME", "JDTLS_JAVA_HOME", "GREYKNIGHT_JDK_DIRS", "MAVEN_HOME", "M2_HOME", "PATH" }
  local saved, places = {}, jdtls.jdk_places
  for _, n in ipairs(names) do saved[n] = vim.env[n] end
  vim.env.GREYKNIGHT_INTELLIJ_CONFIG = base .. "/no-intellij" -- not there: no IntelliJ
  vim.env.JAVA_HOME, vim.env.JDTLS_JAVA_HOME, vim.env.MAVEN_HOME, vim.env.M2_HOME = native(m.jdk17), nil, nil, nil
  vim.env.GREYKNIGHT_JDK_DIRS = native(m.jdk11) .. sep .. native(base .. "/nowhere")
  vim.env.PATH = native(m.jdk17 .. "/bin") .. sep .. native(m.maven .. "/bin") .. sep .. saved.PATH
  jdtls.jdk_places = function() return {} end
  local ok, err = pcall(fn, jdtls, m, ij)
  for _, n in ipairs(names) do vim.env[n] = saved[n] end
  jdtls.jdk_places = places
  vim.fn.delete(base, "rf")
  assert(ok, err)
end

-- A path as the file system has it (Windows' temp directory comes with 8.3 short names)
local function real(path) return path and vim.fs.normalize(vim.uv.fs_realpath(path) or path) end

test("Java without IntelliJ: jdtls runs on an installed JDK 21, projects get $JAVA_HOME's JDK and the others", function()
  without_intellij(function(jdtls, m, ij)
    assert(ij.config_dir() == nil, "IntelliJ not hidden: " .. tostring(ij.config_dir()))
    local java = jdtls.server_java()
    assert(java and real(java) == real(ij.java_bin(m.jdk21)), "jdtls' Java: " .. tostring(java))
    local function runtimes(project)
      return vim.tbl_map(function(r) return r.name .. (r.default and "*" or "") .. "=" .. real(r.path) end, jdtls.runtimes(project))
    end
    local want = { "JavaSE-17*=" .. real(m.jdk17), "JavaSE-11=" .. real(m.jdk11), "JavaSE-21=" .. real(m.jdk21) }
    assert(vim.deep_equal(runtimes(nil), want), vim.inspect(runtimes(nil)))
    -- an .idea from git (no workspace.xml, a JDK IntelliJ's table does not have here): the machine's as well
    local committed = ij.project(m.base .. "/committed")
    assert(committed and not committed.workspace and not committed.jdk, vim.inspect(committed))
    assert(vim.deep_equal(runtimes(committed), want), "committed .idea: " .. vim.inspect(runtimes(committed)))
    -- launches shorten the command line for the project's JDK: an @argfile from Java 9 on, a manifest jar for 8
    local file = m.base .. "/plain/X.java"
    assert(jdtls.dap_overrides(file).shortenCommandLine == "argfile", vim.inspect(jdtls.dap_overrides(file)))
    vim.env.JAVA_HOME = m.jdk8
    assert(jdtls.dap_overrides(file).shortenCommandLine == "jarmanifest", "Java 8: " .. vim.inspect(jdtls.dap_overrides(file)))
    vim.env.JAVA_HOME = m.jdk17
    -- no JDK 21 anywhere: the message says what to do (not only "add one to IntelliJ")
    vim.fn.delete(m.jdk21, "rf")
    local still = jdtls.server_java()
    assert(still == nil, "still a Java for jdtls: " .. tostring(still))
    local config, why = jdtls.config(file)
    assert(config == nil and why and why:find("install a JDK 21", 1, true) and why:find("JDTLS_JAVA_HOME", 1, true), tostring(why))
  end)
end)

test("Java without IntelliJ: Maven's settings as the mvn command line reads them", function()
  without_intellij(function(jdtls, m, ij)
    local global = real(m.maven .. "/conf/settings.xml")
    local s = jdtls.maven_settings(nil) -- the mvn on the PATH: its conf/settings.xml, ~/.m2 as jdtls' default
    assert(s.user == nil and real(s.global) == global, vim.inspect(s))
    assert(real(jdtls.settings(nil).java.configuration.maven.globalSettings) == global, "not in jdtls' settings")
    assert(real(jdtls.maven_settings(ij.project(m.base .. "/committed")).global) == global, "an .idea from git")
    -- 2026-10-20: two G3 repositories IntelliJ had opened but not imported as Maven got jdtls' defaults (no mirror)
    local unimported = ij.project(m.base .. "/unimported")
    assert(unimported and unimported.workspace, "the fixture is no IntelliJ project with a workspace")
    assert(real(jdtls.maven_settings(unimported).global) == global, "IntelliJ project without Maven settings: " .. vim.inspect(jdtls.maven_settings(unimported)))
    vim.env.PATH = m.empty -- no mvn on the PATH: $MAVEN_HOME
    vim.env.MAVEN_HOME = m.maven
    assert(real(jdtls.maven_settings(nil).global) == global, vim.inspect(jdtls.maven_settings(nil)))
    vim.env.MAVEN_HOME = nil -- no Maven at all: jdtls' defaults
    assert(vim.deep_equal(jdtls.maven_settings(nil), {}), vim.inspect(jdtls.maven_settings(nil)))
  end)
end)

-- T12: The docs stay in step with the config
local ROOT = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local function read(file) return table.concat(vim.fn.readfile(ROOT .. "/" .. file), "\n") end
-- G3-DEVELOPMENT.md too: a key it names must exist (2026-10-19)
local DOCS = read("CHEATSHEET.md") .. "\n" .. read("USAGE.md") .. "\n" .. read("README.md") .. "\n" .. read("G3-DEVELOPMENT.md")

test("Docs: every key with a description is documented", function()
  local missing, seen = {}, {}
  for _, mode in ipairs({ "n", "v", "x", "o", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local lhs = m.lhs:gsub("^ ", "<leader>")
      local ours = m.desc and m.desc ~= "" and (lhs:match("^<leader>") or lhs:match("^<S?%-?F%d+>"))
      if ours and not seen[lhs] then
        seen[lhs] = true
        local short, plain = lhs:gsub("^<leader>", ""), lhs:gsub("[<>]", "")
        if not (DOCS:find(lhs, 1, true) or DOCS:find("Space+" .. short, 1, true) or DOCS:find("`" .. plain .. "`", 1, true)
          or (lhs:match("^<leader>%d$") and DOCS:find("<leader>1-4", 1, true))) then
          missing[#missing + 1] = mode .. " " .. lhs .. " (" .. m.desc .. ")"
        end
      end
    end
  end
  assert(#missing == 0, "not in the docs: " .. table.concat(missing, ", "))
end)

test("Docs: every documented <leader> key exists", function()
  -- group prefixes in headings, LSP keys (exist once a server attaches), the AI Dashboard bridge (<leader>W*)
  local known = { ["<leader>a"] = 1, ["<leader>f"] = 1, ["<leader>g"] = 1, ["<leader>r"] = 1, ["<leader>t"] = 1,
    ["<leader>x"] = 1, ["<leader>ca"] = 1, ["<leader>rn"] = 1, ["<leader>D"] = 1, ["<leader>t1/t2/t3"] = 1,
    -- gitsigns' keys: in files of a git repository (the Git test checks them there)
    ["<leader>gs"] = 1, ["<leader>gr"] = 1, ["<leader>gp"] = 1, ["<leader>gb"] = 1 }
  local stale, checked = {}, {}
  for key in DOCS:gmatch("<leader>[%w%-%;%/%:%.]+") do
    if not checked[key] and not known[key] and not key:match("^<leader>W") and not key:match("%d%-%d$") then
      checked[key] = true
      if vim.fn.maparg(key, "n") == "" and vim.fn.maparg(key, "v") == "" and vim.fn.maparg(key, "x") == "" then
        stale[#stale + 1] = key
      end
    end
  end
  assert(#stale == 0, "documented but not mapped: " .. table.concat(stale, ", "))
end)

test("Docs: the README and CHEATSHEET file trees list every module and test", function()
  local missing = {}
  for _, pattern in ipairs({ "lua/config/*.lua", "lua/devsuite/*.lua", "lua/integrations/*.lua", "lua/plugins/*.lua", "tests/*" }) do
    for _, path in ipairs(vim.fn.glob(ROOT .. "/" .. pattern, false, true)) do
      local name = vim.fn.fnamemodify(path, ":t")
      for _, doc in ipairs({ "README.md", "CHEATSHEET.md" }) do
        if not read(doc):find(name, 1, true) then missing[#missing + 1] = doc .. ": " .. name end
      end
    end
  end
  assert(#missing == 0, table.concat(missing, ", "))
end)

test("Docs: every link to a heading or file resolves (GitLab anchors)", function()
  local md = require("config.mdlinks")
  local bad = {}
  for _, doc in ipairs(vim.fn.glob(ROOT .. "/*.md", false, true)) do
    for _, l in ipairs(md.links(vim.fn.readfile(doc))) do
      if not l.target:match("^%a[%w+.-]*:") then
        local file, anchor = l.target:match("^([^#]*)#?(.*)$")
        local path = file == "" and doc or vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(doc), file))
        local where = vim.fn.fnamemodify(doc, ":t") .. ":" .. l.lnum .. " " .. l.target
        if vim.fn.filereadable(path) ~= 1 and vim.fn.isdirectory(path) ~= 1 then
          bad[#bad + 1] = where .. " (no such file)"
        elseif anchor ~= "" and not md.anchors(vim.fn.readfile(path), "gitlab")[anchor] then
          bad[#bad + 1] = where .. " (no such heading on GitLab)"
        end
      end
    end
  end
  assert(#bad == 0, table.concat(bad, ", "))
end)

test("Docs: the CHEATSHEET lists every leader and F key", function()
  local cs, missing, seen = read("CHEATSHEET.md"), {}, {}
  for _, mode in ipairs({ "n", "v", "x", "o", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local lhs = m.lhs:gsub("^ ", "<leader>")
      if m.desc and m.desc ~= "" and (lhs:match("^<leader>") or lhs:match("^<S?%-?F%d+>")) and not seen[lhs] then
        seen[lhs] = true
        local short, plain = lhs:gsub("^<leader>", ""), lhs:gsub("[<>]", "")
        if not (cs:find(lhs, 1, true) or cs:find("`" .. plain .. "`", 1, true) or cs:find("`" .. short .. "`", 1, true)
          or (lhs:match("^<leader>%d$") and cs:find("<leader>1-4", 1, true))) then
          missing[#missing + 1] = mode .. " " .. lhs .. " (" .. m.desc .. ")"
        end
      end
    end
  end
  assert(#missing == 0, "not in the CHEATSHEET: " .. table.concat(missing, ", "))
end)

H.report("Smoke Test Results")
