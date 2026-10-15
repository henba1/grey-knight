-- Grey Knight test harness: test(), helpers for buffers / terminals / tasks, report().
-- report() exits Neovim with status 1 when a test failed, so tests/run.sh (and scripts) can rely on it.
local H = { results = {}, passed = 0, failed = 0 }

-- Warnings and errors that the tests provoke on purpose do not belong in the real error log
pcall(function() require("config.errorlog").path = vim.fn.tempname() .. "-greyknight-test.log" end)
-- Test processes never write harpoon lists (harpoon saves every loaded list when Neovim exits)
pcall(function() require("harpoon").sync = function() end end)

function H.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    H.passed = H.passed + 1
    H.results[#H.results + 1] = "✅ " .. name
  else
    H.failed = H.failed + 1
    H.results[#H.results + 1] = "❌ " .. name .. " → " .. tostring(err)
  end
end

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
  out[#out + 1] = ("  %d passed, %d failed, %d total"):format(H.passed, H.failed, H.passed + H.failed)
  out[#out + 1] = "═══════════════════════════════════════════"
  io.stdout:write(table.concat(out, "\n") .. "\n")
  io.stdout:flush()
  if H.failed > 0 then vim.cmd("cquit 1") end
end

return H
