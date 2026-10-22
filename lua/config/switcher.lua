-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Recent buffers - IntelliJ's Ctrl+Tab: the list starts on   ║
-- ║  the buffer before this one, Tab goes further back           ║
-- ╚══════════════════════════════════════════════════════════════╝
-- The order is the one you entered them in. getbufinfo()'s lastused (the buffer picker's order) counts seconds: two
-- buffers entered in the same second came in either order.
local M = {}

local seen, tick = {}, 0 -- buffer -> when it was entered last

function M.setup()
  local group = vim.api.nvim_create_augroup("greyknight.switcher", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      tick = tick + 1
      seen[ev.buf] = tick
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(ev) seen[ev.buf] = nil end })
end

--- The listed file buffers, the one entered last first
function M.recent()
  local bufs, used = {}, {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
      bufs[#bufs + 1] = buf
      used[buf] = vim.fn.getbufinfo(buf)[1].lastused
    end
  end
  table.sort(bufs, function(a, b)
    local sa, sb = seen[a] or 0, seen[b] or 0
    if sa ~= sb then return sa > sb end
    if used[a] ~= used[b] then return used[a] > used[b] end
    return a > b
  end)
  return bufs
end

--- The picker: Enter opens the marked buffer - at first the one before this one; Tab / Shift+Tab (Ctrl+Tab) go
--- further back / forward again, typing filters, dd (<C-x>) deletes a buffer
function M.pick()
  local cur, alt = vim.api.nvim_get_current_buf(), vim.fn.bufnr("#")
  local items = {}
  for _, buf in ipairs(M.recent()) do
    local info = vim.fn.getbufinfo(buf)[1]
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local name = vim.api.nvim_buf_get_name(buf)
    items[#items + 1] = {
      buf = buf,
      file = name,
      name = name,
      text = name,
      buftype = "",
      filetype = vim.bo[buf].filetype,
      info = info,
      flags = (buf == cur and "%" or buf == alt and "#" or "") .. (info.changed == 1 and "+" or ""),
      pos = mark[1] ~= 0 and mark or { info.lnum, 0 },
    }
  end
  if #items == 0 then return vim.notify("No file buffers", vim.log.levels.INFO, { title = "Recent buffers" }) end
  local start = (items[1].buf == cur and #items > 1) and 2 or 1
  local down, up = { "list_down", mode = { "i", "n" } }, { "list_up", mode = { "i", "n" } }
  return Snacks.picker.pick({
    source = "recent_buffers",
    title = "Recent buffers",
    items = items,
    format = "buffer",
    preview = "file",
    sort = { fields = { "score:desc", "idx" } }, -- filtered: equal matches stay in the order of use
    on_show = function(picker) picker.list:view(start) end,
    win = {
      input = {
        keys = {
          ["<Tab>"] = down,
          ["<S-Tab>"] = up,
          ["<C-Tab>"] = down,
          ["<C-S-Tab>"] = up,
          ["<c-x>"] = { "bufdelete", mode = { "n", "i" } },
        },
      },
      list = { keys = { ["<Tab>"] = "list_down", ["<S-Tab>"] = "list_up", ["dd"] = "bufdelete" } },
    },
  })
end

return M
