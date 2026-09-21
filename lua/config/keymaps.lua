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
        { "<leader>s",  group = "Search & Replace" },
        { "<leader>t",  group = "Terminal/Test" },
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
map("t", "<C-l>",      "<C-\\><C-n><C-w>l", { desc = "Window right (from term)" })

-- ── Dashboard ────────────────────────────────────────────────
map("n", "<leader>;", "<cmd>lua Snacks.dashboard()<cr>", { desc = "Dashboard" })

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
-- Terminal #1 is now the Qwen Code agent; shell snippets go to #2.
map("v", "<leader>ts", function()
  require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = 2 })
end, { desc = "Send selection to term #2" })

map("n", "<leader>tl", function()
  require("toggleterm").send_lines_to_terminal("single_line", true, { args = 2 })
end, { desc = "Send line to term #2" })

-- ── Qwen Code agent (shell-out terminal) ────────────────────
local QWEN = "/home/nix0/.local/bin/qwen"
if vim.fn.executable(QWEN) ~= 1 then QWEN = "qwen" end

local function qwen_term(name, direction)
  -- Drive the terminal through the Lua API: the ex-command isn't registered
  -- until lazy.nvim loads the plugin, and this keymap file loads eagerly.
  require("toggleterm")
  local term = require("toggleterm.terminal").get_or_create_term(1, nil, direction, name)
  -- Spawn qwen specifically. Without this, toggleterm falls back to its
  -- configured shell (which may be unset and error).
  term.cmd = QWEN
  -- Keep the agent process (and its session) alive in a hidden buffer when
  -- its window is hidden, so toggling re-attaches rather than restarting.
  term.close_on_exit = false
  return term
end

-- Vertical splits size proportionally for a clean 50/50.
local function qwen_size(direction)
  return direction == "vertical" and vim.o.columns / 2
end

local function qwen_launch(name, direction)
  local term = qwen_term(name, direction)
  term:open(qwen_size(direction))
  vim.cmd("startinsert!")
end

-- Toggle semantics: close if already open, otherwise open fresh.
local function qwen_toggle(name, direction)
  local term = qwen_term(name, direction)
  term:toggle(qwen_size(direction), direction)
  if term:is_open() then vim.cmd("startinsert!") end
end
vim.g.qwen_launch = qwen_launch
vim.g.qwen_toggle = qwen_toggle

local function qwen_file()
  return vim.fn.expand("%:p")
end

local function qwen_selection()
  local mode = vim.fn.mode()
  if mode:match("^%[vV%]") then
    local start, finish = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start[2], finish[2] + 1, false)
    return table.concat(lines, "\n")
  end
  return ""
end

-- Terminals created via qwen_launch all register as id 1; this grabs the one
-- and feeds it a prompt (once its shell is actually open).
local function qwen_feed(kind)
  local term = require("toggleterm.terminal").get(1, true)
  if not term or not term:is_open() then return end
  term:send(qwen_prompt(kind))
end

local function qwen_prompt(kind)
  local cwd = vim.fn.getcwd()
  if kind == "edit" then
    return string.format(
      "Context: file=%s | cwd=%s | selection:\n%s\n\nEdit ONLY the selection above. Apply the change to that file and stop.",
      qwen_file(), cwd, (qwen_selection() or "(no selection)"))
  elseif kind == "ask" then
    local sel = qwen_selection()
    if sel and sel ~= "" then
      return string.format(
        "Context: file=%s | cwd=%s | selection:\n%s\n\nExplain or answer about the selection above (read-only, no edits).",
        qwen_file(), cwd, sel)
    end
    return string.format(
      "Context: file=%s | cwd=%s\n\nAnswer about the current file (read-only, no edits).",
      qwen_file(), cwd)
  end
  return ""
end

map("n", "<leader>tt", function() qwen_toggle("agent", "vertical") end, { desc = "AI: Toggle" })
map("n", "<leader>tf", function() qwen_launch("agent", "float")    end, { desc = "AI: Float" })
map("n", "<leader>th", function() qwen_launch("agent", "horizontal") end, { desc = "AI: Horizontal" })
map("n", "<leader>tv", function() qwen_launch("agent", "vertical")  end, { desc = "AI: Vertical" })
map("n", "<leader>t1", function() qwen_launch("agent1", "horizontal") end, { desc = "AI: Agent #1" })
map("n", "<leader>t2", function() qwen_launch("agent2", "horizontal") end, { desc = "AI: Agent #2" })
map("n", "<leader>t3", function() qwen_launch("agent3", "horizontal") end, { desc = "AI: Agent #3" })
map("n", "<leader>ac", function()
  qwen_launch("agent", "vertical")
  qwen_feed("new")
end, { desc = "AI: New session" })
map("n", "<leader>aa", function()
  qwen_launch("agent", "vertical")
  qwen_feed("ask")
end, { desc = "AI: Ask about file" })
map("v", "<leader>aa", function()
  qwen_launch("agent", "vertical")
  qwen_feed("ask")
end, { desc = "AI: Ask about selection" })
map("v", "<leader>ae", function()
  qwen_launch("agent", "vertical")
  qwen_feed("edit")
end, { desc = "AI: Edit selection" })

-- ── DAP keymaps ─────────────────────────────────────────────
map("n", "<F5>",       function() require("dap").continue() end,          { desc = "DAP: Continue" })
map("n", "<F10>",      function() require("dap").step_over() end,         { desc = "DAP: Step over" })
map("n", "<F11>",      function() require("dap").step_into() end,         { desc = "DAP: Step into" })
map("n", "<F12>",      function() require("dap").step_out() end,          { desc = "DAP: Step out" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "DAP: Breakpoint" })
map("n", "<leader>dB", function()
  require("dap").set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "DAP: Cond breakpoint" })
map("n", "<leader>dr", function() require("dap").repl.open() end,  { desc = "DAP: REPL" })
map("n", "<leader>du", function() require("dapui").toggle() end,   { desc = "DAP: Toggle UI" })

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
