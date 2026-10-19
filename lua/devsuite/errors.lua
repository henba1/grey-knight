-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Errors in program output -> code locations                 ║
-- ║  Python tracebacks / SyntaxErrors / warnings and bash/sh    ║
-- ║  "line N" errors become quickfix items and inline           ║
-- ║  diagnostics on the lines that failed                       ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

--- Output line without terminal escapes (Python 3.13 colours its tracebacks) and carriage returns.
function M.clean(line)
  line = line:gsub("\27%[[%d;?]*[%a@]", ""):gsub("\27%][^\7\27]*\7", ""):gsub("\27%][^\27]*\27\\", "")
  return (line:gsub("\r", ""))
end

-- Library frames are not where you want to jump
local function is_user_file(path)
  return vim.fn.filereadable(path) == 1
    and not path:find("/site%-packages/") and not path:find("/dist%-packages/")
    and not path:match("^/usr/lib/python") and not path:match("^/usr/local/lib/python")
end

-- Absolute: /x, and on Windows C:\x, C:/x or \\server\share (taking those for relative put the working
-- directory in front of every path a Windows program printed)
local function is_absolute(path)
  return path:match("^/") ~= nil or path:match("^%a:[/\\]") ~= nil or path:match("^\\\\") ~= nil
end

-- Absolute path for a path printed by a program; temp snippet files map back to their source
local function resolve(path, lnum, opts)
  local mapped = opts.map and opts.map[path]
  if mapped then return mapped.file, lnum + mapped.offset end
  if not is_absolute(path) then path = (opts.cwd or vim.fn.getcwd()) .. "/" .. path end
  return vim.fs.normalize(path), lnum
end

--- Error locations in program output.
---@param lines string[] raw output lines
---@param opts { cwd?: string, map?: table<string, { file: string, offset: integer }> }
---@return { filename: string, lnum: integer, text: string, type: "E"|"W"|"I" }[]
function M.parse(lines, opts)
  opts = opts or {}
  local items, frames = {}, {}
  local detail -- pytest's first "E   assert 0 == 4" line of a failure

  -- A traceback ends with the exception line: every frame goes to the quickfix, the innermost
  -- frame in your own code carries the error
  local function close_traceback(message)
    local error_frame
    for i = #frames, 1, -1 do
      if is_user_file(frames[i].filename) then
        error_frame = i
        break
      end
    end
    for i, frame in ipairs(frames) do
      local is_error = i == error_frame
      items[#items + 1] = {
        filename = frame.filename,
        lnum = frame.lnum,
        text = is_error and message or ("called from here" .. (frame.func and (" (" .. frame.func .. ")") or "")),
        type = is_error and "E" or "I",
      }
    end
    frames = {}
  end

  for _, raw in ipairs(lines) do
    local line = M.clean(raw)
    local file, lnum = line:match('^%s*File "(.-)", line (%d+)')
    if file then
      local path, n = resolve(file, tonumber(lnum), opts)
      frames[#frames + 1] = { filename = path, lnum = n, func = line:match(", in (.-)%s*$") }
    elseif #frames > 0 then
      -- indented lines are the code and ^^^ markers of a frame; the first unindented line is the exception
      if line:find("%S") and not line:match("^%s") and not line:match("^Traceback") then close_traceback(vim.trim(line)) end
    else
      local e = line:match("^E%s+(%S.*)$")
      if e then detail = detail or vim.trim(e) end
      local f, n, msg = line:match("^(.-): line (%d+): (.+)$") -- bash
      if not f then f, n, msg = line:match("^([^%s:]+): (%d+): (.+)$") end -- dash / sh
      if f then
        local path, l = resolve(f, tonumber(n), opts)
        if vim.fn.filereadable(path) == 1 then items[#items + 1] = { filename = path, lnum = l, text = msg, type = "E" } end
      else
        -- "x.py:12: message": python warnings, pytest failures ("tests/test_x.py:12: AssertionError")
        local pf, pn, pmsg = line:match("^(.-%.py):(%d+): (.+)$")
        if pf then
          local path, l = resolve(pf, tonumber(pn), opts)
          if is_user_file(path) then
            local warning = pmsg:match("^%u%w*Warning") ~= nil
            local text = (detail and not warning) and (pmsg .. ": " .. detail) or pmsg
            items[#items + 1] = { filename = path, lnum = l, text = text, type = warning and "W" or "E" }
            detail = nil
          end
        end
      end
    end
  end
  if #frames > 0 then close_traceback("(traceback cut off)") end
  return items
end

--- The code location of one output line (for <CR> in the output window), or nil.
function M.location(line, opts)
  line = M.clean(line)
  local file, lnum = line:match('File "(.-)", line (%d+)')
  if not file then file, lnum = line:match("^(.-): line (%d+):") end
  if not file then file, lnum = line:match("^(%a:[/\\][^:]+):(%d+)") end -- Windows: C:\dir\x.py:12
  if not file then file, lnum = line:match("^([^%s:]+):(%d+)") end
  if not file then file, lnum = line:match("^([^%s:]+): (%d+): ") end
  if not file then return nil end
  local path, n = resolve(file, tonumber(lnum), opts or {})
  if vim.fn.filereadable(path) == 1 then return path, n end
end

local SEVERITY = { E = vim.diagnostic.severity.ERROR, W = vim.diagnostic.severity.WARN, I = vim.diagnostic.severity.HINT }

--- Show the items of a run: quickfix list + diagnostics in the namespace of that run
--- (each run target has its own, so a new run replaces only its own marks).
function M.publish(key, title, items)
  local ns = vim.api.nvim_create_namespace("greyknight.run." .. key)
  vim.diagnostic.reset(ns)
  if #items == 0 then return end
  local by_buf = {}
  for _, item in ipairs(items) do
    if item.type ~= "I" then
      local buf = vim.fn.bufadd(item.filename)
      by_buf[buf] = by_buf[buf] or {}
      table.insert(by_buf[buf], {
        lnum = item.lnum - 1,
        col = 0,
        message = item.text,
        severity = SEVERITY[item.type],
        source = "run",
      })
    end
  end
  for buf, diagnostics in pairs(by_buf) do vim.diagnostic.set(ns, buf, diagnostics) end
  vim.fn.setqflist({}, " ", { title = title, items = items })
end

--- Remove the marks of a run target.
function M.clear(key)
  vim.diagnostic.reset(vim.api.nvim_create_namespace("greyknight.run." .. key))
end

return M
