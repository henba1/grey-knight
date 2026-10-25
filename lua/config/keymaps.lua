-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Keymaps (non-plugin, global)                               ║
-- ╚══════════════════════════════════════════════════════════════╝
local map = vim.keymap.set

-- ── Which-key group labels ──────────────────────────────────
-- (registered after which-key loads via VeryLazy)
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({
        { "<leader>a",  group = "AI (" .. require("integrations.agent").backend().name .. ")" },
        { "<leader>b",  group = "Buffer" },
        { "<leader>d",  group = "Debug/DAP" },
        { "<leader>f",  group = "Find (Picker)" },
        { "<leader>g",  group = "Git" },
        { "<leader>h",  group = "Harpoon/Hex" },
        { "<leader>l",  group = "LaTeX" },
        { "<leader>m",  group = "Bookmarks" },
        { "<leader>p",  group = "Session" },
        { "<leader>r",  group = "Run/Tasks/REPL" },
        { "<leader>s",  group = "Search & Replace" },
        { "<leader>t",  group = "Terminal/AI agents" },
        { "<leader>u",  group = "UI" },
        { "<leader>x",  group = "Trouble" },
      })
    end
  end,
})

-- ── Terminal mode ─────────────────────────────────────────────
-- A terminal gets every key but these: Ctrl+H/J/K/L go to the next window, Ctrl+arrows resize (below), <Esc><Esc> is
-- normal mode. The shell keeps its own keys - Ctrl+A/E, Alt+B/F, Ctrl+W/U, Ctrl+R ...; for its Ctrl+L (clear) type
-- clear (cls). Ctrl+L went to the shell, so from a terminal the window on the right was Esc Esc, Ctrl+L (2026-10-21).
-- An agent's terminal keeps only the ways out (Esc Esc, Ctrl+H/J/K/L): every other terminal-mode key here goes to the
-- agent there - Ctrl+arrows move through Claude Code's prompt (integrations/agent.lua, M.own_keys; 2026-10-23).
map("t", "<Esc><Esc>", "<C-\\><C-n>",       { desc = "Exit terminal mode" })
map("t", "<C-h>",      "<C-\\><C-n><C-w>h", { desc = "Window left (from term)" })
map("t", "<C-j>",      "<C-\\><C-n><C-w>j", { desc = "Window down (from term)" })
map("t", "<C-k>",      "<C-\\><C-n><C-w>k", { desc = "Window up (from term)" })
map("t", "<C-l>",      "<C-\\><C-n><C-w>l", { desc = "Window right (from term)" })

-- ── Dashboard ────────────────────────────────────────────────
map("n", "<leader>;", "<cmd>lua Snacks.dashboard()<cr>", { desc = "Dashboard" })

-- ── Errors: notification history is <leader>un (snacks) ─────
map("n", "<leader>ue", function() require("config.errorlog").open() end, { desc = "Error log (all sessions)" })
map("n", "<leader>um", "<cmd>messages<cr>", { desc = "Messages (Lua errors of this session)" })

-- ── Save / Quit ──────────────────────────────────────────────
map("n", "<leader>w", "<cmd>w<cr>",   { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>",   { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa!<cr>", { desc = "Force quit all" })

-- ── Window navigation ────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- ── Window resize - in terminals too, where the keys went to the program (2026-10-21) ──
map({ "n", "t" }, "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Resize up" })
map({ "n", "t" }, "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Resize down" })
map({ "n", "t" }, "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Resize left" })
map({ "n", "t" }, "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Resize right" })
-- Alt+arrows too, in the editor (2026-10-22): PuTTY's default keys send Ctrl+arrows as plain arrows - Neovim cannot
-- tell them apart; Alt+arrows come through. Not in a terminal: there they are the shell's.
map("n", "<M-Up>",    "<cmd>resize +2<cr>",          { desc = "Resize up" })
map("n", "<M-Down>",  "<cmd>resize -2<cr>",          { desc = "Resize down" })
map("n", "<M-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Resize left" })
map("n", "<M-Right>", "<cmd>vertical resize +2<cr>", { desc = "Resize right" })

