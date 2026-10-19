-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Java: jdtls on a project the way IntelliJ has it - the     ║
-- ║  project's JDK, IntelliJ's Maven settings (no drift), Maven ║
-- ║  import only; tests and debugging through java-test and     ║
-- ║  java-debug-adapter; IntelliJ's remote debug configs        ║
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

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Java" }) end

local function mason_path(...) return vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", ...) end

-- jdtls' workspaces are its project index (a G3 import takes minutes): kept in Neovim's data directory - the
-- cache directory is the temp directory on Windows
local function data_path(...) return vim.fs.joinpath(vim.fn.stdpath("data"), ...) end

--- The Java that runs jdtls: IntelliJ's newest JDK 21+, else $JDTLS_JAVA_HOME, $JAVA_HOME or the java on the PATH
--- when it is 21+. Returns the executable and { home, major }, or nil.
function M.server_java()
  local jdk = intellij.newest_jdk(M.MIN_JAVA)
  if jdk then return intellij.java_bin(jdk.home), jdk end
  for _, home in ipairs({ vim.env.JDTLS_JAVA_HOME, vim.env.JAVA_HOME }) do
    if home and home ~= "" then
      home = vim.fs.normalize(home)
      local major = intellij.java_major(home)
      if major and major >= M.MIN_JAVA then return intellij.java_bin(home), { home = home, major = major } end
    end
  end
  local java = vim.fn.exepath("java")
  if java ~= "" then
    local real = vim.fs.normalize(vim.uv.fs_realpath(java) or java)
    local home = vim.fs.dirname(vim.fs.dirname(real))
    local major = intellij.java_major(home)
    if major and major >= M.MIN_JAVA then return real, { home = home, major = major } end
  end
end

-- jdtls' execution environment names: JavaSE-1.8, JavaSE-17
local function environment(major) return major <= 8 and ("JavaSE-1." .. major) or ("JavaSE-" .. major) end

--- jdtls' runtimes: the project's JDK as the default, then the other JDKs IntelliJ knows (one per version);
--- without an IntelliJ project $JAVA_HOME is the default.
function M.runtimes(project)
  local out, seen = {}, {}
  local function add(home, major, default)
    if not home or not major or seen[major] then return end
    seen[major] = true
    out[#out + 1] = { name = environment(major), path = home, default = default or nil }
  end
  if project and project.jdk then
    add(project.jdk.home, project.jdk.major, true)
  elseif vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then
    local home = vim.fs.normalize(vim.env.JAVA_HOME)
    add(home, intellij.java_major(home), true)
  end
  for _, jdk in ipairs(intellij.jdks()) do add(jdk.home, jdk.major, false) end
  return out
end

--- Maven settings for jdtls as IntelliJ uses them: { user, global } (nil = jdtls' defaults). A local repository
--- IntelliJ sets comes in through a generated settings file that holds only that; IntelliJ's settings file then
--- goes in as the global one (no copy of it - it may hold server credentials).
function M.maven_settings(project)
  local m = project and project.maven or {}
  local global = m.home and (m.home .. "/conf/settings.xml") or nil
  if not m.local_repository then return { user = m.user_settings, global = global } end
  local file = data_path("greyknight", "maven-local-repository-" .. vim.fn.sha256(m.local_repository):sub(1, 10) .. ".xml")
  vim.fn.mkdir(vim.fs.dirname(file), "p")
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

--- jdtls' settings for a project: IntelliJ's runtimes and Maven, Maven import only (no Gradle), IntelliJ's
--- import layout (others, javax, java, statics; * from 5 classes / 3 static names), organize imports on save
--- only when IntelliJ's Actions on Save do it, the IntelliJ-like format profile.
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
      import = { gradle = { enabled = false }, maven = { enabled = true } },
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
--- extension decides that before the launch), so it is decided here from the project's JDK.
function M.dap_overrides(path)
  local project = path and intellij.project(intellij.project_root(path))
  local major = project and project.jdk and project.jdk.major
  if not major and vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then major = intellij.java_major(vim.fs.normalize(vim.env.JAVA_HOME)) end
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
    return nil, "jdtls needs Java " .. M.MIN_JAVA .. "+: add one to IntelliJ (Project Structure | SDKs) or set JDTLS_JAVA_HOME"
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
