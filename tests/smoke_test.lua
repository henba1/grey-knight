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
    assert(H.wait(5000, picker), "explorer did not open")
    local p = picker()
    -- like a user: act once the first listing is there (a cd while snacks still lists shows entries twice,
    -- with its own keys too)
    assert(H.wait(5000, function() return not p:is_active() and p.list:count() > 0 end), "explorer did not list")
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
  if picker() then picker():close() end
  H.wait(2000, function() return picker() == nil end) -- gone, so no later test starts in its window
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
    assert(H.wait(5000, picker), "explorer did not open")
    local p = picker()
    assert(H.wait(5000, function() return not p:is_active() and p.list:count() >= 10 end), "explorer did not list")
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
  if picker() then picker():close() end
  H.wait(2000, function() return picker() == nil end)
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
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
    ["<leader>x"] = 1, ["<leader>ca"] = 1, ["<leader>rn"] = 1, ["<leader>D"] = 1, ["<leader>t1/t2/t3"] = 1 }
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
