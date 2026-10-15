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
        ["<Tab>"]     = { "select_next", "snippet_forward", "fallback" },
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
  },
}
