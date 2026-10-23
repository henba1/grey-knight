-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Autocommands                                               ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 }) end,
})

-- Restore cursor position on file open
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Going to a terminal window whose program runs means typing there: terminal mode - a shell, the agent, a REPL, a
-- run's output, the debug console, :terminal. <C-h> leaves a terminal in normal mode, toggleterm brought that mode
-- back on the way in (persist_mode), and the other terminals stayed in normal mode: every return began with i
-- (2026-10-20 toggleterm's, 2026-10-21 all). Not once the program has exited: a key would close the window.
-- <Esc><Esc> still gives normal mode inside (scroll, copy).
local function program_runs(buf)
  local job = vim.b[buf].terminal_job_id
  if job then return vim.fn.jobwait({ job }, 0)[1] == -1 end
  -- a run's output is a terminal without the job (overseer shows the program's output in one of its own)
  local ok, tasks = pcall(require, "devsuite.tasks")
  return ok and tasks.running(buf) or false
end
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("greyknight.terminal_insert", { clear = true }),
  callback = function(ev)
    -- scheduled twice: after toggleterm's restore of the old mode, which it schedules from its own BufEnter; and a
    -- new :terminal is a terminal only after its BufEnter
    vim.schedule(function()
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() ~= ev.buf or vim.bo[ev.buf].buftype ~= "terminal" then return end
        if program_runs(ev.buf) and vim.api.nvim_get_mode().mode:sub(1, 1) == "n" then vim.cmd("startinsert") end
      end)
    end)
  end,
})

-- Bookmarks: their signs, and their lines kept as you edit (lua/config/bookmarks.lua); the order buffers were used in,
-- for <leader><Tab> (lua/config/switcher.lua)
require("config.bookmarks").setup()
require("config.switcher").setup()
require("config.putty").setup() -- over SSH from PuTTY with its default keys: a word once on the settings

-- Files moved or renamed in an oil buffer: bookmarks and harpoon's slots go along, as with the explorer's m and r
-- (config/explorer.lua). They kept the old path (2026-10-22). Each move that happened - a failed batch did some.
vim.api.nvim_create_autocmd("User", {
  pattern = "OilActionsPost",
  group = vim.api.nvim_create_augroup("greyknight.oil_moves", { clear = true }),
  callback = function(ev)
    local ok, util = pcall(require, "oil.util")
    if not ok then return end
    local fs = require("oil.fs")
    for _, action in ipairs(ev.data and ev.data.actions or {}) do
      if action.type == "move" then
        local scheme, src = util.parse_url(action.src_url or "")
        local _, dest = util.parse_url(action.dest_url or "")
        if scheme == "oil://" and src and dest then
          src, dest = fs.posix_to_os_path(src), fs.posix_to_os_path(dest)
          if vim.uv.fs_stat(src) == nil and vim.uv.fs_stat(dest) ~= nil then require("config.explorer").moved(src, dest) end
        end
      end
    end
  end,
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "qf", "man", "notify", "lspinfo", "checkhealth", "oil" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Started in Neovim's own program folder - a shortcut's "Start in", a double-click on nvim.exe: nobody works there, yet
-- terminals and agents start in Neovim's folder (OpenCode ran in C:\dev\tools\nvim\bin, 2026-10-23). The home folder
-- instead (a junction like C:\dev\tools\nvim -> nvim-0.12.6 counts as that folder too)
do
  local function real(p)
    local r = p and vim.uv.fs_realpath(p)
    if not r then return nil end
    r = vim.fs.normalize(r)
    return vim.fn.has("win32") == 1 and r:lower() or r
  end
  local cwd = vim.uv.cwd()
  local here, prog = real(cwd), real(vim.fs.dirname(vim.v.progpath))
  if here and prog and here == prog and vim.uv.os_homedir() then
    vim.fn.chdir(vim.uv.os_homedir())
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        vim.notify(("Started in Neovim's program folder (%s) - working in %s"):format(cwd, vim.fn.fnamemodify(vim.fn.getcwd(), ":~")),
          vim.log.levels.INFO)
      end,
    })
  end
end

-- Startup message
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local lang = vim.g.lang or {}
    local active = {}
    for name, enabled in pairs(lang) do
      if enabled then table.insert(active, name) end
    end
    table.sort(active)
    if #active > 0 then
      local ok, agent = pcall(function() return require("integrations.agent").backend().name end)
      vim.notify("Grey Knight | " .. table.concat(active, ", ") .. " | AI: " .. (ok and agent or "?"), vim.log.levels.INFO)
    end
  end,
})
