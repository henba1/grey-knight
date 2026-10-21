-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Clipboard: over SSH (and in the dashboard's terminal) copy  ║
-- ║  with OSC 52, paste the last copy; locally Neovim's choice   ║
-- ╚══════════════════════════════════════════════════════════════╝
-- OSC 52 puts a copy into the clipboard of the computer the terminal runs on. Reading that clipboard back works in a
-- few terminals only; in the others (Windows Terminal, the dashboard's web terminal) Neovim waited up to 10 s for an
-- answer on every p - clipboard=unnamedplus sends each p there. So p pastes the last copy made here; text from the
-- computer comes in with the terminal's own paste (Ctrl+Shift+V). Locally Neovim picks the tool itself: wl-clipboard,
-- xclip / xsel, the Windows clipboard (2026-10-21: the hand-made choice took xclip wherever DISPLAY was set,
-- installed or not - vim.fn.executable() is 0 or 1, both true in Lua).
local M = {}

--- A clipboard provider: copies go out with OSC 52, a paste is the last copy
---@param name? string
function M.osc52(name)
  local last = { ["+"] = { { "" }, "v" }, ["*"] = { { "" }, "v" } }
  local function copy(reg)
    return function(lines, regtype)
      last[reg] = { lines, regtype }
      require("vim.ui.clipboard.osc52").copy(reg)(lines, regtype)
    end
  end
  local function paste(reg) return function() return last[reg] end end
  return {
    name = name or "OSC 52",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
end

--- The provider for this session: OSC 52 over SSH, else none - Neovim picks the local tool
---@param getenv? fun(name: string): string?
function M.provider(getenv)
  getenv = getenv or os.getenv
  if (getenv("SSH_TTY") or "") ~= "" then return M.osc52("OSC 52 (SSH)") end
end

return M
