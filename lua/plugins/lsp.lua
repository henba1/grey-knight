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

-- shellcheck: bash-language-server runs shellcheck itself and reports its findings, so this only
-- fills in where bashls is not attached (the binary is optional — absent means silent skip)
if lang.bash and vim.fn.executable("shellcheck") == 1 then
  local ns = vim.api.nvim_create_namespace('shellcheck')
  local severity = {
    error   = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARNING,
    info    = vim.diagnostic.severity.INFO,
    style   = vim.diagnostic.severity.HINT,
  }
  local function check(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end
    if vim.bo[buf].filetype ~= "sh" and vim.bo[buf].filetype ~= "bash" then return end
    if #vim.lsp.get_clients({ bufnr = buf, name = "bashls" }) > 0 then
      return vim.diagnostic.reset(ns, buf) -- bashls has the same findings
    end
    local tmp = vim.fn.tempname()
    vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, true), tmp)
    local report = vim.fn.systemlist('shellcheck -f json ' .. tmp)
    vim.fn.delete(tmp)
    local issues = {}
    local ok, found = pcall(vim.json.decode, table.concat(report, '\n'))
    if ok and vim.islist(found) then
      for _, item in ipairs(found) do
        if item.code then
          issues[#issues + 1] = {
            -- shellcheck counts lines and columns from 1, diagnostics from 0
            lnum     = (item.line or 1) - 1,
            col      = math.max((item.column or 1) - 1, 0),
            end_lnum = item.endLine and item.endLine - 1 or nil,
            end_col  = item.endColumn and item.endColumn - 1 or nil,
            message  = item.message or item.code,
            code     = item.code,
            source   = "shellcheck",
            severity = severity[item.level],
          }
        end
      end
    end
    vim.diagnostic.set(ns, buf, issues)
  end
  -- FileType/BufWritePost: (re)check; LspAttach: bashls took over, drop ours
  vim.api.nvim_create_autocmd({ "FileType", "BufWritePost", "LspAttach" }, {
    callback = function(ev) check(ev.buf) end,
  })
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
        local opts = { capabilities = capabilities, settings = settings }
        if server == "pyright" then
          -- Resolve imports against the project's virtualenv ($VIRTUAL_ENV, else the nearest .venv/ or venv/);
          -- pyright alone only sees the python on the PATH
          opts.on_new_config = function(config, root_dir)
            local venv = require("devsuite.util").find_venv(root_dir)
            if venv then
              config.settings = config.settings or {}
              config.settings.python = vim.tbl_extend("force", config.settings.python or {}, { pythonPath = venv .. "/bin/python" })
            end
          end
        end
        lspconfig[server].setup(opts)
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

  -- Treesitter (nvim 0.12+, the main branch — loads eagerly so parsers are available for all plugins)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- Windows: the tree-sitter CLI compiles parsers with $CC and otherwise looks for MSVC; MinGW's gcc
      -- builds them (zig cc does not: the CLI hands it a Rust target name)
      if vim.fn.has("win32") == 1 and (vim.env.CC or "") == "" and vim.fn.executable("gcc") == 1 then
        vim.env.CC = "gcc"
      end
      require("nvim-treesitter").setup({})
      -- The main branch has no ensure_installed / auto_install (both were ignored: a fresh machine got no
      -- parsers). install() adds the missing ones in the background and leaves the others alone.
      require("nvim-treesitter").install(ts_langs)

      -- Node selection with Neovim's own code, what its an / in run (mini.ai has those keys for its "next"
      -- textobjects); the incremental_selection module these keys called is gone from the main branch
      local function select_node(outer)
        local count = vim.v.count1
        if vim.treesitter.get_parser(nil, nil, { error = false }) then
          local select = require("vim.treesitter._select")
          if outer then select.select_parent(count) else select.select_child(count) end
        else
          vim.lsp.buf.selection_range(outer and count or -count)
        end
      end
      vim.keymap.set("n", "<C-space>", "v<C-space>", { remap = true, desc = "TS: Init selection" })
      vim.keymap.set("x", "<C-space>", function() select_node(true) end, { desc = "TS: Expand selection" })
      vim.keymap.set("x", "<bs>", function() select_node(false) end, { desc = "TS: Shrink selection" })
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
