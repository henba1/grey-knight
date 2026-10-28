-- ╔══════════════════════════════════════════════════════════════╗
-- ║  blink.cmp — Rust-powered completion (replaces nvim-cmp)   ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "default",
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"]     = { "hide" },
        ["<CR>"]      = { "accept", "fallback" },
        -- Easy mode (Alt+N, config/easymode.lua): Tab takes the suggestion - the one picked with the arrows, else the
        -- grey one - as in VS Code; it put the next one in and left the menu open (2026-10-28). Esc closes the menu
        -- there (easymode.lua). Outside easy mode Tab goes through the list as before.
        ["<Tab>"]     = {
          function(cmp) if vim.g.greyknight_easymode and cmp.is_menu_visible() then return cmp.select_and_accept() end end,
          "select_next", "snippet_forward", "fallback",
        },
        ["<S-Tab>"]   = { "select_prev", "snippet_backward", "fallback" },
        ["<C-b>"]     = { "scroll_documentation_up" },
        ["<C-f>"]     = { "scroll_documentation_down" },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        -- Nothing is preselected: <CR> only accepts an item you picked (Tab / arrows / C-n), otherwise
        -- it is a plain Enter (new line). A picked item is inserted right away.
        list = { selection = { preselect = false, auto_insert = true } },
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        -- grey preview of the top suggestion while typing (Tab takes it, Enter stays a new line)
        ghost_text    = { enabled = true, show_without_selection = true },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      signature = { enabled = true },
    },
    config = function(_, opts)
      require("blink.cmp").setup(opts)
      -- Enter takes the item a moment later: blink schedules it, then asks the language server for the rest of the
      -- item (up to 100 ms). An Esc in between - typed right after it, or while Neovim or the server was busy - ended
      -- Insert mode first, and the item went in in Normal mode: a character off, U (undo line) typed for brackets,
      -- and its dot-repeat trick failed with E785 and left its 1x1 window open, the cursor in it (2026-10-21). An
      -- item goes in only while Insert mode lasts; after an Esc the text stays as it was.
      local function inserting() return vim.api.nvim_get_mode().mode:find("^[iR]") ~= nil end
      local ok_list, list = pcall(require, "blink.cmp.completion.list")
      if ok_list and type(list.accept) == "function" then
        local accept = list.accept
        list.accept = function(o)
          if (list.context or {}).mode == "default" and not inserting() then
            list.preview_undo = nil -- the item Tab put in stays as it is
            pcall(function() require("blink.cmp.completion.trigger").hide() end)
            return false
          end
          return accept(o)
        end
      end
      local ok_src, sources = pcall(require, "blink.cmp.sources.lib")
      if ok_src and type(sources.execute) == "function" then
        local execute = sources.execute
        sources.execute = function(ctx, ...)
          if (ctx or {}).mode == "default" and not inserting() then
            return require("blink.cmp.lib.async").task.new(function() end) -- dropped: nothing more happens
          end
          return execute(ctx, ...)
        end
      end
    end,
  },
}
