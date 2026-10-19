-- ╔══════════════════════════════════════════════════════════════╗
-- ║  AI Dashboard bridge (optional)                              ║
-- ║  Active only inside a Dev Environment session of the AI      ║
-- ║  Dashboard, whose tmux session sets AIDASH_URL, AIDASH_TOKEN ║
-- ║  and AIDASH_WS. Everywhere else init.lua never loads it.     ║
-- ╚══════════════════════════════════════════════════════════════╝
-- What a terminal editor cannot do on its own, done by the browser tab that shows this session:
--   :AidashPreview [port] [path]  a dev server (127.0.0.1:<port> on the Pi) next to the editor
--   :AidashOpen <url>             localhost URLs → preview, others → a link (also gx, vim.ui.open)
--   :AidashDownload [file]        the file to the laptop (default: current buffer / oil entry)
--   :AidashUpload [dir]           files from the laptop into dir (default: oil dir / buffer's dir)
--   :AidashNotify <message>       a notification in the browser (also when the tab is hidden)
-- Clipboard: "+y goes to the laptop over OSC 52 (as in any SSH terminal); "+p uses the last yank
-- here — paste from the laptop with Ctrl+Shift+V (browsers cannot answer OSC 52 reads).
-- Keys: <leader>W… (which-key group "Web (dashboard)").

local M = {}

function M.active()
  return (vim.env.AIDASH_URL or "") ~= "" and (vim.env.AIDASH_TOKEN or "") ~= ""
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Dashboard" })
end

--- POST <AIDASH_URL>/<action> with a JSON body. The token stays in the environment: curl reads
--- it with --variable, so it never shows up in the process list. Returns the vim.system object.
function M.call(action, payload, on_ok)
  local cmd = {
    "curl", "-sk", "--max-time", "15",
    "--variable", "%AIDASH_TOKEN", "--expand-header", "Authorization: Bearer {{AIDASH_TOKEN}}",
    "-H", "Content-Type: application/json", "--data-binary", "@-",
    vim.env.AIDASH_URL .. "/" .. action,
  }
  local body = vim.json.encode(payload and next(payload) and payload or vim.empty_dict())
  return vim.system(cmd, { stdin = body, text = true }, function(res)
    vim.schedule(function()
      local ok, answer = pcall(vim.json.decode, res.stdout or "")
      if res.code ~= 0 or not ok or type(answer) ~= "table" then
        local why = (res.stderr or "") ~= "" and res.stderr or ("curl exit " .. res.code)
        return notify("Dashboard not reachable: " .. vim.trim(why), vim.log.levels.ERROR)
      end
      if not answer.ok then return notify(answer.error or "request failed", vim.log.levels.WARN) end
      if answer.browsers == 0 then notify("No browser has this workspace open", vim.log.levels.WARN) end
      if on_ok then on_ok(answer) end
    end)
  end)
end

-- ── Paths: current buffer, or the entry / folder under the cursor in oil ───────

local function oil_dir()
  if vim.bo.filetype ~= "oil" then return nil end
  local ok, oil = pcall(require, "oil")
  return ok and oil.get_current_dir() or nil
end

local function current_file()
  local dir = oil_dir()
  if dir then
    local entry = require("oil").get_cursor_entry()
    return entry and entry.type == "file" and (dir .. entry.name) or nil
  end
  local name = vim.api.nvim_buf_get_name(0)
  return name ~= "" and vim.fn.filereadable(name) == 1 and name or nil
end

local function current_dir()
  local dir = oil_dir()
  if dir then return dir end
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and vim.bo.buftype == "" then return vim.fn.fnamemodify(name, ":p:h") end
  return vim.fn.getcwd()
end

-- ── Actions ───────────────────────────────────────────────────────────────────

function M.preview(port, path)
  if port then return M.call("preview", { port = tonumber(port), path = path or "/" }) end
  M.call("ports", nil, function(answer)
    local ports = answer.ports or {}
    if #ports == 0 then return notify("No dev server is listening (start it, then :AidashPreview <port>)", vim.log.levels.WARN) end
    if #ports == 1 then return M.preview(ports[1].port) end
    vim.ui.select(ports, {
      prompt = "Preview which port?",
      format_item = function(p) return string.format("%5d  %s", p.port, p.process or "") end,
    }, function(choice) if choice then M.preview(choice.port) end end)
  end)
end

function M.open(url) return M.call("open", { url = url }) end

function M.download(file)
  file = file and vim.fn.fnamemodify(file, ":p") or current_file()
  if not file then return notify("No file here to download", vim.log.levels.WARN) end
  M.call("download", { path = file }, function() notify("Download: " .. vim.fn.fnamemodify(file, ":t")) end)
end

function M.upload(dir)
  dir = dir and vim.fn.fnamemodify(dir, ":p") or current_dir()
  M.call("upload", { dir = dir }, function() notify("Choose the files in the browser → " .. vim.fn.fnamemodify(dir, ":~:.")) end)
end

function M.notify(message, title) return M.call("notify", { message = message, title = title or "GreyKnight" }) end

-- ── Setup ─────────────────────────────────────────────────────────────────────

function M.setup()
  if not M.active() then return end

  -- Clipboard: copy over OSC 52 (tmux passes it to the page), paste the last copy from here
  local osc52 = require("vim.ui.clipboard.osc52")
  local last = { ["+"] = { { "" }, "v" }, ["*"] = { { "" }, "v" } }
  local function copy(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype) last[reg] = { lines, regtype }; send(lines, regtype) end
  end
  local function paste(reg) return function() return last[reg] end end
  vim.g.clipboard = {
    name = "OSC 52 (AI Dashboard)",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }

  -- URLs (gx, plugins) open in the browser; localhost dev servers become a preview
  local ui_open = vim.ui.open
  vim.ui.open = function(target, opt)
    if type(target) == "string" and target:match("^https?://") then return M.open(target), nil end
    return ui_open(target, opt)
  end

  local cmd = vim.api.nvim_create_user_command
  cmd("AidashPreview", function(o) M.preview(o.fargs[1], o.fargs[2]) end, { nargs = "*", desc = "Dashboard: preview a dev server" })
  cmd("AidashOpen", function(o) M.open(o.args) end, { nargs = 1, desc = "Dashboard: open a URL in the browser" })
  cmd("AidashDownload", function(o) M.download(o.args ~= "" and o.args or nil) end, { nargs = "?", complete = "file", desc = "Dashboard: download to this computer" })
  cmd("AidashUpload", function(o) M.upload(o.args ~= "" and o.args or nil) end, { nargs = "?", complete = "dir", desc = "Dashboard: upload from this computer" })
  cmd("AidashNotify", function(o) M.notify(o.args) end, { nargs = "+", desc = "Dashboard: browser notification" })

  local map = vim.keymap.set
  map("n", "<leader>Wp", M.preview, { desc = "Preview dev server" })
  map("n", "<leader>Wd", function() M.download() end, { desc = "Download file" })
  map("n", "<leader>Wu", function() M.upload() end, { desc = "Upload files here" })
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if ok then wk.add({ { "<leader>W", group = "Web (dashboard)" } }) end
    end,
  })
end

return M
