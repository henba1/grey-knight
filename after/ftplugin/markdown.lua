-- Markdown: wrap, spell, conceallevel for render-markdown
vim.opt_local.wrap = true
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"
vim.opt_local.conceallevel = 2

-- Links: gd / Enter follow [text](#heading), [text](file.md#heading) and URLs (config/mdlinks.lua);
-- Ctrl+o jumps back, gO (Neovim) lists the headings. Off a link both keys keep their usual meaning.
local function follow(key)
  return function()
    local count = vim.v.count > 0 and tostring(vim.v.count) or ""
    require("config.mdlinks").follow(function() vim.api.nvim_feedkeys(count .. vim.keycode(key), "n", false) end)
  end
end
vim.keymap.set("n", "gd", follow("gd"), { buffer = true, desc = "Follow link" })
vim.keymap.set("n", "<CR>", follow("<CR>"), { buffer = true, desc = "Follow link" })
