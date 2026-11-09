-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Your settings: one Lua file outside the repository -        ║
-- ║  ~/.config/greyknight.lua (beside the config folder, which   ║
-- ║  is this repository; $GREYKNIGHT_CONFIG: another file). It   ║
-- ║  returns a table: the look, the agent, easy mode at start,   ║
-- ║  the landing layout, the terminal, options and keys.         ║
-- ║  :GreyKnightConfig opens it (the first time: a template      ║
-- ║  with every setting); saved, options and keys apply at once. ║
-- ╚══════════════════════════════════════════════════════════════╝
-- What the file leaves out stays as before: the environment ($GREYKNIGHT_AGENT, $GREYKNIGHT_STYLE), the choices kept
-- by :GreyKnightStyle and the agents page, GreyKnight's own defaults. What it sets comes first.
local M = {}

--- The settings and their defaults. nil: not set - the environment or a kept choice decides.
M.DEFAULTS = {
  style = nil,     -- "oled" | "greyknight" (:GreyKnightStyle switches for the session)
  easymode = false, -- easy mode (Alt+N) on from the start
  agent = {
    backend = nil, -- "claude" | "opencode" | "qwen" (else $GREYKNIGHT_AGENT, the agents page's choice, what is installed)
    link = true,   -- connect new sessions to Neovim: its tools, the edits as diffs
  },
  -- The windows `gk` opens with when it starts without files: the tree on the left, the start page in the middle (a
  -- file opened from the tree takes its place), the agent's pane on the right. :GreyKnightLanding builds it again.
  landing = {
    enabled = false,
    left = "explorer", -- "explorer" | false
    right = "agent",   -- "agent" (a new session) | "terminal" (a shell) | false
    right_width = 0.4, -- the right pane: a share of the screen (below 1) or columns
    focus = "center",  -- the window with the cursor: "left" | "center" | "right"
  },
  -- A shell in the agent's pane: `key` flips the pane between the agent and the shell (false: no key)
  terminal = {
    key = "<M-t>",
    shell = nil, -- the command (default: 'shell')
  },
  options = {}, -- Neovim's options, e.g. { relativenumber = false, colorcolumn = "120" }
  -- Keys, as in lazy.nvim's specs: { lhs, rhs, mode = "n", desc = "..." }. rhs: a function, keys, a command, one of
  -- the actions (M.ACTIONS: "terminal", "landing", "easymode", "agent", "explorer", "dashboard", "config"), or false -
  -- GreyKnight's key of that name is gone.
  keys = {},
}

M.FILE_DEFAULT = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "greyknight.lua")

--- The file of the settings: $GREYKNIGHT_CONFIG, else greyknight.lua beside the config folder (~/.config/greyknight.lua)
function M.file()
  local own = vim.env.GREYKNIGHT_CONFIG
  return (own and own ~= "") and vim.fn.expand(own) or M.FILE_DEFAULT
end

M.values = vim.deepcopy(M.DEFAULTS)

-- scheduled: read before the plugins, the notifier is not there yet (a plain message wanted Enter)
local function warn(msg) vim.schedule(function() vim.notify(msg, vim.log.levels.WARN, { title = "GreyKnight settings" }) end) end