-- Home / End as PuTTY's default keys send them - the VT220's Find / Select (ESC [1~, ESC [4~): Neovim took them for
-- keys of their own, and the cursor stayed (2026-10-22). In a terminal they stay the program's (bash reads them).
map({ "n", "x", "o", "i", "c" }, "<Find>",   "<Home>", { desc = "Home (as PuTTY sends it)" })
map({ "n", "x", "o", "i", "c" }, "<Select>", "<End>",  { desc = "End (as PuTTY sends it)" })

-- ── Buffer navigation ────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })
-- IntelliJ's Ctrl+Tab: the buffers in the order you used them, starting on the one before this one - Enter goes back,
-- Tab further (lua/config/switcher.lua). Ctrl+Tab itself reaches Neovim in a few terminals only (Windows Terminal and
-- kitty switch their tabs with it)
map("n", "<leader><Tab>", function() require("config.switcher").pick() end, { desc = "Recent buffers (Tab: further back)" })
map("n", "<C-Tab>",       function() require("config.switcher").pick() end, { desc = "Recent buffers (Tab: further back)" })

-- ── Ctrl+Click: IntelliJ's - the declaration of a name, on the declaration its usages (lua/config/navigate.lua) ──
-- A second Ctrl+Click on the same spot soon after is a double click to Neovim (<C-2-LeftMouse>) - after a jump to a
-- declaration the next click (its usages) often is: the same for those
for _, lhs in ipairs({ "<C-LeftMouse>", "<C-2-LeftMouse>", "<C-3-LeftMouse>", "<C-4-LeftMouse>" }) do
  map("n", lhs, function() require("config.navigate").ctrl_click() end, { desc = "Go to declaration / usages" })
end
map("i", "<C-LeftMouse>", "<Esc><C-LeftMouse>", { remap = true, desc = "Go to declaration / usages" })

-- ── Bookmarks: lines to come back to, per project (lua/config/bookmarks.lua) ──
-- IntelliJ's F11 is step into here (the debugger's F-keys); Shift+F11 and Ctrl+F11 are as there
local function bookmarks() return require("config.bookmarks") end
map("n", "<leader>mm", function() bookmarks().toggle() end, { desc = "Bookmark: set / remove on this line" })
map("n", "<leader>mr", function() bookmarks().name() end,   { desc = "Bookmark: name it (sets one if none)" })
map("n", "<leader>ml", function() bookmarks().pick() end,   { desc = "Bookmarks: list - Enter opens, dd deletes" })
map("n", "<leader>mn", function() bookmarks().jump(1) end,  { desc = "Bookmark: next" })
map("n", "<leader>mp", function() bookmarks().jump(-1) end, { desc = "Bookmark: previous" })
-- Shift / Ctrl with an F-key: most terminals send them as xterm does, and Neovim names them as terminfo does -
-- Shift+F11 is <F23>, Ctrl+F11 <F35>, Shift+F5 <F17>; only terminals with the kitty keyboard protocol send <S-F11>
-- itself (2026-10-22: Neovim under TERM=xterm, PuTTY's and xterm's bytes). Both names do it.
for _, lhs in ipairs({ "<S-F11>", "<F23>" }) do map("n", lhs, function() bookmarks().pick() end, { desc = "Bookmarks: list" }) end
for _, lhs in ipairs({ "<C-F11>", "<F35>" }) do map("n", lhs, function() bookmarks().name() end, { desc = "Bookmark with a name" }) end

-- ── Move lines (visual) ─────────────────────────────────────
map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selection up" })

-- ── Centered scrolling ──────────────────────────────────────
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up centered" })
map("n", "n",     "nzzzv",   { desc = "Next search centered" })
map("n", "N",     "Nzzzv",   { desc = "Prev search centered" })

-- ── Join without moving cursor ──────────────────────────────
map("n", "J", "mzJ`z", { desc = "Join line (stay)" })

-- ── Clear search highlight ──────────────────────────────────
map("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlight" })

