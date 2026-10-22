-- Grey Knight test harness: test(), helpers for buffers / terminals / tasks, report().
-- report() exits Neovim with status 1 when a test failed, so tests/run.sh (and scripts) can rely on it.
local H = { results = {}, passed = 0, failed = 0, skipped = 0 }
local SKIP = {} -- metatable of the error H.skip() raises

-- Warnings and errors that the tests provoke on purpose do not belong in the real error log
pcall(function() require("config.errorlog").path = vim.fn.tempname() .. "-greyknight-test.log" end)
-- Test processes never write harpoon lists (harpoon saves every loaded list when Neovim exits)
pcall(function() require("harpoon").sync = function() end end)
-- ... nor sessions: persisted saved the test's leftover windows as the session of the folder the tests ran in (the
-- config's own, over the real one) and of temp folders (2026-10-21)
pcall(function() require("persisted").stop() end)
-- ... nor the ShaDa file: test runs read the jumplist, marks and recent files the user's sessions left, and wrote
-- theirs back - test files among the recent files (jdt:// buffers) and in <C-o>'s history; an a.txt remembered from
-- an earlier run became a buffer when <C-o> loaded the jumplist, the next test found "a.txt" open (2026-10-22).
-- tests/run.sh and run.ps1 start Neovim with -i NONE; started some other way, nothing is written and what was read
-- goes.
vim.o.shadafile = "NONE"
for _, win in ipairs(vim.api.nvim_list_wins()) do vim.api.nvim_win_call(win, function() vim.cmd("clearjumps") end) end
vim.v.oldfiles = {}
vim.cmd("delmarks A-Z0-9")
-- gitsigns follows the working directory: each change ran git rev-parse and restarted its watcher on .git/HEAD.
-- The tests change it hundreds of times - on Windows a thousand git processes in a run, libuv lost the ends of
-- some, and Neovim hung on quitting (2026-10-21; gitsigns' own note on stop/start of that watcher: #1027). Test
-- runs keep the watcher it started with; signs and attaching to files are untouched.
pcall(function()
  require("gitsigns") -- loaded now (lazy: with the first file), so its autocmds exist
  vim.api.nvim_clear_autocmds({ group = "gitsigns", event = "DirChanged" })
end)
-- Tests delete their files; a buffer of one can outlive that (a cleanup that deletes buffers shows another one in
-- the window). Entering it reported E211 "File ... no longer available" - in the Windows test window a prompt that
-- kept Neovim from quitting (2026-10-21). A deleted file goes without a message; anything else as without this
-- autocmd ("ask"; 'autoread' reloads before it is asked at all).
vim.api.nvim_create_autocmd("FileChangedShell", {
  group = vim.api.nvim_create_augroup("greyknight_tests", { clear = true }),
  callback = function()
    if vim.v.fcs_reason ~= "deleted" then vim.v.fcs_choice = "ask" end
  end,
})

-- Some tests of a suite (2026-10-21): GK_TEST_ONLY / GK_TEST_SKIP, comma-separated pieces of test names, e.g.
--   GK_TEST_ONLY='Explorer workflow,Session' tests/run.sh smoke
local function names(var)
  local list = {}
  for piece in (vim.env[var] or ""):gmatch("[^,]+") do list[#list + 1] = vim.trim(piece) end
  return list
end
local ONLY, SKIP = names("GK_TEST_ONLY"), names("GK_TEST_SKIP")
local function named(name, list)
  for _, piece in ipairs(list) do
    if name:find(piece, 1, true) then return true end
  end
  return false
end

-- GK_TEST_TRACE=<file>: each test's name goes there as it starts - after "no report (the suite crashed)" the last
-- line names the test that was running (2026-10-21)
local TRACE = vim.env.GK_TEST_TRACE ~= "" and vim.env.GK_TEST_TRACE or nil

function H.test(name, fn)
  if (#ONLY > 0 and not named(name, ONLY)) or named(name, SKIP) then return end
  if TRACE then vim.fn.writefile({ os.date("%H:%M:%S ") .. name }, TRACE, "a") end
  -- Let earlier tests finish what they scheduled first: a terminal's scheduled stopinsert ended the next
  -- test's insert mode (2026-10-19, Windows, where the agent tests that used to flush it are skipped)
  vim.wait(20)
  -- Every test starts in normal mode: an earlier one's startinsert, still pending in a script, began with the next
  -- keys typed - gsaiw" went into the text as g@iw" (2026-10-21)
  vim.cmd("stopinsert")
  local ok, err = pcall(fn)
  if ok then
    H.passed = H.passed + 1
    H.results[#H.results + 1] = "✅ " .. name
  elseif getmetatable(err) == SKIP then
    H.skipped = H.skipped + 1
    H.results[#H.results + 1] = "⏭  " .. name .. " (skipped: " .. err.reason .. ")"
  else
    H.failed = H.failed + 1
    H.results[#H.results + 1] = "❌ " .. name .. " → " .. tostring(err)
  end
end

--- Skip the running test: this machine lacks an optional tool. Listed as skipped - not counted as passed,
--- and the run does not fail. A missing required tool (e.g. a debug adapter) should fail instead.
function H.skip(reason) error(setmetatable({ reason = reason }, SKIP)) end

--- Wait up to `ms` for fn() to be truthy, processing events meanwhile.
function H.wait(ms, fn) return vim.wait(ms, function() return fn() and true or false end, 50) end

--- Text of a buffer ("" when it is gone).
function H.text(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return "" end
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

--- A new empty buffer with this filetype (and lines) in the current window.
function H.scratch(ft, lines)
  vim.cmd("enew!")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = ft
  if lines then vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines) end
  return buf
end

--- Output of an overseer task.
function H.task_out(task) return H.text(task and task:get_bufnr()) end

--- A file with these lines in a fresh temp dir; returns its path.
function H.file(name, lines)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/" .. name
  vim.fn.writefile(lines, path)
  return path
end

--- Before quitting: language servers stopped, programs that plugins started and that still run ended - a test run
--- leaves no process behind (a language server outlived its run, 2026-10-21). On Windows the whole tree goes
--- (taskkill /T): git.EXE is a launcher, the git.exe it starts holds the pipes.
function H.settle()
  for _, client in ipairs(vim.lsp.get_clients()) do pcall(function() client:stop(true) end) end
  local function running()
    local list = {}
    vim.uv.walk(function(h)
      if h:get_type() == "process" and h:is_active() and not h:is_closing() then list[#list + 1] = h end
    end)
    return list
  end
  vim.wait(2000, function() return #running() == 0 end, 50) -- most end by themselves
  for _, h in ipairs(running()) do
    if vim.fn.has("win32") == 1 then
      pcall(vim.fn.system, { "taskkill", "/T", "/F", "/PID", tostring(h:get_pid()) })
    else
      pcall(h.kill, h, "sigkill")
    end
  end
  vim.wait(3000, function() return #running() == 0 end, 50)
end

--- Print the results; exit with status 1 if anything failed.
function H.report(title)
  if #ONLY > 0 then title = title .. " (only: " .. table.concat(ONLY, ", ") .. ")" end
  if #SKIP > 0 then title = title .. " (skipped: " .. table.concat(SKIP, ", ") .. ")" end
  local out = { "", "═══════════════════════════════════════════", "  GREY KNIGHT — " .. title, "═══════════════════════════════════════════" }
  for _, r in ipairs(H.results) do out[#out + 1] = "  " .. r end
  out[#out + 1] = "───────────────────────────────────────────"
  local skipped = H.skipped > 0 and (", %d skipped"):format(H.skipped) or ""
  out[#out + 1] = ("  %d passed, %d failed%s, %d total"):format(H.passed, H.failed, skipped, H.passed + H.failed + H.skipped)
  out[#out + 1] = "═══════════════════════════════════════════"
  local report = vim.env.GK_TEST_REPORT
  if report and report ~= "" then
    vim.fn.writefile(out, report) -- tests/run.ps1 (Windows): the suite ran in a real Neovim window
  else
    io.stdout:write(table.concat(out, "\n") .. "\n")
    io.stdout:flush()
  end
  H.settle()
  -- exit here, also on success: tests/run.sh ends with "cquit 2", reached only when a suite crashed before
  -- its report - a crash must not count as passed
  vim.cmd(H.failed > 0 and "cquit 1" or "qall!")
end

return H
