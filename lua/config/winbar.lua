-- ╔══════════════════════════════════════════════════════════════╗
-- ║  A bar on top of each file window, as in an IDE: the file    ║
-- ║  (● when modified) and three buttons to click - split right, ║
-- ║  split below, close. Close closes the window; the last       ║
-- ║  editor window keeps its place and loses the file instead.   ║
-- ╚══════════════════════════════════════════════════════════════╝
-- The statusline is global (laststatus=3): a window had nothing of its own to say which file it shows or to click
-- on (2026-10-23). Only file windows (buftype "", not floating) get the bar - not the tree, pickers, terminals, the
-- agent, help, quickfix or the start screen. Other code puts winbars of its own on windows (agent_review.lua's
-- "follows the agent", the diffs of agent_ide.lua / agent_changes.lua, a run's output): a bar is only set where
-- there is none, and only this one is ever taken away.
local M = {}

--- The bar, the same text in each window: what tells this one from the others' (render() fills it per window)
M.BAR = "%{%v:lua.require'config.winbar'.render()%}"

-- buftype "" yet no file window
local SKIP_FT = { snacks_dashboard = true, snacks_picker_list = true, snacks_picker_input = true,
  snacks_picker_preview = true, snacks_layout_box = true, lazy = true, mason = true }

-- ── Colors: from the colorscheme's, again when it changes ─────────

local function rgb(n) return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256 end
local function mix(a, b, t) -- t of the way from a to b
  local r1, g1, b1 = rgb(a)
  local r2, g2, b2 = rgb(b)
  local function c(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return c(r1, r2) * 65536 + c(g1, g2) * 256 + c(b1, b2)
end
local function hl(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end

function M.colors()
  local base = hl("Normal").bg or 0x000000 -- a transparent background: OLED's black
  local text = hl("Normal").fg or 0xe8e8e8
  local grey = hl("Comment").fg or 0x7b8496
  local warn = hl("DiagnosticWarn").fg or 0xffbd5e
  local set = function(name, spec) vim.api.nvim_set_hl(0, name, spec) end
  -- the window with the cursor: the name in the text's color, the buttons grey (readable on true black, not loud);
  -- the others a step back toward the background
  set("GreyKnightWinbar", { fg = mix(base, text, 0.85), bg = base })
  set("GreyKnightWinbarNC", { fg = mix(base, grey, 0.75), bg = base })
  set("GreyKnightWinbarButton", { fg = grey, bg = base })
  set("GreyKnightWinbarButtonNC", { fg = mix(base, grey, 0.6), bg = base })
  set("GreyKnightWinbarModified", { fg = warn, bg = base })
end

-- ── The bar ─────────────────────────────────────────────────────

--- Whether `win` is a file window - one the bar belongs on
function M.eligible(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return false end
  if vim.api.nvim_win_get_config(win).relative ~= "" then return false end -- a float
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and not SKIP_FT[vim.bo[buf].filetype]
end

-- a click handler is a function's name: v:lua reaches this module through a global, not require'' (2026-10-23)
_G.GreyKnightWinbar = M

local function button(win, fn, label, group)
  return ("%%#%s#%%%d@v:lua.GreyKnightWinbar.%s@ %s %%X"):format(group, win, fn, label)
end

--- The bar of the window being drawn (g:statusline_winid): the file on the left, the buttons on the right
function M.render()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win() -- nvim_eval_statusline() leaves it unset
  if not (win and vim.api.nvim_win_is_valid(win)) then return "" end
  local buf = vim.api.nvim_win_get_buf(win)
  local active = win == vim.api.nvim_get_current_win()
  local name = vim.api.nvim_buf_get_name(buf)
  name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
  local file = active and "GreyKnightWinbar" or "GreyKnightWinbarNC"
  local btn = active and "GreyKnightWinbarButton" or "GreyKnightWinbarButtonNC"
  local dot = vim.bo[buf].modified and "%#GreyKnightWinbarModified# ●" or ""
  return ("%%#%s#%%< %s%s%%#%s#%%=%s%s%s"):format(file, name:gsub("%%", "%%%%"), dot, file,
    button(win, "split_right", "◫", btn), button(win, "split_below", "⊟", btn), button(win, "close", "×", btn))
end

--- The bar on `win` when it is a file window and shows no other bar; taken away (only this one) when it is not
function M.update(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local cur = vim.wo[win].winbar
  local want = M.eligible(win)
  -- vim.wo on a global-local option is :setlocal - new windows do not take it from the global value
  if want and cur == "" then
    vim.wo[win].winbar = M.BAR
  elseif not want and cur == M.BAR then
    vim.wo[win].winbar = ""
  end
end

function M.update_all()
  for _, win in ipairs(vim.api.nvim_list_wins()) do M.update(win) end
end

-- ── The buttons (click handlers: minwid is the window) ───────────

local function editor_windows(tab)
  return vim.tbl_filter(M.eligible, vim.api.nvim_tabpage_list_wins(tab))
end

local function split(win, cmd)
  if not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_set_current_win(win)
  vim.cmd(cmd)
end

function M.split_right(win) split(win, "rightbelow vsplit") end
function M.split_below(win) split(win, "belowright split") end

--- As an IDE closes an editor: the window when there are other file windows in its tab; the last one stays where
--- it is and loses its file instead (Snacks.bufdelete: asks first about unsaved changes) - Neovim does not quit
function M.close(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local others = vim.tbl_filter(function(w) return w ~= win end, editor_windows(vim.api.nvim_win_get_tabpage(win)))
  if #others > 0 then
    local ok, err = pcall(vim.api.nvim_win_close, win, false)
    if not ok then vim.notify(tostring(err), vim.log.levels.WARN, { title = "Close" }) end
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  vim.api.nvim_set_current_win(win)
  if _G.Snacks and Snacks.bufdelete then
    Snacks.bufdelete({ buf = buf })
  else
    vim.cmd("enew")
    if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then pcall(vim.api.nvim_buf_delete, buf, {}) end
  end
end

function M.setup()
  M.colors()
  local group = vim.api.nvim_create_augroup("greyknight.winbar", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.colors })
  -- a window takes the options of the one it was split from, a buffer brings its own to the window it enters:
  -- looked at again whenever a window or what it shows changes
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinEnter", "FileType", "TermOpen" }, {
    group = group,
    callback = function() M.update_all() end,
  })
  vim.api.nvim_create_autocmd("OptionSet", { group = group, pattern = "buftype", callback = function() M.update_all() end })
  M.update_all()
end

return M
