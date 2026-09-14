-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Autocommands                                               ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 200 }) end,
})

-- Restore cursor position on file open
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-resize splits on window resize
vim.api.nvim_create_autocmd("VimResized", {
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "help", "qf", "man", "notify", "lspinfo", "checkhealth", "oil" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Startup message
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local lang = vim.g.lang or {}
    local active = {}
    for name, enabled in pairs(lang) do
      if enabled then table.insert(active, name) end
    end
    table.sort(active)
    if #active > 0 then
      vim.notify("Grey Knight | " .. table.concat(active, ", ") .. " | AI: Qwen Code @ rig", vim.log.levels.INFO)
    end
  end,
})
