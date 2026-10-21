-- Grey Knight test harness: test(), helpers for buffers / terminals / tasks, report().
-- report() exits Neovim with status 1 when a test failed, so tests/run.sh (and scripts) can rely on it.
local H = { results = {}, passed = 0, failed = 0, skipped = 0 }
local SKIP = {} -- metatable of the error H.skip() raises

-- Warnings and errors that the tests provoke on purpose do not belong in the real error log
pcall(function() require("config.errorlog").path = vim.fn.tempname() .. "-greyknight-test.log" end)
-- Test processes never write harpoon lists (harpoon saves every loaded list when Neovim exits)
pcall(function() require("harpoon").sync = function() end end)
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

function H.test(name, fn)
  -- Let earlier tests finish what they scheduled first: a terminal's scheduled stopinsert ended the next
  -- test's insert mode (2026-10-19, Windows, where the agent tests that used to flush it are skipped)
  vim.wait(20)
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

--- Print the results; exit with status 1 if anything failed.
function H.report(title)
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
  -- exit here, also on success: tests/run.sh ends with "cquit 2", reached only when a suite crashed before
  -- its report - a crash must not count as passed
  vim.cmd(H.failed > 0 and "cquit 1" or "qall!")
end

return H
