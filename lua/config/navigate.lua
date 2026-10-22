-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Ctrl+Click as in IntelliJ: on a name to its declaration,   ║
-- ║  on the declaration itself to its usages                     ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local WIN = vim.fn.has("win32") == 1

local function notify(msg) vim.notify(msg, vim.log.levels.INFO, { title = "Go to" }) end
local function key(path) local p = vim.fs.normalize(vim.fn.fnamemodify(path, ":p")); return WIN and p:lower() or p end

--- Is the definition `item` (as vim.lsp.util.locations_to_items gives it) where the cursor is: the declaration itself?
local function at_cursor(item, buf, row, col)
  if not item.filename or key(item.filename) ~= key(vim.api.nvim_buf_get_name(buf)) or item.lnum ~= row then return false end
  local from = item.col - 1
  local to = (item.end_lnum == row and item.end_col and item.end_col > item.col) and item.end_col - 1
    or from + math.max(#vim.fn.expand("<cword>"), 1)
  return col >= from and col < to
end

--- Each place once: two servers of a file (angularls and ts_ls in a .ts file) both name the same declaration - one
--- place, a jump, not a list of two
local function unique(items)
  local seen, out = {}, {}
  for _, item in ipairs(items or {}) do
    local id = ("%s:%d:%d"):format(item.filename and key(item.filename) or tostring(item.bufnr), item.lnum or 0, item.col or 0)
    if not seen[id] then
      seen[id] = true
      out[#out + 1] = item
    end
  end
  return out
end

--- To one place as gd does: the jump list (<C-o> comes back) and the tag stack (<C-t>)
local function jump(item)
  local win = vim.api.nvim_get_current_win()
  local from = vim.fn.getpos(".")
  from[1] = vim.api.nvim_get_current_buf()
  local tagname = vim.fn.expand("<cword>")
  local buf = item.bufnr or vim.fn.bufadd(item.filename)
  vim.cmd("normal! m'")
  vim.fn.settagstack(win, { items = { { tagname = tagname, from = from } } }, "t")
  vim.bo[buf].buflisted = true
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { item.lnum, math.max(item.col - 1, 0) })
  vim.cmd("normal! zv")
end

--- Several places: the quickfix list, as gd and gr show them
local function show(list, items)
  vim.fn.setqflist({}, " ", { title = list.title, items = items, context = list.context })
  vim.cmd("botright copen")
end

--- The usages of the name at the cursor, without its declaration; just one: there
function M.usages()
  local name = vim.fn.expand("<cword>")
  vim.lsp.buf.references({ includeDeclaration = false }, {
    on_list = function(list)
      local items = unique(list.items)
      if #items == 0 then return notify("No usages of " .. name) end
      if #items == 1 then return jump(items[1]) end
      show(list, items)
    end,
  })
end

--- IntelliJ's Ctrl+Click (Ctrl+B): the declaration of the name at the cursor; on the declaration itself its usages.
--- Without a language server that finds definitions Vim's gd (the first use in the file); in help the tag.
function M.declaration_or_usages()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == "help" then return pcall(vim.cmd.normal, { vim.keycode("<C-]>"), bang = true }) end
  if vim.bo[buf].buftype ~= "" then return end
  if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/definition" }) == 0 then
    return pcall(vim.cmd.normal, { "gd", bang = true })
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.lsp.buf.definition({
    on_list = function(list)
      local items = unique(list.items)
      if #items == 0 then return notify("No declaration found for " .. vim.fn.expand("<cword>")) end
      local here = true
      for _, item in ipairs(items) do here = here and at_cursor(item, buf, row, col) end
      if here then return M.usages() end
      if #items == 1 then return jump(items[1]) end
      show(list, items)
    end,
  })
end

--- Ctrl+Click: the cursor to the click, then the above - only the click when it is not on a name (after the end of a
--- line, a space, a status line)
function M.ctrl_click()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or not vim.api.nvim_win_is_valid(pos.winid) then return end
  vim.api.nvim_set_current_win(pos.winid)
  if pos.line == 0 then return end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local text = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1] or ""
  vim.api.nvim_win_set_cursor(pos.winid, { pos.line, math.max(math.min(pos.column, #text) - 1, 0) })
  if pos.column < 1 or pos.column > #text then return end
  local char = vim.fn.strcharpart(text:sub(pos.column), 0, 1)
  if vim.fn.match(char, [[\k]]) ~= 0 then return end
  M.declaration_or_usages()
end

return M
