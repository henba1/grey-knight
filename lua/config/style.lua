-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The look: OLED - cyberdream's neon on true black, for       ║
-- ║  OLED screens (black pixels stay off) - or GreyKnight's own: ║
-- ║  cyberdream's neon on its grey. Both on cyberdream's engine  ║
-- ║  (every plugin colored alike), both the GREY KNIGHT start    ║
-- ║  screen. :GreyKnightStyle oled|greyknight switches and keeps ║
-- ║  the choice for this machine; before it: the                 ║
-- ║  vim.g.greyknight_style (init.lua), then $GREYKNIGHT_STYLE;  ║
-- ║  else OLED.                                                  ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

M.STYLES = { "oled", "greyknight" }
M.DEFAULT = "oled"
--- Where :GreyKnightStyle keeps the choice - this machine's, in no repository
M.FILE = vim.fn.stdpath("data") .. "/greyknight-style"

--- cyberdream's dark palette on true black: its accents as they are, the backgrounds black and near-black (the
--- floats, the cursor line and the selection still stand apart), the text a little off white - pure white on pure
--- black glares. Light (:CyberdreamToggleMode) stays cyberdream's own.
M.PALETTE = {
  default = {
    bg = "#000000", bg_alt = "#0a0b0c", bg_highlight = "#1c1f23", fg = "#e8e8e8",
    grey = "#7b8496",    -- comments
    blue = "#5ea1ff",    -- functions, folders
    cyan = "#5ef1ff",    -- booleans, the start screen's entries
    green = "#5eff6c",   -- strings
    yellow = "#f1ff5e",  -- warnings
    orange = "#ffbd5e",  -- keywords, numbers, the start screen's keys
    pink = "#ff5ea0",    -- constants, special
    magenta = "#ff5ef1", -- statements, modules
    purple = "#bd5eff",  -- types, operators
    red = "#ff6e5e",     -- errors
  },
}

--- The selection in the OLED look: white on a strong blue. cyberdream draws it in bg_highlight, which on true black
--- was almost invisible (2026-10-28). A blue under the neon text would hide the blue and purple of functions and
--- types, so the selected text is white: 5.9:1 on this blue, and no accent of the palette is lost in it.
M.SELECTION = { fg = "#ffffff", bg = "#2b63b8" }

--- The style in use: vim.g.greyknight_style, $GREYKNIGHT_STYLE, the choice kept by :GreyKnightStyle, else OLED
function M.current()
  -- one after the other: in a list an unset vim.g.greyknight_style is nil, and ipairs stopped before $GREYKNIGHT_STYLE
  local function valid(s) return type(s) == "string" and vim.tbl_contains(M.STYLES, s) end
  if valid(vim.g.greyknight_style) then return vim.g.greyknight_style end
  if valid(vim.env.GREYKNIGHT_STYLE) then return vim.env.GREYKNIGHT_STYLE end
  local ok, lines = pcall(vim.fn.readfile, M.FILE)
  local kept = ok and vim.trim(lines[1] or "") or ""
  return vim.tbl_contains(M.STYLES, kept) and kept or M.DEFAULT
end

--- cyberdream's `colors` for the style (none: its own)
function M.palette(style)
  return (style or M.current()) == "oled" and vim.deepcopy(M.PALETTE) or {}
end

M.HEADER = table.concat({
  " ██████╗ ██████╗ ███████╗██╗   ██╗    ██╗  ██╗███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗",
  "██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝    ██║ ██╔╝████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝",
  "██║  ███╗██████╔╝█████╗   ╚████╔╝     █████╔╝ ██╔██╗ ██║██║██║  ███╗███████║   ██║",
  "██║   ██║██╔══██╗██╔══╝    ╚██╔╝      ██╔═██╗ ██║╚██╗██║██║██║   ██║██╔══██║   ██║",
  "╚██████╔╝██║  ██║███████╗   ██║       ██║  ██╗██║ ╚████║██║╚██████╔╝██║  ██║   ██║",
  " ╚═════╝ ╚═╝  ╚═╝╚══════╝   ╚═╝       ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝",
}, "\n")

--- The start screen's header (snacks.dashboard sections, read when it draws)
function M.dashboard_header()
  return { { header = M.HEADER, padding = 2 } }
end

--- The theme in the style's colors (cyberdream's options: plugins/colorscheme.lua)
function M.apply(opts)
  opts = vim.tbl_deep_extend("force", opts or vim.g.cyberdream_opts or {}, {})
  opts.colors = M.palette()
  -- the selection's colors in OLED only; a switch to greyknight takes them out of the options cyberdream kept
  opts.highlights = opts.highlights or {}
  local selection = M.current() == "oled" and vim.deepcopy(M.SELECTION) or nil
  opts.highlights.Visual, opts.highlights.VisualNOS = selection, selection and vim.deepcopy(selection)
  require("cyberdream").setup(opts)
  vim.cmd.colorscheme("cyberdream")
end

--- Switch the look - kept for this machine; the theme now, the start screen drawn again
function M.set(style)
  if not vim.tbl_contains(M.STYLES, style) then
    return vim.notify(("No such style: %s (%s)"):format(tostring(style), table.concat(M.STYLES, ", ")), vim.log.levels.WARN)
  end
  vim.fn.mkdir(vim.fs.dirname(M.FILE), "p")
  vim.fn.writefile({ style }, M.FILE)
  local forced = vim.g.greyknight_style or vim.env.GREYKNIGHT_STYLE
  if forced and forced ~= style then
    vim.notify(("Kept %s - yet %s chooses %s here"):format(style,
      vim.g.greyknight_style and "vim.g.greyknight_style" or "$GREYKNIGHT_STYLE", forced), vim.log.levels.WARN)
  end
  M.apply()
  pcall(function() Snacks.dashboard.update() end)
end

vim.api.nvim_create_user_command("GreyKnightStyle", function(o)
  if o.args == "" then return vim.notify("Style: " .. M.current() .. " (" .. table.concat(M.STYLES, ", ") .. ")") end
  M.set(o.args)
end, { nargs = "?", complete = function() return M.STYLES end, desc = "The look: oled (true black) or greyknight (cyberdream's grey)" })

return M
