-- ╔══════════════════════════════════════════════════════════════╗
-- ║  IntelliJ IDEA's settings, read (never written): its JDKs,  ║
-- ║  a project's JDK and Maven, Actions on Save, Prettier and   ║
-- ║  Remote JVM Debug configurations - GreyNight works on an    ║
-- ║  IntelliJ project the way IntelliJ does (no JDK drift)      ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local WIN = vim.fn.has("win32") == 1

-- IntelliJ's default "Run for files" pattern of Prettier
M.PRETTIER_PATTERN = "**/*.{js,ts,jsx,tsx,cjs,cts,mjs,mts,vue,astro}"

-- File types of IntelliJ's Actions on Save -> Neovim filetypes
M.FILE_TYPES = {
  JAVA = { "java" },
  JavaScript = { "javascript", "javascriptreact" },
  TypeScript = { "typescript" },
  ["TypeScript JSX"] = { "typescriptreact" },
  HTML = { "html", "htmlangular" },
  CSS = { "css" },
  SCSS = { "scss" },
  JSON = { "json" },
  XML = { "xml" },
  YAML = { "yaml" },
}

-- ── Reading IntelliJ's XML ──────────────────────────────────
-- Its files are small and regular (attributes and <option name= value=>): patterns are enough.
local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }

local function unescape(s)
  s = s:gsub("&#(%d+);", function(n) return vim.fn.nr2char(tonumber(n)) end)
  return (s:gsub("&(%a+);", function(e) return ENTITIES[e] end))
end

local function attrs(tag)
  local out = {}
  for k, v in (tag or ""):gmatch('([%w_:%-]+)="([^"]*)"') do out[k] = unescape(v) end
  return out
end

