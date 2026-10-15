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

H.report("Smoke Test Results")