-- ── Better paste / delete ───────────────────────────────────
map("x", "<leader>p", [["_dP]], { desc = "Paste without yank" })
-- visual only: in normal mode <leader>d starts the debug keys (an operator there shadowed dl, dh, dt, ...)
map("x", "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- ── Send to terminal (pentesting workflow) ──────────────────
-- Terminal #1 is the Qwen Code agent; shell snippets go to #2.
map("v", "<leader>ts", function()
  require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = 2 })
end, { desc = "Send selection to term #2" })

map("n", "<leader>tl", function()
  require("toggleterm").send_lines_to_terminal("single_line", true, { args = 2 })
end, { desc = "Send line to term #2" })

-- ── Run / REPL: the bash + python dev suite (lua/devsuite/) ─
-- Every run is a task (overseer.nvim): scripts run side by side, running one again replaces its
-- old run. Output in a real terminal at the bottom (input(), read, sudo prompts work); the cursor
-- goes there while it runs and back to the code when it ends. Errors are marked in the code
-- (]q / <CR> on an error line). Files run from Neovim's directory with the project's .venv python
-- (or the #! line); arguments are remembered per script.
local function runner() return require("devsuite.runner") end
local function repl() return require("devsuite.repl") end
map("n", "<F6>",       function() runner().run_file() end,         { desc = "Run: File" })
map("n", "<leader>rr", function() runner().run_file() end,         { desc = "Run: File" })
map("n", "<leader>ra", function() runner().run_file_args() end,    { desc = "Run: File with args (remembered)" })
map("n", "<leader>rR", function() runner().run_sudo() end,         { desc = "Run: File as root (sudo)" })
map("n", "<leader>rp", function() runner().pick_script() end,      { desc = "Run: Project script" })
map("n", "<leader>rP", function() runner().pick_script(true) end,  { desc = "Run: Project script with args" })
map("n", "<leader>rl", function() runner().rerun() end,            { desc = "Run: Again (restart)" })
map("n", "<leader>rc", function() runner().run_cell() end,         { desc = "Run: Cell (# %%)" })
map("v", "<leader>rs", function() runner().run_selection() end,    { desc = "Run: Selection as script" })
map("n", "<leader>rx", function() runner().run_trace() end,        { desc = "Run: Trace (bash -x)" })
map("n", "<leader>rt", function() runner().test_file() end,        { desc = "Run: Tests of the file (pytest / Java: TestNG, JUnit)" })
map("n", "<leader>rT", function() runner().test_nearest() end,     { desc = "Run: Test at cursor (pytest / Java: TestNG, JUnit)" })
map("n", "<leader>rw", function() runner().toggle_watch() end,     { desc = "Run: Watch (re-run on save)" })
map("n", "<leader>rk", function() runner().stop() end,             { desc = "Run: Kill" })
map("n", "<leader>ro", function() runner().toggle() end,           { desc = "Run: Toggle output" })
map("n", "<leader>rL", function() runner().list() end,             { desc = "Run: Task list" })
map("n", "<leader>rf", function() runner().fix_with_qwen() end,    { desc = "Run: Fix the failed run with the agent" })
map("n", "<leader>rO", "<cmd>OverseerRun<cr>",                     { desc = "Run: Task templates (make, npm, tasks.json)" })
map("n", "<leader>ri", function() repl().toggle() end,             { desc = "REPL: Toggle (IPython/bash)" })
map("n", "<leader>re", function() repl().send_line() end,          { desc = "REPL: Send line" })
map("v", "<leader>re", function() repl().send_selection() end,     { desc = "REPL: Send selection" })
map("n", "<leader>rE", function() repl().send_cell() end,          { desc = "REPL: Send cell (# %%)" })

-- ── LaTeX: latexmk builds the document of the file (lua/devsuite/latex.lua) ─
-- The document: the file's "% !TEX root = ..." line, the file itself (\documentclass) or the main.tex above it.
-- Errors go to the quickfix list and onto their lines, as a failed run's do.
local function latex() return require("devsuite.latex") end
map("n", "<leader>lb", function() latex().build() end,             { desc = "LaTeX: Build (latexmk)" })
map("n", "<leader>lw", function() latex().toggle_watch() end,      { desc = "LaTeX: Watch (build on save + preview; a PDF / image: its preview; toggle)" })
map("n", "<leader>le", function() latex().show_errors() end,       { desc = "LaTeX: Errors of the last build (quickfix)" })

-- ── Coding agent: Qwen Code or OpenCode (lua/integrations/agent.lua) ─
local function agent() return require("integrations.agent") end
-- The start page's "AI" key calls these
vim.g.qwen_launch = function(name, direction) agent().launch(name, direction) end
vim.g.qwen_toggle = function(name, direction) agent().toggle(name, direction) end

map("n", "<leader>tt", function() agent().toggle("agent", "vertical") end,    { desc = "AI: Toggle" })
map("n", "<leader>tf", function() agent().launch("agent", "float") end,       { desc = "AI: Float" })
map("n", "<leader>th", function() agent().launch("agent", "horizontal") end,  { desc = "AI: Horizontal" })
map("n", "<leader>tv", function() agent().launch("agent", "vertical") end,    { desc = "AI: Vertical" })
map("n", "<leader>t1", function() agent().launch("agent1", "horizontal") end, { desc = "AI: Agent #1 (own session)" })
map("n", "<leader>t2", function() agent().launch("agent2", "horizontal") end, { desc = "AI: Agent #2 (own session)" })
map("n", "<leader>t3", function() agent().launch("agent3", "horizontal") end, { desc = "AI: Agent #3 (own session)" })
map("n", "<leader>ac", function() agent().new_session() end, { desc = "AI: New session" })
map("n", "<leader>am", function() agent().model_info() end,  { desc = "AI: Model running on the rig" })
map("n", "<leader>aa", function() agent().ask() end,         { desc = "AI: Ask about file" })
map("v", "<leader>aa", function() agent().ask() end,         { desc = "AI: Ask about selection" })
map("v", "<leader>ae", function() agent().edit() end,        { desc = "AI: Edit selection" })
map("n", "<leader>ad", function() require("integrations.agent_changes").pick() end, { desc = "AI: What changed since the agent started (diff, take back)" })
-- The agent's edits, reviewed in their buffers (lua/integrations/agent_review.lua): ]c / [c go between them; a
-- window following the agent goes to each edit as it lands
local function review() return require("integrations.agent_review") end
local function sel() local a, b = vim.fn.line("v"), vim.fn.line("."); return math.min(a, b), math.max(a, b) end
map("n", "<leader>ay", function() review().act(true) end,  { desc = "AI: Keep the agent's change here" })
map("n", "<leader>an", function() review().act(false) end, { desc = "AI: Revert the agent's change here" })
map("v", "<leader>ay", function() local a, b = sel(); review().act(true, false, a, b) end,  { desc = "AI: Keep the agent's changes in the selection" })
map("v", "<leader>an", function() local a, b = sel(); review().act(false, false, a, b) end, { desc = "AI: Revert the agent's changes in the selection" })
map("n", "<leader>aY", function() review().act(true, true) end,  { desc = "AI: Keep all of the agent's changes in this file" })
map("n", "<leader>aN", function() review().act(false, true) end, { desc = "AI: Revert all of the agent's changes in this file" })
map("n", "<leader>ar", function() review().pick() end,           { desc = "AI: The agent's edits to review (keep, revert)" })
map("n", "<leader>af", function() review().toggle_follow() end,  { desc = "AI: This window follows the agent's edits (again: stops)" })
-- Speech to text on this machine (lua/integrations/voice.lua): press to start, again to stop
local function voice() return require("integrations.voice") end
map("n", "<leader>av", function() voice().toggle("agent") end,  { desc = "AI: Speak a prompt to the agent (again: stop)" })
map("n", "<leader>aV", function() voice().toggle("cursor") end, { desc = "AI: Dictate at the cursor (again: stop)" })
vim.api.nvim_create_user_command("VoiceInstall", function(o) voice().install(o.args) end, {
  nargs = "?", complete = function() return { "small", "base", "turbo" } end,
  desc = "Speech to text: download whisper.cpp and a model (small - the default, base, turbo)",
})
vim.api.nvim_create_user_command("VoiceCancel", function() voice().cancel() end, { desc = "Speech to text: drop the recording" })

-- ── Debug: Python (debugpy) + bash (bashdb) - lua/devsuite/debug.lua ─
-- F5 debugs the current file (or continues; with .vscode/launch.json it offers those configs).
-- Programs get a terminal (DAP console pane): input() and read work while debugging.
local function dbg() return require("devsuite.debug") end
map("n", "<F5>",       function() dbg().start_or_continue() end,         { desc = "Debug: Start this file / Continue" })
-- Shift+F5: <F17> in most terminals (as Shift+F11 above)
for _, lhs in ipairs({ "<S-F5>", "<F17>" }) do map("n", lhs, function() require("dap").terminate() end, { desc = "Debug: Stop" }) end
map("n", "<F9>",       function() require("dap").toggle_breakpoint() end, { desc = "Debug: Breakpoint" })
map("n", "<F10>",      function() require("dap").step_over() end,         { desc = "Debug: Step over" })
map("n", "<F11>",      function() require("dap").step_into() end,         { desc = "Debug: Step into" })
map("n", "<F12>",      function() require("dap").step_out() end,          { desc = "Debug: Step out" })
map("n", "<leader>dl", function() dbg().launch() end,                     { desc = "Debug: Launch this file" })
map("n", "<leader>dL", function() dbg().launch(true) end,                 { desc = "Debug: Launch with args" })
map("n", "<leader>dt", function() dbg().debug_test() end,                 { desc = "Debug: Test at cursor (pytest / Java: TestNG, JUnit)" })
map("n", "<leader>de", function() dbg().toggle_exceptions() end,          { desc = "Debug: Stop on raised exceptions (toggle)" })
map("n", "<leader>dc", function() require("dap").run_to_cursor() end,     { desc = "Debug: Run to cursor" })
map("n", "<leader>dh", function() require("dap.ui.widgets").hover() end,  { desc = "Debug: Value under cursor" })
map("n", "<leader>dq", function() require("dap").terminate() end,         { desc = "Debug: Stop" })
map("n", "<leader>dR", function() require("dap").restart() end,           { desc = "Debug: Restart" })
map("n", "<leader>da", function()
  -- Java: IntelliJ's Remote JVM Debug configurations (or host:port)
  if vim.bo.filetype == "java" then return require("integrations.jdtls").attach() end
  local port = tonumber(vim.fn.input("debugpy port: "))
  require("dap").run({
    type = "python",
    name = "attach: " .. tostring(port),
    request = "attach",
    connect = { host = "127.0.0.1", port = port },
  })
end, { desc = "Debug: Attach (debugpy port / Java: IntelliJ's remote configs)" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Debug: Breakpoint" })
map("n", "<leader>dB", function()
  require("dap").set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "Debug: Conditional breakpoint" })
map("n", "<leader>dp", function()
  require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message ({expr} is evaluated): "))
end, { desc = "Debug: Log point" })
map("n", "<leader>dr", function() require("dap").repl.open() end,  { desc = "Debug: REPL" })
map("n", "<leader>du", function() require("dapui").toggle() end,   { desc = "Debug: Toggle UI" })

-- ── Git diffs: codediff (VS Code's diff), else Diffview (lua/config/gitdiff.lua) ─
-- <leader>gv: <leader>gd is the docs picker below
map("n", "<leader>gv", function() require("config.gitdiff").review() end,  { desc = "Git: Review the changes (VS Code's diff, live)" })
map("n", "<leader>gh", function() require("config.gitdiff").history() end, { desc = "Git: File history" })

-- ── GreyKnight Docs (read-only picker) ───────────────────────
-- The guide is a file per topic (docs/, 2026-10-23): its index first, the topics in the order one reads them, any
-- other file in docs/ after them
local GUIDE = { "README", "start", "agent", "files", "windows", "find", "code", "run-debug", "git", "ssh", "testbook" }
map("n", "<leader>gd", function()
  local config_dir = vim.fn.stdpath("config")
  local names = { "README.md", "CHEATSHEET.md" }
  local seen = {}
  for _, topic in ipairs(GUIDE) do
    names[#names + 1] = "docs/" .. topic .. ".md"
    seen[topic .. ".md"] = true
  end
  local more = {} -- not glob(): a [ ] in the config's path would be a pattern
  pcall(function()
    for file, kind in vim.fs.dir(config_dir .. "/docs") do
      if kind == "file" and file:match("%.md$") and not seen[file] then more[#more + 1] = "docs/" .. file end
    end
  end)
  table.sort(more)
  vim.list_extend(names, more)
  names[#names + 1] = "G3-DEVELOPMENT.md"
  local docs = {}
  for _, name in ipairs(names) do
    local path = config_dir .. "/" .. name
    if vim.fn.filereadable(path) == 1 then
      table.insert(docs, { name = name, path = path })
    end
  end
  if #docs == 0 then
    vim.notify("No docs found in " .. config_dir, vim.log.levels.WARN)
    return
  end
  vim.ui.select(
    vim.tbl_map(function(d) return d.name end, docs),
    { prompt = "GreyKnight Docs:" },
    function(choice)
      if not choice then return end
      for _, d in ipairs(docs) do
        if d.name == choice then
          vim.cmd.vsplit({ args = { d.path }, magic = { file = false } }) -- the path as it is: a space, #, % or [ ] in it
          -- read-only, q closes it; links followed from it open the same way (config/mdlinks.lua)
          require("config.mdlinks").read_only(0)
          break
        end
      end
    end
  )
end, { desc = "GreyKnight: Read docs" })
