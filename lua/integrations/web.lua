-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Angular (2+) and AngularJS: angularls, eslint, html and    ║
-- ║  css servers - each installed (Mason) with the first file   ║
-- ║  that needs it. Templates of Angular workspaces are         ║
-- ║  htmlangular (lua/config/options.lua). AngularJS code gets  ║
-- ║  ts_ls + eslint: no server knows its templates              ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

-- Angular workspaces: Angular CLI (angular.json) and Nx (nx.json - ngx-his has no angular.json)
M.ANGULAR = { "angular.json", "nx.json" }
M.ESLINT = {
  "eslint.config.js", "eslint.config.cjs", "eslint.config.mjs", "eslint.config.ts",
  ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml", ".eslintrc",
}
local SCRIPTS = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

-- server -> Mason package, its executable, the filetypes it serves, the files that must be above the buffer
M.SERVERS = {
  angularls = { package = "angular-language-server", cmd = "ngserver", filetypes = { "typescript", "htmlangular" }, markers = M.ANGULAR },
  eslint = { package = "eslint-lsp", cmd = "vscode-eslint-language-server", filetypes = vim.list_extend({ "htmlangular" }, SCRIPTS), markers = M.ESLINT },
  html = { package = "html-lsp", cmd = "vscode-html-language-server", filetypes = { "html" } },
  cssls = { package = "css-lsp", cmd = "vscode-css-language-server", filetypes = { "css", "scss", "less" } },
}

--- The servers a buffer needs (its filetype, and the workspace files above it).
function M.needed(buf)
  local ft, file = vim.bo[buf].filetype, vim.api.nvim_buf_get_name(buf)
  local out = {}
  for name, s in pairs(M.SERVERS) do
    if vim.tbl_contains(s.filetypes, ft) and (not s.markers or (file ~= "" and vim.fs.root(file, s.markers))) then
      out[#out + 1] = name
    end
  end
  table.sort(out)
  return out
end

--- angularls' root: the Angular workspace (angular.json or nx.json). lspconfig's own angularls looked for
--- angular.json only and never started in Nx workspaces like ngx-his (2026-10-19).
function M.angular_root(fname) return vim.fs.root(fname, M.ANGULAR) end

-- The project's Angular version (node_modules/@angular/core), or nil
local function angular_version(root)
  local f = io.open(root .. "/node_modules/@angular/core/package.json", "r")
  if not f then return nil end
  local ok, pkg = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(pkg) == "table" and pkg.version or nil
end

-- angularls: the project's @angular/language-service and typescript first, Mason's own as the fallback - npm
-- nests that language service under the server, typescript sits one level up (2026-10-19)
local function angular_cmd(root)
  root = root or vim.fn.getcwd()
  local own = vim.fn.stdpath("data") .. "/mason/packages/angular-language-server/node_modules"
  local probe = table.concat({ root .. "/node_modules", own, own .. "/@angular/language-server/node_modules" }, ",")
  local cmd = { "ngserver", "--stdio", "--tsProbeLocations", probe, "--ngProbeLocations", probe }
  local version = angular_version(root)
  if version then vim.list_extend(cmd, { "--angularCoreVersion", version }) end
  return cmd
end

local ready = {}

local function setup(name, capabilities)
  if ready[name] then return end
  ready[name] = true
  local opts = { capabilities = capabilities }
  if name == "angularls" then
    opts.root_dir = function(fname) return M.angular_root(fname) end
    opts.cmd = angular_cmd()
    opts.on_new_config = function(config, root) config.cmd = angular_cmd(root) end
  end
  require("lspconfig")[name].setup(opts)
end

--- Sets up the installed servers (lspconfig attaches them); the others are installed and started with the first
--- buffer that needs them.
function M.setup(capabilities)
  for name, s in pairs(M.SERVERS) do
    if vim.fn.executable(s.cmd) == 1 then setup(name, capabilities) end
  end
  local filetypes = {}
  for _, s in pairs(M.SERVERS) do
    for _, ft in ipairs(s.filetypes) do
      if not vim.tbl_contains(filetypes, ft) then filetypes[#filetypes + 1] = ft end
    end
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("greyknight.web", { clear = true }),
    pattern = filetypes,
    callback = function(ev)
      local missing = vim.tbl_filter(function(name) return not ready[name] end, M.needed(ev.buf))
      if #missing == 0 then return end
      local packages = vim.tbl_map(function(name) return M.SERVERS[name].package end, missing)
      require("integrations.mason").ensure(packages, function()
        for _, name in ipairs(missing) do
          if vim.fn.executable(M.SERVERS[name].cmd) == 1 then
            setup(name, capabilities)
            -- this buffer's FileType has passed: start the server for it now
            if vim.api.nvim_buf_is_valid(ev.buf) then
              vim.api.nvim_buf_call(ev.buf, function() pcall(vim.cmd, "LspStart " .. name) end)
            end
          end
        end
      end, "Angular")
    end,
  })
end

return M
