-- Grey Knight smoke tests: config, plugins, parsers, tools. Run all suites with tests/run.sh
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/harness.lua")
local test = H.test

-- T1: Config loads
test("Config loads without errors", function()
  assert(vim.g.mapleader == " ", "leader not space")
end)

-- T2: All plugins registered
test("38 plugins registered", function()
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
end)

-- T5: Treesitter parsers
test("Markdown parser available", function()
  local ok = pcall(vim.treesitter.language.add, "markdown")
  assert(ok, "markdown parser missing")
end)

test("Python parser available", function()
  local ok = pcall(vim.treesitter.language.add, "python")
  assert(ok, "python parser missing")
end)

test("Lua parser available", function()
  local ok = pcall(vim.treesitter.language.add, "lua")
  assert(ok, "lua parser missing")
end)

test("Bash parser available", function()
  local ok = pcall(vim.treesitter.language.add, "bash")
  assert(ok, "bash parser missing")
end)

test("TypeScript parser available", function()
  local ok = pcall(vim.treesitter.language.add, "typescript")
  assert(ok, "typescript parser missing")
end)

-- T6: Core plugins loadable
test("blink.cmp loads", function()
  assert(pcall(require, "blink.cmp"), "blink.cmp failed to load")
end)

test("snacks loads", function()
  assert(pcall(require, "snacks"), "snacks failed to load")
end)

test("qwen binary available", function()
  local env = vim.loop.os_environ()
  local q = env.QWEN_BIN or "/home/nix0/.local/bin/qwen"
  assert(vim.fn.executable(q) == 1, "qwen not found at " .. q)
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
  local root = vim.fn.resolve(vim.fn.tempname())
  vim.fn.mkdir(root .. "/a/b", "p")
  vim.fn.chdir(root .. "/a")
  Snacks.explorer()
  local function picker() return Snacks.picker.get({ source = "explorer" })[1] end
  local ok, err = pcall(function()
    assert(H.wait(5000, picker), "explorer did not open")
    local p = picker()
    -- like a user: act once the first listing is there (a cd while snacks still lists shows entries twice,
    -- with its own keys too)
    assert(H.wait(5000, function() return not p:is_active() and p.list:count() > 0 end), "explorer did not list")
    for key, action in pairs({ ["."] = "gk_cd_here", ["<BS>"] = "gk_cd_up", ["-"] = "gk_cd_up" }) do
      local m = vim.api.nvim_buf_call(p.list.win.buf, function() return vim.fn.maparg(key, "n", false, true) end)
      assert(m.desc == action, key .. " runs " .. tostring(m.desc) .. ", not " .. action)
    end
    p:action("gk_cd_up")
    assert(H.wait(3000, function() return not p:is_active() and vim.fn.getcwd() == root and p:cwd() == root end), "cd ..: " .. vim.fn.getcwd())
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
    assert(H.wait(2000, function() return vim.fn.getcwd() == root .. "/a" and p:cwd() == root .. "/a" end), "cd here: " .. vim.fn.getcwd())
  end)
  if picker() then picker():close() end
  vim.fn.chdir(before)
  vim.fn.delete(root, "rf")
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

-- T12: The docs stay in step with the config
local ROOT = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local function read(file) return table.concat(vim.fn.readfile(ROOT .. "/" .. file), "\n") end
local DOCS = read("CHEATSHEET.md") .. "\n" .. read("USAGE.md") .. "\n" .. read("README.md")

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
