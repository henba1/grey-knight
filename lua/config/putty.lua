-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Over SSH from PuTTY: its default keys lose some of ours -  ║
-- ║  the first time a word on the settings that fix it          ║
-- ╚══════════════════════════════════════════════════════════════╝
-- PuTTY's default keyboard settings (2026-10-22, PuTTY 0.85, its bytes fed to Neovim under TERM=xterm): Ctrl+arrows
-- come as plain arrows - nothing on this side can tell them apart; Shift+F11 and Ctrl+F11 as F11 (the debugger's
-- step into); Home / End as the VT220's Find / Select (keymaps.lua maps those). With xterm-style keys every one
-- arrives as itself. docs/ssh.md: "Over SSH (PuTTY)".
local M = {}

-- once on a machine: the state folder (a test run has its own)
M.flag = vim.fn.stdpath("state") .. "/greyknight/putty-hint"

M.TEXT = table.concat({
  "This looks like PuTTY with its default keys (SSH, terminal type xterm): Ctrl+arrows arrive as plain arrows,",
  "Shift+F11 / Ctrl+F11 as F11. In PuTTY: Change Settings, then Save the session -",
  "  Terminal > Keyboard: Shift/Ctrl/Alt with the arrow keys = xterm-style bitmap",
  "  Terminal > Keyboard: The Function keys and keypad = Xterm 216+",
  "  Connection > Data: Terminal-type string = xterm-256color",
  "Until then Alt+arrows resize, <leader>ml lists the bookmarks. docs/ssh.md: Over SSH (PuTTY).",
}, "\n")

--- A session that looks like PuTTY's defaults: over SSH, the terminal type "xterm" - PuTTY's default; Windows
--- Terminal (OpenSSH) and most others say xterm-256color.
function M.looks_like(env)
  env = env or vim.env
  return (env.SSH_CONNECTION or env.SSH_CLIENT or "") ~= "" and env.TERM == "xterm"
end

--- The word, once on this machine; true when it was said now.
function M.show_once(env)
  if not M.looks_like(env) or vim.uv.fs_stat(M.flag) then return false end
  vim.fn.mkdir(vim.fs.dirname(M.flag), "p")
  vim.fn.writefile({ os.date("%Y-%m-%d") }, M.flag)
  vim.notify(M.TEXT, vim.log.levels.INFO, { title = "PuTTY?", timeout = 20000 })
  return true
end

function M.setup()
  -- once the screen is up (a notice before that is lost); a headless Neovim has no UI and says nothing
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("greyknight.putty", { clear = true }),
    once = true,
    callback = function() vim.defer_fn(function() pcall(M.show_once) end, 500) end,
  })
end

return M
