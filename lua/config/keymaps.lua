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
        { "<leader>a",  group = "AI (Avante)" },
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
map("v", "<leader>ts", function()
  require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = 1 })
end, { desc = "Send selection to term #1" })

map("n", "<leader>tl", function()
  require("toggleterm").send_lines_to_terminal("single_line", true, { args = 1 })
end, { desc = "Send line to term #1" })

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
