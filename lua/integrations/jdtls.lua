-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Java: jdtls with the project's JDK and Maven - IntelliJ's  ║
-- ║  where IntelliJ has the project (no drift), else the JDKs   ║
-- ║  and the Maven of this machine, as the mvn command line;    ║
-- ║  Maven import only; tests and debugging through java-test   ║
-- ║  and java-debug-adapter; IntelliJ's remote debug configs    ║
-- ╚══════════════════════════════════════════════════════════════╝
local intellij = require("integrations.intellij")
local M = {}

M.MIN_JAVA = 21 -- jdtls itself runs on Java 21+
M.PACKAGES = { "jdtls", "java-debug-adapter", "java-test" }
-- An Eclipse formatter profile close to IntelliJ's default Java code style (formatting is approximate: IntelliJ's
-- own formatter cannot run while IntelliJ is open)
M.FORMAT_PROFILE = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/resources/intellij-java-format.xml"
M.FORMAT_PROFILE_NAME = "IntelliJ IDEA default (GreyKnight)"


local WARN = vim.log.levels.WARN
local WIN = vim.fn.has("win32") == 1

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Java" }) end

local function mason_path(...) return vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", ...) end

-- jdtls' workspaces are its project index (a G3 import takes minutes): kept in Neovim's data directory - the
-- cache directory is the temp directory on Windows
local function data_path(...) return vim.fs.joinpath(vim.fn.stdpath("data"), ...) end

-- The Maven settings generated for a local repository IntelliJ sets: one file per repository (the tests use their
-- own folder - each run's temp project was one more file here, 2026-10-22)
M.settings_dir = data_path("greyknight")

-- ── The JDKs and the Maven of this machine (no IntelliJ needed) ──
-- 2026-10-19: without IntelliJ jdtls only knew $JAVA_HOME and the java on the PATH - on the work laptop both are
-- 17, so jdtls (21+) did not start although a JDK 21 sat next to them, and every project compiled against that
-- one JDK. GreyKnight finds the installed JDKs and reads Maven's settings the way the mvn command line does.
local function env_path(name)
  local value = vim.env[name]
  return value and value ~= "" and vim.fs.normalize(value) or nil
end

-- The JDK in a directory ({ home, major }): its release file names the version and its java runs. macOS bundles
-- keep it in Contents/Home.
local function jdk_at(dir)
  if not dir then return nil end
  for _, home in ipairs({ dir, dir .. "/Contents/Home" }) do
    local major = intellij.java_major(home)
    if major and vim.fn.executable(intellij.java_bin(home)) == 1 then return { home = home, major = major } end
  end
end

local function env_jdk(name) return jdk_at(env_path(name)) end

-- The JDK of the java on the PATH (/usr/bin/java is a chain of links into /usr/lib/jvm)
local function path_jdk()
  local java = vim.fn.exepath("java")
  if java == "" then return nil end
  return jdk_at(vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.uv.fs_realpath(java) or java))))
end

