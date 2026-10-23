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

-- T3: Colorscheme - from the start, also the first one (2026-10-22: with cyberdream's cache a start without its
-- cache file - a new machine, an emptied ~/.cache, changed options - had Neovim's colors for a second, then "A
-- restart may be required"; a test run has an empty cache folder of its own)
test("Cyberdream colorscheme active from the start - also the first one (an empty cache folder)", function()
  assert(vim.g.colors_name == "cyberdream", "colorscheme is " .. tostring(vim.g.colors_name))
  assert(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, "Normal has no background of the theme")
  if (vim.env.GK_TEST_RUN_DIR or "") ~= "" then -- the run's own cache folder, empty at its start (tests/run.sh)
    local cache = vim.fn.stdpath("cache") .. "/cyberdream_cache.json"
    assert(not vim.uv.fs_stat(cache), "cyberdream built its cache (the theme comes a second later): " .. cache)
  end
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

-- 2026-10-22: test runs read the jumplist and recent files of the user's sessions (an a.txt remembered from an
-- earlier run became a buffer when <C-o> loaded the jumplist) and wrote theirs back among the user's (tests/harness.lua)
test("Tests: a run leaves the user's ShaDa alone - their history is not read, the test files' not written", function()
  assert(vim.o.shadafile == "NONE", "'shadafile': " .. vim.inspect(vim.o.shadafile))
  assert(#vim.v.oldfiles == 0, ("the user's recent files were read: %d, e.g. %s"):format(#vim.v.oldfiles, tostring(vim.v.oldfiles[1])))
end)

-- 2026-10-22: a test run left pyright's and tsserver's temp folders (11 and 4 a run, never removed), grew lsp.log,
-- dap.log and conform.log, wrote grug-far's history, blink's frecency, the pickers' history, the run arguments and a
-- Maven settings file for each run's temp project into the user's folders (tests/run.sh, run.ps1, tests/harness.lua)
test("Tests: a run keeps to folders of its own - temp, state, cache, undo; no picker history, run arguments, Maven settings, Qwen lock files in the user's", function()
  local run = vim.env.GK_TEST_RUN_DIR
  if not run or run == "" then H.skip("started without tests/run.sh or run.ps1") end
  local function real(path) -- made if missing: Neovim makes a folder when it first writes there
    vim.fn.mkdir(path, "p")
    return vim.fs.normalize(assert(vim.uv.fs_realpath(path))):lower()
  end
  run = real(run)
  local own = {
    ["Neovim's temp folder"] = vim.fs.dirname(vim.fn.tempname()),
    ["the temp folder of servers and plugins"] = vim.uv.os_tmpdir(),
    state = vim.fn.stdpath("state"),
    log = vim.fn.stdpath("log"),
    cache = vim.fn.stdpath("cache"),
    -- 2026-10-22: undo files went to ~/.vim/undodir; an agent started in a test put a lock file into ~/.qwen/ide
    ["the undo files"] = vim.o.undodir,
    ["Qwen Code's folder (the agents' lock file)"] = require("integrations.agent_link").qwen_home(),
  }
  for what, path in pairs(own) do
    assert(vim.startswith(real(path), run .. "/"), ("%s is the user's: %s"):format(what, path))
  end
  local ok, au = pcall(vim.api.nvim_get_autocmds, { group = "snacks_history" })
  assert(not ok or #au == 0, "the pickers' history is saved on exit")
  local data = vim.fs.normalize(vim.fn.stdpath("data")):lower()
  for what, path in pairs({ ["the run arguments"] = require("devsuite.tasks").args_file, ["the Maven settings"] = require("integrations.jdtls").settings_dir }) do
    assert(not vim.startswith(vim.fs.normalize(path):lower(), data .. "/"), ("%s in the user's data folder: %s"):format(what, path))
  end
end)

-- T13: Keys that once misbehaved (2026-10-19). 2026-10-21: Ctrl+L moves from a terminal too (it went to the shell),
-- Ctrl+arrows resize a terminal; every other key is the program's, so bash's own keys work in a terminal - and only
-- there: insert and command-line mode stay Vim's (the same keys on any machine)
test("Keys: in a terminal Ctrl+H/J/K/L go to the next window, Ctrl+arrows resize, bash's keys are the program's; insert mode stays Vim's", function()
  for _, d in ipairs({ "h", "j", "k", "l" }) do
    local rhs = vim.fn.maparg("<C-" .. d .. ">", "t")
    assert(rhs:lower() == ("<c-\\><c-n><c-w>" .. d), ("<C-%s> in terminal mode: %q"):format(d, rhs))
  end
  for _, k in ipairs({ "<C-Up>", "<C-Down>", "<C-Left>", "<C-Right>" }) do
    assert(vim.fn.maparg(k, "t"):find("resize", 1, true), k .. " does not resize from terminal mode: " .. vim.fn.maparg(k, "t"))
  end
  for _, k in ipairs({ "<C-a>", "<C-e>", "<C-b>", "<C-f>", "<C-w>", "<C-u>", "<C-r>", "<C-d>", "<C-y>", "<C-p>", "<C-n>", "<M-b>", "<M-f>", "<M-d>", "<M-.>" }) do
    assert(vim.fn.maparg(k, "t") == "", k .. " is taken in terminal mode (bash's): " .. vim.fn.maparg(k, "t"))
  end
  local nvim_default = { ["<C-u>"] = "<C-G>u<C-U>", ["<C-w>"] = "<C-G>u<C-W>" } -- Neovim's own: an undo point first
  for _, k in ipairs({ "<C-a>", "<C-k>", "<C-u>", "<C-w>", "<C-d>", "<M-b>", "<M-f>" }) do
    local rhs = vim.fn.maparg(k, "i")
    assert(rhs == "" or rhs == nvim_default[k], k .. " is mapped in insert mode (Vim's): " .. rhs)
  end
  for _, k in ipairs({ "<C-a>", "<C-b>", "<C-f>", "<C-k>", "<M-b>", "<M-f>" }) do
    assert(vim.fn.maparg(k, "c") == "", k .. " is mapped in command-line mode (Vim's): " .. vim.fn.maparg(k, "c"))
  end
end)

-- 2026-10-22, over SSH from PuTTY 0.85 with its default keys (its bytes fed to Neovim under TERM=xterm): Ctrl+arrows
-- came as plain arrows, Home / End as Find / Select (the cursor stayed), Shift+F11 / Ctrl+F11 as F11; and most
-- terminals send Shift+F5 / Shift+F11 / Ctrl+F11 so that Neovim names them <F17> / <F23> / <F35>
test("Keys: as PuTTY sends them - Alt+arrows resize, Find / Select are Home / End, <F17> <F23> <F35> are Shift+F5 / Shift+F11 / Ctrl+F11", function()
  for _, k in ipairs({ "<M-Up>", "<M-Down>", "<M-Left>", "<M-Right>" }) do
    assert(vim.fn.maparg(k, "n"):find("resize", 1, true), k .. " does not resize: " .. vim.fn.maparg(k, "n"))
    assert(vim.fn.maparg(k, "t") == "", k .. " is taken in terminal mode (the shell's): " .. vim.fn.maparg(k, "t"))
  end
  for alias, key in pairs({ ["<F17>"] = "<S-F5>", ["<F23>"] = "<S-F11>", ["<F35>"] = "<C-F11>" }) do
    local a, k = vim.fn.maparg(alias, "n", false, true), vim.fn.maparg(key, "n", false, true)
    assert(a.callback and a.desc == k.desc, ("%s is not %s: %s / %s"):format(alias, key, tostring(a.desc), tostring(k.desc)))
  end
  for _, mode in ipairs({ "n", "x", "o", "i", "c" }) do
    assert(vim.fn.maparg("<Find>", mode) == "<Home>" and vim.fn.maparg("<Select>", mode) == "<End>", "Find / Select in mode " .. mode)
  end
  assert(vim.fn.maparg("<Find>", "t") == "", "Find in terminal mode: the program's")
  local buf = H.scratch("text", { "hello world" })
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    vim.api.nvim_feedkeys(vim.keycode("<Find>"), "mx", false)
    assert(vim.fn.col(".") == 1, "Find (Home): column " .. vim.fn.col("."))
    vim.api.nvim_feedkeys(vim.keycode("<Select>"), "mx", false)
    assert(vim.fn.col(".") == 11, "Select (End): column " .. vim.fn.col("."))
    vim.api.nvim_feedkeys(vim.keycode("i<Find>X<Esc>"), "mx", false) -- insert mode
    assert(vim.api.nvim_get_current_line() == "Xhello world", "Find in insert mode: " .. vim.api.nvim_get_current_line())
    -- <F23>: the bookmarks' list, as Shift+F11 (an empty one only says so: the call is what counts)
    local bm = require("config.bookmarks")
    local pick, listed = bm.pick, false
    bm.pick = function() listed = true end
    local fed = pcall(vim.api.nvim_feedkeys, vim.keycode("<F23>"), "mx", false)
    bm.pick = pick
    assert(fed and listed, "<F23> did not list the bookmarks")
  end)
  vim.cmd("stopinsert")
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  assert(ok, err)
end)

test("PuTTY: a session that looks like PuTTY's default keys (SSH, TERM=xterm) gets the word on the settings - once", function()
  local putty = require("config.putty")
  local ssh = "10.0.0.2 50000 10.0.0.1 22"
  assert(putty.looks_like({ SSH_CONNECTION = ssh, TERM = "xterm" }), "SSH, TERM=xterm")
  assert(not putty.looks_like({ SSH_CONNECTION = ssh, TERM = "xterm-256color" }), "TERM=xterm-256color (Windows Terminal, PuTTY set up)")
  assert(not putty.looks_like({ TERM = "xterm" }), "no SSH")
  local saved, notes, notify = putty.flag, {}, vim.notify
  putty.flag = vim.fn.tempname() .. "/putty-hint"
  vim.notify = function(msg, level, opts)
    notes[#notes + 1] = tostring(msg)
    return notify(msg, level, opts)
  end
  local ok, err = pcall(function()
    assert(not putty.show_once({ SSH_CONNECTION = ssh, TERM = "xterm-256color" }) and #notes == 0, "a word without PuTTY")
    assert(putty.show_once({ SSH_CONNECTION = ssh, TERM = "xterm" }), "no word")
    assert(notes[1] and notes[1]:find("xterm-style bitmap", 1, true) and notes[1]:find("Xterm 216+", 1, true)
      and notes[1]:find("xterm-256color", 1, true), "the word: " .. tostring(notes[1]))
    assert(not putty.show_once({ SSH_CONNECTION = ssh, TERM = "xterm" }) and #notes == 1, "a second word")
  end)
  vim.notify, putty.flag = notify, saved
  assert(ok, err)
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

-- 2026-10-22: regex search in the explorer (config/explorer.lua): fd gets a Rust regex - or a glob, a text with a * and
-- nothing only a regex has - against the name, or with a / the path below the tree's root; smart case
test("Explorer: regex search - fd gets a regex or a glob, for the name or (with a /) the path below the tree's root", function()
  local x = require("config.explorer")
  local kinds = { ["*.sh"] = true, ["test_*.py"] = true, ["*.{sh,bash}"] = true, ["**/*.ts"] = true, [".*\\.sh$"] = false,
    ["\\.sh$"] = false, ["colou?r"] = false, ["^a*b"] = false, ["(a|b)*"] = false, ["a+*"] = false }
  for text, glob in pairs(kinds) do
    assert(x.is_glob(text) == glob, ("%s should be %s"):format(text, glob and "a glob" or "a regex"))
  end
  local function args(text, root, win) return x.fd_args(text, root, { win = win }) end
  local a, kind = args(".*\\.sh$", "/home/u/p", false)
  assert(kind == "regex" and vim.tbl_contains(a, "--regex") and not vim.tbl_contains(a, "--full-path"), vim.inspect(a))
  assert(a[#a - 1] == ".*\\.sh$" and a[#a] == "/home/u/p" and a[#a - 2] == "--", vim.inspect(a))
  assert(vim.tbl_contains(a, "--ignore-case"), "smart case, no capital: the case does not count " .. vim.inspect(a))
  assert(vim.tbl_contains(args(".*\\.SH$", "/home/u/p", false), "--case-sensitive"), "smart case: a capital")
  a, kind = args("*.sh", "/home/u/p", false)
  assert(kind == "glob" and vim.tbl_contains(a, "--glob") and a[#a - 1] == "*.sh", vim.inspect(a))
  -- with a /: the path below the root (fd matches the absolute one) - ^ anchors at the root, else anywhere below it
  a = args("^src/.*\\.ts$", "/home/u/my.proj", false)
  assert(vim.tbl_contains(a, "--full-path") and a[#a - 1] == "^/home/u/my\\.proj/(?:src/.*\\.ts$)", a[#a - 1])
  a = args("sub/.*\\.ts$", "/home/u/p", false)
  assert(a[#a - 1] == "^/home/u/p/.*?(?:sub/.*\\.ts$)", a[#a - 1])
  -- a glob with a /: below the root, as in .gitignore - as the regex it is (fd's globs take no \ of Windows' paths)
  a, kind = args("src/*.ts", "/home/u/[x]", false)
  assert(kind == "glob" and vim.tbl_contains(a, "--regex") and a[#a - 1] == "^/home/u/\\[x\\]/(?:src/[^/]*\\.ts$)", a[#a - 1])
  for glob, regex in pairs({ ["**/test_*.py"] = "(?:.*/)?test_[^/]*\\.py", ["*.{sh,bash}"] = "[^/]*\\.(?:sh|bash)",
    ["[!a]?.txt"] = "[^a][^/]\\.txt", ["a**b"] = "a.*b" }) do
    assert(x.glob_to_regex(glob) == regex, ("%s: %s, not %s"):format(glob, x.glob_to_regex(glob), regex))
  end
  -- Windows: fd's full path has \ - a / matches both, in a [^/] class too; the root's case does not count
  a = args("^src/[^/]*\\.ts$", "C:/dev/p", true)
  assert(a[#a - 1] == "^(?i:C:[/\\\\]dev[/\\\\]p)[/\\\\](?:src[/\\\\][^/\\\\]*\\.ts$)", a[#a - 1])
end)

-- the regex tests' tree: scripts, Python, TypeScript - names in both cases, a folder named like a script
local function regex_world(fn)
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  for _, rel in ipairs({ "a.sh", "X.SH", "b.py", "notes.sh.txt", "scripts/c.sh", "scripts/sub/d.bash", "src/x.ts",
    "src/sub/y.ts", "shell/run.txt" }) do
    vim.fn.mkdir(vim.fs.dirname(root .. "/" .. rel), "p")
    vim.fn.writefile({ "x" }, root .. "/" .. rel)
  end
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  close_explorers()
  Snacks.explorer()
  local ok, err = pcall(function()
    -- the one shown here: an earlier test's, closed scheduled, may still be among explorers()
    local function shown()
      local p = Snacks.picker.get({ source = "explorer" })[1]
      return p and not p.closed and p.list.win:valid() and p or nil
    end
    assert(H.wait(OPEN_MS, shown), "explorer did not open")
    local p = shown()
    assert(H.wait(OPEN_MS, function() return not p:is_active() and p.list:count() >= 6 end), "explorer did not list")
    local w = { p = p, root = root }
    function w.type(text) -- as typing does: the box's text, then its TextChanged (a test never waits for keys)
      vim.api.nvim_buf_set_lines(p.input.win.buf, 0, -1, false, { text })
      vim.api.nvim_exec_autocmds("TextChanged", { buffer = p.input.win.buf })
    end
    function w.hits() -- the matches below the root, folders with a /, sorted
      local r = {}
      for i = 1, p.list:count() do
        local it = p.list:get(i)
        if it.gk_hit then r[#r + 1] = it.file:sub(#root + 2) .. (it.dir and "/" or "") end
      end
      table.sort(r)
      return table.concat(r, " ")
    end
    function w.expect(title, want)
      assert(H.wait(5000, function() return not p:is_active() and p.title == title and w.hits() == want end),
        ("%q (%s): %q, not %q (%s)"):format(p.input:get(), p.title, w.hits(), want, title))
    end
    function w.marked()
      local r = {}
      for _, it in ipairs(p.list.selected) do r[#r + 1] = it.file:sub(#root + 2) .. (it.dir and "/" or "") end
      table.sort(r)
      return table.concat(r, " ")
    end
    fn(w)
  end)
  require("config.explorer").regex = false -- the next tests search fuzzy, as a session starts
  close_explorers()
  vim.cmd("stopinsert")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

test("Explorer: R finds files by regex (a glob too, with a / the path below the root); Alt+r: fuzzy, the text stays", function()
  regex_world(function(w)
    local p = w.p
    local function key(win, lhs, mode)
      return vim.api.nvim_buf_call(win.buf, function() return vim.fn.maparg(lhs, mode, false, true) end).desc
    end
    assert(key(p.list.win, "R", "n") == "gk_search_regex" and key(p.list.win, "<C-A>", "n") == "gk_mark_matches", "list keys")
    -- while typing (keys with a mode: the action's description)
    local toggle, mark = tostring(key(p.input.win, "<M-r>", "i")), tostring(key(p.input.win, "<C-A>", "i"))
    assert(toggle:find("Regex / fuzzy", 1, true) and mark:find("Mark the search", 1, true), ("box keys: %s / %s"):format(toggle, mark))
    p:action("gk_search_regex") -- R
    assert(H.wait(2000, function() return p.title == "Search files (regex)" end), "R: " .. p.title)
    w.type(".*\\.sh$")
    w.expect("Search files (regex)", "X.SH a.sh scripts/c.sh") -- the name; no capital: X.SH too (smart case)
    w.type(".*\\.SH$")
    w.expect("Search files (regex)", "X.SH")
    w.type("*.sh")
    w.expect("Search files (glob)", "X.SH a.sh scripts/c.sh")
    w.type("^src/.*\\.ts$") -- a /: the path below the root, ^ at the root
    w.expect("Search files (regex)", "src/sub/y.ts src/x.ts")
    w.type("sub/.*\\.(ts|bash)$") -- anywhere below it
    w.expect("Search files (regex)", "scripts/sub/d.bash src/sub/y.ts")
    w.type("src/*.ts") -- a glob with a /: below the root, as in .gitignore
    w.expect("Search files (glob)", "src/x.ts")
    w.type("(foo") -- fd cannot read it: the title says why
    w.expect("Search files (regex: unclosed group)", "")
    -- D: folders by regex; Alt+r: fuzzy, the same text; again: regex
    p:action("gk_search_folders")
    w.type("^sh")
    w.expect("Search folders (regex)", "shell/")
    p:action("gk_regex_toggle")
    assert(H.wait(3000, function() return p.title == "Search folders" end), "Alt+r: " .. p.title)
    assert(p.input:get() == "^sh", "Alt+r: the text went - " .. p.input:get())
    p:action("gk_regex_toggle")
    w.expect("Search folders (regex)", "shell/")
    -- it stays on: after the search, / searches by regex again
    p:action("gk_search_back")
    p:action("gk_search_leave")
    assert(H.wait(3000, function() return p.input.filter:is_empty() and p.title == "Explorer" end), "not back in the tree: " .. p.title)
    p:action("gk_search_files")
    assert(H.wait(2000, function() return p.title == "Search files (regex)" end), "/ after a regex search: " .. p.title)
    p:action("gk_regex_toggle")
    assert(H.wait(2000, function() return p.title == "Search files" end), "Alt+r off: " .. p.title)
  end)
end)

-- 2026-10-22: snacks' <c-a> (select_all) in a search marked the folders shown above the matches as well - a d after it
-- deleted them whole. Now it marks the matches only: a file search's files, a folder search's folders.
test("Explorer: Ctrl+a marks a search's matches - not the folders above them; again unmarks them", function()
  regex_world(function(w)
    local p = w.p
    p:action("gk_search_regex")
    w.type(".*\\.sh$")
    w.expect("Search files (regex)", "X.SH a.sh scripts/c.sh")
    p:action("gk_mark_matches")
    assert(w.marked() == "X.SH a.sh scripts/c.sh", "marked: " .. w.marked()) -- not scripts/
    p:action("gk_mark_matches")
    assert(w.marked() == "", "again - still marked: " .. w.marked())
    -- fuzzy: the matches snacks' matcher found, not the folders it shows above them
    p:action("gk_regex_toggle")
    w.type("x.ts")
    assert(H.wait(5000, function()
      for i = 1, p.list:count() do if p.list:get(i).file == w.root .. "/src/x.ts" then return not p:is_active() end end
    end), "fuzzy: no src/x.ts")
    p:action("gk_mark_matches")
    assert(w.marked() == "src/x.ts", "fuzzy, marked: " .. w.marked()) -- not src/
  end)
end)

-- 2026-10-22: % renames the marked items by regex (config/explorer.lua): s/regex/replacement/ as sed - the first
-- match, g every one, i case ignored - with the Rust regex of the search (rg does it: $1, $0, ${name})
test("Explorer: rename by regex - s/re/repl/ as sed (the first match, g every one, i), $1 $0 ${name}, any delimiter", function()
  local x = require("config.explorer")
  local s = x.parse_substitution([[s/(\d+)\.txt$/$1.md/]])
  assert(s and s.regex == [[(\d+)\.txt$]] and s.replacement == "$1.md" and not s.global and not s.ignore_case, vim.inspect(s))
  s = x.parse_substitution("s#a/b#c#gi") -- another delimiter: / is no delimiter then
  assert(s and s.regex == "a/b" and s.replacement == "c" and s.global and s.ignore_case, vim.inspect(s))
  s = x.parse_substitution([[s/a\/b/c/]]) -- \ before the delimiter: the delimiter itself
  assert(s and s.regex == "a/b", vim.inspect(s))
  s = x.parse_substitution("s/a/b") -- the last delimiter left out
  assert(s and s.regex == "a" and s.replacement == "b", vim.inspect(s))
  for _, bad in ipairs({ "x/a/b/", "s//b/", "s/a/b/q", "s" }) do
    assert(x.parse_substitution(bad) == nil, bad .. " was taken")
  end
  local names = { "a-b-c", "report-1.txt", "README.md" }
  local function sub(text)
    local new, err = x.substitute(names, assert(x.parse_substitution(text)))
    return new and table.concat(new, " ") or ("error: " .. tostring(err))
  end
  for text, want in pairs({
    ["s/-/_/"] = "a_b-c report_1.txt README.md", -- the first match
    ["s/-/_/g"] = "a_b_c report_1.txt README.md", -- every one
    [ [[s/(\d+)\.txt$/$1.md/]] ] = "a-b-c report-1.md README.md",
    [ [[s/^(\w+)-(\d+)/$2-$1/]] ] = "a-b-c 1-report.txt README.md",
    [ [[s/\d+/[$0]/]] ] = "a-b-c report-[1].txt README.md", -- $0: the match
    ["s/(?P<w>[a-z]+)-(?P<n>\\d)/${n}_${w}/"] = "a-b-c 1_report.txt README.md",
    ["s/readme/x/i"] = "a-b-c report-1.txt x.md",
    ["s/readme/x/"] = "a-b-c report-1.txt README.md", -- case counts without i
  }) do
    assert(sub(text) == want, ("%s: %s, not %s"):format(text, sub(text), want))
  end
  local new, err = x.substitute(names, assert(x.parse_substitution("s/(/x/")))
  assert(new == nil and tostring(err):find("unclosed group", 1, true), "a regex rg cannot read: " .. tostring(err))
end)

test("Explorer: % renames the marked by regex - R, Ctrl+a, % s/\\.sh$/.bash/; an open file follows; clashes, existing names stay", function()
  local util, x = Snacks.picker.util, require("config.explorer")
  local saved = { confirm = util.confirm, input = Snacks.input, notify = vim.notify }
  local asked, default, notes = {}, nil, {}
  local answer
  util.confirm = function(prompt, yes) asked[#asked + 1] = prompt; yes() end
  Snacks.input = function(opts, on_confirm) default = opts.default; on_confirm(answer) end
  vim.notify = function(msg, level, opts)
    notes[#notes + 1] = tostring(msg)
    return saved.notify(msg, level, opts)
  end
  local ok, err = pcall(regex_world, function(w)
    local p, root = w.p, w.root
    local function key(lhs)
      return vim.api.nvim_buf_call(p.list.win.buf, function() return vim.fn.maparg(lhs, "n", false, true) end).desc
    end
    assert(key("%") == "gk_rename_regex", "% in the list: " .. tostring(key("%")))
    local buf = vim.fn.bufadd(root .. "/a.sh") -- open (loaded), as a file in the editor
    vim.fn.bufload(buf)
    p:action("gk_search_regex")
    w.type(".*\\.sh$")
    w.expect("Search files (regex)", "X.SH a.sh scripts/c.sh")
    p:action("gk_mark_matches")
    answer = "s/\\.sh$/.bash/" -- case counts: X.SH stays
    p:action("gk_rename_regex")
    assert(asked[#asked] == "Rename 2 items as listed?", "asked: " .. tostring(asked[#asked]))
    for rel, there in pairs({ ["a.bash"] = true, ["scripts/c.bash"] = true, ["X.SH"] = true, ["a.sh"] = false, ["scripts/c.sh"] = false }) do
      assert((vim.uv.fs_stat(root .. "/" .. rel) ~= nil) == there, rel .. (there and " is not there" or " is still there"))
    end
    assert(vim.fn.bufexists(root .. "/a.bash") == 1 and vim.fn.bufexists(root .. "/a.sh") == 0, "the open a.sh did not follow")
    assert(#p.list.selected == 0, "still marked: " .. #p.list.selected)
    -- what stays: two onto one name, onto an existing one, out of the folder - nothing renamed, each says why
    local function rename(text, marks)
      w.type(marks)
      assert(H.wait(5000, function() return not p:is_active() and w.hits() ~= "" end), "no match for " .. marks)
      p.list:set_selected()
      p:action("gk_mark_matches")
      answer, notes = text, {}
      local before = #asked
      p:action("gk_rename_regex")
      assert(#asked == before, text .. ": asked to rename")
      return table.concat(notes, " | ")
    end
    assert(rename("s/.*/same.txt/", "^(b\\.py|X\\.SH)$"):find("would both be same.txt", 1, true), "two onto one: " .. table.concat(notes, " | "))
    assert(default == "s/\\.sh$/.bash/", "the last one as the default: " .. tostring(default))
    assert(rename("s/b\\.py/notes.sh.txt/", "^b\\.py$"):find("exists - nothing overwritten", 1, true), "onto one that exists: " .. table.concat(notes, " | "))
    assert(rename("s/b/x\\/b/", "^b\\.py$"):find("is no name in its folder", 1, true), "out of the folder: " .. table.concat(notes, " | "))
    assert(vim.uv.fs_stat(root .. "/b.py") and vim.uv.fs_stat(root .. "/X.SH"), "renamed after all")
  end)
  util.confirm, Snacks.input, vim.notify = saved.confirm, saved.input, saved.notify
  x.last_substitution = nil
  assert(ok, err)
end)

-- 2026-10-22: the agent shows things in the editor (integrations/agent_tools.lua) - "where is ...?" opens the tree
-- on it, or runs a search there; the user's own R / Alt+r setting stays
local function agent_tool(name, args)
  local got
  require("integrations.agent_tools").call(name, args, function(r) got = r end)
  assert(H.wait(15000, function() return got end), name .. ": no answer")
  return got.content[1].text, got.isError
end

test("Agent tools: show_in_file_tree - the tree on a file, the cursor on it; a regex search shows its matches; then a path again", function()
  regex_world(function(w)
    local p = w.p
    local text, err = agent_tool("show_in_file_tree", { path = "scripts/sub/d.bash" }) -- relative to the project
    assert(not err and text:find("scripts/sub/d.bash", 1, true), text)
    assert(p:current() and p:current().file == w.root .. "/scripts/sub/d.bash", "the cursor: " .. tostring(p:current() and p:current().file))
    assert(vim.api.nvim_get_current_win() == p.list.win.win, "the tree does not have the cursor")
    text = agent_tool("show_in_file_tree", { search = ".*\\.sh$", regex = true })
    assert(text:find("3 file matches", 1, true) and text:find("scripts/c.sh", 1, true) and text:find("X.SH", 1, true)
      and not text:find("d.bash", 1, true), text)
    w.expect("Search files (regex)", "X.SH a.sh scripts/c.sh")
    assert(require("config.explorer").regex == false, "the user's R / Alt+r setting changed")
    -- a path while that search runs: the search ends - the tree as a session starts, fuzzy (snacks' reveal took the
    -- text away, the regex mode stayed) - and it shows the path
    text, err = agent_tool("show_in_file_tree", { path = w.root .. "/src/sub/y.ts" })
    assert(not err, text)
    assert(p.input.filter:is_empty() and p:current().file == w.root .. "/src/sub/y.ts", "after the search: " .. tostring(p:current() and p:current().file))
    assert(not p.opts.live, "the tree stayed in regex (live) mode")
    text = agent_tool("show_in_file_tree", { search = "scripts", folders = true }) -- fuzzy, folders
    assert(text:find("folder match", 1, true) and text:find("scripts", 1, true), text)
    text, err = agent_tool("show_in_file_tree", { path = "nope/missing.txt" })
    assert(err and text:find("No such file", 1, true), text)
  end)
end)

test("Agent tools: open_file shows code at a line in the code window (not the agent's), lit up; show_locations, editor_state, notify", function()
  local link = require("integrations.agent_link")
  link.track()
  local file = H.file("shown.lua", { "local a = 1", "local b = 2", "local c = 3", "local d = 4", "return a" })
  vim.cmd("only | enew!")
  local code = vim.api.nvim_get_current_win()
  vim.cmd("botright vsplit | enew") -- stands in for the agent's terminal: no file in it
  vim.bo.buftype = "nofile"
  local agent_win = vim.api.nvim_get_current_win()
  local saved_notify, notes = vim.notify, {}
  vim.notify = function(msg, _, opts) notes[#notes + 1] = (opts and opts.title or "") .. ": " .. msg end
  local ok, err = pcall(function()
    vim.api.nvim_set_current_win(code) -- the code window was the one used last
    vim.api.nvim_set_current_win(agent_win)
    local text, failed = agent_tool("open_file", { path = file, line = 3, end_line = 4 })
    assert(not failed and text:find("at line 3", 1, true), text)
    assert(vim.api.nvim_get_current_win() == code, "not in the code window")
    assert(vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == vim.fs.normalize(file) and vim.api.nvim_win_get_cursor(0)[1] == 3, "not at line 3")
    local ns = vim.api.nvim_get_namespaces().greyknight_agent_show
    local lit = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
    assert(#lit > 0 and lit[1][2] == 2, "lines 3-4 not lit up: " .. vim.inspect(lit))
    text = agent_tool("show_locations", { title = "Uses of a", locations = { { path = file, line = 1, text = "a" }, { path = file, line = 5 } } })
    local qf = vim.fn.getqflist({ title = 1, items = 1, winid = 1 })
    assert(qf.title == "Uses of a" and #qf.items == 2 and qf.items[2].lnum == 5 and qf.winid ~= 0, vim.inspect(qf))
    vim.cmd("cclose")
    vim.api.nvim_set_current_win(code)
    vim.cmd("normal! 2GVj\27") -- lines 2-3 selected, then the user goes to the agent
    vim.api.nvim_set_current_win(agent_win)
    local state = vim.json.decode((agent_tool("editor_state", {})))
    assert(state.current_file and vim.fs.normalize(state.current_file):find("shown.lua", 1, true), vim.inspect(state))
    assert(state.selected_text == "local b = 2\nlocal c = 3", "selection: " .. vim.inspect(state.selected_text))
    assert(state.cursor and state.cursor.line == 3, vim.inspect(state.cursor))
    agent_tool("notify", { message = "Tests are green" })
    assert(notes[#notes] and notes[#notes]:find("Tests are green", 1, true), vim.inspect(notes))
  end)
  vim.notify = saved_notify
  vim.cmd("only")
  assert(ok, err)
end)

-- 2026-10-23: the tree not open yet - its first listing put the cursor on the current buffer's file, after the
-- agent's reveal (OpenCode with ChatGPT 5.4 on Windows: "The file tree opened but did not get to util/strings.py")
test("Agent tools: show_in_file_tree with the tree closed - it opens and goes to the file, not to the current buffer's", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/util", "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  vim.fn.writefile({ "x" }, root .. "/util/strings.py")
  vim.fn.writefile({ "x" }, root .. "/calc.py")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  close_explorers()
  vim.cmd("only | edit " .. vim.fn.fnameescape(root .. "/calc.py"))
  local ok, err = pcall(function()
    assert(not Snacks.picker.get({ source = "explorer" })[1], "a tree is open")
    local text, failed = agent_tool("show_in_file_tree", { path = "util/strings.py" })
    assert(not failed, text)
    local p = Snacks.picker.get({ source = "explorer" })[1]
    local cur = p and p:current() and vim.fs.normalize(p:current().file)
    local want = root .. "/util/strings.py"
    local win32 = vim.fn.has("win32") == 1
    assert(cur and (win32 and cur:lower() == want:lower() or cur == want), "the cursor: " .. tostring(cur))
  end)
  close_explorers()
  vim.fn.chdir(before)
  assert(ok, err)
end)

test("Agent tools: mark_in_file_tree marks files in the tree, their folders opened; editor_state lists the marks and the review; @ hands the marked to the agent", function()
  regex_world(function(w)
    local text, err = agent_tool("mark_in_file_tree", { paths = { "scripts/sub/d.bash", "src/x.ts", "nope.txt" } })
    assert(not err and text:find("marks 2 items", 1, true) and text:find("Not found: nope.txt", 1, true), text)
    assert(w.marked() == "scripts/sub/d.bash src/x.ts", "marked: " .. w.marked())
    text = agent_tool("mark_in_file_tree", { paths = { "a.sh" }, add = true })
    assert(w.marked() == "a.sh scripts/sub/d.bash src/x.ts", "added: " .. w.marked())
    local state = vim.json.decode((agent_tool("editor_state", {})))
    assert(state.file_tree and state.file_tree.open and #state.file_tree.marked == 3, vim.inspect(state.file_tree))
    assert(state.review_of_your_edits and state.review_of_your_edits.reverted_by_user, vim.inspect(state.review_of_your_edits))
    -- @: the marked to the agent's prompt (agent.lua types them there - here only what it gets)
    local agent, got = require("integrations.agent"), nil
    local mention = agent.mention
    agent.mention = function(paths) got = paths end
    local ok, e = pcall(function() w.p:action("gk_mention") end)
    agent.mention = mention
    assert(ok, e)
    table.sort(got)
    assert(#got == 3 and got[1] == w.root .. "/a.sh" and got[3] == w.root .. "/src/x.ts", vim.inspect(got))
    text, err = agent_tool("mark_in_file_tree", { paths = { "missing/x" } })
    assert(err, text)
  end)
end)

-- 2026-10-23: the agent's edits reviewed in their buffers (integrations/agent_review.lua) - as an agent's hooks do it:
-- before (the file noted), the agent writes, after
local function review_file(name, lines)
  local file = vim.fs.normalize(H.file(name, lines))
  vim.cmd("only | edit! " .. vim.fn.fnameescape(file))
  return require("integrations.agent_review"), file, vim.api.nvim_get_current_buf()
end
local function agent_writes(review, file, lines)
  review.before(file, "Test agent")
  vim.fn.writefile(lines, file)
  review.after(file, "Test agent")
end
local function review_marks(buf)
  local ns = vim.api.nvim_get_namespaces().greyknight_agent_review
  local old, lit, words = {}, {}, {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local d = m[4]
    for _, l in ipairs(d.virt_lines or {}) do
      local t = {}
      for _, chunk in ipairs(l) do t[#t + 1] = chunk[1] end
      old[#old + 1] = vim.trim(table.concat(t))
    end
    if d.line_hl_group then lit[#lit + 1] = (m[2] + 1) .. ":" .. d.line_hl_group end
    if d.hl_group == "GreyKnightReviewText" then
      words[#words + 1] = vim.api.nvim_buf_get_text(buf, m[2], m[3], d.end_row or m[2], d.end_col, {})[1]
    end
  end
  return old, lit, words
end
local function keys(k) vim.api.nvim_feedkeys(vim.keycode(k), "mx", false) end

test("Agent review: an edit shows in its buffer - the old line in red above, the new ones green, the changed word marked; ]c / [c go to them", function()
  local review, file, buf = review_file("reviewed.py", { "a = 1", "b = 2", "c = 3", "d = 4", "e = 5" })
  local ok, err = pcall(function()
    agent_writes(review, file, { "a = 1", "b = 20", "x = 9", "c = 3", "d = 4", "e = 5" })
    assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "b = 20", "the buffer did not take the agent's text")
    local old, lit, words = review_marks(buf)
    assert(#old == 1 and old[1] == "b = 2", "old lines: " .. vim.inspect(old))
    assert(vim.tbl_contains(lit, "2:GreyKnightReviewChange") and vim.tbl_contains(lit, "3:GreyKnightReviewAdd") and #lit == 2, vim.inspect(lit))
    assert(#words == 1 and words[1] == "20", "changed words: " .. vim.inspect(words))
    assert(review.active(buf), "no review")
    -- ]c / [c: the review's (the test's files are in no git repository - no gitsigns there)
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    keys("]c")
    assert(vim.fn.line(".") == 2, "]c (around the end) went to " .. vim.fn.line("."))
    keys("]c")
    assert(vim.fn.line(".") == 3, "]c went to " .. vim.fn.line("."))
    keys("[c")
    assert(vim.fn.line(".") == 2, "[c went to " .. vim.fn.line("."))
    local hint = vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_get_namespaces().greyknight_agent_review_hint, 0, -1, { details = true })
    assert(#hint == 1 and hint[1][2] == 1 and hint[1][4].virt_text[1][1]:find("<leader>ay keeps", 1, true), vim.inspect(hint))
    -- the user edits the buffer: the review follows; their edit back to the old text ends that change
    vim.api.nvim_buf_set_lines(buf, 2, 3, false, {})
    review.render(buf)
    assert(#review.entry(file).hunks == 1, "after the user's edit: " .. vim.inspect(review.entry(file).hunks))
  end)
  review.stop(file)
  assert(not review.active(buf) and #review_marks(buf) == 0, "the review did not end")
  assert(ok, err)
end)

test("Agent review: <leader>an reverts the change at the cursor - buffer and disk; <leader>ay keeps one; the whole file; a new file reverted goes", function()
  local review, file, buf = review_file("kept.py", { "a = 1", "b = 2", "c = 3", "d = 4", "e = 5" })
  local saved, notes = vim.notify, {}
  vim.notify = function(msg) notes[#notes + 1] = msg end
  local ok, err = pcall(function()
    agent_writes(review, file, { "a = 1", "b = 20", "c = 3", "d = 4", "e = 50" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    keys("<leader>an")
    assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "b = 2", "the buffer: " .. vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
    assert(vim.fn.readfile(file)[2] == "b = 2" and vim.fn.readfile(file)[5] == "e = 50", "on disk: " .. vim.inspect(vim.fn.readfile(file)))
    assert(not vim.bo[buf].modified, "not saved")
    assert(review.reverted[#review.reverted].lines == "2", vim.inspect(review.reverted))
    assert(review.active(buf), "the review ended with a change left")
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    keys("<leader>ay")
    assert(not review.active(buf) and #review_marks(buf) == 0, "kept the last: the review is still on")
    assert(vim.fn.readfile(file)[5] == "e = 50", "kept, yet changed on disk")
    -- the whole file: <leader>aN puts it back as it was before the agent
    agent_writes(review, file, { "A = 1", "b = 2", "c = 3", "d = 4", "e = 5" })
    agent_writes(review, file, { "A = 1", "b = 2", "c = 3", "d = 4", "E = 5" }) -- a second edit: compared with before the first
    assert(#review.entry(file).hunks == 2, vim.inspect(review.entry(file).hunks))
    keys("<leader>aN")
    assert(table.concat(vim.fn.readfile(file), ",") == "a = 1,b = 2,c = 3,d = 4,e = 50", "on disk: " .. table.concat(vim.fn.readfile(file), ","))
    assert(not review.active(buf), "the review is still on")
    -- a file the agent made: reverted whole, it goes
    local new = vim.fs.normalize(vim.fn.fnamemodify(file, ":h") .. "/made.py")
    review.before(new, "Test agent")
    vim.fn.writefile({ "print('new')" }, new)
    review.after(new, "Test agent")
    vim.cmd("edit " .. vim.fn.fnameescape(new))
    local nb = vim.api.nvim_get_current_buf()
    local _, lit = review_marks(nb)
    assert(review.active(nb) and #lit == 1, "the new file is not shown for review: " .. vim.inspect(lit))
    keys("<leader>aN")
    assert(not vim.uv.fs_stat(new) and not vim.api.nvim_buf_is_valid(nb), "the new file is still there")
    assert(table.concat(notes, " | "):find("made.py: the agent made it - it is deleted", 1, true), table.concat(notes, " | "))
  end)
  vim.notify = saved
  review.stop(file)
  assert(ok, err)
end)

test("Agent review: unsaved changes of the user's - the agent's edit does not overwrite them; Qwen Code's diff accepted needs no second review", function()
  local review, file, buf = review_file("mine.py", { "a = 1", "b = 2" })
  local saved, notes = vim.notify, {}
  vim.notify = function(msg) notes[#notes + 1] = msg end
  local ok, err = pcall(function()
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "a = 'mine'" })
    agent_writes(review, file, { "a = 1", "b = 'agent'" })
    assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "a = 'mine'", "the user's unsaved change is gone")
    assert(table.concat(notes, " | "):find("while you have unsaved changes", 1, true), table.concat(notes, " | "))
    vim.cmd("edit!")
    review.stop(file)
    -- accepted in Qwen Code's diff (agent_ide.lua): the write that follows is reviewed already
    review.before(file, "Qwen Code")
    review.accept_content(file, "a = 1\nb = 3\n")
    vim.fn.writefile({ "a = 1", "b = 3" }, file)
    review.after(file, "Qwen Code")
    assert(not review.active(buf) and review.entry(file) == nil, "an accepted diff came up for review again")
    assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "b = 3", "the buffer did not take the accepted text")
  end)
  vim.notify = saved
  review.stop(file)
  assert(ok, err)
end)

test("Agent review: a window following the agent shows each edit as it lands - the user's window stays current; <leader>af again stops", function()
  local review = require("integrations.agent_review")
  local a = vim.fs.normalize(H.file("follow_a.py", { "x = 1" }))
  local b = vim.fs.normalize(H.file("follow_b.py", { "one", "two", "three", "four", "five", "six" }))
  vim.cmd("only | edit! " .. vim.fn.fnameescape(a))
  local code = vim.api.nvim_get_current_win()
  local saved = vim.notify
  vim.notify = function() end
  local ok, err = pcall(function()
    keys("<leader>af")
    assert(review.following(code) and vim.wo[code].winbar:find("follows the agent", 1, true), "not following: " .. vim.wo[code].winbar)
    vim.cmd("botright vsplit | enew") -- the user works elsewhere
    local mine = vim.api.nvim_get_current_win()
    agent_writes(review, b, { "one", "two", "three", "four", "FIVE", "six" })
    assert(vim.api.nvim_get_current_win() == mine, "the user's window lost the cursor")
    assert(vim.fs.normalize(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(code))) == b, "the following window shows "
      .. vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(code)))
    assert(vim.api.nvim_win_get_cursor(code)[1] == 5, "not at the change: " .. vim.inspect(vim.api.nvim_win_get_cursor(code)))
    assert(vim.wo[code].winbar:find("follows the agent", 1, true), "the winbar went with the buffer")
    assert(#review_marks(vim.api.nvim_win_get_buf(code)) == 1, "no review in the following window")
    vim.api.nvim_set_current_win(code)
    keys("<leader>af")
    assert(not review.following(code) and vim.wo[code].winbar == "", "still following: " .. vim.wo[code].winbar)
  end)
  vim.notify = saved
  review.stop(b)
  for win in pairs(review.followers) do review.followers[win] = nil end
  vim.cmd("only")
  assert(ok, err)
end)

test("Agent review: in a git file ]c goes to the agent's changes first (gitsigns' ]c asks the review), once reviewed to git's", function()
  local review = require("integrations.agent_review")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath((function() local t = vim.fn.tempname(); vim.fn.mkdir(t, "p"); return t end)())))
  local file = root .. "/g.py"
  local function git(...)
    local out = vim.fn.system(vim.list_extend({ "git", "-C", root, "-c", "user.name=gk", "-c", "user.email=gk@example.invalid" }, { ... }))
    assert(vim.v.shell_error == 0, out)
  end
  vim.fn.writefile({ "l1", "l2", "l3", "l4", "l5", "l6" }, file)
  git("init", "-q")
  git("add", ".")
  git("commit", "-q", "-m", "init")
  vim.fn.writefile({ "l1", "l2", "l3", "l4", "L5 mine", "l6" }, file) -- the user's own change: git's, not the review's
  vim.cmd("only | edit! " .. vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()
  local gs = require("gitsigns")
  local ok, err = pcall(function()
    assert(H.wait(15000, function() return vim.fn.maparg("]c", "n", false, true).buffer == 1 end), "gitsigns did not attach")
    agent_writes(review, file, { "l1", "l2", "L3 agent", "l4", "L5 mine", "l6" })
    assert(H.wait(10000, function() return #(gs.get_hunks(buf) or {}) == 2 end), "git's changes: " .. vim.inspect(gs.get_hunks(buf)))
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    keys("]c")
    assert(vim.fn.line(".") == 3, "]c went to " .. vim.fn.line(".") .. " - not the agent's change (line 3)")
    review.act(true, true) -- reviewed: ]c is git's again
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    keys("]c")
    assert(H.wait(3000, function() return vim.fn.line(".") == 5 end), "]c went to " .. vim.fn.line(".") .. " - not git's next change (line 5)")
  end)
  review.stop(file)
  assert(ok, err)
end)

test("Agent review: its hooks - Qwen Code's before / after its edit tools (JSON on stdin), OpenCode's plugin before / after its edits and patches", function()
  local link, review = require("integrations.agent_link"), require("integrations.agent_review")
  local s = link.qwen_settings()
  local pre, post = s.hooks.PreToolUse[#s.hooks.PreToolUse], s.hooks.PostToolUse[#s.hooks.PostToolUse]
  assert(pre.matcher == link.EDIT_TOOLS and post.matcher == link.EDIT_TOOLS and pre.hooks[1].command:find("before", 1, true)
    and post.hooks[1].command:find("after", 1, true), vim.inspect({ pre, post }))
  -- a JavaScript regex (Qwen Code's): Vim's very magic reads it the same
  local re = vim.regex("\\v" .. link.EDIT_TOOLS)
  assert(re:match_str("write_file") and re:match_str("edit") and re:match_str("notebook_edit") and not re:match_str("read_file")
    and not re:match_str("edit_x"), "the matcher")
  local file = vim.fs.normalize(H.file("hooked.py", { "x = 1" }))
  -- as Qwen Code runs a hook: its command, the JSON on stdin; waited for without jobwait (it would hold the RPC up)
  local function hook(event, payload)
    local job = vim.fn.jobstart(link.hook_command(event))
    vim.fn.chansend(job, vim.json.encode(payload))
    vim.fn.chanclose(job, "stdin")
    assert(H.wait(15000, function() return vim.fn.jobwait({ job }, 0)[1] ~= -1 end), "the hook did not end")
  end
  local ok, err = pcall(function()
    hook("before", { hook_event_name = "PreToolUse", tool_name = "write_file", tool_input = { file_path = file, content = "x = 2\n" } })
    vim.fn.writefile({ "x = 2" }, file)
    hook("after", { hook_event_name = "PostToolUse", tool_name = "write_file", tool_input = { file_path = file, content = "x = 2\n" } })
    local f = review.entry(file)
    assert(f and f.edits == 1 and f.ref[1] == "x = 1", vim.inspect(f))
    review.stop(file)
    -- OpenCode's plugin, run by node as OpenCode runs it: an edit (filePath), then a patch of two files (relative)
    local node = vim.fn.exepath("node")
    if node == "" then return end
    -- as an .mjs: node before 22 reads a .js with import as CommonJS (OpenCode's bun does not)
    local js = vim.fn.tempname() .. "-greyknight.mjs"
    vim.fn.writefile(vim.fn.readfile(link.opencode_dir() .. "/plugins/greyknight.js"), js)
    local root = vim.fs.dirname(file)
    vim.fn.writefile({ "x = 1" }, root .. "/p1.py")
    local runner = vim.fn.tempname() .. "-run.mjs"
    vim.fn.writefile({
      ("import { pathToFileURL } from 'node:url'; import { writeFileSync } from 'node:fs'"),
      ("const m = await import(pathToFileURL(%s).href)"):format(vim.json.encode(js)),
      ("const h = await m.GreyKnight({ directory: %s })"):format(vim.json.encode(root)),
      ("await h['tool.execute.before']({ tool: 'edit', callID: 'c1' }, { args: { filePath: %s } })"):format(vim.json.encode(file)),
      ("writeFileSync(%s, 'x = 3\\n')"):format(vim.json.encode(file)),
      "await h['tool.execute.after']({ tool: 'edit', callID: 'c1' }, {})",
      "const patch = '*** Begin Patch\\n*** Update File: p1.py\\n@@\\n-x = 1\\n+x = 9\\n*** Add File: p2.py\\n+y = 1\\n*** End Patch'",
      "await h['tool.execute.before']({ tool: 'apply_patch', callID: 'c2' }, { args: { patchText: patch } })",
      ("writeFileSync(%s, 'x = 9\\n'); writeFileSync(%s, 'y = 1\\n')"):format(vim.json.encode(root .. "/p1.py"), vim.json.encode(root .. "/p2.py")),
      "await h['tool.execute.after']({ tool: 'apply_patch', callID: 'c2' }, {})",
      "await h['tool.execute.before']({ tool: 'read', callID: 'c3' }, { args: { filePath: 'p1.py' } })",
    }, runner)
    local done, out = false, {}
    local job = vim.fn.jobstart({ node, runner }, { on_exit = function() done = true end,
      on_stderr = function(_, d) vim.list_extend(out, d) end })
    assert(job > 0 and H.wait(30000, function() return done end), "node did not end: " .. table.concat(out, "\n"))
    local f1, p1, p2 = review.entry(file), review.entry(root .. "/p1.py"), review.entry(root .. "/p2.py")
    -- before OpenCode's edit the file is as Qwen Code's left it
    assert(f1 and f1.edits == 1 and f1.ref[1] == "x = 2" and f1.last[1] == "x = 3", "edit: " .. vim.inspect(f1) .. table.concat(out, "\n"))
    assert(p1 and p1.edits == 1 and p1.ref[1] == "x = 1" and p2 and p2.new and p2.edits == 1, "patch: " .. vim.inspect({ p1, p2 }))
    assert(f1.agent and p1.agent, "who edited")
  end)
  for _, name in ipairs({ file, vim.fs.dirname(file) .. "/p1.py", vim.fs.dirname(file) .. "/p2.py" }) do review.stop(name) end
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

-- 2026-10-22: Neovim 0.12's errors as :messages has them (taken from a real session). A callback's error, "vim.schedule
-- callback: ...", was not logged at all; an autocommand's kept only its header - the Kali log had
-- 'Error in BufEnter Autocommands for "<buffer=25>":' and nothing of the error itself
test("Error log: Neovim 0.12's errors are logged whole - a scheduled callback's, an autocommand's with its Lua error and traceback", function()
  local el = require("config.errorlog")
  local autocmd = { 'Error in User Autocommands for "GkBoom":', "Lua callback: /tmp/gk-err.lua:1: attempt to index local 't' (a nil value)",
    "stack traceback:", "\t/tmp/gk-err.lua:1: in function </tmp/gk-err.lua:1>" }
  local scheduled = { "vim.schedule callback: /tmp/gk-err.lua:6: boom in a scheduled callback", "stack traceback:",
    "\t[C]: in function 'error'", "\t/tmp/gk-err.lua:6: in function </tmp/gk-err.lua:6>" }
  local sourced = { "Error detected while processing /tmp/x.vim:", "line    3:", "E492: Not an editor command: foo" }
  local plain = { "E21: Cannot make changes, 'modifiable' is off" }
  local output = table.concat(vim.iter({ { "some info message" }, autocmd, scheduled, sourced, plain, { "written" } }):flatten():totable(), "\n")
  local blocks = el.parse_messages(output)
  local want = vim.tbl_map(function(b) return table.concat(b, "\n") end, { autocmd, scheduled, sourced, plain })
  assert(vim.deep_equal(blocks, want), "parsed: " .. vim.inspect(blocks))
  -- and into the log, the lines after the first indented below it
  local saved_path, exec2 = el.path, vim.api.nvim_exec2
  el.path = vim.fn.tempname()
  vim.api.nvim_exec2 = function(cmd, opts)
    if cmd == "messages" then return { output = output } end
    return exec2(cmd, opts)
  end
  local ok, err = pcall(function()
    el.log_messages()
    local log = table.concat(vim.fn.readfile(el.path), "\n")
    for _, want_line in ipairs({ "[messages] Error in User Autocommands", "      Lua callback: /tmp/gk-err.lua:1: attempt to index local 't'",
      "[messages] vim.schedule callback: /tmp/gk-err.lua:6: boom", "      E492: Not an editor command: foo" }) do
      assert(log:find(want_line, 1, true), want_line .. " - the log:\n" .. log)
    end
  end)
  vim.api.nvim_exec2 = exec2
  vim.fn.delete(el.path)
  el.path = saved_path
  assert(ok, err)
end)

-- 2026-10-22: each big file opened put snacks' "Big file detected" (a warning) into the error log, between the errors
test("Error log: a big file's notice is shown, not logged - another warning still is", function()
  local el = require("config.errorlog")
  local saved = el.path
  el.path = vim.fn.tempname()
  local lines = {}
  for i = 1, 40000 do lines[#lines + 1] = ("line %06d of a big log file, long enough to pass snacks' 1.5 MB"):format(i) end
  local file = H.file("big.log", lines)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(file))
    assert(H.wait(3000, function() return vim.bo.filetype == "bigfile" end), "not taken for a big file: " .. vim.bo.filetype)
    vim.notify("a warning of something else", vim.log.levels.WARN, { title = "Test" })
    local log = vim.fn.filereadable(el.path) == 1 and table.concat(vim.fn.readfile(el.path), "\n") or ""
    assert(not log:find("Big file", 1, true), "the big file's notice was logged: " .. log)
    assert(log:find("a warning of something else", 1, true), "another warning was not: " .. log)
  end)
  pcall(vim.cmd, "bwipeout!")
  vim.fn.delete(el.path)
  el.path = saved
  assert(ok, err)
end)

-- 2026-10-22: Neovim stops the language servers when it quits without waiting for them; on Windows a server ended that
-- way reports exit code 1, and "Client lua_ls quit with exit code 1 and signal 15" went into the log at most quits
test("Error log: a language server ended because Neovim quits is not logged - one that ends while it runs is", function()
  local el = require("config.errorlog")
  local saved_path, saved_exiting, temp = el.path, el.exiting, vim.fn.tempname()
  el.path = temp
  local msg = "Client lua_ls quit with exit code 1 and signal 15. Check log for errors: lsp.log"
  local function log() return vim.fn.filereadable(el.path) == 1 and table.concat(vim.fn.readfile(el.path), "\n") or "" end
  local ok, err = pcall(function()
    el.exiting = function() return true end -- Neovim quits
    vim.notify(msg, vim.log.levels.WARN)
    assert(not log():find("lua_ls quit", 1, true), "logged while Neovim quits: " .. log())
    el.exiting = function() return false end -- a server that ends in the middle of the work
    vim.notify(msg, vim.log.levels.WARN)
    assert(log():find("lua_ls quit", 1, true), "a server that ended while Neovim runs was not logged: " .. log())
  end)
  el.path, el.exiting = saved_path, saved_exiting
  vim.fn.delete(temp)
  assert(ok, err)
end)

-- 2026-10-22: <C-space> grows the selection node by node; <BS> went to a node's first child instead of back -
-- from foo(bar, baz) to foo, not to (bar, baz)
test("Editing: <C-space> grows the selection node by node, <BS> takes it back the same way", function()
  vim.cmd.edit(vim.fn.fnameescape(H.file("sel.lua", { "local function f()", "  local x = foo(bar, baz)", "  return x", "end" })))
  pcall(function() vim.treesitter.get_parser(0):parse(true) end)
  vim.api.nvim_win_set_cursor(0, { 2, 17 }) -- on bar
  local function selected()
    return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() }), "\n")
  end
  local seen = {}
  local ok, err = pcall(function()
    for _, k in ipairs({ "<C-space>", "<C-space>", "<C-space>", "<C-space>", "<BS>", "<BS>", "<BS>" }) do
      vim.api.nvim_feedkeys(vim.keycode(k), "x", false)
      seen[#seen + 1] = selected()
    end
  end)
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "x", false)
  vim.cmd("silent! bwipeout!")
  assert(ok, err)
  local want = { "bar", "(bar, baz)", "foo(bar, baz)", "x = foo(bar, baz)", "foo(bar, baz)", "(bar, baz)", "bar" }
  assert(vim.deep_equal(seen, want), "selections: " .. vim.inspect(seen))
end)

local function real_tmp()
  local t = vim.fn.tempname()
  vim.fn.mkdir(t, "p")
  return vim.fs.normalize(assert(vim.uv.fs_realpath(t)))
end

-- ── Bookmarks (config/bookmarks.lua, 2026-10-22): lines to come back to, per project - IntelliJ's F11 / Shift+F11 ──

local BOOKMARK_NS = vim.api.nvim_create_namespace("greyknight.bookmarks")

-- a project of its own (Neovim's directory) with these files, and a bookmarks file of its own
local function with_bookmarks(files, fn)
  local bm = require("config.bookmarks")
  local root, before, saved = real_tmp(), vim.fn.getcwd(), bm.file
  for name, lines in pairs(files) do vim.fn.writefile(lines, root .. "/" .. name) end
  bm.file = root .. "/.bookmarks.json"
  vim.fn.chdir(root)
  bm.reload()
  local ok, err = pcall(fn, root, bm)
  for _, p in ipairs(Snacks.picker.get({ source = "bookmarks", tab = false })) do pcall(p.close, p) end
  vim.cmd("silent! only")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)):find(root .. "/", 1, true) == 1 then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
  vim.fn.chdir(before)
  bm.file = saved
  bm.reload()
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

-- the lines of buf with a bookmark's sign
local function bookmark_signs(buf)
  local rows = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, BOOKMARK_NS, 0, -1, { details = true })) do
    if not m[4].invalid then rows[#rows + 1] = m[2] + 1 end
  end
  table.sort(rows)
  return rows
end

-- what the bookmarks file keeps: "file:line[:name]" of every project in it
local function bookmarks_kept(bm)
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(bm.file), "\n")) end)
  local out = {}
  for _, list in pairs(ok and type(data) == "table" and type(data.projects) == "table" and data.projects or {}) do
    for _, b in ipairs(list) do out[#out + 1] = vim.fs.basename(b.file) .. ":" .. b.line .. (b.name and (":" .. b.name) or "") end
  end
  table.sort(out)
  return out
end

local function at() return vim.fs.basename(vim.api.nvim_buf_get_name(0)) .. ":" .. vim.api.nvim_win_get_cursor(0)[1] end
-- a file by its name as it is: Windows' fnameescape() leaves [ ] alone, :edit took "[draft]" as a pattern
local function edit(path) vim.cmd.edit({ args = { path }, magic = { file = false } }) end

test("Bookmarks: <leader>mm puts a ⚑ on the line and keeps it for the project - read again next time; again takes it away", function()
  with_bookmarks({ ["notes.txt"] = { "one", "two", "three", "four" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes.txt"))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<leader>mm"), "mx", false)
    assert(vim.deep_equal(bookmark_signs(buf), { 3 }), "signs: " .. vim.inspect(bookmark_signs(buf)))
    local mark = vim.api.nvim_buf_get_extmarks(buf, BOOKMARK_NS, 0, -1, { details = true })[1]
    assert(vim.trim(mark[4].sign_text) == bm.SIGN, "the sign: " .. tostring(mark[4].sign_text))
    assert(vim.deep_equal(bookmarks_kept(bm), { "notes.txt:3" }), "kept: " .. vim.inspect(bookmarks_kept(bm)))
    local data = vim.json.decode(table.concat(vim.fn.readfile(bm.file), "\n"))
    local project = next(data.projects)
    assert(vim.fs.normalize(project):lower() == root:lower(), "kept for " .. tostring(project) .. ", not " .. root)
    -- the next session: read again, the file opened again - the sign is back
    vim.cmd("bwipeout!")
    bm.reload()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes.txt"))
    assert(vim.deep_equal(bookmark_signs(0), { 3 }), "read again: " .. vim.inspect(bookmark_signs(0)))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<leader>mm"), "mx", false)
    assert(#bookmark_signs(0) == 0, "the sign stayed")
    assert(#bookmarks_kept(bm) == 0, "still kept: " .. vim.inspect(bookmarks_kept(bm)))
  end)
end)

test("Bookmarks: one goes with its line - lines added above, its line deleted (undo brings it back), the file changed outside", function()
  with_bookmarks({ ["code.txt"] = { "a", "b", "target", "c" }, ["other.txt"] = { "x", "keep me", "y" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/code.txt"))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    bm.toggle()
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { "new 1", "new 2" })
    vim.cmd("silent write")
    assert(vim.deep_equal(bookmarks_kept(bm), { "code.txt:5" }), "two lines above, saved: " .. vim.inspect(bookmarks_kept(bm)))
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    vim.cmd("normal! dd")
    assert(#bookmark_signs(0) == 0, "the sign stayed on a deleted line")
    vim.cmd("silent undo")
    assert(vim.deep_equal(bookmark_signs(0), { 5 }), "undo did not bring it back: " .. vim.inspect(bookmark_signs(0)))
    vim.cmd("normal! dd")
    vim.cmd("silent write")
    assert(#bookmarks_kept(bm) == 0, "its line deleted and saved, still kept: " .. vim.inspect(bookmarks_kept(bm)))
    -- changed outside Neovim (a git pull put three lines on top): found again by its text
    vim.cmd.edit(vim.fn.fnameescape(root .. "/other.txt"))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    bm.toggle()
    vim.cmd("bwipeout!")
    vim.fn.writefile({ "1", "2", "3", "x", "keep me", "y" }, root .. "/other.txt")
    vim.cmd.edit(vim.fn.fnameescape(root .. "/other.txt"))
    assert(vim.deep_equal(bookmark_signs(0), { 5 }), "not found again: " .. vim.inspect(bookmark_signs(0)))
    assert(vim.deep_equal(bookmarks_kept(bm), { "other.txt:5" }), "kept: " .. vim.inspect(bookmarks_kept(bm)))
  end)
end)

test("Bookmarks: <leader>ml lists them, a named one by its name; Enter opens the file at the line - one not open, [ ] in its name", function()
  local files = { ["a.txt"] = { "a1", "a2", "a3" }, ["notes [draft].txt"] = { "n1", "n2", "n3", "n4" }, ["notes d.txt"] = { "decoy" } }
  with_bookmarks(files, function(root, bm)
    local input = vim.ui.input
    vim.ui.input = function(_, on_confirm) on_confirm("the draft") end
    local ok, err = pcall(function()
      edit(root .. "/notes [draft].txt")
      vim.api.nvim_win_set_cursor(0, { 4, 0 })
      vim.api.nvim_feedkeys(vim.keycode("<leader>mr"), "mx", false) -- a name; the bookmark set on the way
    end)
    vim.ui.input = input
    assert(ok, err)
    assert(vim.deep_equal(bookmarks_kept(bm), { "notes [draft].txt:4:the draft" }), "named: " .. vim.inspect(bookmarks_kept(bm)))
    vim.cmd("bwipeout!") -- not open any more; "notes d.txt" is (the name as a pattern matched it, 2026-10-21)
    edit(root .. "/notes d.txt")
    edit(root .. "/a.txt")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.keycode("<leader>mm"), "mx", false)
    vim.api.nvim_feedkeys(vim.keycode("<leader>ml"), "mx", false)
    local p
    assert(H.wait(3000, function() p = Snacks.picker.get({ source = "bookmarks" })[1]; return p and p.list:count() == 2 end), "no list of two")
    local shown = {}
    for _, item in ipairs(p:items()) do shown[#shown + 1] = (item.label or "-") .. " " .. vim.fs.basename(item.file) .. ":" .. item.pos[1] end
    assert(vim.deep_equal(shown, { "- a.txt:2", "the draft notes [draft].txt:4" }), "listed: " .. vim.inspect(shown))
    p.list:view(2)
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert(H.wait(3000, function() return at() == "notes [draft].txt:4" end), "Enter: " .. at())
    assert(vim.deep_equal(bookmark_signs(0), { 4 }), "no sign in the opened file")
    -- <C-x> in the list deletes the one under the cursor
    vim.api.nvim_feedkeys(vim.keycode("<leader>ml"), "mx", false)
    assert(H.wait(3000, function() p = Snacks.picker.get({ source = "bookmarks" })[1]; return p and p.list:count() == 2 end), "no list again")
    p.list:view(1)
    vim.api.nvim_feedkeys(vim.keycode("<C-x>"), "x", false)
    assert(H.wait(3000, function() return p.list:count() == 1 end), "<C-x> did not delete: " .. p.list:count())
    assert(vim.deep_equal(bookmarks_kept(bm), { "notes [draft].txt:4:the draft" }), "kept: " .. vim.inspect(bookmarks_kept(bm)))
  end)
end)

test("Bookmarks: <leader>mn / <leader>mp go to the next / previous in file and line order, file to file, round at the ends", function()
  with_bookmarks({ ["a.txt"] = { "1", "2", "3", "4", "5" }, ["b.txt"] = { "1", "2", "3" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/b.txt"))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    bm.toggle()
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    for _, line in ipairs({ 2, 4 }) do
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      bm.toggle()
    end
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local seen = {}
    for _, keys in ipairs({ "<leader>mn", "<leader>mn", "<leader>mn", "<leader>mn", "<leader>mp" }) do
      vim.api.nvim_feedkeys(vim.keycode(keys), "mx", false)
      seen[#seen + 1] = at()
    end
    assert(vim.deep_equal(seen, { "a.txt:2", "a.txt:4", "b.txt:3", "a.txt:2", "b.txt:3" }), "went: " .. vim.inspect(seen))
    vim.api.nvim_feedkeys(vim.keycode("<C-o>"), "x", false)
    assert(at() == "a.txt:2", "<C-o> did not come back: " .. at())
  end)
end)

test("Bookmarks: each project its own - in another directory the list and the signs are that one's", function()
  with_bookmarks({ ["a.txt"] = { "1", "2" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    bm.toggle()
    local other = real_tmp()
    vim.fn.chdir(other)
    local ok, err = pcall(function()
      assert(#bm.list() == 0, "another project lists them: " .. vim.inspect(bm.list()))
      assert(#bookmark_signs(buf) == 0, "the sign stayed in another project")
    end)
    vim.fn.chdir(root)
    vim.fn.delete(other, "rf")
    assert(ok, err)
    assert(#bm.list() == 1 and vim.deep_equal(bookmark_signs(buf), { 2 }), "back in the project: " .. vim.inspect(bm.list()))
  end)
end)

-- 2026-10-22: a line replaced rather than edited - cut and put back elsewhere (dd, p), the whole text set anew (some
-- formatters, :%!) - lost its bookmark with the next save; and one that followed its text was written at its old line
test("Bookmarks: a line moved, cut and put back, or replaced stays bookmarked - the sign goes along, the file says where", function()
  with_bookmarks({ ["m.txt"] = { "alpha line", "beta line", "gamma line", "delta line" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/m.txt"))
    local buf = vim.api.nvim_get_current_buf()
    -- what Neovim sends once it waits for keys again - a test never does
    local function changed() vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf }) end
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    bm.toggle()
    vim.cmd("2move 3") -- moved: the sign goes along by itself
    changed()
    assert(vim.deep_equal(bookmark_signs(buf), { 3 }), ":m - the sign: " .. vim.inspect(bookmark_signs(buf)))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.api.nvim_feedkeys(vim.keycode("VJ<Esc>"), "mx", false) -- the selection one line down (keymaps.lua)
    changed()
    assert(vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1] == "beta line", "visual J did not move it: " .. vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
    assert(vim.deep_equal(bookmark_signs(buf), { 4 }), "visual J - the sign: " .. vim.inspect(bookmark_signs(buf)))
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alpha line", "gamma line", "beta    line", "delta line" })
    changed()
    assert(vim.deep_equal(bookmark_signs(buf), { 3 }), "the text set anew - the sign: " .. vim.inspect(bookmark_signs(buf)))
    vim.cmd("silent write")
    assert(vim.deep_equal(bookmarks_kept(bm), { "m.txt:3" }), "saved: " .. vim.inspect(bookmarks_kept(bm)))
    vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- cut, put back below the last line: the same text at a new line
    vim.cmd("normal! dd")
    changed()
    vim.cmd("normal! Gp")
    changed()
    assert(vim.deep_equal(bookmark_signs(buf), { 4 }), "dd, p - the sign: " .. vim.inspect(bookmark_signs(buf)))
    vim.cmd("silent write")
    assert(vim.deep_equal(bookmarks_kept(bm), { "m.txt:4" }), "dd, p, saved: " .. vim.inspect(bookmarks_kept(bm)))
    vim.cmd("normal! dd") -- deleted for real: gone with the save
    changed()
    vim.cmd("silent write")
    assert(#bookmarks_kept(bm) == 0, "its line deleted and saved, still kept: " .. vim.inspect(bookmarks_kept(bm)))
  end)
end)

-- 2026-10-22: a renamed or moved file kept its bookmarks at the old path; the list opened an empty file there
test("Bookmarks: renamed or moved, a file keeps its bookmarks - the explorer's r and m (a file not open, its folder), :file", function()
  explorer_world(function(ex, w)
    local bm, p, R = require("config.bookmarks"), w.picker, w.root
    local saved = bm.file
    bm.file = w.far .. "/bookmarks.json"
    bm.reload()
    local ok, err = pcall(function()
      vim.fn.writefile({ "one", "two", "three" }, R .. "/open.txt")
      vim.fn.writefile({ "x", "y", "z" }, R .. "/sub/closed.txt")
      vim.cmd.edit(vim.fn.fnameescape(R .. "/sub/closed.txt"))
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      bm.toggle()
      vim.cmd("bwipeout")
      vim.cmd.edit(vim.fn.fnameescape(R .. "/open.txt"))
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      bm.toggle()
      w.answer = "renamed.txt"
      ex.rename(p, w.at(R .. "/open.txt")) -- r on the open one
      assert(vim.fs.basename(vim.api.nvim_buf_get_name(0)) == "renamed.txt", "r: the buffer " .. vim.api.nvim_buf_get_name(0))
      assert(vim.deep_equal(bookmark_signs(0), { 2 }), "r: the sign did not go along - " .. vim.inspect(bookmark_signs(0)))
      ex.move(p, w.at(R .. "/sub")) -- m on its folder, m on the target: the file not open goes with the folder
      ex.move(p, w.at(R .. "/other"))
      vim.cmd("file " .. vim.fn.fnameescape(R .. "/named.txt"))
      vim.cmd("silent write")
      local paths = vim.tbl_map(function(b) return b.file:sub(#R + 2) .. ":" .. b.line end, bm.list())
      table.sort(paths)
      assert(vim.deep_equal(paths, { "named.txt:2", "other/sub/closed.txt:3" }), "the bookmarks: " .. vim.inspect(paths))
      vim.cmd.edit(vim.fn.fnameescape(R .. "/other/sub/closed.txt"))
      assert(vim.deep_equal(bookmark_signs(0), { 3 }), "the moved file's sign: " .. vim.inspect(bookmark_signs(0)))
    end)
    bm.file = saved
    bm.reload()
    assert(ok, err)
  end)
end)

-- 2026-10-22: harpoon's slots kept the old path of a renamed or moved file - the slot made an empty new file there;
-- renamed in an oil buffer, also the bookmarks of a file not open stayed behind
test("Harpoon and bookmarks follow a file - the explorer's r, m of its folder, a rename in oil; a deleted one's slot opens nothing", function()
  explorer_world(function(ex, w)
    local harpoon, bm, p, R = require("harpoon"), require("config.bookmarks"), w.picker, w.root
    local list = harpoon:list()
    local function clear() for i = list:length(), 1, -1 do list:remove_at(i) end end
    -- the files the slots name, below the root: harpoon writes a path relative to the working directory, on Windows
    -- an absolute one (plenary cannot take C:\... off C:/...) - the moved ones as harpoon would
    local function slots()
      return vim.tbl_map(function(it) return vim.fs.normalize(vim.fn.fnamemodify(it.value, ":p")):sub(#R + 2) end, list.items)
    end
    local function marks() return vim.tbl_map(function(b) return b.file:sub(#R + 2) .. ":" .. b.line end, bm.list()) end
    local saved = bm.file
    bm.file = w.far .. "/bookmarks.json"
    bm.reload()
    clear()
    local ok, err = pcall(function()
      vim.fn.writefile({ "one", "two" }, R .. "/pinned.txt")
      vim.fn.writefile({ "x" }, R .. "/sub/deep.txt")
      vim.cmd.edit(vim.fn.fnameescape(R .. "/pinned.txt"))
      list:add()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      bm.toggle()
      vim.cmd("bwipeout")
      vim.cmd.edit(vim.fn.fnameescape(R .. "/sub/deep.txt"))
      list:add()
      vim.cmd("bwipeout")
      w.answer = "renamed.txt"
      ex.rename(p, w.at(R .. "/pinned.txt")) -- r: neither file open
      ex.move(p, w.at(R .. "/sub")) -- m of the folder, m on the target
      ex.move(p, w.at(R .. "/other"))
      assert(vim.deep_equal(slots(), { "renamed.txt", "other/sub/deep.txt" }), "the slots: " .. vim.inspect(slots()))
      assert(vim.deep_equal(marks(), { "renamed.txt:2" }), "the bookmark: " .. vim.inspect(marks()))
      list:select(2)
      assert(vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == R .. "/other/sub/deep.txt", "slot 2 opened " .. vim.api.nvim_buf_get_name(0))
      vim.cmd("bwipeout")
      require("oil").open(R) -- renamed by editing the folder's listing, saved
      assert(H.wait(5000, function() return vim.bo.filetype == "oil" and vim.bo.modifiable and H.text(0):find("renamed.txt", 1, true) end),
        "oil did not list the folder: " .. H.text(0))
      for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        if line:find("renamed.txt", 1, true) then vim.api.nvim_buf_set_lines(0, i - 1, i, false, { (line:gsub("renamed%.txt", "oiled.txt")) }) end
      end
      local done = false
      require("oil").save({ confirm = false }, function() done = true end)
      assert(H.wait(5000, function() return done end), "oil did not save")
      assert(exists(R .. "/oiled.txt") and not exists(R .. "/renamed.txt"), "oil did not rename it: " .. vim.inspect(vim.fn.readdir(R)))
      assert(slots()[1] == "oiled.txt", "the slot after oil: " .. vim.inspect(slots()))
      assert(vim.deep_equal(marks(), { "oiled.txt:2" }), "the bookmark after oil: " .. vim.inspect(marks()))
      vim.cmd("bwipeout!")
      vim.fn.delete(R .. "/oiled.txt") -- gone: the slot says so and opens nothing
      list:select(1)
      assert(table.concat(w.notes, " | "):find("gone", 1, true), "no word of it: " .. table.concat(w.notes, " | "))
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        assert(vim.fs.basename(vim.api.nvim_buf_get_name(b)) ~= "oiled.txt", "an empty oiled.txt was opened")
      end
    end)
    clear()
    bm.file = saved
    bm.reload()
    assert(ok, err)
  end)
end)

test("Bookmarks: one of a deleted file stays, listed as gone - Enter opens nothing, next skips it, <C-x> removes it", function()
  with_bookmarks({ ["a.txt"] = { "1", "2", "3" }, ["b.txt"] = { "1", "2", "3" } }, function(root, bm)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    bm.toggle()
    vim.cmd("bwipeout!")
    vim.cmd.edit(vim.fn.fnameescape(root .. "/b.txt"))
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    bm.toggle()
    vim.fn.delete(root .. "/a.txt")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    for _, want in ipairs({ "b.txt:3", "b.txt:3" }) do -- round the ends: a.txt's is skipped
      vim.api.nvim_feedkeys(vim.keycode("<leader>mn"), "mx", false)
      assert(at() == want, "next: " .. at())
    end
    local notes, notify = {}, vim.notify
    vim.notify = function(msg) notes[#notes + 1] = tostring(msg) end
    local ok, err = pcall(function()
      vim.api.nvim_feedkeys(vim.keycode("<leader>ml"), "mx", false)
      local p
      assert(H.wait(3000, function() p = Snacks.picker.get({ source = "bookmarks" })[1]; return p and p.list:count() == 2 end), "no list of two")
      local item = p:items()[1]
      assert(vim.fs.basename(item.file) == "a.txt" and item.gone and item.comment, "a.txt not listed as gone: " .. vim.inspect(item.comment))
      p.list:view(1)
      vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
      assert(table.concat(notes, " | "):find("gone", 1, true), "Enter on it: no word - " .. table.concat(notes, " | "))
      for _, b in ipairs(vim.api.nvim_list_bufs()) do -- this one's: not any a.txt (one of an earlier run, 2026-10-22)
        assert(vim.fs.normalize(vim.api.nvim_buf_get_name(b)) ~= root .. "/a.txt", "an empty a.txt was opened")
      end
      p.list:view(1)
      vim.api.nvim_feedkeys(vim.keycode("<C-x>"), "x", false)
      assert(H.wait(3000, function() return p.list:count() == 1 end), "<C-x> did not remove it")
      assert(vim.deep_equal(bookmarks_kept(bm), { "b.txt:3" }), "kept: " .. vim.inspect(bookmarks_kept(bm)))
    end)
    vim.notify = notify
    assert(ok, err)
  end)
end)

-- ── Recent buffers (config/switcher.lua, 2026-10-22): IntelliJ's Ctrl+Tab ──

-- these files opened one after the other (their buffers by name), all within a second
local function with_recent(names, fn)
  local root, bufs = real_tmp(), {}
  for _, name in ipairs(names) do
    vim.fn.writefile({ name }, root .. "/" .. name)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. name))
    bufs[name] = vim.api.nvim_get_current_buf()
  end
  local ok, err = pcall(fn, bufs)
  for _, p in ipairs(Snacks.picker.get({ source = "recent_buffers", tab = false })) do pcall(p.close, p) end
  for _, buf in pairs(bufs) do pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

local function recent_picker(want_buf)
  local p
  local ok = H.wait(3000, function()
    p = Snacks.picker.get({ source = "recent_buffers" })[1]
    local item = p and p.list:current()
    return item and (not want_buf or item.buf == want_buf)
  end)
  local item = p and p.list:current()
  assert(ok, "the list is not on the buffer wanted: " .. tostring(item and vim.fs.basename(item.file)))
  return p
end

test("Recent buffers: <leader><Tab> starts on the buffer before this one, Enter goes back to it - the order of use", function()
  with_recent({ "a.txt", "b.txt", "c.txt" }, function(bufs)
    vim.cmd.buffer(bufs["a.txt"]) -- used: b, c, a - before this one: c
    vim.api.nvim_feedkeys(vim.keycode("<leader><Tab>"), "mx", false)
    local p = recent_picker(bufs["c.txt"])
    local order = {}
    for _, item in ipairs(p:items()) do order[#order + 1] = vim.fs.basename(item.file) end
    assert(vim.deep_equal(vim.list_slice(order, 1, 3), { "a.txt", "c.txt", "b.txt" }), "order: " .. table.concat(order, ", "))
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert(H.wait(3000, function() return vim.api.nvim_get_current_buf() == bufs["c.txt"] end), "Enter: " .. at())
  end)
end)

test("Recent buffers: Tab goes further back, Shift+Tab forward again; typing filters", function()
  with_recent({ "a.txt", "b.txt", "c.txt" }, function(bufs)
    vim.api.nvim_feedkeys(vim.keycode("<leader><Tab>"), "mx", false) -- this is c: on b
    local p = recent_picker(bufs["b.txt"])
    vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
    assert(p.list:current().buf == bufs["a.txt"], "Tab: " .. vim.fs.basename(p.list:current().file))
    vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "x", false)
    assert(p.list:current().buf == bufs["b.txt"], "Shift+Tab: " .. vim.fs.basename(p.list:current().file))
    vim.api.nvim_feedkeys(vim.keycode("<Tab><CR>"), "x", false)
    assert(H.wait(3000, function() return vim.api.nvim_get_current_buf() == bufs["a.txt"] end), "Tab, Enter: " .. at())
    vim.api.nvim_feedkeys(vim.keycode("<leader><Tab>"), "mx", false)
    p = recent_picker(bufs["c.txt"])
    -- the picker types into its input once it shows (insert mode, scheduled) - typing, whichever mode it is in
    local typing = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
    vim.api.nvim_feedkeys((typing and "" or "i") .. "b.tx", "x", false)
    -- the box filters on TextChanged, which Neovim sends once it waits for keys again - a test never does
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = p.input.win.buf })
    assert(H.wait(3000, function() local item = p.list:current(); return item and item.buf == bufs["b.txt"] end),
      ("typing b.tx (in mode %s): the pattern %q, on %s"):format(typing and "i" or "n", p.input:get(),
        p.list:current() and vim.fs.basename(p.list:current().file) or "nothing"))
    vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
    assert(H.wait(3000, function() return vim.api.nvim_get_current_buf() == bufs["b.txt"] end), "filtered, Enter: " .. at())
  end)
end)

-- 2026-10-22: after a restart (a session restored) the buffers were in the order of their numbers - IntelliJ keeps the
-- recent files over one; Neovim's own are v:oldfiles, from the ShaDa file
test("Recent buffers: after a restart, those not entered yet come in the order of Neovim's recent files; one entered first", function()
  local root, bufs, saved = real_tmp(), {}, vim.v.oldfiles
  local function order()
    local names = {}
    for _, b in ipairs(require("config.switcher").recent()) do
      local name = vim.fs.basename(vim.api.nvim_buf_get_name(b))
      if bufs[name] == b then names[#names + 1] = name end
    end
    return names
  end
  local ok, err = pcall(function()
    for _, name in ipairs({ "a.txt", "b.txt", "c.txt" }) do -- as a session brings them back: listed, not entered
      vim.fn.writefile({ name }, root .. "/" .. name)
      bufs[name] = vim.fn.bufadd(root .. "/" .. name)
      vim.bo[bufs[name]].buflisted = true
    end
    vim.v.oldfiles = { root .. "/b.txt", root .. "/elsewhere.txt", root .. "/c.txt", root .. "/a.txt" }
    assert(vim.deep_equal(order(), { "b.txt", "c.txt", "a.txt" }), "after a restart: " .. table.concat(order(), ", "))
    vim.cmd.buffer(bufs["a.txt"])
    assert(vim.deep_equal(order(), { "a.txt", "b.txt", "c.txt" }), "one entered: " .. table.concat(order(), ", "))
  end)
  vim.v.oldfiles = saved
  for _, b in pairs(bufs) do pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  vim.fn.delete(root, "rf")
  assert(ok, err)
end)

-- ── Script slots (config/slots.lua, 2026-10-22): !1 .. !9 run a script on the cursor's item and the marked ones ──
local function native(path) return vim.fn.has("win32") == 1 and (path:gsub("/", "\\")) or path end

-- the slots of a test: its own folder of scripts (the repo's helpers, slots/lib, with them)
local function with_slots(scripts, fn)
  local slots = require("config.slots")
  local dir = real_tmp()
  for name, lines in pairs(scripts) do vim.fn.writefile(lines, dir .. "/" .. name) end
  local dirs = slots.dirs
  slots.dirs = function() return { dir } end
  local ok, err = pcall(fn, dir)
  slots.dirs = dirs
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end

-- a slot run as !n starts it; done, its output (the program's lines, as it printed them: the window wraps them)
local function run_slot(p, n)
  local tasks = require("devsuite.tasks")
  local before = tasks.state.last
  p:action("gk_slot_" .. n)
  local task = tasks.state.last
  assert(task and task ~= before and task.name:find("slot " .. n, 1, true), "slot " .. n .. " did not run")
  assert(H.wait(20000, function() return task:is_complete() end), "slot " .. n .. " did not end: " .. H.task_out(task))
  vim.wait(300)
  local run = tasks.state.runs[task.id]
  return task, table.concat(require("devsuite.errors").lines(run and run.lines or {}), "\n")
end

test("Slots: files named 1-<name> .. 9-<name> are slots 1-9 - yours before the config's; backups, folders, others are not", function()
  local slots = require("config.slots")
  local mine, shared = real_tmp(), real_tmp()
  vim.fn.writefile({ "# mine" }, mine .. "/1-mine.py")
  vim.fn.writefile({ "echo three" }, mine .. "/3.sh")
  vim.fn.writefile({ "# shared one" }, shared .. "/1-shared.py")
  vim.fn.writefile({ "#!/usr/bin/env python3", "", "# Prints the two" }, shared .. "/2-two.py")
  vim.fn.writefile({ "x" }, shared .. "/2-two.py~")
  vim.fn.writefile({ "x" }, shared .. "/10-ten.py")
  vim.fn.writefile({ "x" }, shared .. "/x-1.py")
  vim.fn.mkdir(shared .. "/4-folder", "p")
  vim.fn.mkdir(shared .. "/lib", "p")
  local dirs = slots.dirs
  slots.dirs = function() return { mine, shared } end
  local ok, err = pcall(function()
    local l = slots.list()
    assert(l[1] and l[1].name == "1-mine.py", "slot 1: yours wins - " .. vim.inspect(l[1]))
    assert(l[2] and l[2].name == "2-two.py" and l[2].desc == "Prints the two", "slot 2: " .. vim.inspect(l[2]))
    assert(l[3] and l[3].name == "3.sh", "slot 3 (a name without one): " .. vim.inspect(l[3]))
    assert(l[4] == nil and l[10] == nil, "a folder or 10 is a slot: " .. vim.inspect(l))
    local n = 0
    for _ in pairs(l) do n = n + 1 end
    assert(n == 3, "slots: " .. vim.inspect(vim.tbl_keys(l)))
  end)
  slots.dirs = dirs
  vim.fn.delete(mine, "rf")
  vim.fn.delete(shared, "rf")
  assert(ok, err)
end)

test("Slots: a run gets the marked items as arguments and in $GK_MARKED, the cursor's in $GK_CURSOR, runs in the root - names with spaces, ä, & and [ ]", function()
  local slots = require("config.slots")
  local WIN = vim.fn.has("win32") == 1
  local root = "/work/R&D ä [x]"
  local ctx = { cursor = root .. "/a b.txt", marked = { root .. "/c & d.txt", root .. "/[e] ä.txt" }, dir = root, root = root }
  local spec, list = slots.spec({ slot = 2, path = "/s/2-x.py", name = "2-x.py" }, ctx)
  assert(spec, list)
  assert(spec.cmd[2] == "/s/2-x.py" and spec.cmd[3] == native(ctx.marked[1]) and spec.cmd[4] == native(ctx.marked[2]) and #spec.cmd == 4,
    "argv: " .. vim.inspect(spec.cmd))
  assert(spec.cmd[1] == require("devsuite.util").system_python(), "python: " .. spec.cmd[1])
  assert(vim.deep_equal(vim.fn.readfile(list), { native(ctx.marked[1]), native(ctx.marked[2]) }), "GK_MARKED: " .. vim.inspect(vim.fn.readfile(list)))
  local env = spec.env
  assert(env.GK_MARKED == native(list) and env.GK_CURSOR == native(ctx.cursor) and env.GK_ROOT == native(root) and env.GK_DIR == native(root)
    and env.GK_SLOT == "2", "env: " .. vim.inspect(env))
  assert(env.PYTHONPATH:find(native(slots.lib()), 1, true) == 1 and env.GK_LIB == native(slots.lib()), "helpers: " .. vim.inspect(env))
  assert(env.PYTHONDONTWRITEBYTECODE == "1", "gk.py's bytecode would go into the config (slots/lib/__pycache__)")
  assert(spec.cwd == root and spec.focus == false and spec.key == "slot:2", vim.inspect(spec))
  vim.fn.delete(list)
  -- nothing marked: no arguments, an empty list
  spec, list = slots.spec({ slot = 1, path = "/s/1-x.py", name = "1-x.py" }, { cursor = root, marked = {}, dir = root, root = root })
  assert(#spec.cmd == 2 and vim.deep_equal(vim.fn.readfile(list), {}), "nothing marked: " .. vim.inspect(spec.cmd))
  vim.fn.delete(list)
  -- how each kind runs here
  local sh, why = slots.argv("/s/3-x.sh")
  if WIN then assert(not sh and why:find("Linux", 1, true), "a .sh on Windows: " .. vim.inspect(sh)) else assert(sh and sh[1] == "bash", vim.inspect(sh)) end
  local ps = slots.argv("C:/s/4-x.ps1")
  if WIN then assert(ps and ps[1] == "powershell" and ps[#ps] == "C:/s/4-x.ps1", vim.inspect(ps)) end
  local none, because = slots.argv("/s/5-x.txt")
  assert(not none and because:find(".py", 1, true), "a .txt: " .. vim.inspect(none))
end)

test("Slots: !1 runs slot 1 (info) on the marked items - their paths, sizes and permissions; on the cursor's item when none is marked", function()
  local slots = require("config.slots")
  local dirs = slots.dirs
  slots.dirs = function() return { vim.fn.stdpath("config") .. "/slots" } end -- the repo's slot 1, not yours
  local ok, err = pcall(with_explorer, { "docs/a b ä & [x].txt", "docs/plain.txt", "src/" }, function(p, root, x)
    for _, n in ipairs({ "1", "2", "9", "!" }) do
      local m = vim.api.nvim_buf_call(p.list.win.buf, function() return vim.fn.maparg("!" .. n, "n", false, true) end)
      local want = n == "!" and "gk_slots" or ("gk_slot_" .. n)
      assert(m.desc == want, "!" .. n .. " runs " .. tostring(m.desc) .. ", not " .. want)
    end
    p.list:select(x.item("docs/plain.txt")) -- marked in this order
    p.list:select(x.item("docs/a b ä & [x].txt"))
    local task, out = run_slot(p, 1)
    assert(task.status == "SUCCESS", "slot 1: " .. task.status .. "\n" .. out)
    local lines = vim.split(out, "\n", { trimempty = true })
    local mode = vim.fn.has("win32") == 1 and "-rw-rw-rw-" or "-rw-"
    local seen = {}
    for _, rel in ipairs({ "docs/plain.txt", "docs/a b ä & [x].txt" }) do
      local path = native(root .. "/" .. rel)
      for i, line in ipairs(lines) do
        if vim.endswith(line, path) then
          seen[#seen + 1] = i
          assert(line:find(mode, 1, true) == 1 and line:find(" " .. (#rel + 1) .. " ", 1, true) and line:find(" file ", 1, true),
            "the line of " .. rel .. ": " .. line)
        end
      end
    end
    assert(#seen == 2 and seen[1] < seen[2], "both marked items, in their order: " .. out)
    p.list:set_selected() -- nothing marked: the item under the cursor
    x.on("src")
    task, out = run_slot(p, 1)
    local folder
    for _, line in ipairs(vim.split(out, "\n", { trimempty = true })) do
      if vim.endswith(line, " dir  " .. native(root .. "/src")) then folder = line end
    end
    assert(folder and folder:sub(1, 1) == "d", "the cursor's folder: " .. out)
  end, { open = { "docs" } })
  slots.dirs = dirs
  assert(ok, err)
end)

test("Slots: a script asks - Yes/No, a text with its default, a choice - Neovim's dialogs answer it; it notifies and opens a file", function()
  local script = {
    "import gk",
    'print("CONFIRM", gk.confirm("Delete 2 files in R&D?"))',
    'print("ASK", gk.ask("New name:", default="notes.md"))',
    'print("CHOOSE", gk.choose("Color:", ["red", "green::dark"]))',
    'gk.notify("done & dusted")',
    'gk.open("docs/plain.txt", 1)',
  }
  local select, input, notify = vim.ui.select, vim.ui.input, vim.notify
  local asked, notes, answer = {}, {}, true
  vim.ui.select = function(items, opts, cb)
    asked[#asked + 1] = opts.prompt
    if not answer then return cb(nil, nil) end -- closed without an answer
    if items[2] == "Yes" then return cb("Yes", 2) end
    return cb(items[#items], #items)
  end
  vim.ui.input = function(opts, cb)
    asked[#asked + 1] = opts.prompt
    cb(answer and (opts.default .. "!") or nil)
  end
  vim.notify = function(msg, level, o) notes[#notes + 1] = tostring(msg); return notify(msg, level, o) end
  local ok, err = pcall(with_slots, { ["1-ask.py"] = script }, function()
    with_explorer({ "docs/plain.txt" }, function(p, root, x)
      local task, out = run_slot(p, 1)
      assert(task.status == "SUCCESS", task.status .. "\n" .. out)
      assert(vim.deep_equal(asked, { "Delete 2 files in R&D?", "New name:", "Color:" }), "asked: " .. vim.inspect(asked))
      for _, want in ipairs({ "CONFIRM True", "ASK notes.md!", "CHOOSE green::dark" }) do
        assert(out:find(want, 1, true), want .. " - the script printed:\n" .. out)
      end
      assert(H.wait(3000, function() return vim.tbl_contains(notes, "done & dusted") end), "no notification: " .. vim.inspect(notes))
      assert(H.wait(3000, function() return vim.fs.normalize(vim.api.nvim_buf_get_name(0)) == root .. "/docs/plain.txt" end),
        "not opened: " .. vim.api.nvim_buf_get_name(0))
      -- the dialogs closed without an answer
      answer, asked = false, {}
      task, out = run_slot(p, 1)
      for _, want in ipairs({ "CONFIRM False", "ASK None", "CHOOSE None" }) do
        assert(out:find(want, 1, true), want .. " - the script printed:\n" .. out)
      end
    end)
  end)
  vim.ui.select, vim.ui.input, vim.notify = select, input, notify
  assert(ok, err)
end)

test("Slots: the real Yes/No dialog (snacks) pops up over the tree, and its Yes reaches the script", function()
  -- as in a session: snacks puts its select in at VimEnter, after a test script has started (until then it is
  -- Neovim's own, a numbered list on the command line)
  local select = vim.ui.select
  vim.ui.select = Snacks.picker.select
  local ok, err = pcall(with_slots, { ["1-go.py"] = { "import gk", 'print("CONFIRM", gk.confirm("Go on?"))' } }, function()
    with_explorer({ "a.txt" }, function(p)
      local tasks = require("devsuite.tasks")
      p:action("gk_slot_1")
      local task = tasks.state.last
      local dialog
      assert(H.wait(15000, function()
        dialog = Snacks.picker.get({ source = "select" })[1]
        return dialog and not dialog:is_active() and dialog.list:count() == 2
      end), "no Yes/No dialog")
      assert(dialog.title:find("Go on?", 1, true) or (dialog.opts.prompt or ""):find("Go on?", 1, true), "the dialog asks " .. tostring(dialog.title))
      dialog.list:view(2) -- Yes (No is first: Enter alone says no)
      assert(dialog:current().item == "Yes", "on " .. tostring(dialog:current().text))
      dialog:action("confirm")
      assert(H.wait(15000, function() return task:is_complete() end), "the script did not end: " .. H.task_out(task))
      local run = tasks.state.runs[task.id]
      local out = table.concat(require("devsuite.errors").lines(run and run.lines or {}), "\n")
      assert(out:find("CONFIRM True", 1, true), "the script printed:\n" .. out)
    end)
  end)
  vim.ui.select = select
  for _, picker in ipairs(Snacks.picker.get({ source = "select" })) do picker:close() end
  vim.cmd("stopinsert")
  assert(ok, err)
end)

test("Slots: !! lists the slots and runs the one picked; a missing slot says where to put one; a failure shows its exit; the tree shows what a run made", function()
  local scripts = {
    ["2-make.py"] = { "# Makes made.txt in the cursor's folder", "import os", 'open(os.path.join(os.environ["GK_DIR"], "made.txt"), "w").close()' },
    ["3-fail.py"] = { "import sys", 'print("boom")', "sys.exit(3)" },
  }
  local select, notify = vim.ui.select, vim.notify
  local offered, notes = nil, {}
  vim.ui.select = function(items, opts, cb)
    offered = vim.tbl_map(opts.format_item, items)
    for _, item in ipairs(items) do
      if item.slot == 2 then return cb(item) end
    end
    cb(nil)
  end
  vim.notify = function(msg, level, o) notes[#notes + 1] = tostring(msg); return notify(msg, level, o) end
  local ok, err = pcall(with_slots, scripts, function()
    with_explorer({ "docs/plain.txt" }, function(p, root, x)
      local tasks = require("devsuite.tasks")
      local before = tasks.state.last
      x.on("docs/plain.txt")
      p:action("gk_slots") -- !!
      assert(vim.deep_equal(offered, { "!2  2-make.py  - Makes made.txt in the cursor's folder", "!3  3-fail.py" }), "!! offered: " .. vim.inspect(offered))
      local task = tasks.state.last
      assert(task ~= before and task.name:find("slot 2", 1, true), "!! did not run slot 2")
      assert(H.wait(20000, function() return task:is_complete() end), "slot 2 did not end")
      assert(H.wait(5000, function() return pcall(x.item, "docs/made.txt") end), "the tree does not show made.txt: " .. x.found())
      p:action("gk_slot_5")
      assert(H.wait(2000, function()
        for _, n in ipairs(notes) do if n:find("No script in slot 5", 1, true) then return true end end
      end), "a missing slot: " .. vim.inspect(notes))
      local failed, out = run_slot(p, 3)
      assert(failed.status == "FAILURE" and failed.exit_code == 3 and out:find("boom", 1, true), failed.status .. " " .. tostring(failed.exit_code) .. ": " .. out)
    end, { open = { "docs" } })
  end)
  vim.ui.select, vim.notify = select, notify
  assert(ok, err)
end)

test("Slots: the bash helper (gk.sh) on Linux, the PowerShell one (gk.ps1) on Windows - the context and the dialogs", function()
  local WIN = vim.fn.has("win32") == 1
  local name, script
  if WIN then
    name, script = "1-ask.ps1", {
      ". (Join-Path $env:GK_LIB 'gk.ps1')",
      "$files = Get-GkMarked",
      "'MARKED ' + $files.Count + ' ' + ($files -join '|')",
      "'CURSOR ' + $env:GK_CURSOR",
      "'CONFIRM ' + (Confirm-Gk 'Go on?')",
      "'ASK ' + (Read-Gk 'Name:' 'x.md')",
      "'CHOOSE ' + (Select-Gk 'Pick:' @('a', 'b & c'))",
    }
  else
    name, script = "1-ask.sh", {
      'source "$GK_LIB/gk.sh"',
      "mapfile -t files < <(gk_marked)",
      'echo "MARKED ${#files[@]} $(IFS="|"; echo "${files[*]}")"',
      'echo "CURSOR $GK_CURSOR"',
      'if gk_confirm "Go on?"; then echo "CONFIRM True"; else echo "CONFIRM False"; fi',
      'echo "ASK $(gk_ask "Name:" "x.md")"',
      'echo "CHOOSE $(gk_choose "Pick:" a "b & c")"',
    }
  end
  local select, input = vim.ui.select, vim.ui.input
  vim.ui.select = function(items, _, cb) cb(items[#items], #items) end -- Yes; the last option
  vim.ui.input = function(opts, cb) cb(opts.default .. "!") end
  local ok, err = pcall(with_slots, { [name] = script }, function()
    with_explorer({ "a b.txt", "c & d.txt" }, function(p, root, x)
      p.list:select(x.item("c & d.txt"))
      x.on("a b.txt")
      local task, out = run_slot(p, 1)
      assert(task.status == "SUCCESS", task.status .. "\n" .. out)
      for _, want in ipairs({ "MARKED 1 " .. native(root .. "/c & d.txt"), "CURSOR " .. native(root .. "/a b.txt"), "CONFIRM True", "ASK x.md!", "CHOOSE b & c" }) do
        assert(out:find(want, 1, true), want .. " - the script printed:\n" .. out)
      end
    end)
  end)
  vim.ui.select, vim.ui.input = select, input
  assert(ok, err)
end)

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
    -- a file opened in the editor some other way: the tree opens its folder and goes to it. snacks follows from a
    -- scheduled callback that does nothing when the explorer has the focus by then: what the open above scheduled
    -- runs first (2026-10-22: on a busy Windows the tree did not follow, 10 s did not help)
    vim.wait(300)
    vim.api.nvim_set_current_win(editor)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/notes/todo.txt"))
    -- the folder listed first, as when the explorer opens: 3 s were too few on a busy Windows (2026-10-22)
    assert(H.wait(OPEN_MS, function() return p:current() and p:current().file == root .. "/notes/todo.txt" end),
      ("the tree did not follow: on %s - explorer focused %s, closed %s, current window the editor %s, buffer %s"):format(
        tostring(p:current() and x.rel(p:current().file)), tostring(p:is_focused()), tostring(p.closed),
        tostring(vim.api.nvim_get_current_win() == editor), vim.fs.basename(vim.api.nvim_buf_get_name(0))))
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

-- 2026-10-22: where the trash refuses - gio on /tmp ("Trashing on system internal mounts is not supported", Kali) - d
-- deleted nothing and said so as an error; now it asks to delete for good. The refusal is a stand-in here (the same
-- message), so it runs everywhere.
test("Explorer: d where the trash refuses asks to delete for good - yes deletes, no keeps it (no error)", function()
  local util, actions = Snacks.picker.util, require("snacks.explorer.actions")
  local saved = { confirm = util.confirm, trash = actions.trash }
  local asked, answers = {}, {}
  util.confirm = function(prompt, yes)
    asked[#asked + 1] = prompt
    if table.remove(answers, 1) ~= false then yes() end
  end
  actions.trash = function(path)
    return false, ("- cmd: `gio trash %s`\n- error: gio: file://%s: Trashing on system internal mounts is not supported"):format(path, path)
  end
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, ...) if (level or 0) >= vim.log.levels.ERROR then notes[#notes + 1] = tostring(msg) end return notify(msg, level, ...) end
  local ok, err = pcall(with_explorer, { "a.txt", "b.txt" }, function(p, root, x)
    x.on("a.txt")
    answers = { true, true }
    p:action("explorer_del")
    assert(H.wait(3000, function() return not vim.uv.fs_stat(root .. "/a.txt") end), "a.txt not deleted - asked: " .. vim.inspect(asked))
    assert(asked[2] and asked[2]:find("a.txt cannot go to the trash here (Trashing on system internal mounts is not supported)", 1, true)
      and asked[2]:find("delete for good?", 1, true), "asked: " .. vim.inspect(asked))
    x.on("b.txt")
    asked, answers = {}, { true, false } -- delete: yes; for good: no
    p:action("explorer_del")
    vim.wait(500)
    assert(#asked == 2 and vim.uv.fs_stat(root .. "/b.txt"), "b.txt: asked " .. vim.inspect(asked))
    assert(#notes == 0, "an error: " .. table.concat(notes, " | "))
  end)
  util.confirm, actions.trash, vim.notify = saved.confirm, saved.trash, notify
  assert(ok, err)
end)

-- 2026-10-22: a link deleted is the link - never the folder it points to, nor what is in it (Linux)
test("Explorer: d on a link to a folder deletes the link; the folder and its files stay", function()
  if vim.fn.has("win32") == 1 then H.skip("links need extra rights on Windows") end
  local util, config = Snacks.picker.util, Snacks.explorer.config
  local saved = { confirm = util.confirm, trash = config.trash }
  util.confirm = function(_, yes) yes() end
  config.trash = false -- gone for good: no trash for temp folders everywhere
  local ok, err = pcall(with_explorer, { "target/file.txt", "target/sub/deep.txt" }, function(p, root, x)
    assert(vim.uv.fs_symlink("target", root .. "/link"))
    require("snacks.explorer.tree"):refresh(root)
    require("snacks.explorer.actions").update(p, {})
    assert(H.wait(5000, function() return pcall(x.item, "link") end), "no link in the tree: " .. x.found())
    x.on("link")
    p:action("explorer_del")
    assert(H.wait(3000, function() return not vim.uv.fs_lstat(root .. "/link") end), "the link is still there")
    assert(vim.uv.fs_stat(root .. "/target/file.txt") and vim.uv.fs_stat(root .. "/target/sub/deep.txt"), "the folder's files went with the link")
  end)
  util.confirm, config.trash = saved.confirm, saved.trash
  assert(ok, err)
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
    -- the last change: eight deleted (after the undo, gitsigns' hunks are that one alone - it updates them a moment later)
    assert(H.wait(5000, function() return kinds() == "delete" end), "hunks after <leader>gr: " .. kinds())
    key("]c").callback()
    assert(H.wait(3000, function() return line() == 7 end), "]c to the deleted line: line " .. line())
    key("<leader>gp").callback()
    -- gitsigns shows it a moment later (async); on a busy Windows 5 s were too few once (2026-10-22)
    local preview = H.wait(10000, function() return has_float("eight") end)
    local floats = {} -- what there was instead, for the failure message
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        floats[#floats + 1] = H.text(vim.api.nvim_win_get_buf(win)):gsub("%s+", " "):sub(1, 80)
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
    assert(preview, ("<leader>gp showed no change with eight - floats: %s, hunks: %s, line %d"):format(vim.inspect(floats), kinds(), line()))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    key("<leader>gb").callback()
    local blame = H.wait(10000, function() return has_float("gk") end)
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

-- ── More of the day (2026-10-21): keys that clash, git views, pickers, Trouble, undo, terminals, big files ─────────
-- flash's s and mini.surround's sa / sd / sr: typed within timeoutlen (500 ms), s then d deleted a surrounding instead
-- of jumping to a d. A one-key map that begins longer ones waits for them - and the longer one wins when typed fast.
test("Keys: a one-key map is not the start of others (flash's s and the surround keys)", function()
  require("lazy").load({ plugins = { "flash.nvim", "mini.surround", "mini.ai", "oil.nvim" } })
  local clashes = {}
  for _, mode in ipairs({ "n", "x", "o" }) do
    local maps, singles = vim.api.nvim_get_keymap(mode), {}
    for _, m in ipairs(maps) do
      if m.lhs:match("^%g$") then singles[m.lhs] = m end
    end
    for _, m in ipairs(maps) do
      local first, single = m.lhs:sub(1, 1), singles[m.lhs:sub(1, 1)]
      -- mini.ai's a / i and its an / il ... are one family on purpose
      local family = single and (single.desc or ""):find("textobject") and (m.desc or ""):find("textobject")
      if #m.lhs > 1 and single and not family then
        clashes[#clashes + 1] = ("%s %s (%s) begins with %s (%s)"):format(mode, m.lhs, m.desc or "", first, single.desc or "")
      end
    end
  end
  assert(#clashes == 0, table.concat(clashes, "; "))
end)

test("Editing: gsaiw\" surrounds a word, gsr\"' changes the quotes, gsd' takes them away (mini.surround on gs)", function()
  require("lazy").load({ plugins = { "mini.surround" } })
  vim.cmd("enew!")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "say hello now" })
  local function line() return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] end
  local ok, err = pcall(function()
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    vim.api.nvim_feedkeys('gsaiw"', "x", false)
    assert(line() == 'say "hello" now', "gsaiw\": " .. line())
    vim.api.nvim_feedkeys([[gsr"']], "x", false)
    assert(line() == "say 'hello' now", "gsr\"': " .. line())
    vim.api.nvim_feedkeys("gsd'", "x", false)
    assert(line() == "say hello now", "gsd': " .. line())
  end)
  vim.cmd("bwipeout!")
  assert(ok, err)
end)

-- A temp repository with a committed a.txt changed afterwards; fn(root) runs in it as the working directory
local function in_repo(fn)
  if vim.fn.executable("git") == 0 then H.skip("git not installed") end
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local root = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local function git(...) vim.fn.system(vim.list_extend({ "git", "-C", root, "-c", "user.name=gk", "-c", "user.email=gk@example.invalid" }, { ... })) end
  vim.fn.writefile({ "one", "two", "three" }, root .. "/a.txt")
  git("init", "-q")
  git("add", ".")
  git("commit", "-q", "-m", "init")
  vim.fn.writefile({ "one", "TWO", "three" }, root .. "/a.txt")
  local before = vim.fn.getcwd()
  vim.fn.chdir(root)
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, opts)
    if (level or 0) >= vim.log.levels.ERROR then notes[#notes + 1] = tostring(msg) end
    return notify(msg, level, opts)
  end
  local ok, err = pcall(fn, root, notes)
  vim.notify = notify
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
  assert(ok, err)
end

local function has_ft(ft)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then return vim.api.nvim_win_get_buf(win) end
  end
end

-- 2026-10-22: <leader>gv / <leader>gh are codediff's - VS Code's diff (config/gitdiff.lua)
test("Git: <leader>gv reviews the changes with codediff (VS Code's diff, colored), live as files change; <leader>gh a file's history", function()
  -- looked at without loading codediff: loading it would download the library (no downloads in a test)
  if not require("config.gitdiff").library() then H.skip("codediff's library is not downloaded here (:CodeDiff install)") end
  in_repo(function(root, notes)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    local tabs = #vim.api.nvim_list_tabpages()
    vim.api.nvim_feedkeys(vim.keycode("<leader>gv"), "x", false)
    -- 20 s: on a busy Windows the tab took longer than 10 once (2026-10-23; git status, its file watcher starting)
    assert(H.wait(20000, function() return #vim.api.nvim_list_tabpages() == tabs + 1 and has_ft("codediff-explorer") end), "<leader>gv: no codediff tab")
    local explorer = has_ft("codediff-explorer")
    assert(H.wait(10000, function() return H.text(explorer):find("a.txt", 1, true) end), "the explorer: " .. H.text(explorer))
    -- the changed file side by side, its changes colored (codediff's highlights)
    local ns = vim.api.nvim_get_namespaces()["codediff-highlight"]
    assert(H.wait(5000, function()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == root .. "/a.txt" and #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}) > 0 then return true end
      end
    end), "a.txt is not shown with its changes colored")
    -- live: a file an agent writes now shows up
    vim.fn.writefile({ "new" }, root .. "/b.txt")
    assert(H.wait(10000, function() return H.text(explorer):find("b.txt", 1, true) end), "b.txt did not show up: " .. H.text(explorer))
    vim.cmd("tabclose")
    assert(H.wait(5000, function() return #vim.api.nvim_list_tabpages() == tabs end), "the review did not close")
    vim.api.nvim_feedkeys(vim.keycode("<leader>gh"), "x", false)
    assert(H.wait(20000, function() return has_ft("codediff-history") end), "<leader>gh: no file history")
    vim.cmd("tabclose")
    assert(H.wait(5000, function() return #vim.api.nvim_list_tabpages() == tabs end), "the file history did not close")
    assert(#notes == 0, "errors: " .. table.concat(notes, " | "))
  end)
end)

-- 2026-10-22: codediff downloads its library when it loads, and fails with an error when that download does (a 403 on
-- the work laptop once): <leader>gv tries once a session, quietly, then Diffview
test("Git: without codediff's library (its download refused) <leader>gv / <leader>gh are Diffview's - one word, no error", function()
  package.loaded["config.gitdiff"] = nil -- a session that has not tried yet
  local gitdiff = require("config.gitdiff")
  gitdiff.library = function() return false end
  local lazy = require("lazy")
  local load, tries = lazy.load, 0
  lazy.load = function(opts) -- loading codediff: its download fails, as codediff and lazy.nvim report it
    if vim.tbl_contains(opts.plugins or {}, "codediff.nvim") then
      tries = tries + 1
      vim.notify("Failed to download library: curl: (22) The requested URL returned error: 403", vim.log.levels.ERROR)
      error("libvscode-diff not found and automatic installation failed")
    end
    return load(opts)
  end
  local infos = {}
  local ok, err = pcall(in_repo, function(root, notes)
    local notify = vim.notify
    vim.notify = function(msg, level, opts)
      if level == vim.log.levels.INFO then infos[#infos + 1] = tostring(msg) end
      return notify(msg, level, opts)
    end
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    local tabs = #vim.api.nvim_list_tabpages()
    for _ = 1, 2 do
      vim.api.nvim_feedkeys(vim.keycode("<leader>gv"), "x", false)
      assert(H.wait(10000, function() return #vim.api.nvim_list_tabpages() == tabs + 1 and has_ft("DiffviewFiles") end), "<leader>gv: no Diffview tab")
      vim.cmd("DiffviewClose")
      assert(H.wait(5000, function() return #vim.api.nvim_list_tabpages() == tabs end), "Diffview did not close")
    end
    vim.api.nvim_feedkeys(vim.keycode("<leader>gh"), "x", false)
    assert(H.wait(10000, function() return has_ft("DiffviewFileHistory") end), "<leader>gh: no file history")
    vim.cmd("DiffviewClose")
    assert(H.wait(5000, function() return #vim.api.nvim_list_tabpages() == tabs end), "the file history did not close")
    vim.notify = notify
    assert(#notes == 0, "errors: " .. table.concat(notes, " | "))
  end)
  lazy.load = load
  package.loaded["config.gitdiff"] = nil
  assert(ok, err)
  assert(tries == 1, "download tries: " .. tries)
  local words = vim.tbl_filter(function(m) return m:find("Diffview instead", 1, true) end, infos)
  assert(#words == 1, "the word: " .. vim.inspect(infos))
  assert(require("diffview.config").get_config().enhanced_diff_hl == true, "Diffview's old side is not red")
end)

-- 2026-10-22: the agent's diff (integrations/agent_ide.lua): the friend's "color coded, state of the art"
test("Diffs: changed words colored (inline:char), histogram, linematch; the agent's diff - the old side red, the new green, words stronger", function()
  local o = vim.o.diffopt
  for _, want in ipairs({ "inline:char", "algorithm:histogram", "linematch:60", "indent-heuristic" }) do
    assert(o:find(want, 1, true), want .. " missing: " .. o)
  end
  assert(not o:find("linematch:40", 1, true), "linematch twice: " .. o)
  local ide = require("integrations.agent_ide")
  local file = H.file("colors.py", { "def f(x):", "    return x + 1", "", "print(f(2))" })
  local tabs = #vim.api.nvim_list_tabpages()
  local ok, err = pcall(function()
    -- no agent to tell: a channel that is none (0 would be every channel)
    ide.call("openDiff", { filePath = file, newContent = "def f(x):\n    return x * 2\n\nprint(f(2))\nprint('more')\n" }, function() end, 999999)
    local view = assert(ide.views[file], "no diff")
    local left, right = vim.fn.bufwinid(view.orig), vim.fn.bufwinid(view.prop)
    assert(vim.wo[left].winhighlight == ide.WINHL.old and vim.wo[right].winhighlight == ide.WINHL.new,
      "sides: " .. vim.wo[left].winhighlight .. " / " .. vim.wo[right].winhighlight)
    assert(vim.wo[left].fillchars:find("diff:╱", 1, true), "fillers: " .. vim.wo[left].fillchars)
    local function rgb(group)
      local c = vim.api.nvim_get_hl(0, { name = group, link = false }).bg
      assert(c, group .. " has no background")
      return math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256
    end
    local r1, g1 = rgb("GreyKnightDiffTextOld")
    local r2, g2 = rgb("GreyKnightDiffTextNew")
    assert(r1 > g1 and g2 > r2, ("old not red / new not green: %d,%d / %d,%d"):format(r1, g1, r2, g2))
    local function sum(group) local r, g, b = rgb(group); return r + g + b end
    assert(sum("GreyKnightDiffTextOld") > sum("GreyKnightDiffChangedOld") and sum("GreyKnightDiffTextNew") > sum("GreyKnightDiffChangedNew"),
      "the changed words are not stronger than their line")
    -- Neovim marks the changed word of line 2, not the whole line (inline:char): x * 2 against x + 1
    vim.api.nvim_win_call(right, function()
      local line = vim.fn.getline(2)
      local star = line:find("*", 1, true)
      local name = function(col) return vim.fn.synIDattr(vim.fn.diff_hlID(2, col), "name") end
      assert(name(star) == "DiffText" and name(1) == "DiffChange", ("line 2: %s at the *, %s at its start"):format(name(star), name(1)))
      assert(vim.fn.synIDattr(vim.fn.diff_hlID(5, 1), "name") == "DiffAdd", "line 5 is not an added line")
    end)
    ide.reject(view)
  end)
  vim.wait(100)
  while #vim.api.nvim_list_tabpages() > tabs do vim.cmd("tabclose") end
  assert(ok, err)
end)

test("Git: <leader>gg opens Lazygit over the editor, q leaves it and closes the window", function()
  if vim.fn.executable("lazygit") == 0 then H.skip("lazygit not installed") end
  in_repo(function(root, notes)
    vim.cmd.edit(vim.fn.fnameescape(root .. "/a.txt"))
    -- a state of its own: a first start greets with a popup (Enter closes it), and yours stays as it is
    local state = vim.env.XDG_STATE_HOME
    vim.env.XDG_STATE_HOME = vim.fn.tempname()
    vim.api.nvim_feedkeys(vim.keycode("<leader>gg"), "x", false)
    vim.env.XDG_STATE_HOME = state
    local term
    local function terminals()
      local seen = {}
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype == "terminal" then seen[#seen + 1] = vim.api.nvim_buf_get_name(b) .. ": " .. H.text(b):gsub("%s+", " "):sub(1, 300) end
      end
      return table.concat(seen, " ## ")
    end
    assert(H.wait(10000, function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].buftype == "terminal" and H.text(b):find("Status", 1, true) then term = b; return true end
      end
    end), "<leader>gg: no Lazygit - terminals: " .. terminals())
    local job = vim.b[term].terminal_job_id
    if H.wait(3000, function() return H.text(term):find("Confirm: <enter>", 1, true) end) then vim.fn.chansend(job, "\r") end
    assert(H.wait(10000, function() return H.text(term):find("a.txt", 1, true) end), "Lazygit does not list a.txt - terminals: " .. terminals())
    for _ = 1, 3 do -- q leaves Lazygit (a popup first, if one is up)
      if vim.fn.jobwait({ job }, 0)[1] ~= -1 then break end
      vim.fn.chansend(job, "q")
      H.wait(2000, function() return vim.fn.jobwait({ job }, 0)[1] ~= -1 end)
    end
    assert(vim.fn.jobwait({ job }, 0)[1] ~= -1, "Lazygit did not quit on q")
    assert(H.wait(3000, function() return #vim.fn.win_findbuf(term) == 0 end), "Lazygit's window stayed")
    assert(#notes == 0, "errors: " .. table.concat(notes, " | "))
  end)
end)

test("Pickers: every <leader>f picker and <leader>/ opens, lists and closes without an error", function()
  vim.cmd.edit(vim.fn.fnameescape(vim.fn.stdpath("config") .. "/README.md")) -- a file open: buffers, grep_buffers
  -- a history of its own - a test run reads none of the user's (tests/harness.lua): a recent file, a command, a
  -- diagnostic; each picker has something to list (an empty one waited out its 5 s, 2026-10-22)
  local oldfiles, ns = vim.v.oldfiles, vim.api.nvim_create_namespace("gk-test-pickers")
  vim.v.oldfiles = { vim.fn.stdpath("config") .. "/CHEATSHEET.md" }
  vim.fn.histadd("cmd", "echo 'gk pickers'")
  -- on a file under the working directory: <leader>fd lists only those (stdpath("config") is a link to it)
  local marked_file = vim.fn.getcwd() .. "/CHEATSHEET.md"
  local had_marked = vim.fn.bufexists(marked_file) == 1
  local marked = vim.fn.bufadd(marked_file)
  vim.fn.bufload(marked)
  vim.diagnostic.set(ns, marked, { { lnum = 0, col = 0, message = "gk picker mark", severity = vim.diagnostic.severity.WARN } })
  local live = { ["<leader>fg"] = true, ["<leader>/"] = true } -- the greps list what is typed: nothing yet
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, opts)
    if (level or 0) >= vim.log.levels.ERROR then notes[#notes + 1] = tostring(msg) end
    return notify(msg, level, opts)
  end
  local counts = {}
  local ok, err = pcall(function()
    for _, lhs in ipairs({ "<leader>ff", "<leader>fg", "<leader>fb", "<leader>fh", "<leader>fr", "<leader>fc", "<leader>fd",
      "<leader>fk", "<leader>f:", "<leader>/" }) do
      for _, p in ipairs(Snacks.picker.get()) do p:close() end
      vim.api.nvim_feedkeys(vim.keycode(lhs), "x", false)
      H.wait(5000, function()
        local p = Snacks.picker.get()[1]
        return p and not p:is_active() and (live[lhs] or p.list:count() > 0)
      end)
      local p = Snacks.picker.get()[1] -- an empty one said "No results" and closed
      counts[lhs] = p and p.list:count() or 0
      if p then p:close() end
      vim.cmd("stopinsert")
    end
  end)
  vim.notify = notify
  vim.v.oldfiles = oldfiles
  vim.diagnostic.reset(ns)
  if not had_marked then pcall(vim.api.nvim_buf_delete, marked, { force = true }) end
  for _, p in ipairs(Snacks.picker.get()) do p:close() end
  vim.cmd("silent! bwipeout " .. vim.fn.fnameescape(vim.fn.stdpath("config") .. "/README.md"))
  assert(ok, err)
  assert(#notes == 0, "errors: " .. table.concat(notes, " | "))
  for _, lhs in ipairs({ "<leader>ff", "<leader>fb", "<leader>fh", "<leader>fr", "<leader>fc", "<leader>fd", "<leader>fk", "<leader>f:" }) do
    assert(counts[lhs] > 0, lhs .. " listed nothing: " .. vim.inspect(counts))
  end
end)

test("Trouble: <leader>xx lists the diagnostics, <leader>xq the quickfix list - each closes again", function()
  local file = H.file("trouble.txt", { "one", "two" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local ns = vim.api.nvim_create_namespace("gk-test-trouble")
  vim.diagnostic.set(ns, 0, { { lnum = 1, col = 0, message = "gk trouble mark", severity = vim.diagnostic.severity.ERROR } })
  local function trouble()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].filetype == "trouble" then return H.text(b) end
    end
  end
  local ok, err = pcall(function()
    vim.api.nvim_feedkeys(vim.keycode("<leader>xx"), "x", false)
    assert(H.wait(5000, function() return (trouble() or ""):find("gk trouble mark", 1, true) end), "<leader>xx: " .. tostring(trouble()))
    vim.api.nvim_feedkeys(vim.keycode("<leader>xx"), "x", false)
    assert(H.wait(3000, function() return trouble() == nil end), "<leader>xx did not close it")
    vim.fn.setqflist({ { filename = file, lnum = 2, text = "gk quickfix item" } }, "r")
    vim.api.nvim_feedkeys(vim.keycode("<leader>xq"), "x", false)
    assert(H.wait(5000, function() return (trouble() or ""):find("gk quickfix item", 1, true) end), "<leader>xq: " .. tostring(trouble()))
    vim.api.nvim_feedkeys(vim.keycode("<leader>xq"), "x", false)
    assert(H.wait(3000, function() return trouble() == nil end), "<leader>xq did not close it")
  end)
  vim.diagnostic.reset(ns)
  vim.fn.setqflist({}, "r")
  pcall(vim.cmd, "Trouble close")
  vim.cmd("silent! bwipeout! " .. vim.fn.fnameescape(file))
  assert(ok, err)
end)

-- 2026-10-22: Neovim's :Cfilter (an optional package) - a quickfix list kept or thinned by regex
test("Quickfix: :Cfilter /re/ keeps the entries whose file or text matches, :Cfilter! drops them; :Lfilter too", function()
  assert(vim.fn.exists(":Cfilter") == 2 and vim.fn.exists(":Lfilter") == 2, "no :Cfilter / :Lfilter")
  local dir = vim.fn.tempname()
  local items = {
    { filename = dir .. "/a.sh", lnum = 1, text = "one" },
    { filename = dir .. "/b.py", lnum = 2, text = "two" },
    { filename = dir .. "/c.sh", lnum = 3, text = "three" },
  }
  local function names()
    return table.concat(vim.tbl_map(function(i) return vim.fs.basename(vim.api.nvim_buf_get_name(i.bufnr)) end, vim.fn.getqflist()), " ")
  end
  local ok, err = pcall(function()
    vim.fn.setqflist({}, "r", { items = items })
    vim.cmd([[Cfilter /\.sh$/]]) -- the file
    assert(names() == "a.sh c.sh", "kept: " .. names())
    vim.fn.setqflist({}, "r", { items = items })
    vim.cmd([[Cfilter! /^t/]]) -- the text: two, three go
    assert(names() == "a.sh", "dropped: " .. names())
  end)
  vim.fn.setqflist({}, "f") -- the lists of the test gone
  for _, i in ipairs(items) do pcall(vim.cmd, "silent! bwipeout! " .. vim.fn.fnameescape(i.filename)) end
  assert(ok, err)
end)

test("Editing: undo outlives the buffer - :w, wipe it, open the file again, u brings the old text back", function()
  assert(vim.o.undofile, "'undofile' is off")
  local file = H.file("undo.txt", { "first" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "second" })
  vim.cmd("silent write")
  vim.cmd("bwipeout")
  vim.cmd.edit(vim.fn.fnameescape(file))
  vim.cmd("silent undo")
  local line = vim.api.nvim_get_current_line()
  vim.cmd("bwipeout!")
  assert(line == "first", "after u: " .. line)
end)

test("Explorer: <C-t> drops a terminal in the folder under the cursor", function()
  with_explorer({ "proj/sub/x.txt", "other/" }, function(p, root, x)
    x.on("proj/sub")
    p:action("terminal")
    local term
    assert(H.wait(5000, function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].filetype == "snacks_terminal" and vim.b[b].terminal_job_id then term = b; return true end
      end
    end), "<C-t>: no terminal")
    local job = vim.b[term].terminal_job_id
    vim.fn.chansend(job, (vim.fn.has("win32") == 1 and "cd" or "pwd") .. "\r")
    local want = root .. "/proj/sub"
    local function shown() return (table.concat(vim.api.nvim_buf_get_lines(term, 0, -1, false), ""):gsub("\\", "/")) end
    local ok = H.wait(8000, function() return shown():find(want, 1, true) ~= nil end)
    local text = shown()
    pcall(vim.fn.jobstop, job)
    pcall(vim.api.nvim_buf_delete, term, { force = true })
    assert(ok, "the terminal is not in " .. want .. ": " .. text)
  end, { open = { "proj" } })
end)

test("Markdown: a .md file wraps, checks the spelling (English), conceals for render-markdown", function()
  local file = H.file("notes.md", { "# Title", "", "Some txet with a typo." })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local ok, err = pcall(function()
    assert(vim.wo.wrap and vim.wo.spell and vim.bo.spelllang == "en_us" and vim.wo.conceallevel == 2,
      ("wrap %s spell %s spelllang %s conceallevel %d"):format(vim.wo.wrap, vim.wo.spell, vim.bo.spelllang, vim.wo.conceallevel))
    assert(vim.fn.spellbadword("txet")[1] == "txet" and vim.fn.spellbadword("text")[1] == "", "the spell check does not work")
  end)
  vim.cmd("bwipeout!")
  assert(ok, err)
end)

test("Big files: one over 1.5 MB opens as bigfile - no treesitter, no language server", function()
  local file = vim.fn.tempname() .. ".py"
  local lines, line = {}, "x = 1  # " .. ("y"):rep(70)
  for i = 1, 22000 do lines[i] = line end -- about 1.7 MB
  vim.fn.writefile(lines, file)
  vim.cmd.edit(vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()
  local ok, err = pcall(function()
    assert(H.wait(3000, function() return vim.bo[buf].filetype == "bigfile" end), "filetype " .. vim.bo[buf].filetype)
    vim.wait(1000)
    assert(#vim.lsp.get_clients({ bufnr = buf }) == 0, "a language server attached to the big file")
    assert(not vim.treesitter.highlighter.active[buf], "treesitter highlights the big file")
  end)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  vim.fn.delete(file)
  assert(ok, err)
end)

-- ── Round 6 (2026-10-21): folders you cannot read, oil, formatting, sessions with %, small daily things ───────────
-- The Windows error log: "Failed to watch ...\Anwendungsdaten: EPERM" - legacy junctions in the home folder that no one
-- may list; on Linux another user's folder. Opened in the tree it stays empty, and watching it was an error each time.
test("Explorer: a folder it cannot read opens empty with a word why - no error, the rest of the tree works", function()
  with_explorer({ "locked/secret.txt", "open/a.txt" }, function(p, root, x)
    local locked = root .. "/locked"
    local function lock(on)
      if vim.fn.has("win32") == 1 then
        vim.fn.system({ "icacls", locked, on and "/deny" or "/remove:d", vim.env.USERNAME .. (on and ":(RD)" or "") })
      else
        vim.uv.fs_chmod(locked, on and 0 or 493) -- 493: 0755
      end
    end
    lock(true)
    local notes, notify = {}, vim.notify
    vim.notify = function(msg, level, opts)
      notes[#notes + 1] = { level = level or 0, msg = tostring(msg) }
      return notify(msg, level, opts)
    end
    local ok, err = pcall(function()
      if vim.uv.fs_scandir(locked) then H.skip("this user reads every folder (root?)") end
      x.on("locked")
      p:action("confirm") -- open it
      H.wait(3000, function() return not p:is_active() end)
      x.on("open")
      p:action("confirm")
      x.on("open/a.txt") -- the rest of the tree works
      local errors, why = {}, false
      for _, n in ipairs(notes) do
        if n.level >= vim.log.levels.ERROR then errors[#errors + 1] = n.msg end
        if n.msg:find("locked", 1, true) and n.msg:find("cannot be read", 1, true) then why = true end
      end
      assert(#errors == 0, "errors: " .. table.concat(errors, " | "))
      assert(why, "no word why locked/ is empty: " .. vim.inspect(notes))
    end)
    vim.notify = notify
    lock(false) -- so it can be deleted
    assert(ok, err)
  end)
end)

test("Oil: - shows the file's folder; renamed, added and deleted lines are done on disk by :w - the open buffer goes along", function()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  for _, name in ipairs({ "a.txt", "keep.txt", "gone.txt" }) do vim.fn.writefile({ name }, dir .. "/" .. name) end
  vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.txt"))
  local ok, err = pcall(function()
    vim.api.nvim_feedkeys("-", "x", false)
    -- the listing, and oil done with it: it shows the names before the buffer can be edited (a busy Windows: "Buffer is
    -- not 'modifiable'" for the lines set right after)
    assert(H.wait(5000, function() return vim.bo.filetype == "oil" and vim.bo.modifiable and H.text(0):find("keep.txt", 1, true) end),
      "-: no listing to edit: " .. H.text(0))
    local buf, out = vim.api.nvim_get_current_buf(), {}
    for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if l:find("gone.txt", 1, true) then -- deleted
      elseif l:find("a.txt", 1, true) then out[#out + 1] = (l:gsub("a%.txt", "renamed.txt"))
      else out[#out + 1] = l end
    end
    out[#out + 1] = "new.txt"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
    local done = false
    require("oil").save({ confirm = false }, function() done = true end)
    assert(H.wait(5000, function() return done end), "oil did not save")
    local function there(name) return vim.uv.fs_stat(dir .. "/" .. name) ~= nil end
    assert(there("renamed.txt") and not there("a.txt") and there("new.txt") and not there("gone.txt") and there("keep.txt"),
      vim.inspect(vim.fn.readdir(dir)))
    assert(vim.fn.bufexists(dir .. "/renamed.txt") == 1, "the open buffer did not go along with the rename")
  end)
  pcall(function() require("oil").close() end)
  vim.cmd("silent! %bwipeout!")
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- The Kali error log: "Formatter failed. See :ConformInfo" on saving bash scripts that did not parse yet (4 times)
test("Formatting: :w formats a shell script (shfmt); an unfinished one is saved as it is, without an error popup", function()
  if vim.fn.executable("shfmt") == 0 then H.skip("shfmt not installed (Mason)") end
  -- on several lines: shfmt keeps a one-line if on one line
  local file = H.file("fmt.sh", { "#!/bin/bash", "if [ 1 ];then", "echo hi", "fi" })
  vim.cmd.edit(vim.fn.fnameescape(file))
  local notes, notify = {}, vim.notify
  vim.notify = function(msg, level, opts)
    if (level or 0) >= vim.log.levels.ERROR then notes[#notes + 1] = tostring(msg) end
    return notify(msg, level, opts)
  end
  local ok, err = pcall(function()
    vim.cmd("silent write")
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    -- indented as the buffer is set up: spaces (expandtab, shiftwidth) - conform hands them to shfmt as -i
    local indent = vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t"
    assert(vim.deep_equal(lines, { "#!/bin/bash", "if [ 1 ]; then", indent .. "echo hi", "fi" }), "not formatted: " .. vim.inspect(lines))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "#!/bin/bash", "if [ 1 ]; then", "echo hi" }) -- no fi yet
    vim.cmd("silent write")
    vim.wait(300) -- conform's message comes a moment after the write (scheduled)
    assert(vim.fn.readfile(file)[3] == "echo hi", "the unfinished script was not saved as it is: " .. vim.inspect(vim.fn.readfile(file)))
    assert(#notes == 0, "an error popup on saving an unfinished script: " .. table.concat(notes, " | "))
  end)
  vim.notify = notify
  vim.cmd("bwipeout!")
  assert(ok, err)
end)

-- 2026-10-21: a project's own prettier, as npm puts it there - node_modules/.bin/prettier (Windows: npm's .cmd) and
-- the package; the stand-in puts spaces around "=" and notes its arguments. On Windows cmd.exe ran the .cmd and cut a
-- quoted path at its first space: in a folder with a space the project's prettier never ran
local NPM_CMD = { "@ECHO off", "GOTO start", ":find_dp0", "SET dp0=%~dp0", "EXIT /b", ":start", "SETLOCAL", "CALL :find_dp0", "",
  'IF EXIST "%dp0%\\node.exe" (', '  SET "_prog=%dp0%\\node.exe"', ") ELSE (", '  SET "_prog=node"',
  "  SET PATHEXT=%PATHEXT:;.JS;=;%", ")", "",
  'endLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%_prog%"  "%dp0%\\..\\prettier\\bin\\prettier.cjs" %*' }
local function prettier_project(root)
  vim.fn.mkdir(root .. "/node_modules/.bin", "p")
  vim.fn.mkdir(root .. "/node_modules/prettier/bin", "p")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({ '{ "name": "demo", "private": true }' }, root .. "/package.json")
  vim.fn.writefile({ '{ "name": "prettier", "version": "3.0.0", "bin": "./bin/prettier.cjs" }' }, root .. "/node_modules/prettier/package.json")
  local bin = root .. "/node_modules/prettier/bin/prettier.cjs"
  vim.fn.writefile({
    "#!/usr/bin/env node",
    "const fs = require('fs'), path = require('path');",
    "fs.appendFileSync(path.join(__dirname, 'args.log'), JSON.stringify(process.argv.slice(2)) + '\\n');",
    "let input = ''; process.stdin.setEncoding('utf8');",
    "process.stdin.on('data', d => input += d);",
    "process.stdin.on('end', () => process.stdout.write(input.replace(/\\s*=\\s*/g, ' = ')));",
  }, bin)
  if vim.fn.has("win32") == 1 then
    vim.fn.writefile(NPM_CMD, root .. "/node_modules/.bin/prettier.cmd")
  else
    vim.fn.setfperm(bin, "rwxr-xr-x")
    assert(vim.uv.fs_symlink("../prettier/bin/prettier.cjs", root .. "/node_modules/.bin/prettier"))
  end
  return root .. "/src/a.ts", root .. "/node_modules/prettier/bin/args.log"
end

test("Formatting: a project's own prettier formats TypeScript on :w and <leader>fm - in folders named with spaces, ä, #, % and &, and R&D", function()
  if vim.fn.executable("node") == 0 then H.skip("node not installed") end
  local tmp = vim.fs.normalize(assert(vim.uv.fs_realpath((function() local t = vim.fn.tempname(); vim.fn.mkdir(t, "p"); return t end)())))
  local ok, err = pcall(function()
    -- R&D: an & in a path without spaces is not quoted - on Windows cmd.exe (npm's .cmd, Volta's node.exe) split it there
    for _, name in ipairs({ "plain", "my app ä #1 100% & co", "R&D" }) do
      local file, args_log = prettier_project(tmp .. "/" .. name)
      vim.fn.writefile({ "const x={a:1}", "export const y=x" }, file)
      vim.cmd.edit({ args = { file }, magic = { file = false } })
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd("silent write")
      local want = { "const x = {a:1}", "export const y = x" }
      assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), want), name .. ": not formatted on :w - " .. vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
      assert(vim.deep_equal(vim.fn.readfile(file), want), name .. ": not saved formatted")
      local args = vim.json.decode(vim.fn.readfile(args_log)[1])
      assert(args[1] == "--stdin-filepath" and vim.fs.normalize(args[2]) == vim.fs.normalize(file), name .. ": prettier was told " .. vim.inspect(args))
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "let z=1" })
      vim.api.nvim_feedkeys(vim.keycode("<leader>fm"), "x", false)
      assert(H.wait(5000, function() return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "let z = 1" end), name .. ": <leader>fm did not format - " .. vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
      vim.cmd("silent! bwipeout!")
    end
  end)
  vim.cmd("silent! bwipeout!")
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

-- 2026-10-21: on Windows ruff is Mason's ruff.cmd, and cmd.exe split the file's path at an & and dropped a ^: a file in
-- R&D was not formatted
test("Formatting: ruff formats Python on :w in folders named R&D and a^b", function()
  if vim.fn.executable("ruff") == 0 then H.skip("ruff not installed (Mason)") end
  local tmp = vim.fs.normalize(assert(vim.uv.fs_realpath((function() local t = vim.fn.tempname(); vim.fn.mkdir(t, "p"); return t end)())))
  local ok, err = pcall(function()
    for _, name in ipairs({ "R&D", "a^b" }) do
      vim.fn.mkdir(tmp .. "/" .. name, "p")
      local file = tmp .. "/" .. name .. "/a.py"
      vim.fn.writefile({ "x=1", "def f( a ):", "  return a" }, file)
      vim.cmd.edit({ args = { file }, magic = { file = false } })
      vim.cmd("silent write")
      local got = vim.fn.readfile(file)
      assert(vim.deep_equal(got, { "x = 1", "", "", "def f(a):", "    return a" }), name .. ": " .. vim.inspect(got))
      vim.cmd("silent! bwipeout!")
    end
  end)
  vim.cmd("silent! bwipeout!")
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

-- 2026-10-21: Windows - a .cmd shim (npm's, Mason's) runs as what it starts; cmd.exe never sees the arguments
test("Windows: .cmd shims run as what they start - the program, or node and the script; one with arguments of its own stays", function()
  local util = require("devsuite.util")
  local argv = { "some-tool", "--stdin-filepath", "R&D/a b.ts" }
  if vim.fn.has("win32") == 0 then
    assert(util.unshim(argv) == argv, "Linux: argv changed")
    return
  end
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath((function() local t = vim.fn.tempname(); vim.fn.mkdir(t, "p"); return t end)())))
  local ok, err = pcall(function()
    vim.fn.mkdir(dir .. "/bin", "p")
    vim.fn.mkdir(dir .. "/pkg/tool", "p")
    vim.fn.writefile({ "" }, dir .. "/pkg/tool/tool.exe")
    vim.fn.writefile({ "" }, dir .. "/pkg/tool/cli") -- a node script without an extension (angular's bin/ngserver)
    vim.fn.writefile({ "" }, dir .. "/pkg/tool/cli.mjs")
    local shims = {
      exe = { "@ECHO off", 'endLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%dp0%\\..\\pkg\\tool\\tool.exe" %*' },
      node = vim.list_extend(vim.list_slice(NPM_CMD, 1, #NPM_CMD - 1), { 'endLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%_prog%"  "%dp0%\\..\\pkg\\tool\\cli" %*' }),
      old = { '@IF EXIST "%~dp0\\node.exe" (', '  "%~dp0\\node.exe"  "%~dp0\\..\\pkg\\tool\\cli.mjs" %*', ") ELSE (", "  node  \"%~dp0\\..\\pkg\\tool\\cli.mjs\" %*", ")" },
      chain = { "@ECHO off", 'endLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%dp0%\\exe.cmd" %*' },
      own_args = { "@ECHO off", '"C:/Python/python" -m tool.adapter %*' },
      unknown = { "@ECHO off", "echo hi" },
    }
    for name, lines in pairs(shims) do vim.fn.writefile(lines, dir .. "/bin/" .. name .. ".cmd") end
    local function run(name) return util.unshim({ dir .. "/bin/" .. name .. ".cmd", "--stdin-filepath", "R&D/a b.ts" }) end
    local function same(a, b) return vim.fs.normalize(a):lower() == vim.fs.normalize(b):lower() end
    local function is_node(p) return type(p) == "string" and vim.fn.fnamemodify(p, ":t"):lower() == "node.exe" and vim.uv.fs_stat(p) ~= nil end
    local r = run("exe")
    assert(same(r[1], dir .. "/pkg/tool/tool.exe") and r[2] == "--stdin-filepath" and r[3] == "R&D/a b.ts" and #r == 3, "exe: " .. vim.inspect(r))
    r = run("node")
    assert(is_node(r[1]) and same(r[2], dir .. "/pkg/tool/cli") and r[4] == "R&D/a b.ts", "node: " .. vim.inspect(r))
    -- behind Volta's node.exe the real one: Volta's launcher handed the arguments to cmd.exe
    local path_node = vim.fn.exepath("node")
    if path_node:lower():find("volta", 1, true) and vim.fn.executable("volta") == 1 then
      assert(not same(r[1], path_node), "Volta's launcher, not the node behind it: " .. r[1])
    end
    r = run("old")
    assert(is_node(r[1]) and same(r[2], dir .. "/pkg/tool/cli.mjs"), "old npm shim: " .. vim.inspect(r))
    r = run("chain")
    assert(same(r[1], dir .. "/pkg/tool/tool.exe") and #r == 3, "a shim of a shim: " .. vim.inspect(r))
    for _, name in ipairs({ "own_args", "unknown" }) do
      r = run(name)
      assert(same(r[1], dir .. "/bin/" .. name .. ".cmd") and #r == 3, name .. " was changed: " .. vim.inspect(r))
    end
    assert(util.unshim({ "git", "status" })[1] == "git", "an .exe on the PATH was changed")
  end)
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

-- 2026-10-21: folds come from treesitter - a function, a block, a markdown section; files open unfolded
test("Folding: zc folds a function's block, a markdown section; files open unfolded, zR opens all", function()
  local cases = {
    { "f.py", { "def outer(x):", "    if x:", "        return 1", "    return 2", "", "print(outer(1))" }, 2, { 2, 3 } },
    { "f.lua", { "local function f(x)", "  if x then", "    return 1", "  end", "  return 2", "end" }, 2, { 2, 4 } },
    { "f.ts", { "function f(x: number): number {", "  if (x) {", "    return 1;", "  }", "  return 2;", "}" }, 2, { 2, 4 } },
    { "f.md", { "# One", "", "text one", "", "## Two", "", "text two", "", "# Three", "", "last" }, 2, { 1, 7 } },
  }
  local ok, err = pcall(function()
    for _, c in ipairs(cases) do
      vim.cmd.edit(vim.fn.fnameescape(H.file(c[1], c[2])))
      pcall(function() vim.treesitter.get_parser(0):parse(true) end)
      for l = 1, #c[2] do assert(vim.fn.foldclosed(l) == -1, c[1] .. ": opened with line " .. l .. " folded") end
      -- treesitter's folds come a moment after the file (computed in the background; the pi: E490 right away)
      assert(H.wait(5000, function() return vim.fn.foldlevel(c[3]) > 0 end), c[1] .. ": no fold at line " .. c[3])
      vim.api.nvim_win_set_cursor(0, { c[3], 0 })
      vim.cmd("normal! zc")
      assert(vim.fn.foldclosed(c[3]) == c[4][1] and vim.fn.foldclosedend(c[3]) == c[4][2],
        ("%s: zc on line %d folded %d..%d, not %d..%d"):format(c[1], c[3], vim.fn.foldclosed(c[3]), vim.fn.foldclosedend(c[3]), c[4][1], c[4][2]))
      vim.cmd("normal! zR")
      assert(vim.fn.foldclosed(c[3]) == -1, c[1] .. ": zR left a fold closed")
      vim.cmd("silent! bwipeout!")
    end
  end)
  vim.cmd("silent! bwipeout!")
  assert(ok, err)
end)

-- 2026-10-21: gx opens what is under the cursor with the system's handler - the URL of a markdown link (on its text),
-- a bare URL without the period after it, one in a code comment
test("gx: opens a markdown link's URL from its text, a bare URL without the period after it, one in a comment", function()
  local opened, ui_open = {}, vim.ui.open
  vim.ui.open = function(target) opened[#opened + 1] = target; return nil, nil end
  local ok, err = pcall(function()
    local function gx_on(file, lines, lnum, at)
      vim.cmd.edit(vim.fn.fnameescape(H.file(file, lines)))
      pcall(function() vim.treesitter.get_parser(0):parse(true) end)
      opened = {}
      local col = lines[lnum]:find(at, 1, true)
      vim.api.nvim_win_set_cursor(0, { lnum, col })
      vim.api.nvim_feedkeys("gx", "x", false)
      vim.cmd("silent! bwipeout!")
      return opened
    end
    local md = { "# Docs", "", "see [the docs](https://example.org/a) and https://example.org/bare." }
    local got = gx_on("t.md", md, 3, "the docs")
    assert(vim.deep_equal(got, { "https://example.org/a" }), "markdown link text: " .. vim.inspect(got))
    got = gx_on("t.md", md, 3, "example.org/bare")
    assert(vim.deep_equal(got, { "https://example.org/bare" }), "bare URL: " .. vim.inspect(got))
    got = gx_on("t.lua", { "-- see https://example.org/lua-docs." }, 1, "example.org")
    assert(vim.deep_equal(got, { "https://example.org/lua-docs" }), "in a comment: " .. vim.inspect(got))
  end)
  vim.ui.open = ui_open
  vim.cmd("silent! bwipeout!")
  assert(ok, err)
end)

-- persisted named the session file after the folder with % for every separator, and read every % back as / - the
-- folder "100% done" became "100/ done", no such folder, so :Persisted clean deleted its session
test("Session: :Persisted clean keeps the session of a folder with a % in its name", function()
  local persisted, config = require("persisted"), require("persisted.config")
  local saved_dir = config.save_dir
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp .. "/sessions", "p")
  vim.fn.mkdir(tmp .. "/100% done", "p")
  config.save_dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp .. "/sessions"))) .. "/"
  local project = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp .. "/100% done")))
  local before = vim.fn.getcwd()
  local ok, err = pcall(function()
    vim.fn.chdir(project)
    persisted.save({ force = true })
    local session = persisted.current()
    assert(vim.fn.filereadable(session) == 1, "no session file: " .. session)
    assert(persisted.session_info(session).dir == vim.fs.normalize(project), "read back as " .. persisted.session_info(session).dir)
    persisted.clean({ confirm = false })
    vim.wait(300)
    assert(vim.fn.filereadable(session) == 1, ":Persisted clean deleted the session of " .. project)
  end)
  config.save_dir = saved_dir
  vim.fn.chdir(before)
  vim.fn.delete(tmp, "rf")
  assert(ok, err)
end)

test("Search & replace: <leader>sw opens grug-far with the word under the cursor as the search", function()
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello target_word_gk world" })
  vim.api.nvim_win_set_cursor(0, { 1, 9 })
  local ok, err = pcall(function()
    vim.api.nvim_feedkeys(vim.keycode("<leader>sw"), "x", false)
    assert(H.wait(5000, function() return vim.bo.filetype == "grug-far" end), "<leader>sw: no grug-far")
    assert(H.wait(3000, function() return H.text(0):find("target_word_gk", 1, true) end), "the search is not the word: " .. H.text(0))
  end)
  pcall(function() require("grug-far").kill_instance(0) end)
  vim.cmd("silent! %bwipeout!")
  assert(ok, err)
end)

-- harpoon found a pinned file's buffer by bufnr(), a pattern: "notes [draft] #1.txt" is also "notes d #1.txt"
test("Harpoon: a file named with [ ], # and spaces - pinned, and its slot opens it, not a file its name matches as a pattern", function()
  local harpoon = require("harpoon")
  harpoon.sync = function() end -- this test process never writes your real harpoon lists
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local dir = vim.fs.normalize(assert(vim.uv.fs_realpath(tmp)))
  local real, decoy = dir .. "/notes [draft] #1.txt", dir .. "/notes d #1.txt"
  vim.fn.writefile({ "real" }, real)
  vim.fn.writefile({ "decoy" }, decoy)
  local before = vim.fn.getcwd()
  -- the names as they are (on Windows fnameescape() leaves [ ] alone, and :edit took the real one as a pattern)
  local function open(path) vim.cmd.edit({ args = { path }, magic = { file = false } }) end
  local ok, err = pcall(function()
    open(decoy)
    open(real)
    -- then into their folder, as the explorer's . does: a list of its own (lists are per working directory), and
    -- the buffers' names become relative - only then did harpoon's pattern name the decoy on Linux too
    vim.fn.chdir(dir)
    vim.api.nvim_feedkeys(vim.keycode("<leader>ha"), "x", false)
    assert(harpoon:list():length() == 1, "not pinned: " .. vim.inspect(harpoon:list().items))
    assert(harpoon:list().items[1].value:find("[draft]", 1, true), "pinned: " .. harpoon:list().items[1].value)
    open(decoy)
    vim.api.nvim_feedkeys(vim.keycode("<leader>1"), "x", false)
    local shown = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
    assert(shown == real, "<leader>1 opened " .. shown)
  end)
  vim.cmd("silent! %bwipeout!")
  vim.fn.chdir(before)
  vim.fn.delete(dir, "rf")
  assert(ok, err)
end)

test("Editing: gcc comments a line out in the file's language and back in", function()
  vim.cmd("enew!")
  vim.bo.filetype = "python"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x = 1" })
  vim.api.nvim_feedkeys("gcc", "x", false)
  local commented = vim.api.nvim_get_current_line()
  vim.api.nvim_feedkeys("gcc", "x", false)
  local back = vim.api.nvim_get_current_line()
  vim.cmd("bwipeout!")
  assert(commented == "# x = 1" and back == "x = 1", commented .. " / " .. back)
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
-- [e]: on Windows fnameescape() left [ ] alone, and :edit took "notes [draft].md" as a pattern - "notes d.md" (2026-10-21)
test("Markdown: links to files with spaces, umlauts and [ ] - <my notes.md>, my%20notes.md, Gr%C3%BC%C3%9Fe.md, <notes [draft].md> - are followed", function()
  local md = require("config.mdlinks")
  local links = md.links({ '[a](<my notes.md>) [b](my%20notes.md#teil-zwei "t") [c](Gr%C3%BC%C3%9Fe.md) [d](https://x.org/a%20b) [e](<notes [draft].md>)' })
  local targets = vim.tbl_map(function(l) return l.target end, links)
  assert(vim.deep_equal(targets, { "my notes.md", "my notes.md#teil-zwei", "Grüße.md", "https://x.org/a%20b", "notes [draft].md" }), vim.inspect(targets))
  local dir = vim.fs.normalize(vim.fn.resolve(vim.fn.tempname()))
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ "[a](<my notes.md>) [b](my%20notes.md#teil-zwei) [c](Gr%C3%BC%C3%9Fe.md) [e](<notes [draft].md>)" }, dir .. "/index.md")
  vim.fn.writefile({ "# Notes", "", "## Teil zwei", "x" }, dir .. "/my notes.md")
  vim.fn.writefile({ "# Grüße" }, dir .. "/Grüße.md")
  vim.fn.writefile({ "# Draft" }, dir .. "/notes [draft].md")
  vim.fn.writefile({ "# Decoy" }, dir .. "/notes d.md") -- what [draft] matches as a pattern
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
    follow("[e]", "notes [draft].md", 1)
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
-- G3-DEVELOPMENT.md too: a key it names must exist (2026-10-19). The guide is a file per topic in docs/ (2026-10-23)
local GUIDE = vim.fn.glob(ROOT .. "/docs/*.md", false, true)
local function guide_text()
  local parts = {}
  for _, path in ipairs(GUIDE) do parts[#parts + 1] = table.concat(vim.fn.readfile(path), "\n") end
  return table.concat(parts, "\n")
end
local DOCS = read("CHEATSHEET.md") .. "\n" .. guide_text() .. "\n" .. read("README.md") .. "\n" .. read("G3-DEVELOPMENT.md")

-- 2026-10-23: the guide split into a file per topic - none of them out of reach
test("Docs: the guide's topics - each file in docs/ in its index, in the README and in <leader>gd", function()
  assert(#GUIDE >= 9, "docs/: " .. vim.inspect(GUIDE))
  local index, readme = read("docs/README.md"), read("README.md")
  local select, offered = vim.ui.select, nil
  vim.ui.select = function(items, _, cb) offered = items; cb(nil) end
  local ok, err = pcall(vim.api.nvim_feedkeys, " gd", "x", false)
  vim.ui.select = select
  assert(ok, err)
  local missing = {}
  for _, path in ipairs(GUIDE) do
    local file = vim.fn.fnamemodify(path, ":t")
    if file ~= "README.md" then
      if not index:find("(" .. file .. ")", 1, true) then missing[#missing + 1] = "docs/README.md: " .. file end
      if not readme:find("(docs/" .. file .. ")", 1, true) then missing[#missing + 1] = "README.md: " .. file end
    end
    if not vim.tbl_contains(offered or {}, "docs/" .. file) then missing[#missing + 1] = "<leader>gd: " .. file end
  end
  assert(#missing == 0, table.concat(missing, ", "))
  assert(vim.fn.filereadable(ROOT .. "/USAGE.md") == 0, "USAGE.md is back")
end)

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
  local known = { ["<leader>a"] = 1, ["<leader>f"] = 1, ["<leader>g"] = 1, ["<leader>m"] = 1, ["<leader>r"] = 1, ["<leader>t"] = 1,
    ["<leader>x"] = 1, ["<leader>ca"] = 1, ["<leader>rn"] = 1, ["<leader>D"] = 1, ["<leader>t1/t2/t3"] = 1,
    -- gitsigns' keys: in files of a git repository (the Git test checks them there); <leader>gu: in a codediff review
    ["<leader>gs"] = 1, ["<leader>gr"] = 1, ["<leader>gp"] = 1, ["<leader>gb"] = 1, ["<leader>gu"] = 1 }
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
  for _, doc in ipairs(vim.list_extend(vim.fn.glob(ROOT .. "/*.md", false, true), vim.deepcopy(GUIDE))) do
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
