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
        { "<leader>a",  group = "AI (Qwen Code)" },
        { "<leader>b",  group = "Buffer" },
        { "<leader>d",  group = "Debug/DAP" },
        { "<leader>f",  group = "Find (Picker)" },
        { "<leader>g",  group = "Git" },
        { "<leader>h",  group = "Harpoon/Hex" },
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
map("t", "<Esc><Esc>", "<C-\\><C-n>",       { desc = "Exit terminal mode" })
map("t", "<C-h>",      "<C-\\><C-n><C-w>h", { desc = "Window left (from term)" })
map("t", "<C-j>",      "<C-\\><C-n><C-w>j", { desc = "Window down (from term)" })
map("t", "<C-k>",      "<C-\\><C-n><C-w>k", { desc = "Window up (from term)" })
-- no <C-l> here: in a terminal, Ctrl+L belongs to the program (clears a shell). Window right: Esc Esc, <C-l>

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

-- ── Window resize ────────────────────────────────────────────
map("n", "<C-Up>",    "<cmd>resize +2<cr>",          { desc = "Resize up" })
map("n", "<C-Down>",  "<cmd>resize -2<cr>",          { desc = "Resize down" })
map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { desc = "Resize left" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Resize right" })

-- ── Buffer navigation ────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>",     { desc = "Next buffer" })

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
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete to void" })

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
map("n", "<leader>rt", function() runner().test_file() end,        { desc = "Run: pytest file" })
map("n", "<leader>rT", function() runner().test_nearest() end,     { desc = "Run: pytest test at cursor" })
map("n", "<leader>rw", function() runner().toggle_watch() end,     { desc = "Run: Watch (re-run on save)" })
map("n", "<leader>rk", function() runner().stop() end,             { desc = "Run: Kill" })
map("n", "<leader>ro", function() runner().toggle() end,           { desc = "Run: Toggle output" })
map("n", "<leader>rL", function() runner().list() end,             { desc = "Run: Task list" })
map("n", "<leader>rf", function() runner().fix_with_qwen() end,    { desc = "Run: Fix the failed run with Qwen" })
map("n", "<leader>rO", "<cmd>OverseerRun<cr>",                     { desc = "Run: Task templates (make, npm, tasks.json)" })
map("n", "<leader>ri", function() repl().toggle() end,             { desc = "REPL: Toggle (IPython/bash)" })
map("n", "<leader>re", function() repl().send_line() end,          { desc = "REPL: Send line" })
map("v", "<leader>re", function() repl().send_selection() end,     { desc = "REPL: Send selection" })
map("n", "<leader>rE", function() repl().send_cell() end,          { desc = "REPL: Send cell (# %%)" })

-- ── Qwen Code agent (lua/integrations/qwen.lua) ─────────────
local function qwen() return require("integrations.qwen") end
-- The start page's "AI" key calls these
vim.g.qwen_launch = function(name, direction) qwen().launch(name, direction) end
vim.g.qwen_toggle = function(name, direction) qwen().toggle(name, direction) end

map("n", "<leader>tt", function() qwen().toggle("agent", "vertical") end,    { desc = "AI: Toggle" })
map("n", "<leader>tf", function() qwen().launch("agent", "float") end,       { desc = "AI: Float" })
map("n", "<leader>th", function() qwen().launch("agent", "horizontal") end,  { desc = "AI: Horizontal" })
map("n", "<leader>tv", function() qwen().launch("agent", "vertical") end,    { desc = "AI: Vertical" })
map("n", "<leader>t1", function() qwen().launch("agent1", "horizontal") end, { desc = "AI: Agent #1 (own session)" })
map("n", "<leader>t2", function() qwen().launch("agent2", "horizontal") end, { desc = "AI: Agent #2 (own session)" })
map("n", "<leader>t3", function() qwen().launch("agent3", "horizontal") end, { desc = "AI: Agent #3 (own session)" })
map("n", "<leader>ac", function() qwen().new_session() end, { desc = "AI: New session (/clear)" })
map("n", "<leader>am", function() qwen().model_info() end,  { desc = "AI: Model running on the rig" })
map("n", "<leader>aa", function() qwen().ask() end,         { desc = "AI: Ask about file" })
map("v", "<leader>aa", function() qwen().ask() end,         { desc = "AI: Ask about selection" })
map("v", "<leader>ae", function() qwen().edit() end,        { desc = "AI: Edit selection" })

-- ── Debug: Python (debugpy) + bash (bashdb) - lua/devsuite/debug.lua ─
-- F5 debugs the current file (or continues; with .vscode/launch.json it offers those configs).
-- Programs get a terminal (DAP console pane): input() and read work while debugging.
local function dbg() return require("devsuite.debug") end
map("n", "<F5>",       function() dbg().start_or_continue() end,         { desc = "Debug: Start this file / Continue" })
map("n", "<S-F5>",     function() require("dap").terminate() end,        { desc = "Debug: Stop" })
map("n", "<F9>",       function() require("dap").toggle_breakpoint() end, { desc = "Debug: Breakpoint" })
map("n", "<F10>",      function() require("dap").step_over() end,         { desc = "Debug: Step over" })
map("n", "<F11>",      function() require("dap").step_into() end,         { desc = "Debug: Step into" })
map("n", "<F12>",      function() require("dap").step_out() end,          { desc = "Debug: Step out" })
map("n", "<leader>dl", function() dbg().launch() end,                     { desc = "Debug: Launch this file" })
map("n", "<leader>dL", function() dbg().launch(true) end,                 { desc = "Debug: Launch with args" })
map("n", "<leader>dt", function() dbg().debug_test() end,                 { desc = "Debug: pytest test at cursor" })
map("n", "<leader>de", function() dbg().toggle_exceptions() end,          { desc = "Debug: Stop on raised exceptions (toggle)" })
map("n", "<leader>dc", function() require("dap").run_to_cursor() end,     { desc = "Debug: Run to cursor" })
map("n", "<leader>dh", function() require("dap.ui.widgets").hover() end,  { desc = "Debug: Value under cursor" })
map("n", "<leader>dq", function() require("dap").terminate() end,         { desc = "Debug: Stop" })
map("n", "<leader>dR", function() require("dap").restart() end,           { desc = "Debug: Restart" })
map("n", "<leader>da", function()
  local port = tonumber(vim.fn.input("debugpy port: "))
  require("dap").run({
    type = "python",
    name = "attach: " .. tostring(port),
    request = "attach",
    connect = { host = "127.0.0.1", port = port },
  })
end, { desc = "Debug: Attach to debugpy listener" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Debug: Breakpoint" })
map("n", "<leader>dB", function()
  require("dap").set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "Debug: Conditional breakpoint" })
map("n", "<leader>dp", function()
  require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message ({expr} is evaluated): "))
end, { desc = "Debug: Log point" })
map("n", "<leader>dr", function() require("dap").repl.open() end,  { desc = "Debug: REPL" })
map("n", "<leader>du", function() require("dapui").toggle() end,   { desc = "Debug: Toggle UI" })

-- ── GreyNight Docs (read-only telescope picker) ─────────────
map("n", "<leader>gd", function()
  local config_dir = vim.fn.stdpath("config")
  local docs = {}
  for _, name in ipairs({ "README.md", "CHEATSHEET.md", "USAGE.md" }) do
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
    { prompt = "GreyNight Docs:" },
    function(choice)
      if not choice then return end
      for _, d in ipairs(docs) do
        if d.name == choice then
          vim.cmd("vsplit " .. d.path)
          vim.bo.readonly = true
          vim.bo.modifiable = false
          vim.bo.bufhidden = "wipe"
          -- q closes the doc and returns to previous window
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, desc = "Close doc" })
          break
        end
      end
    end
  )
end, { desc = "GreyNight: Read docs" })