--- The places of this OS that hold installed JDKs.
function M.jdk_places()
  local home = vim.fs.normalize((WIN and vim.env.USERPROFILE) or vim.env.HOME or "~")
  if WIN then
    local programs = vim.fs.normalize(vim.env.ProgramFiles or "C:/Program Files")
    local out = {}
    for _, vendor in ipairs({ "Java", "Eclipse Adoptium", "Microsoft", "Zulu", "Amazon Corretto", "BellSoft", "Semeru" }) do
      out[#out + 1] = programs .. "/" .. vendor
    end
    out[#out + 1] = home .. "/.jdks" -- the JDKs IntelliJ downloaded stay there without IntelliJ
    return out
  elseif vim.fn.has("mac") == 1 then
    return { "/Library/Java/JavaVirtualMachines", home .. "/Library/Java/JavaVirtualMachines",
      home .. "/.sdkman/candidates/java", home .. "/.jdks" }
  end
  return { "/usr/lib/jvm", "/usr/java", "/opt/java", home .. "/.sdkman/candidates/java", home .. "/.jdks",
    home .. "/.local/share/mise/installs/java", home .. "/.asdf/installs/java" }
end

--- The JDKs installed on this machine, found without IntelliJ - { home, major } each, every JDK once, in this
--- order: $JDTLS_JAVA_HOME, $JAVA_HOME and the java on the PATH; what $GREYKNIGHT_JDK_DIRS names (JDKs or folders
--- of JDKs, separated like PATH); the folders next to the first ones (JDKs unpacked side by side, as
--- C:/dev/tools/jdk/*); the places of the OS (M.jdk_places()).
function M.installed_jdks()
  local out, seen = {}, {}
  local function add(jdk)
    if not jdk then return end
    local key = vim.fs.normalize(vim.uv.fs_realpath(jdk.home) or jdk.home)
    if WIN then key = key:lower() end
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = jdk
  end
  -- A JDK, or a folder of JDKs: directories before links, so /usr/lib/jvm/default-java (a link that moves with
  -- the system's default) never stands for a version
  local function scan(dir)
    if not dir or vim.fn.isdirectory(dir) == 0 then return end
    local jdk = jdk_at(dir)
    if jdk then return add(jdk) end
    local dirs, links = {}, {}
    pcall(function()
      for name, kind in vim.fs.dir(dir) do
        if kind == "directory" then dirs[#dirs + 1] = name elseif kind == "link" then links[#links + 1] = name end
      end
    end)
    table.sort(dirs)
    table.sort(links)
    for _, name in ipairs(vim.list_extend(dirs, links)) do add(jdk_at(dir .. "/" .. name)) end
  end
  local first = {} -- (a list literal of the three would end at the first nil)
  for _, find in ipairs({ function() return env_jdk("JDTLS_JAVA_HOME") end, function() return env_jdk("JAVA_HOME") end, path_jdk }) do
    first[#first + 1] = find()
  end
  for _, jdk in ipairs(first) do add(jdk) end
  for _, dir in ipairs(vim.split(vim.env.GREYKNIGHT_JDK_DIRS or "", WIN and ";" or ":", { trimempty = true })) do
    scan(vim.fs.normalize(dir))
  end
  for _, jdk in ipairs(first) do scan(vim.fs.dirname(jdk.home)) end
  for _, dir in ipairs(M.jdk_places()) do scan(dir) end
  return out
end

--- The JDK the mvn command line runs on: $JAVA_HOME, else the java on the PATH - { home, major } or nil. Projects
--- IntelliJ does not describe get it as their JDK.
function M.default_jdk() return env_jdk("JAVA_HOME") or path_jdk() end

--- The Java that runs jdtls (21+): $JDTLS_JAVA_HOME when set, else IntelliJ's newest JDK 21+, else $JAVA_HOME or
--- the java on the PATH when it is 21+, else the newest JDK 21+ installed. It does not decide how projects compile
--- (that is M.runtimes()). Returns the executable and { home, major }, or nil.
function M.server_java()
  local function usable(jdk) return jdk and jdk.major >= M.MIN_JAVA and jdk or nil end
  local jdk = usable(env_jdk("JDTLS_JAVA_HOME")) or intellij.newest_jdk(M.MIN_JAVA)
    or usable(env_jdk("JAVA_HOME")) or usable(path_jdk())
  if not jdk then
    for _, j in ipairs(M.installed_jdks()) do
      if j.major >= M.MIN_JAVA and (not jdk or j.major > jdk.major) then jdk = j end
    end
  end
  if jdk then return intellij.java_bin(jdk.home), jdk end
end

-- jdtls' execution environment names: JavaSE-1.8, JavaSE-17
local function environment(major) return major <= 8 and ("JavaSE-1." .. major) or ("JavaSE-" .. major) end

--- jdtls' runtimes: the JDKs projects compile and run with, one per Java version. A project whose JDK IntelliJ
--- knows: that JDK as the default, then IntelliJ's other JDKs - as IntelliJ compiles it. Any other project: the
--- JDK the mvn command line runs on (M.default_jdk()) as the default, then IntelliJ's JDKs where it is installed and
--- the JDKs of this machine (M.installed_jdks()) - a project on another Java version gets that version.
function M.runtimes(project)
  local out, seen = {}, {}
  local function add(jdk, default)
    if not jdk or not jdk.home or not jdk.major or seen[jdk.major] then return end
    seen[jdk.major] = true
    out[#out + 1] = { name = environment(jdk.major), path = jdk.home, default = default or nil }
  end
  if project and project.jdk then
    add(project.jdk, true)
    for _, jdk in ipairs(intellij.jdks()) do add(jdk) end
    return out
  end
  add(M.default_jdk(), true)
  for _, jdk in ipairs(intellij.jdks()) do add(jdk) end
  for _, jdk in ipairs(M.installed_jdks()) do add(jdk) end
  return out
end

--- Maven's home as the mvn command line has it: the mvn on the PATH (links resolved), else $MAVEN_HOME or $M2_HOME.
function M.maven_home()
  local mvn = vim.fn.exepath("mvn")
  if mvn ~= "" then return vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.uv.fs_realpath(mvn) or mvn))) end
  for _, name in ipairs({ "MAVEN_HOME", "M2_HOME" }) do
    local home = env_path(name)
    if home and vim.fn.isdirectory(home) == 1 then return home end
  end
end

--- Maven's settings as the mvn command line reads them: { global = <Maven's home>/conf/settings.xml - where a
--- company mirror and the local repository usually are - , user = nil: jdtls' default ~/.m2/settings.xml, as mvn's }.
function M.mvn_settings()
  local home = M.maven_home()
  local global = home and (home .. "/conf/settings.xml")
  return { user = nil, global = global and vim.uv.fs_stat(global) and global or nil }
end

--- Maven's settings for jdtls: { user, global } (nil = jdtls' defaults). A project IntelliJ has imported as Maven
--- on this machine (Maven settings in .idea/workspace.xml): IntelliJ's - a local repository IntelliJ sets comes in
--- through a generated settings file that holds only that, IntelliJ's settings file then goes in as the global one
--- (no copy of it - it may hold server credentials). Any other project: as the mvn command line (M.mvn_settings()) -
--- also one IntelliJ opened but never imported as Maven (2026-10-20: two G3 repositories got jdtls' defaults then,
--- without the company's mirror).
function M.maven_settings(project)
  local m = project and project.workspace and project.maven
  if not (m and (m.home or m.user_settings or m.local_repository)) then return M.mvn_settings() end
  local global = m.home and (m.home .. "/conf/settings.xml") or nil
  if not m.local_repository then return { user = m.user_settings, global = global } end
  local file = vim.fs.joinpath(M.settings_dir, "maven-local-repository-" .. vim.fn.sha256(m.local_repository):sub(1, 10) .. ".xml")
  vim.fn.mkdir(M.settings_dir, "p")
  local repo = (m.local_repository:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
  vim.fn.writefile({
    '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">',
    "  <!-- written by GreyKnight: the local repository IntelliJ uses for this project -->",
    "  <localRepository>" .. repo .. "</localRepository>",
    "</settings>",
  }, file)
  return { user = file, global = m.user_settings or global }
end

--- The directory jdtls works on: IntelliJ's project (where .idea is), else the outermost pom.xml below the git
--- root, else the git root.
function M.root(file)
  local ij = intellij.project_root(file)
  if ij then return ij end
  local git = vim.fs.root(file, ".git")
  local root
  for dir in vim.fs.parents(file) do
    if vim.uv.fs_stat(dir .. "/pom.xml") then root = dir end
    if dir == git then break end
  end
  return root or git or vim.fs.dirname(file)
end

--- jdtls' settings for a project (IntelliJ's, or nil): its runtimes and Maven (M.runtimes(), M.maven_settings()),
--- Maven import only (no Gradle), IntelliJ's import layout (others, javax, java, statics; * from 5 classes / 3
--- static names), organize imports on save only when IntelliJ's Actions on Save do it, the IntelliJ-like format
--- profile.
function M.settings(project)
  local maven = M.maven_settings(project)
  local optimize = false
  if project then
    local s = project.save
    optimize = s.optimize_imports and (s.optimize_types == nil or vim.tbl_contains(s.optimize_types, "JAVA"))
  end
  return {
    java = {
      configuration = {
        runtimes = M.runtimes(project),
        maven = { userSettings = maven.user, globalSettings = maven.global },
        updateBuildConfiguration = "interactive",
      },
      -- Eclipse's .project / .classpath / .settings / .factorypath in jdtls' workspace, not in the repository
      -- (2026-10-20: jdtls wrote 44 of them into a G3 checkout, untracked and not ignored - one git add -A away)
      import = { gradle = { enabled = false }, maven = { enabled = true }, generatesMetadataFilesAtProjectRoot = false },
      maven = { downloadSources = false }, -- as IntelliJ: sources when you open a class
      format = {
        enabled = true,
        comments = { enabled = false },
        settings = { url = vim.uri_from_fname(M.FORMAT_PROFILE), profile = M.FORMAT_PROFILE_NAME },
      },
      saveActions = { organizeImports = optimize },
      sources = { organizeImports = { starThreshold = 5, staticStarThreshold = 3 } },
      completion = { importOrder = { "", "javax", "java", "#" } },
      contentProvider = { preferred = "fernflower" }, -- classes without sources: decompiled
      signatureHelp = { enabled = true },
    },
  }
end

local function total_memory_gb() return vim.uv.get_total_memory() / 1024 ^ 3 end

--- The command that starts jdtls (Mason's package) with this Java, or nil when jdtls is not installed.
function M.cmd(java, workspace)
  local home = mason_path("jdtls")
  local launcher = vim.fn.glob(home .. "/plugins/org.eclipse.equinox.launcher_*.jar", false, true)[1]
  if not launcher then return nil end
  local config = (vim.fn.has("win32") == 1 and "config_win") or (vim.fn.has("mac") == 1 and "config_mac") or "config_linux"
  if config ~= "config_win" and vim.uv.os_uname().machine:match("^a") and vim.fn.isdirectory(home .. "/" .. config .. "_arm") == 1 then
    config = config .. "_arm"
  end
  local gb = total_memory_gb()
  return {
    java,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dosgi.checkConfiguration=true",
    "-Dosgi.sharedConfiguration.area=" .. home .. "/" .. config,
    "-Dosgi.sharedConfiguration.area.readOnly=true",
    "-Dosgi.configuration.cascaded=true",
    "-Xms256m",
    "-Xmx" .. (gb >= 24 and "4g" or gb >= 12 and "2g" or "1g"), -- G3 is a big multi-module build
    "--add-modules=ALL-SYSTEM",
    "--add-opens", "java.base/java.util=ALL-UNNAMED",
    "--add-opens", "java.base/java.lang=ALL-UNNAMED",
    "-jar", launcher,
    "-configuration", data_path("jdtls", "configuration"),
    "-data", workspace,
  }
end

--- java-debug-adapter and java-test as jdtls bundles (java-test's runner and jacoco are no bundles).
function M.bundles()
  local out = vim.fn.glob(mason_path("java-debug-adapter", "extension", "server", "com.microsoft.java.debug.plugin-*.jar"), false, true)
  for _, jar in ipairs(vim.fn.glob(mason_path("java-test", "extension", "server", "*.jar"), false, true)) do
    local name = vim.fs.basename(jar)
    if name ~= "com.microsoft.java.test.runner-jar-with-dependencies.jar" and name ~= "jacocoagent.jar" then out[#out + 1] = jar end
  end
  return out
end

local testng_patched = false

--- nvim-jdtls' TestNG reporter cuts the protocol frame off each line ("@@<TestRunner-{json}-TestRunner>"); on
--- Windows the runner ends its lines with \r\n, the \r stayed in and no line decoded - in a window that error
--- was a prompt that blocked Neovim, and no test got its mark (2026-10-19). Its reader gets the data without \r.
function M.patch_testng()
  if testng_patched then return end
  local ok, testng = pcall(require, "jdtls.testng")
  if not ok then return end
  testng_patched = true
  local mk_test_results = testng.mk_test_results
  testng.mk_test_results = function(bufnr)
    local results = mk_test_results(bufnr)
    local mk_reader = results.mk_reader
    results.mk_reader = function(sock)
      local reader = mk_reader(sock)
      return function(err, chunk) return reader(err, chunk and (chunk:gsub("\r", ""))) end
    end
    return results
  end
end

--- Overrides for every launch (tests, main classes). The classpath of a G3 module is far longer than Windows'
--- 32 767 characters ("E903: name too long", 2026-10-19): java-debug passes it in a file, as IntelliJ does - an
--- @argfile from Java 9 on, a manifest jar for Java 8. java-debug itself does not know "auto" (VS Code's
--- extension decides that before the launch), so it is decided here from the project's JDK - IntelliJ's, else the
--- one the mvn command line runs on.
function M.dap_overrides(path)
  local project = path and intellij.project(intellij.project_root(path))
  local jdk = (project and project.jdk) or M.default_jdk()
  local major = jdk and jdk.major
  return { shortenCommandLine = (major and major < 9) and "jarmanifest" or "argfile" }
end

--- IntelliJ's Remote JVM Debug configurations as nvim-dap attach configurations.
function M.remote_configurations(path)
  return vim.tbl_map(function(r)
    return {
      type = "java",
      request = "attach",
      name = ("IntelliJ: %s (%s:%d)"):format(r.name, r.host, r.port),
      hostName = r.host,
      port = r.port,
    }
  end, intellij.remote_debug(intellij.project_root(path)))
end

-- F5 offers them in Java files (next to the main classes nvim-jdtls finds)
local function add_remote_configurations(path)
  local dap = require("dap")
  dap.configurations.java = dap.configurations.java or {}
  local have = {}
  for _, c in ipairs(dap.configurations.java) do have[c.name] = true end
  for _, c in ipairs(M.remote_configurations(path)) do
    if not have[c.name] then table.insert(dap.configurations.java, c) end
  end
end

--- <leader>da in Java: attach the debugger to a JVM - one of IntelliJ's Remote JVM Debug configurations, or
--- host:port typed in (IntelliJ's default port for G3 servers is 8000).
function M.attach()
  local file = vim.api.nvim_buf_get_name(0)
  local choices = M.remote_configurations(file)
  table.insert(choices, { name = "Other host:port ..." })
  vim.ui.select(choices, { prompt = "Attach the debugger", format_item = function(c) return c.name end }, function(choice)
    if not choice then return end
    if not choice.request then
      local target = vim.fn.input("host:port: ", "localhost:8000")
      local host, port = target:match("^%s*(%S+):(%d+)%s*$")
      if not host then return notify("Debug: host:port expected", WARN) end
      choice = { type = "java", request = "attach", name = "attach: " .. target, hostName = host, port = tonumber(port) }
    end
    require("dap").run(choice)
  end)
end

local function capabilities()
  local caps = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  return ok and blink.get_lsp_capabilities(caps) or caps
end

local warned = false

--- jdtls' workspace (its index) for a project root.
function M.workspace(root)
  return data_path("jdtls", "workspace", vim.fs.basename(root) .. "-" .. vim.fn.sha256(root):sub(1, 8))
end

--- jdtls' initialization options: the settings too - jdtls imports the project before it gets them over
--- didChangeConfiguration, so without them it imported with its defaults (G3's build.gradle went to Gradle,
--- 2026-10-19).
function M.init_options(settings)
  return {
    settings = settings,
    bundles = M.bundles(),
    extendedClientCapabilities = require("jdtls.setup").extendedClientCapabilities,
  }
end

--- The jdtls configuration for a Java file, or nil and why not.
function M.config(file)
  local java = M.server_java()
  if not java then
    return nil, ("jdtls needs Java %d+ and found none: install a JDK %d or newer (or add one in IntelliJ), or set"
      .. " JDTLS_JAVA_HOME to one - JDKs in a folder of your own: GREYKNIGHT_JDK_DIRS"):format(M.MIN_JAVA, M.MIN_JAVA)
  end
  local root = M.root(file)
  local project = intellij.project(intellij.project_root(file))
  local cmd = M.cmd(java, M.workspace(root))
  if not cmd then return nil, "jdtls is not installed (Mason)" end
  local settings = M.settings(project)
  return {
    name = "jdtls",
    cmd = cmd,
    root_dir = root,
    settings = settings,
    init_options = M.init_options(settings),
    capabilities = capabilities(),
    on_attach = function()
      pcall(function()
        require("jdtls.dap").setup_dap({ hotcodereplace = "auto", config_overrides = M.dap_overrides(file) })
        -- java-debug resolves a G3 module's classpath before it answers: no "adapter didn't respond" after 4 s
        require("dap").defaults.java.initialize_timeout_sec = 30
        require("jdtls.dap").setup_dap_main_class_configs()
      end)
      add_remote_configurations(file)
    end,
  }
end

--- Starts jdtls for a Java buffer (or attaches it to the running one of its project).
function M.start(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or vim.bo[buf].buftype ~= "" or file:match("^jdt://") then return end -- jdt:// = nvim-jdtls' own
  require("integrations.mason").ensure(M.PACKAGES, function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local config, why = M.config(vim.fs.normalize(file))
    if not config then
      if not warned then notify(why, WARN) end
      warned = true
      return
    end
    M.patch_testng()
    require("jdtls").start_or_attach(config, {}, { bufnr = buf })
  end, "Java")
end

return M
