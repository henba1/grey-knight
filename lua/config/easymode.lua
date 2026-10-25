-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Easy mode: file windows as in a plain text editor - always  ║
-- ║  typing, Ctrl+S / Z / Y / C / X / V / A / F, Shift+arrows    ║
-- ║  select. Alt+N (or :EasyMode, the start screen) on and off;  ║
-- ║  Esc is normal mode for one command (Space f f, :w ...)      ║
-- ╚══════════════════════════════════════════════════════════════╝
-- For this session only. Terminals, the file tree, pickers and the agent's pane keep their keys: only windows with
-- a file go back to typing. Neovim dropped Vim's own easy mode ('insertmode', evim) - this is its replacement.
local M = {}

M.enabled = false

-- What a plain editor does: Shift+arrows (and the mouse) select, typing replaces the selection, arrows end it; the
-- arrows go on over the end of a line; Ctrl+Backspace deletes the whole word, not only what was typed since the cursor
-- came (nostop). Only Ctrl+C / Ctrl+X reach the clipboard: with GreyKnight's unnamedplus the text a typed letter
-- replaced went there too, and Ctrl+V pasted that instead of the copy (2026-10-25).
local OPTIONS = {
  keymodel = "startsel,stopsel", selectmode = "mouse,key", selection = "exclusive", whichwrap = "b,s,<,>,[,]",
  backspace = "indent,eol,nostop", clipboard = "",
}

local saved_options, saved_maps, group = {}, {}, nil

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Easy mode" }) end

--- A window easy mode types in: a file (or a new, unnamed one) - not a terminal, tree, picker or float.
function M.eligible(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and vim.bo[buf].modifiable and vim.bo[buf].filetype ~= "snacks_dashboard"
end

local function save()
  if vim.api.nvim_buf_get_name(0) ~= "" then return vim.cmd("silent! update") end
  vim.ui.input({ prompt = "Save as: ", completion = "file" }, function(path)
    if path and path ~= "" then vim.cmd.write(vim.fn.fnameescape(path)) end
  end)
end

local function goto_line()
  vim.ui.input({ prompt = "Go to line: " }, function(text)
    local n = tonumber(text or "")
    if n then vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(n, vim.api.nvim_buf_line_count(0))), 0 }) end
  end)
end

-- Replace in this file: grug-far (<leader>sr), on this file only
local function replace()
  local file = vim.api.nvim_buf_get_name(0)
  require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>"), paths = file ~= "" and vim.fn.fnameescape(file) or nil } })
end

-- Select all: from the first character to the end, in select mode (typing replaces it, Ctrl+C copies it)
local SELECT_ALL = "<Esc>gg0vG$<C-g>"

--- The keys: { modes, lhs, rhs, description }. Insert mode is where easy mode types; select mode has the selection.
--- Ctrl+H is Ctrl+Backspace in Windows Terminal and most terminals (both send ^H): delete a word, as there.
--- Ctrl+/ comes as Ctrl+_ from terminals. Ctrl+V: Windows Terminal pastes its own clipboard before Neovim sees it.
M.KEYS = {
  { { "i", "s" }, "<C-s>", save, "Save" },
  { "i", "<C-z>", "<Cmd>undo<CR>", "Undo" },
  { "i", "<C-y>", "<Cmd>redo<CR>", "Redo" },
  { "s", "<C-z>", "<Esc><Cmd>undo<CR>", "Undo" },
  { "s", "<C-y>", "<Esc><Cmd>redo<CR>", "Redo" },
  { { "i", "s" }, "<C-a>", SELECT_ALL, "Select all" },
  { "s", "<C-c>", '<C-g>"+ygv<C-g>', "Copy" },
  { "s", "<C-x>", '<C-g>"+d', "Cut" },
  { "s", "<C-v>", '<C-g>"_d"+P', "Paste over the selection" },
  { "i", "<C-c>", '<Cmd>normal! "+yy<CR>', "Copy the line" },
  { "i", "<C-x>", '<Cmd>normal! "+dd<CR>', "Cut the line" },
  { "i", "<C-v>", "<C-r><C-o>+", "Paste" },
  { "i", "<C-f>", "<C-o>/", "Find" },
  { { "i", "s" }, "<C-r>", replace, "Replace (in this file)" },
  { { "i", "s" }, "<C-g>", goto_line, "Go to line" },
  { "i", "<C-_>", "<Cmd>normal gcc<CR>", "Comment / uncomment the line" },
  { "i", "<C-/>", "<Cmd>normal gcc<CR>", "Comment / uncomment the line" },
  { "s", "<C-_>", "<C-g>gc", "Comment / uncomment the selection" },
  { "s", "<C-/>", "<C-g>gc", "Comment / uncomment the selection" },
  { "s", "<Tab>", "<C-g>>gv<C-g>", "Indent the selection" },
  { "s", "<S-Tab>", "<C-g><gv<C-g>", "Outdent the selection" },
  { "i", "<S-Tab>", "<C-d>", "Outdent the line" },
  { "i", "<C-h>", "<C-w>", "Delete the word before (Ctrl+Backspace)" },
  { "i", "<C-Del>", "<C-o>dw", "Delete the word after" },
  { "i", "<C-o>", function() Snacks.picker.files() end, "Open a file" },
  { "i", "<C-n>", "<Cmd>enew<CR>", "New file" },
  { "i", "<C-w>", function() Snacks.bufdelete() end, "Close the file (asks about unsaved changes)" },
  -- one command in normal mode, then typing again: Neovim's own Ctrl+O (the map above takes Ctrl+O itself)
  { "i", "<Esc>", "<C-o>", "Normal mode for one command" },
  { "i", "<F1>", function() M.help() end, "These keys" },
}

