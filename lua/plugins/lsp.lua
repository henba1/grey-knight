-- ╔══════════════════════════════════════════════════════════════╗
-- ║  LSP + Mason + Treesitter + Formatting                     ║
-- ╚══════════════════════════════════════════════════════════════╝
local lang = vim.g.lang or {}

-- Behind a TLS-inspecting proxy (a work laptop) pip trusts only its own CA bundle, so Mason's pip installs
-- (debugpy) failed; $SSL_CERT_FILE names the bundle that has the proxy's CA
if (vim.env.PIP_CERT or "") == "" and (vim.env.SSL_CERT_FILE or "") ~= "" then
  vim.env.PIP_CERT = vim.env.SSL_CERT_FILE
end

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
if lang.java then
  vim.list_extend(ts_langs, { "java" }) -- jdtls itself: lua/plugins/java.lua
end
if lang.angular then
  vim.list_extend(ts_langs, { "angular", "scss" }) -- its servers: lua/integrations/web.lua
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
            local util = require("devsuite.util")
            local venv = util.find_venv(root_dir)
            if venv then
              config.settings = config.settings or {}
              config.settings.python = vim.tbl_extend("force", config.settings.python or {}, { pythonPath = util.venv_python(venv) })
            end
          end
        end
        lspconfig[server].setup(opts)
      end

      -- Angular / AngularJS: angularls, eslint, html, css - installed with the first file that needs them
      if lang.angular then require("integrations.web").setup(capabilities) end

      -- LSP keymaps, each for a server that can do it: gd with only ruff, html or eslint attached said "method
      -- textDocument/definition is not supported by any server" - now it stays Vim's gd there (2026-10-21, error log)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local b = ev.buf
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          local map = function(k, method, f, d)
            if client and client:supports_method(method, b) then
              vim.keymap.set("n", k, f, { buffer = b, desc = "LSP: " .. d })
            end
          end
          map("gd",         "textDocument/definition",     vim.lsp.buf.definition,      "Definition")
          map("gD",         "textDocument/declaration",    vim.lsp.buf.declaration,     "Declaration")
          map("gr",         "textDocument/references",     vim.lsp.buf.references,      "References")
          map("gi",         "textDocument/implementation", vim.lsp.buf.implementation,  "Implementation")
          map("K",          "textDocument/hover",          vim.lsp.buf.hover,           "Hover")
          map("<leader>rn", "textDocument/rename",         vim.lsp.buf.rename,          "Rename")
          map("<leader>ca", "textDocument/codeAction",     vim.lsp.buf.code_action,     "Code action")
          map("<leader>D",  "textDocument/typeDefinition", vim.lsp.buf.type_definition, "Type definition")
          -- diagnostics of any source (runs too), with the message in a float as before; goto_prev/goto_next are
          -- deprecated
          local function jump(count) return function() vim.diagnostic.jump({ count = count, float = true }) end end
          vim.keymap.set("n", "[d", jump(-1), { buffer = b, desc = "Prev diagnostic" })
          vim.keymap.set("n", "]d", jump(1), { buffer = b, desc = "Next diagnostic" })
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

  -- Formatting. In IntelliJ projects as IntelliJ does it (lua/integrations/intellij.lua): saving runs its Actions
  -- on Save (by default nothing), <leader>fm is its Reformat Code (the project's prettier where IntelliJ runs
  -- it, else the language server). Elsewhere: conform's formatters on save, the language server as fallback.
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = formatters,
      -- stylua for a project that formats with it: one with a stylua.toml (its style; stylua's own is tabs)
      formatters = {
        stylua = {
          condition = function(_, ctx)
            return vim.fs.find({ "stylua.toml", ".stylua.toml" }, { path = ctx.dirname, upward = true })[1] ~= nil
          end,
        },
      },
      -- Saving never pops up an error (quiet): a formatter that fails - mostly on a file that does not parse yet, an
      -- unfinished script ("Formatter failed" 4 times in the Kali error log, 2026-10-21) - leaves the text as it is,
      -- and it is saved as it is. :ConformInfo has the details; <leader>fm still says when it fails.
      format_on_save = function(buf)
        local intellij = require("integrations.intellij")
        local actions = intellij.save_actions(buf)
        if actions == nil then
          -- Lua is saved as written, unless the project formats it with stylua: lua_ls' own style, the fallback while
          -- stylua is not installed, rewrote this config's hand-aligned files on every save - 74 lines of keymaps.lua
          -- for one (2026-10-22). <leader>fm still formats it.
          if vim.bo[buf].filetype == "lua" then return { timeout_ms = 2000, lsp_format = "never", quiet = true } end
          return { timeout_ms = 2000, lsp_fallback = true, quiet = true }
        end
        if not actions.format then return nil end
        local opts = actions.prettier and { timeout_ms = 3000, formatters = { "prettier" }, lsp_format = "never", quiet = true }
          or { timeout_ms = 3000, lsp_format = "prefer", quiet = true }
        if not actions.changed_lines then return opts end
        -- "Only changes uncommitted to VCS": the changed lines, not the whole file
        for _, range in ipairs(intellij.changed_ranges(buf)) do
          require("conform").format(vim.tbl_extend("force", opts, { bufnr = buf, range = range }))
        end
        return nil
      end,
    },
    config = function(_, opts)
      require("conform").setup(opts)
      -- On Windows a formatter is mostly a .cmd (Mason's, a project's node_modules/.bin), and cmd.exe split or changed
      -- its arguments: ruff did not format a file in R&D, a project's prettier in "C:\my projects" never ran
      -- (2026-10-21). It runs as what the .cmd runs (devsuite/util.lua, unshim).
      if vim.fn.has("win32") == 1 then
        local runner = require("conform.runner")
        local build = runner.build_cmd
        runner.build_cmd = function(...)
          local cmd = build(...)
          return type(cmd) == "table" and require("devsuite.util").unshim(cmd) or cmd
        end
      end
    end,
    keys = {
      { "<leader>fm", function()
        local opts = require("integrations.intellij").reformat_options(0) or { lsp_fallback = true }
        require("conform").format(vim.tbl_extend("force", opts, { async = true })) -- visual mode: the selection
      end, mode = { "n", "v" }, desc = "Format" },
    },
  },
}