-- Settings of the file that are not GreyKnight's, or of another type: a word each, and they are left out. Tables of
-- their own (options, keys) are taken as they are.
local FREE = { options = true, keys = true }
local function check(user, defaults, path, problems)
  for k, v in pairs(user) do
    local name = path .. k
    local default = defaults[k]
    if defaults[k] == nil and not (M.KNOWN_NIL[name]) then
      problems[#problems + 1] = ("%s: no such setting"):format(name)
      user[k] = nil
    elseif type(default) == "table" and not FREE[name] then
      if type(v) ~= "table" then
        problems[#problems + 1] = ("%s: a table, not %s"):format(name, type(v))
        user[k] = nil
      else
        check(v, default, name .. ".", problems)
      end
    elseif default ~= nil and type(v) ~= type(default) and not (v == false and M.MAY_BE_FALSE[name]) then
      problems[#problems + 1] = ("%s: %s, not %s"):format(name, type(default), type(v))
      user[k] = nil
    end
  end
end
-- Settings whose default is nil (unset), and the ones false switches off
M.KNOWN_NIL = { style = true, ["agent.backend"] = true, ["terminal.shell"] = true }
M.MAY_BE_FALSE = { ["landing.left"] = true, ["landing.right"] = true, ["terminal.key"] = true }

--- Read the file: the settings over the defaults. A file that fails (a syntax error, not a table) is a word, and the
--- defaults stand. Returns the settings.
function M.load()
  local values, path = vim.deepcopy(M.DEFAULTS), M.file()
  if vim.uv.fs_stat(path) then
    local ok, user = pcall(dofile, path)
    if not ok then
      warn(("%s did not load - GreyKnight's defaults for now:\n%s"):format(vim.fn.fnamemodify(path, ":~"), tostring(user)))
    elseif user ~= nil and type(user) ~= "table" then
      warn(("%s returns %s, not a table of settings"):format(vim.fn.fnamemodify(path, ":~"), type(user)))
    elseif user then
      local problems = {}
      check(user, M.DEFAULTS, "", problems)
      if #problems > 0 then
        warn(("%s - left out:\n%s"):format(vim.fn.fnamemodify(path, ":~"), table.concat(problems, "\n")))
      end
      values = vim.tbl_deep_extend("force", values, user)
      values.keys = user.keys or {} -- a list: not merged by index into the defaults
    end
  end
  M.values = values
  -- the settings other modules read where they were read before: the style, the agent, its link
  if values.style then vim.g.greyknight_style = values.style end
  if values.agent.backend then vim.g.greyknight_agent = values.agent.backend end
  if values.agent.link == false then vim.g.greyknight_agent_link = false end
  return values
end

--- A setting by its path ("landing.right")
function M.get(path)
  local v = M.values
  for part in path:gmatch("[^.]+") do
    if type(v) ~= "table" then return nil end
    v = v[part]
  end
  return v
end

--- Neovim's options of the file (after GreyKnight's own: config/options.lua)
function M.apply_options()
  for name, value in pairs(M.values.options or {}) do
    local ok, err = pcall(function() vim.opt[name] = value end)
    if not ok then warn(("options.%s: %s"):format(name, err)) end
  end
end

--- What a key of the file can name instead of a function
M.ACTIONS = {
  terminal = { function() require("config.terminal").toggle() end, "Terminal: the shell in the agent's pane (again: the agent)" },
  landing = { function() require("config.landing").open() end, "The landing layout: tree, start page, agent" },
  easymode = { function() require("config.easymode").toggle() end, "Easy mode on / off" },
  agent = { function() require("integrations.agent").open_pane() end, "Agent: the pane" },
  explorer = { function() Snacks.explorer() end, "File explorer" },
  dashboard = { function() Snacks.dashboard() end, "Dashboard" },
  config = { function() M.edit() end, "GreyKnight: your settings (~/.config/greyknight.lua)" },
}

--- The keys of the file, over GreyKnight's. Again after a plugin loads: lazy.nvim sets a plugin's own keys then.
function M.apply_keys()
  for i, spec in ipairs(M.values.keys or {}) do
    local ok, err = pcall(function()
      assert(type(spec) == "table" and type(spec[1]) == "string", "{ lhs, rhs, mode = ..., desc = ... }")
      local lhs, rhs = spec[1], spec[2]
      local modes = spec.mode or "n"
      modes = type(modes) == "table" and modes or { modes }
      if rhs == false then
        for _, mode in ipairs(modes) do pcall(vim.keymap.del, mode, lhs) end
        return
      end
      local desc = spec.desc
      if rhs == "terminal" then -- through the agent's window too (integrations/agent.lua, own_keys)
        local keys = require("config.terminal").keys
        if not vim.tbl_contains(keys, lhs) then keys[#keys + 1] = lhs end
      end
      if type(rhs) == "string" and M.ACTIONS[rhs] then rhs, desc = M.ACTIONS[rhs][1], desc or M.ACTIONS[rhs][2] end
      assert(type(rhs) == "string" or type(rhs) == "function", "rhs: a function, keys, an action or false")
      local opts = {}
      for k, v in pairs(spec) do if type(k) == "string" and k ~= "mode" then opts[k] = v end end
      opts.desc = desc or "Your key (greyknight.lua)"
      vim.keymap.set(modes, lhs, rhs, opts)
    end)
    if not ok then warn(("keys[%d]: %s"):format(i, tostring(err):gsub("^.-:%d+: ", ""))) end
  end
end

--- The template of a new settings file: every setting, as GreyKnight has it
M.TEMPLATE = [[
-- GreyKnight: your settings. Saved, options and keys apply at once; the rest with the next start.
-- Leave a setting out (or commented) and GreyKnight's default stands. :GreyKnightConfig opens this file.
return {
  -- style = "oled",          -- the look: "oled" (true black) | "greyknight" (cyberdream's grey)
  easymode = false,           -- easy mode (Alt+N: a plain text editor's keys) on from the start

  agent = {
    -- backend = "claude",    -- "claude" | "opencode" | "qwen" - else the agents page's choice (<leader>al)
    link = true,              -- new sessions get Neovim's tools and show their edits as diffs
  },

  -- The windows `gk` opens with when it starts without files
  landing = {
    enabled = false,
    left = "explorer",        -- "explorer" | false
    right = "agent",          -- "agent" (a new session) | "terminal" (a shell) | false
    right_width = 0.4,        -- a share of the screen (below 1) or columns
    focus = "center",         -- "left" | "center" | "right"
  },

  -- A shell in the agent's pane: the key flips the pane between agent and shell
  terminal = {
    key = "<M-t>",            -- false: no key
    -- shell = "zsh",         -- default: Neovim's 'shell'
  },

  options = {
    -- relativenumber = false,
    -- colorcolumn = "120",
  },

  -- Keys over GreyKnight's, as in lazy.nvim: { lhs, rhs, mode = "n", desc = "..." }. rhs: a function, keys, a command,
  -- an action ("terminal", "landing", "easymode", "agent", "explorer", "dashboard", "config") or false (key gone)
  keys = {
    -- { "<C-t>", "terminal", mode = { "n", "t" } },
    -- { "<C-p>", function() Snacks.picker.files() end, desc = "Files" },
    -- { "<S-h>", false },
  },
}
]]

--- :GreyKnightConfig - the settings file (the first time written from the template)
function M.edit()
  local path = M.file()
  if not vim.uv.fs_stat(path) then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(vim.split(M.TEMPLATE, "\n"), path)
    vim.notify("New settings file: " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO, { title = "GreyKnight settings" })
  end
  vim.cmd.edit({ args = { path }, magic = { file = false } })
end

--- Saved: the file read again; options and keys at once, the look if it changed
function M.reload()
  local style = M.values.style
  M.load()
  M.apply_options()
  M.apply_keys()
  if M.values.style and M.values.style ~= style then pcall(function() require("config.style").apply() end) end
  vim.notify("Settings read again - options and keys apply now; the landing, easy mode and the agent with the next start",
    vim.log.levels.INFO, { title = "GreyKnight settings" })
end

function M.setup()
  vim.api.nvim_create_user_command("GreyKnightConfig", function() M.edit() end,
    { desc = "GreyKnight: your settings (~/.config/greyknight.lua)" })
  local group = vim.api.nvim_create_augroup("greyknight.settings", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", { group = group, callback = function(ev)
    if vim.fs.normalize(vim.fn.fnamemodify(ev.file, ":p")) == vim.fs.normalize(vim.fn.fnamemodify(M.file(), ":p")) then
      M.reload()
    end
  end })
  -- a plugin loaded later (lazy.nvim) sets its own keys: yours again over them
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "LazyLoad", callback = function()
    if #(M.values.keys or {}) > 0 then vim.schedule(M.apply_keys) end
  end })
  M.apply_keys()
end

return M
