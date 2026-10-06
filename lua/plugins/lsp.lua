-- ╔══════════════════════════════════════════════════════════════╗
-- ║  LSP + Mason + Treesitter + Formatting                     ║
-- ╚══════════════════════════════════════════════════════════════╝
local lang = vim.g.lang or {}

-- Collect per-language config
local ts_langs    = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "regex", "diff" }
local lsp_servers = {}
local formatters  = {}

if lang.python then
  vim.list_extend(ts_langs, { "python" })
  lsp_servers["pyright"] = {}
  lsp_servers["ruff"]    = {}
  formatters["python"]   = { "ruff_format" }
end
if lang.bash then
  vim.list_extend(ts_langs, { "bash" })
  lsp_servers["bashls"] = {}
  formatters["sh"]      = { "shfmt" }
end
if lang.c then
  vim.list_extend(ts_langs, { "c", "cpp" })
  lsp_servers["clangd"]  = {}
  formatters["c"]   = { "clang-format" }
  formatters["cpp"] = { "clang-format" }
end
if lang.typescript then
  vim.list_extend(ts_langs, { "typescript", "javascript", "tsx", "json", "html", "css" })
  lsp_servers["ts_ls"] = {}
  formatters["typescript"]      = { "prettierd", "prettier", stop_after_first = true }
  formatters["javascript"]      = { "prettierd", "prettier", stop_after_first = true }
  formatters["typescriptreact"] = { "prettierd", "prettier", stop_after_first = true }
  formatters["javascriptreact"] = { "prettierd", "prettier", stop_after_first = true }
  formatters["json"]            = { "prettierd", "prettier", stop_after_first = true }
  formatters["html"]            = { "prettierd", "prettier", stop_after_first = true }
  formatters["css"]             = { "prettierd", "prettier", stop_after_first = true }
end
if lang.lua then
  lsp_servers["lua_ls"] = {
    Lua = {
      runtime     = { version = "LuaJIT" },
      workspace   = { checkThirdParty = false, library = vim.api.nvim_get_runtime_file("", true) },
      telemetry   = { enable = false },
      diagnostics = { globals = { "vim", "Snacks" } },
    },
  }
  formatters["lua"] = { "stylua" }
end

return {
  -- Mason
  { "williamboman/mason.nvim", config = true },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = { automatic_enable = false },
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      -- blink.cmp capabilities
      local ok_blink, blink = pcall(require, "blink.cmp")
      if ok_blink then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end

      -- Mason only installs the servers that are missing. Servers already on the PATH (system packages, or
      -- Mason's own bin directory, which mason.nvim puts on the PATH) are left alone: Mason has no clangd for
      -- arm64 Linux, so on the pi it failed on every start although Debian's clangd is installed.
      local server_cmd = {
        bashls  = "bash-language-server",
        clangd  = "clangd",
        lua_ls  = "lua-language-server",
        pyright = "pyright-langserver",
        ruff    = "ruff",
        ts_ls   = "typescript-language-server",
      }
      local missing = vim.tbl_filter(function(server)
        return vim.fn.executable(server_cmd[server] or server) == 0
      end, vim.tbl_keys(lsp_servers))

      local ok_mason_lsp, mason_lsp = pcall(require, "mason-lspconfig")
      if ok_mason_lsp then
        mason_lsp.setup({
          ensure_installed = missing,
          automatic_enable = false,
        })
      end

      local lspconfig = require("lspconfig")
      for server, settings in pairs(lsp_servers) do
        lspconfig[server].setup({ capabilities = capabilities, settings = settings })
      end

      -- LSP keymaps
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local b = ev.buf
          local map = function(k, f, d) vim.keymap.set("n", k, f, { buffer = b, desc = "LSP: " .. d }) end
          map("gd",         vim.lsp.buf.definition,     "Definition")
          map("gD",         vim.lsp.buf.declaration,    "Declaration")
          map("gr",         vim.lsp.buf.references,     "References")
          map("gi",         vim.lsp.buf.implementation, "Implementation")
          map("K",          vim.lsp.buf.hover,          "Hover")
          map("<leader>rn", vim.lsp.buf.rename,         "Rename")
          map("<leader>ca", vim.lsp.buf.code_action,    "Code action")
          map("<leader>D",  vim.lsp.buf.type_definition,"Type definition")
          map("[d",         vim.diagnostic.goto_prev,    "Prev diagnostic")
          map("]d",         vim.diagnostic.goto_next,    "Next diagnostic")
        end,
      })
    end,
  },

  -- Treesitter (nvim 0.13+ — loads eagerly so parsers are available for all plugins)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = ts_langs,
        auto_install     = true,
      })
      vim.keymap.set("n", "<C-space>", function()
        require("nvim-treesitter.incremental_selection").init_selection()
      end, { desc = "TS: Init selection" })
      vim.keymap.set("x", "<C-space>", function()
        require("nvim-treesitter.incremental_selection").node_incremental()
      end, { desc = "TS: Expand selection" })
      vim.keymap.set("x", "<bs>", function()
        require("nvim-treesitter.incremental_selection").node_decremental()
      end, { desc = "TS: Shrink selection" })
    end,
  },

  -- Treesitter context (sticky header)
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    opts = { max_lines = 3 },
  },

  -- Formatting
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = formatters,
      format_on_save = { timeout_ms = 2000, lsp_fallback = true },
    },
    keys = {
      { "<leader>fm", function() require("conform").format({ async = true, lsp_fallback = true }) end, mode = { "n", "v" }, desc = "Format" },
    },
  },
}
