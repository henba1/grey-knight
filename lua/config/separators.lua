-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The borders between windows: a thin line you can see, and   ║
-- ║  the one under the mouse lit up - where a drag resizes.      ║
-- ║  cyberdream drew them as blanks (hide_fillchars): on true    ║
-- ║  black there was nothing to aim at (2026-11-09).             ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

M.ns = vim.api.nvim_create_namespace("greyknight.separator_hover") -- its vim.on_key

-- the line: dim, but there; under the mouse: the comments' grey, bold - as long as the drag lasts
M.COLORS = { line = "#2e333a", hover = "#7b8496" }

local hovered -- the window whose border is lit

local function colors()
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = M.COLORS.line, bg = "NONE" })
  vim.api.nvim_set_hl(0, "GkSeparatorHover", { fg = M.COLORS.hover, bold = true })
end

-- One entry in the window's 'winhighlight', taken out again: the other entries are its own (toggleterm's shading, the
-- tree's, the start page's) - every window has colors of its own, a namespace of ours would replace them
local ENTRY = "WinSeparator:GkSeparatorHover"
local function without(whl)
  local parts = vim.tbl_filter(function(p) return p ~= ENTRY and p ~= "" end, vim.split(whl, ",", { plain = true }))
  return table.concat(parts, ",")
end

local function light(win)
  if win == hovered then return end
  if hovered and vim.api.nvim_win_is_valid(hovered) then
    vim.wo[hovered].winhighlight = without(vim.wo[hovered].winhighlight)
  end
  hovered = nil
  if win and vim.api.nvim_win_is_valid(win) then
    local whl = without(vim.wo[win].winhighlight)
    vim.wo[win].winhighlight = whl == "" and ENTRY or (whl .. "," .. ENTRY)
    hovered = win
  end
end

--- The window whose border the mouse is on: the line right of it (wincol past its width) or below it (winrow past its
--- height - with the global status line that is the border to the window below)
function M.border_at(pos)
  local win = pos.winid
  if not win or win == 0 or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
    return nil
  end
  if pos.wincol > vim.api.nvim_win_get_width(win) or pos.winrow > vim.api.nvim_win_get_height(win) then return win end
end

local dragging, queued = false, false
local MOVE, DRAG, RELEASE = vim.keycode("<MouseMove>"), vim.keycode("<LeftDrag>"), vim.keycode("<LeftRelease>")

-- every mouse move: looked at once per tick, not per event (a move sends many)
local function check()
  queued = false
  if dragging then return end
  light(M.border_at(vim.fn.getmousepos()))
end

function M.setup()
  local enabled = require("config.settings").get("separators.hover")
  -- a line, not blanks (cyberdream's hide_fillchars is off: plugins/colorscheme.lua)
  vim.opt.fillchars:append({ vert = "│", horiz = "─", horizup = "┴", horizdown = "┬", vertleft = "┤",
    vertright = "├", verthoriz = "┼" })
  colors()
  vim.api.nvim_create_autocmd("ColorScheme", { group = vim.api.nvim_create_augroup("greyknight.separators", { clear = true }),
    callback = colors })
  if not enabled then return end
  -- the moves reach Neovim only with this; nothing is mapped to them - looked at as they pass (vim.on_key)
  vim.o.mousemoveevent = true
  vim.on_key(function(key)
    if key == DRAG then
      dragging = true -- the border stays lit while it is dragged, also where the mouse runs ahead of it
    elseif key == RELEASE then
      dragging = false
      if not queued then queued = true; vim.schedule(check) end
    elseif key == MOVE and not queued then
      queued = true
      vim.schedule(check)
    end
  end, M.ns)
end

return M