-- Back to typing when a file window ends up in normal mode: Esc's one command is done, a selection ended, a window
-- with a file got the cursor. "niI" (the one command of Ctrl+O) is not "n": it goes back by itself.
local function resume()
  if not M.enabled then return end
  vim.schedule(function()
    if M.enabled and vim.api.nvim_get_mode().mode == "n" and M.eligible() then vim.cmd("startinsert") end
  end)
end

-- Esc's one command (Neovim's Ctrl+O) types again afterwards wherever it ended - also in a window without a file it
-- went to (the file tree, a scratch or help buffer). There it is Neovim's normal mode again; floats and input boxes
-- (pickers, prompts) keep typing: they start it themselves.
local function after_one_command()
  if not M.enabled or M.eligible() then return end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_win_get_config(0).relative ~= "" or vim.bo[buf].buftype == "prompt" or vim.bo[buf].buftype == "terminal"
    or vim.bo[buf].filetype:match("input") then return end
  -- after Neovim has gone back to typing: a stopinsert while it does is lost
  vim.schedule(function()
    if vim.api.nvim_get_current_buf() == buf and vim.api.nvim_get_mode().mode == "i" then vim.cmd("stopinsert") end
  end)
end

function M.enable()
  if M.enabled then return end
  M.enabled = true
  vim.g.greyknight_easymode = true
  for name, value in pairs(OPTIONS) do
    saved_options[name] = vim.o[name]
    vim.o[name] = value
  end
  for _, key in ipairs(M.KEYS) do
    local modes = type(key[1]) == "table" and key[1] or { key[1] }
    for _, mode in ipairs(modes) do
      local old = vim.fn.maparg(key[2], mode, false, true)
      saved_maps[#saved_maps + 1] = { mode = mode, lhs = key[2], old = (old and old.lhs) and old or nil }
      vim.keymap.set(mode, key[2], key[3], { desc = "Easy mode: " .. key[4] })
    end
  end
  group = vim.api.nvim_create_augroup("greyknight_easymode", { clear = true })
  vim.api.nvim_create_autocmd("ModeChanged", { group = group, pattern = "*:n", callback = resume })
  vim.api.nvim_create_autocmd("ModeChanged", { group = group, pattern = "niI:i", callback = after_one_command })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { group = group, callback = resume })
  if M.eligible() then vim.cmd("startinsert") end
  pcall(vim.cmd.redrawstatus, { bang = true })
  notify("Easy mode on: Ctrl+S save · Ctrl+Z / Y undo / redo · Shift+arrows select · Ctrl+C / X / V · Ctrl+F find"
    .. " · Esc: one normal-mode command · F1 all keys · Alt+N off")
end

function M.disable()
  if not M.enabled then return end
  M.enabled = false
  vim.g.greyknight_easymode = false
  for name, value in pairs(saved_options) do vim.o[name] = value end
  saved_options = {}
  for i = #saved_maps, 1, -1 do
    local m = saved_maps[i]
    pcall(vim.keymap.del, m.mode, m.lhs)
    if m.old then vim.fn.mapset(m.mode, false, m.old) end -- a key GreyKnight (or a plugin) had: back as it was
  end
  saved_maps = {}
  if group then pcall(vim.api.nvim_del_augroup_by_id, group) end
  group = nil
  if vim.api.nvim_get_mode().mode:match("^[is]") then vim.cmd("stopinsert") end
  pcall(vim.cmd.redrawstatus, { bang = true })
  notify("Easy mode off - Neovim's keys again")
end

function M.toggle() if M.enabled then M.disable() else M.enable() end end

--- The keys of easy mode in a float (F1).
function M.help()
  local lines = { "Easy mode - Alt+N switches it off", "" }
  for _, key in ipairs(M.KEYS) do
    local modes = type(key[1]) == "table" and table.concat(key[1], "/") or key[1]
    lines[#lines + 1] = ("  %-9s %-4s %s"):format(key[2], modes == "s" and "sel" or "", key[4])
  end
  vim.list_extend(lines, { "", "  Shift+arrows, Shift+Home/End, Ctrl+Shift+arrows select; typing replaces the selection",
    "  Ctrl+arrows: a word; Ctrl+Home/End: the start / end of the file", "  Esc then Ctrl+H/J/K/L: another window" })
  Snacks.win({ text = lines, width = 80, height = #lines + 2, border = "rounded", title = " Easy mode ", ft = "text",
    wo = { cursorline = false } })
end

function M.setup()
  vim.api.nvim_create_user_command("EasyMode", function(opts)
    local arg = opts.args
    if arg == "on" then M.enable() elseif arg == "off" then M.disable() else M.toggle() end
  end, { nargs = "?", complete = function() return { "on", "off" } end, desc = "Easy mode: a plain text editor's keys (on / off)" })
  vim.keymap.set({ "n", "i", "v", "s" }, "<M-n>", M.toggle, { desc = "Easy mode: plain text editor keys (on / off)" })
end

return M
