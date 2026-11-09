-- ╔══════════════════════════════════════════════════════════════╗
-- ║  The landing layout: the windows `gk` opens with when it     ║
-- ║  starts without files (landing in ~/.config/greyknight.lua): ║
-- ║  the file tree on the left, the start page in the middle -   ║
-- ║  a file opened from the tree takes its place - and the       ║
-- ║  agent's pane on the right, a new session (or the shell of   ║
-- ║  terminal mode). :GreyKnightLanding builds what of it is     ║
-- ║  missing, at any time; the windows you have stay.            ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local function settings() return require("config.settings") end
local function agent() return require("integrations.agent") end

--- Whether the tree (snacks' explorer) is open in this tab: its picker
function M.explorer()
  local ok, list = pcall(function() return Snacks.picker.get({ source = "explorer", tab = true }) end)
  return ok and list and list[1] or nil
end

local function width(w)
  w = w or 0.4
  return math.max(20, math.floor(w < 1 and vim.o.columns * w or w))
end

-- The window in the middle: the current one, unless it is the tree, the pane, a terminal or a float - then the
-- first window with a file or the start page
local function center()
  local function fits(win)
    if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then return false end
    if vim.w[win].snacks_layout then return false end -- the tree's windows
    local buf = vim.api.nvim_win_get_buf(win)
    return vim.bo[buf].buftype == "" or vim.bo[buf].filetype == "snacks_dashboard"
  end
  local cur = vim.api.nvim_get_current_win()
  if fits(cur) then return cur end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if fits(win) then return win end
  end
  return cur
end

-- The start page's window is where the tree opens files: snacks takes a window with a file for that, and next to the
-- start page there is none - the file went into the agent's pane. Once it shows a file it is such a window anyway.
local function main_window(win)
  if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then return end
  vim.w[win].snacks_main = true
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("greyknight.landing_main", { clear = true }),
    callback = function()
      if not vim.api.nvim_win_is_valid(win) then return true end
      if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
        vim.w[win].snacks_main = nil
        return true
      end
    end,
  })
end

--- Build the layout (`opts`: the settings' landing, by default); what is open already stays as it is
function M.open(opts)
  opts = vim.tbl_extend("force", settings().get("landing") or {}, opts or {})
  local mid = center()
  vim.api.nvim_set_current_win(mid)
  main_window(mid)
  if opts.left == "explorer" and not M.explorer() then
    -- not entered unless the cursor goes there: it focused its list when it showed, after the cursor was elsewhere
    pcall(function() Snacks.explorer({ enter = opts.focus == "left" }) end)
  end
  vim.api.nvim_set_current_win(mid)
  local pane = agent().pane()
  if not pane and opts.right == "agent" then
    agent().open_pane()
  elseif not pane and opts.right == "terminal" then
    require("config.terminal").show()
  end
  pane = agent().pane()
  if pane then pcall(vim.api.nvim_win_set_width, pane, width(opts.right_width)) end
  M.focus(opts.focus, mid)
end

--- The cursor to the window `where` says: "left" (the tree), "center", "right" (the pane). Twice deferred: after what
--- the tree and the pane schedule as they open
function M.focus(where, mid)
  local function go()
    if where == "right" then
      local pane = agent().pane()
      if pane then
        vim.api.nvim_set_current_win(pane)
        return vim.cmd("startinsert!")
      end
    elseif where == "left" then
      local tree = M.explorer()
      if tree then return pcall(function() tree:focus("list") end) end
    end
    if mid and vim.api.nvim_win_is_valid(mid) then
      vim.cmd("stopinsert")
      vim.api.nvim_set_current_win(mid)
    end
  end
  vim.schedule(function() vim.schedule(go) end)
end

--- At the start: the layout when the settings ask for it and Neovim started without files, with a screen (not
--- headless, not reading stdin) - after the start page opened (snacks: on UIEnter)
function M.at_start()
  if not settings().get("landing.enabled") then return end
  if vim.fn.argc(-1) > 0 then return end
  local buf = vim.api.nvim_get_current_buf()
  local dashboard = vim.bo[buf].filetype == "snacks_dashboard"
  local empty = vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
  if not (dashboard or empty) then return end
  M.open()
end

function M.setup()
  vim.api.nvim_create_user_command("GreyKnightLanding", function() M.open() end,
    { desc = "The landing layout: the tree, the start page, the agent's pane (what is missing of it)" })
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("greyknight.landing", { clear = true }),
    once = true,
    callback = function() vim.schedule(M.at_start) end,
  })
end

return M
