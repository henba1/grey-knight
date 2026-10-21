-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Markdown links: follow them in Neovim                       ║
-- ╚══════════════════════════════════════════════════════════════╝
-- gd / Enter on a link in a markdown buffer (keys: after/ftplugin/markdown.lua):
--   [text](#heading)          the heading in this file (tables of contents work)
--   [text](USAGE.md#heading)  that file at that heading (read-only when you came from a read-only doc)
--   [text](https://...)       the browser
-- Ctrl+o jumps back. Anchors are built like GitLab does: lowercase, punctuation dropped, spaces -> "-",
-- runs of "-" folded into one, a repeated heading gets "-1", "-2", ... GitHub's form (no folding) works too.
local M = {}

--- The anchor of a heading text; github = true keeps runs of "-" like GitHub does
function M.slug(text, github)
  local s = vim.fn.tolower(text)
  s = s:gsub("%[([^%]]*)%]%b()", "%1") -- [text](url) -> text
  s = s:gsub("%p", function(c) return (c == "-" or c == "_") and c or "" end)
  s = s:gsub("\226[\128-\191][\128-\191]", "") -- U+2000-U+2FFF: dashes, quotes, arrows, symbols
  s = s:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", "") -- emoji
  s = s:gsub("\239\184\143", "") -- emoji variation selector
  s = s:gsub(" ", "-")
  if not github then s = s:gsub("%-%-+", "-") end
  return s
end

-- Calls fn(lnum, line) for every line outside fenced code blocks
local function text_lines(lines, fn)
  local fence
  for lnum, line in ipairs(lines) do
    local f = line:match("^%s*([`~][`~][`~])")
    if f then
      if not fence then fence = f elseif f == fence then fence = nil end
    elseif not fence then
      fn(lnum, line)
    end
  end
end

--- { [anchor] = line } for the headings in `lines`; style "gitlab" or "github" (default: both)
function M.anchors(lines, style)
  local found = {}
  for _, github in ipairs({ false, true }) do
    if style == nil or style == (github and "github" or "gitlab") then
      local count = {}
      text_lines(lines, function(lnum, line)
        local text = line:match("^#+%s+(.-)%s*#*%s*$")
        if text and text ~= "" then
          local base = M.slug(text, github)
          local n = count[base]
          count[base] = (n or 0) + 1
          local anchor = n and (base .. "-" .. n) or base
          if found[anchor] == nil then found[anchor] = lnum end
        end
      end)
    end
  end
  return found
end

--- Links in `lines`, not in fenced or inline code: { lnum, s, e, target } (byte columns from 1). The target as a path:
--- <my notes.md> (spaces) and %20, %C3%BC decoded - CommonMark's ways to write a name with spaces or umlauts
--- (2026-10-21: the target ended at the first space, %20 stayed). URLs (https: ...) stay as they are.
function M.links(lines)
  local out = {}
  text_lines(lines, function(lnum, line)
    local masked = line:gsub("`[^`]*`", function(code) return (" "):rep(#code) end)
    local init = 1
    while true do
      local s, e, inner = masked:find("%[[^%]]*%]%(([^%)]*)%)", init) -- [text](<target> "title") or [text](target "title")
      if not s then break end
      local target = inner:match("^%s*<([^>]+)>") or inner:match("^%s*([^%s<>]+)")
      if target then
        if not target:match("^%a[%w+.-]*:") then
          target = target:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
        end
        out[#out + 1] = { lnum = lnum, s = s, e = e, target = target }
      end
      init = e + 1
    end
  end)
  return out
end

--- A doc read-only, q closes it: the docs picker (<leader>gd) and links followed from such a doc
function M.read_only(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  vim.bo[buf].readonly = true
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close doc" })
end

local function warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "Markdown link" }) end

--- Follow the link under the cursor; `fallback` runs when there is none (the key's usual meaning)
function M.follow(fallback)
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local link
  for _, l in ipairs(M.links({ vim.api.nvim_get_current_line() })) do
    if col >= l.s and col <= l.e then link = l end
  end
  if not link then
    if fallback then fallback() end
    return
  end
  if link.target:match("^%a[%w+.-]*:") then return vim.ui.open(link.target) end -- https:, mailto: ...
  local file, anchor = link.target:match("^([^#]*)#?(.*)$")
  local from = vim.api.nvim_get_current_buf()
  vim.cmd("normal! m'") -- Ctrl+o comes back here
  if file ~= "" then
    local path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(vim.api.nvim_buf_get_name(from)), file))
    if vim.fn.filereadable(path) ~= 1 then return warn("No file " .. file) end
    local read_only = vim.bo[from].readonly and not vim.bo[from].modifiable
    vim.cmd.edit(vim.fn.fnameescape(path))
    if read_only then M.read_only(0) end
  end
  if anchor == "" then return end
  local lnum = M.anchors(vim.api.nvim_buf_get_lines(0, 0, -1, false))[vim.fn.tolower(anchor)]
  if not lnum then return warn("No heading #" .. anchor) end
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.cmd("normal! zvzt")
end

return M