local function read(path)
  local f = path and io.open(path, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

-- The body of <component name="..."> (nil when missing, "" when it closes itself) and its attributes
local function component(xml, name)
  if not xml then return nil end
  local _, e, open = xml:find('(<component name="' .. vim.pesc(name) .. '"[^>]*>)')
  if not e then return nil end
  if open:sub(-2) == "/>" then return "", attrs(open) end
  local close = xml:find("</component>", e + 1, true)
  return xml:sub(e + 1, (close or #xml + 1) - 1), attrs(open)
end

-- The <option name= value=> pairs in a piece of XML, nested ones included (the first of a name wins)
local function options(xml)
  local out = {}
  for tag in (xml or ""):gmatch("<option%s[^>]*>") do
    local a = attrs(tag)
    if a.name and a.value and out[a.name] == nil then out[a.name] = a.value end
  end
  return out
end

-- The values of the <option value=> entries of a list or set
local function values(xml)
  local out = {}
  for v in (xml or ""):gmatch('<option value="([^"]*)"') do out[#out + 1] = unescape(v) end
  return out
end

-- A path from IntelliJ's files: $USER_HOME$ / $PROJECT_DIR$ expanded, / separated
local function expand(value, root)
  local home = (WIN and vim.env.USERPROFILE) or vim.env.HOME or ""
  value = value:gsub("%$USER_HOME%$", function() return home end)
  if root then value = value:gsub("%$PROJECT_DIR%$", function() return root end) end
  return vim.fs.normalize(value)
end

-- ── IntelliJ's own settings and JDKs ────────────────────────
--- IntelliJ's config directory (the newest IntelliJIdea* / IdeaIC*), or nil. $GREYKNIGHT_INTELLIJ_CONFIG overrides it.
function M.config_dir()
  local override = vim.env.GREYKNIGHT_INTELLIJ_CONFIG
  if override and override ~= "" then
    return vim.fn.isdirectory(override) == 1 and vim.fs.normalize(override) or nil
  end
  local base
  if WIN then
    base = vim.env.APPDATA and (vim.env.APPDATA .. "/JetBrains")
  elseif vim.fn.has("mac") == 1 then
    base = vim.fn.expand("~/Library/Application Support/JetBrains")
  else
    base = (vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")) .. "/JetBrains"
  end
  if not base or vim.fn.isdirectory(base) == 0 then return nil end
  local best, best_version
  for name, kind in vim.fs.dir(base) do
    local v = kind == "directory" and (name:match("^IntelliJIdea(%d+%.%d+)$") or name:match("^IdeaIC(%d+%.%d+)$"))
    local version = v and vim.version.parse(v)
    if version and (not best_version or vim.version.gt(version, best_version)) then best, best_version = name, version end
  end
  return best and vim.fs.normalize(base .. "/" .. best) or nil
end

--- The java executable of a JDK.
function M.java_bin(home) return home .. (WIN and "/bin/java.exe" or "/bin/java") end

--- Major version of a JDK from its release file (17 for "17.0.19", 8 for "1.8.0_402"), or nil.
function M.java_major(home)
  local text = read(home and (home .. "/release"))
  local v = text and text:match('JAVA_VERSION="([^"]+)"')
  if not v then return nil end
  local major, minor = v:match("^(%d+)%.?(%d*)")
  major = tonumber(major)
  if major == 1 then return tonumber(minor) end
  return major
end

--- The JDKs IntelliJ knows (File | Project Structure | SDKs): { name, home, version, major }.
function M.jdks()
  local dir = M.config_dir()
  local xml = dir and read(dir .. "/options/jdk.table.xml")
  local out = {}
  for block in (xml or ""):gmatch("<jdk[%s>].-</jdk>") do
    local function value(tag)
      local v = block:match("<" .. tag .. '%s+value="([^"]*)"')
      return v and unescape(v)
    end
    if value("type") == "JavaSDK" and value("homePath") then
      local home = expand(value("homePath"))
      out[#out + 1] = { name = value("name"), home = home, version = value("version"), major = M.java_major(home) }
    end
  end
  return out
end

--- The newest JDK IntelliJ knows with at least this major version (jdtls itself needs 21), or nil.
function M.newest_jdk(min_major)
  local best
  for _, jdk in ipairs(M.jdks()) do
    if jdk.major and jdk.major >= (min_major or 0) and (not best or jdk.major > best.major)
        and vim.fn.executable(M.java_bin(jdk.home)) == 1 then
      best = jdk
    end
  end
  return best
end

-- ── Projects ────────────────────────────────────────────────
--- The IntelliJ project of a file or directory: the nearest directory with an .idea folder, or nil.
function M.project_root(path)
  if not path or path == "" then return nil end
  local root = vim.fs.root(path, ".idea")
  return root and vim.fn.isdirectory(root .. "/.idea") == 1 and vim.fs.normalize(root) or nil
end

local cache = {}

local function stamp(paths)
  local out = {}
  for _, p in ipairs(paths) do
    local st = vim.uv.fs_stat(p)
    out[#out + 1] = st and (st.mtime.sec .. "." .. st.mtime.nsec .. "." .. st.size) or "-"
  end
  return table.concat(out, "|")
end

-- An Actions on Save entry of workspace.xml: on?, its file types (nil = all), its options
local function on_save(ws, name)
  local body = component(ws, name)
  local o = options(body)
  local types = nil
  if o.myAllFileTypesSelected == "false" then
    types = values((body or ""):match('<option name="mySelectedFileTypes">(.-)</option>'))
  end
  return o.myRunOnSave == "true", types, o
end

--- What IntelliJ uses for a project (nil when the directory has no .idea):
---   jdk_name, jdk (its SDK entry; nil when IntelliJ does not know it), language_level (17),
---   maven = { home, user_settings, local_repository } (nil = IntelliJ's default),
---   save = { format, format_types (nil = all), changed_lines, optimize_imports, optimize_types },
---   prettier = { mode ("AUTOMATIC" | "MANUAL" | "DISABLED"), on_save, on_reformat, pattern }
--- Read again whenever one of IntelliJ's files changed.
function M.project(root)
  local idea = root and (root .. "/.idea")
  if not idea or vim.fn.isdirectory(idea) == 0 then return nil end
  local config = M.config_dir() or ""
  local files = { idea .. "/misc.xml", idea .. "/workspace.xml", idea .. "/prettier.xml", config .. "/options/jdk.table.xml" }
  local key = config .. "|" .. stamp(files)
  if cache[root] and cache[root].key == key then return cache[root].project end

  local _, prm = component(read(files[1]), "ProjectRootManager")
  prm = prm or {}
  local jdk
  for _, j in ipairs(M.jdks()) do
    if j.name == prm["project-jdk-name"] then
      jdk = j
      break
    end
  end
  local level = (prm.languageLevel or ""):match("^JDK_(.*)$")
  level = level and tonumber(level:match("^1_(%d+)$") or level:match("^(%d+)"))

  local ws = read(files[2])
  local mvn = options(component(ws, "MavenImportPreferences"))
  local home = mvn.customMavenHome or mvn.mavenHome
  if home and not home:find("[/\\]") then home = nil end -- "Bundled (Maven 3)" names no directory
  local function path(v) return (v and v ~= "") and expand(v, root) or nil end
  local format, format_types, fo = on_save(ws, "FormatOnSaveOptions")
  local optimize, optimize_types = on_save(ws, "OptimizeOnSaveOptions")
  local pr = options(component(read(files[3]), "PrettierConfiguration"))

  local project = {
    root = root,
    jdk_name = prm["project-jdk-name"],
    jdk = jdk,
    language_level = level,
    maven = { home = path(home), user_settings = path(mvn.userSettingsFile), local_repository = path(mvn.localRepository) },
    save = {
      format = format,
      format_types = format_types,
      changed_lines = fo.myFormatOnlyChangedLines == "true",
      optimize_imports = optimize,
      optimize_types = optimize_types,
    },
    prettier = {
      mode = pr.myConfigurationMode or "DISABLED",
      on_save = pr.myRunOnSave == "true",
      on_reformat = pr.myRunOnReformat == "true",
      pattern = pr.myFilesPattern or M.PRETTIER_PATTERN,
    },
  }
  cache[root] = { key = key, project = project }
  return project
end

--- Does IntelliJ run Prettier on this file when it is saved / reformatted (action "save" / "reformat")?
--- As in its Automatic mode: the file matches "Run for files" and a prettier package sits in a node_modules
--- above it.
function M.prettier_applies(project, file, action)
  local p = project.prettier
  if p.mode == "DISABLED" then return false end
  if action == "save" and not p.on_save then return false end
  if action == "reformat" and p.mode == "MANUAL" and not p.on_reformat then return false end
  file = vim.fs.normalize(file)
  local rel = vim.fs.relpath(project.root, file)
  local ok, glob = pcall(vim.glob.to_lpeg, p.pattern)
  if not (rel and ok and glob:match(rel)) then return false end
  for dir in vim.fs.parents(file) do
    if vim.uv.fs_stat(dir .. "/node_modules/prettier/package.json") then return true end
  end
  return false
end

local function selected(types, ft)
  if not types then return true end
  for _, t in ipairs(types) do
    if vim.tbl_contains(M.FILE_TYPES[t] or {}, ft) then return true end
  end
  return false
end

local function project_of(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or vim.bo[buf].buftype ~= "" then return nil end
  return M.project(M.project_root(file)), vim.fs.normalize(file)
end

--- What saving does to a buffer, like IntelliJ's Actions on Save: nil outside IntelliJ projects (GreyNight's own
--- behavior - except Java, which gets IntelliJ's defaults everywhere: nothing), else
--- { format, changed_lines, prettier, organize_imports }.
function M.save_actions(buf)
  local project, file = project_of(buf)
  local ft = vim.bo[buf].filetype
  if not project then
    if ft == "java" then return { format = false, changed_lines = false, prettier = false, organize_imports = false } end
    return nil
  end
  local s = project.save
  local format = s.format and selected(s.format_types, ft)
  local prettier_on_save = M.prettier_applies(project, file, "save")
  return {
    format = format or prettier_on_save,
    changed_lines = format and s.changed_lines or false,
    prettier = prettier_on_save or (format and M.prettier_applies(project, file, "reformat")),
    organize_imports = s.optimize_imports and selected(s.optimize_types, ft) or false,
  }
end

--- How <leader>fm formats, like IntelliJ's Reformat Code: nil outside IntelliJ projects (GreyNight's own way),
--- else conform options - the project's prettier where IntelliJ would run it, else the language server
--- (IntelliJ's own formatter cannot run while IntelliJ is open: the server comes closest).
function M.reformat_options(buf)
  local project, file = project_of(buf)
  if not project then return nil end
  if M.prettier_applies(project, file, "reformat") then return { formatters = { "prettier" }, lsp_format = "never" } end
  return { lsp_format = "prefer" }
end

--- The lines changed since the last commit (gitsigns' hunks) as conform ranges, for "Only changes uncommitted
--- to VCS".
function M.changed_ranges(buf)
  local ok, gitsigns = pcall(require, "gitsigns")
  local hunks = ok and gitsigns.get_hunks and gitsigns.get_hunks(buf) or {}
  local out = {}
  for _, h in ipairs(hunks or {}) do
    if h.added and h.added.count > 0 then
      local last = h.added.start + h.added.count - 1
      local line = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ""
      out[#out + 1] = { start = { h.added.start, 0 }, ["end"] = { last, #line } }
    end
  end
  return out
end

-- ── Remote JVM Debug configurations ─────────────────────────
local function xml_files(dir)
  local out = {}
  if vim.fn.isdirectory(dir) == 0 then return out end
  for name, kind in vim.fs.dir(dir) do
    if kind == "file" and name:match("%.xml$") then out[#out + 1] = read(dir .. "/" .. name) end
  end
  return out
end

--- IntelliJ's Remote JVM Debug configurations that attach to a JVM: this project's first, then those of
--- IntelliJ's other recent projects, each host:port once - { name, host, port, project }.
function M.remote_debug(root)
  local roots = root and { root } or {}
  local config = M.config_dir()
  local recent = config and read(config .. "/options/recentProjects.xml")
  for key in (recent or ""):gmatch('<entry key="([^"]+)"') do
    local dir = expand(unescape(key))
    if not vim.tbl_contains(roots, dir) and vim.fn.isdirectory(dir .. "/.idea") == 1 then roots[#roots + 1] = dir end
  end
  local out, seen = {}, {}
  for _, dir in ipairs(roots) do
    local sources = { read(dir .. "/.idea/workspace.xml") }
    vim.list_extend(sources, xml_files(dir .. "/.idea/runConfigurations"))
    vim.list_extend(sources, xml_files(dir .. "/.run"))
    for _, xml in ipairs(sources) do
      for cfg in (xml or ""):gmatch('<configuration%s[^>]-type="Remote".-</configuration>') do
        local a = attrs(cfg:match("^<configuration%s[^>]*>"))
        local o = options(cfg)
        local port = tonumber(o.PORT)
        local key = tostring(o.HOST) .. ":" .. tostring(port)
        if a.default ~= "true" and o.SERVER_MODE ~= "true" and o.HOST and port and not seen[key] then
          seen[key] = true
          out[#out + 1] = { name = a.name or key, host = o.HOST, port = port, project = vim.fs.basename(dir) }
        end
      end
    end
  end
  return out
end

return M
