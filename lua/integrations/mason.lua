-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Mason packages on demand: installed with the first file    ║
-- ║  that needs them (Java, Angular), not on every machine at   ║
-- ║  startup                                                    ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local waiting = {} -- package name -> callbacks waiting for its install to end

--- Installs the packages Mason lacks, then calls done (once, when all are there; at once when none is missing).
--- title names the feature in the notification ("Java", "Angular").
function M.ensure(names, done, title)
  local ok, registry = pcall(require, "mason-registry")
  if not ok then return done() end
  local function install()
    local missing = {}
    for _, name in ipairs(names) do
      local found, pkg = pcall(registry.get_package, name)
      if found and not pkg:is_installed() then missing[#missing + 1] = pkg end
    end
    if #missing == 0 then return done() end
    vim.notify("installing " .. table.concat(vim.tbl_map(function(p) return p.name end, missing), ", ")
      .. " (Mason) - it starts when that is done", vim.log.levels.INFO, { title = title })
    local left = #missing
    local function one_done()
      left = left - 1
      if left == 0 then done() end
    end
    for _, pkg in ipairs(missing) do
      if waiting[pkg.name] then -- another buffer started this install: wait for it
        table.insert(waiting[pkg.name], one_done)
      else
        waiting[pkg.name] = { one_done }
        pkg:install():once("closed", vim.schedule_wrap(function()
          local callbacks = waiting[pkg.name] or {}
          waiting[pkg.name] = nil
          for _, cb in ipairs(callbacks) do cb() end
        end))
      end
    end
  end
  if registry.refresh then registry.refresh(vim.schedule_wrap(install)) else install() end
end

return M
