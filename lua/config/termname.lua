-- ╔══════════════════════════════════════════════════════════════╗
-- ║  A terminal's name for the statusline: an agent's own -      ║
-- ║  "OpenCode", "Qwen Code #2" -, else the program and          ║
-- ║  toggleterm's number ("pwsh #2", "bash"). Not the buffer's   ║
-- ║  name: term://<cwd>//<pid>:<the whole command line> plus     ║
-- ║  toggleterm's mark (&::toggleterm::1, ;#toggleterm#1).       ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

--- The program a terminal buffer runs, from its name: "opencode" for term://C:\x//1:"C:\...\opencode.CMD"&::toggleterm::1
function M.program(bufname)
  local cmd = bufname:match("^term://.-//%d+:(.*)$")
  if not cmd then return nil end
  cmd = cmd:gsub(";#toggleterm#%d+$", ""):gsub("&::toggleterm::%d+$", "")
  local prog = cmd:match('^"([^"]+)"') or cmd:match("^'([^']+)'") or cmd:match("^(%S+)") or ""
  -- without its folder - / and \ on any system - and without a Windows program's extension (python3.12 keeps its own)
  local name = prog:match("[^/\\]+$") or ""
  for _, ext in ipairs({ ".exe", ".cmd", ".bat", ".com", ".ps1" }) do
    if #name > #ext and name:sub(-#ext):lower() == ext then
      name = name:sub(1, #name - #ext)
      break
    end
  end
  return name ~= "" and name or nil
end

--- The name of terminal buffer `buf` (0: the current one)
function M.name(buf)
  if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
  local id = vim.b[buf].toggle_number
  if id then
    local ok, term = pcall(function() return require("toggleterm.terminal").get(id, true) end)
    if ok and term and type(term.display_name) == "string" and term.display_name ~= "" then
      -- an agent working in another folder than Neovim's (started before a cd): where
      if term.gk_agent and term.dir and not require("integrations.agent").same_dir(term.dir, vim.fn.getcwd(-1, -1)) then
        return ("%s - in %s"):format(term.display_name, vim.fn.fnamemodify(term.dir, ":~"))
      end
      return term.display_name
    end
  end
  local name = M.program(vim.api.nvim_buf_get_name(buf)) or "terminal"
  return id and (name .. " #" .. id) or name
end

return M
