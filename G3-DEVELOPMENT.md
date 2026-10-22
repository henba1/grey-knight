# G3 Development with GreyKnight

GreyKnight for the G3 repositories: the Java backends (Maven multi-module), **ngx-his** (Angular, Nx) and the
`*-html5/client` folders (AngularJS in TypeScript). It works next to IntelliJ IDEA and reads IntelliJ's settings -
never writing them - so the JDK, Maven and what saving does are the same in both editors. It needs no IntelliJ
either: without it (Linux, another machine) it takes the JDKs and the Maven of the machine, as the `mvn` command
line does - see [Without IntelliJ](#without-intellij).

Leader = `Space`. Open this file: `<leader>gd`, or **Config** on the start screen.

**Contents:** [Before You Start](#before-you-start) · [What Comes from IntelliJ](#what-comes-from-intellij) ·
[Without IntelliJ](#without-intellij) · [Java Backend](#java-backend) · [ngx-his (Angular)](#ngx-his-angular) ·
[html5 Clients (AngularJS)](#html5-clients-angularjs) · [Working Next to IntelliJ](#working-next-to-intellij) ·
[Troubleshooting](#troubleshooting) · [Quick Reference](#quick-reference)

---

## Before You Start

1. **With IntelliJ: open the repository there once.** That creates its `.idea` folder with the project's JDK and
   the Maven settings GreyKnight takes over. Start Neovim in the repository root: the folder with `.idea` is the
   project. No IntelliJ: [Without IntelliJ](#without-intellij).
2. **A JDK 21 or newer** - in IntelliJ (File → Project Structure → SDKs) or installed on the machine. The Java
   language server (jdtls) runs on it; your project keeps compiling with its own JDK.
3. **ngx-his: `npm ci` once.** The Angular language server uses the project's own Angular and TypeScript from
   `node_modules`.
4. **Windows:** start Neovim from a new terminal after installing tools, so their `PATH` is current.

The language servers install themselves (Mason) with the first file that needs them - jdtls, the Java debugger
and test runner with the first `.java` file, the Angular, ESLint, HTML and CSS servers with the first web file.

## What Comes from IntelliJ

| Setting | In IntelliJ | In GreyKnight |
|---|---|---|
| Project JDK | File → Project Structure → Project → SDK | Errors, runs and tests use this JDK (per repository: 17 or 21) |
| JDK for jdtls | File → Project Structure → SDKs | The newest JDK 21+ there runs the language server (`JDTLS_JAVA_HOME`, when set, comes first) |
| Maven | Settings → Build Tools → Maven: home, settings file, local repository | jdtls imports the project with exactly these; Maven only, never Gradle |
| Actions on Save | Settings → Tools → Actions on Save | Saving does the same: reformat (also "only changed lines"), optimize imports - by default nothing |
| Prettier | Settings → Languages & Frameworks → JavaScript → Prettier | `<leader>fm` uses the project's prettier where IntelliJ would ("Run for files"); "Run on save" works on save |
| Remote JVM Debug | Run → Edit Configurations | `F5` and `<leader>da` in a Java file offer them (from all your recent projects) |

Changes in IntelliJ count at once for saving and formatting; JDK and Maven settings when jdtls starts the next
time - restart Neovim (`:JdtRestart` keeps the settings it started with).

## Without IntelliJ

GreyKnight needs no IntelliJ: on Linux, or on a machine without it, it takes what the machine has - the way the
`mvn` command line does. A repository IntelliJ has not imported as a Maven project on this machine (no Maven
settings in `.idea/workspace.xml`) gets the same; one it has imported keeps the Maven settings of its `.idea`, also
when IntelliJ is gone.

| Setting | Without IntelliJ |
|---|---|
| Project JDK | `JAVA_HOME`, else the `java` on the `PATH` - the JDK `mvn` runs on. A project on another Java version gets an installed JDK of that version |
| JDK for jdtls | `JDTLS_JAVA_HOME`; else `JAVA_HOME` or the `java` on the `PATH` when it is 21+; else the newest JDK 21+ installed |
| Installed JDKs | Next to `JAVA_HOME`, `JDTLS_JAVA_HOME` and the `java` on the `PATH` (JDKs unpacked side by side), in the usual places (`/usr/lib/jvm`, SDKMAN, `~/.jdks`, `C:\Program Files\Java`, Eclipse Adoptium, ...) and in the folders `GREYKNIGHT_JDK_DIRS` names (separated like `PATH`) |
| Maven | The `mvn` on the `PATH` (else `MAVEN_HOME`, `M2_HOME`): its `conf/settings.xml` - mirror, local repository - and `~/.m2/settings.xml`. Maven only, never Gradle |
| Saving, `<leader>fm` | Java as IntelliJ's defaults: nothing on save, `<leader>fm` with the IntelliJ-like profile. Other files: GreyKnight's own [format on save](docs/code.md#format-on-save) |
| Debugging | `<leader>da` attaches to `host:port`; `F5` offers the main classes |

On Linux (Debian, Ubuntu, Kali): `sudo apt install openjdk-21-jdk maven`, plus the JDK of the project when that is
another version. G3 needs the company's Maven settings (the mirror) there as for the command line: in Maven's
`conf/settings.xml` or in `~/.m2/settings.xml`.

## Java Backend

### The First Java File

Open any `.java` file. The first time, Mason installs jdtls, java-debug-adapter and java-test, then jdtls imports
the Maven project - about two minutes for a G3 repository (progress in the notifications). The index is kept, so
later starts take seconds. Until the import is through, imports from other modules show as unresolved.

### Navigation and Code Intelligence

| Key | Action |
|---|---|
| `gd` / `gD` | Definition / declaration - also into dependencies (sources or decompiled) |
| `Ctrl+Click` | As in IntelliJ: the declaration; on the declaration its usages (one: there) |
| `gr` / `gi` | References / implementations |
| `K` | Javadoc and signature |
| `<leader>ca` | Code actions: organize imports, add import, extract variable / constant / method, generate getters, ... |
| `<leader>rn` | Rename (across modules) |
| `<leader>D` | Type definition |
| `[d` / `]d`, `<leader>xx` | Previous / next problem, all problems (Trouble) |
| `<leader>fs` | Symbols of the file |
| `<leader>ff` / `<leader>fg` | Find files / text in the repository |

### Tests (TestNG)

| Key | Action |
|---|---|
| `<leader>rt` | Run the test class of the file |
| `<leader>rT` | Run the test method at the cursor |
| `<leader>dt` | Debug the test method at the cursor (breakpoints first) |

Passed tests get a ✔️ next to them, failed ones a diagnostic with the message (`]d`, `<leader>xx`); TestNG's
summary and the stack traces are in the debug REPL (`<leader>dr`, or the debug UI `<leader>du`). Methods that are
tests only through a `@Test` on the class run as well, but get no mark. A G3 module's classpath is too long for
Windows' command line: the test JVM gets it in a file, as in IntelliJ.

### Running and Debugging

| Key | Action |
|---|---|
| `F9` / `<leader>db` | Breakpoint (`<leader>dB` conditional, `<leader>dp` log point) |
| `F5` | Start: a `main` class jdtls found, or one of IntelliJ's Remote JVM Debug configurations; continue when stopped |
| `<leader>da` | Attach to a running server: IntelliJ's Remote JVM Debug configurations, or `host:port` |
| `F10` / `F11` / `F12` | Step over / into / out |
| `<leader>dh` | Value under the cursor |
| `<leader>dq` / `Shift+F5` | Stop |

To debug a G3 server, start it with its debug port open (as you do for IntelliJ), then `<leader>da` and pick the
configuration. During a debug session, saving a changed class replaces it in the running JVM (hot code replace),
as far as the JVM allows - as in IntelliJ.

### Formatting and Imports

- **Saving** does what IntelliJ's Actions on Save do - by default nothing, so no file changes without you.
- **`<leader>fm`** formats with a profile close to IntelliJ's default Java style. Approximate: IntelliJ's own
  formatter cannot run while IntelliJ is open. **Select the lines first** (`V`, move, `<leader>fm`) to touch only
  those - the way to keep diffs small.
- **Organize imports** (`<leader>ca`) follows IntelliJ's default layout: other imports, `javax.*`, `java.*`, statics;
  `*` from 5 classes of a package (3 static names).

### Building

Build with Maven as you do now - in IntelliJ's Maven tool window or a terminal (`:ToggleTerm`), e.g.
`mvn -pl <module> -am install`. After a change to a `pom.xml`, `:JdtUpdateConfig` lets jdtls read it again.
`:JdtShowMavenActiveProfiles` / `:JdtUpdateMavenActiveProfiles` show and set the Maven profiles jdtls uses.

## ngx-his (Angular)

ngx-his is an Nx workspace (`nx.json`). In it:

- **Templates** (`*.component.html`) are filetype `htmlangular`: the Angular language server knows the component -
  completion of its members, inputs and outputs, errors in bindings, `gd` from the template into the class.
- **TypeScript** gets `ts_ls` plus the Angular language server; **ESLint** runs with the project's
  `eslint.config.cjs` (problems as diagnostics, fixes as code actions `<leader>ca`); **SCSS** has its own server.
- The language server uses the project's Angular version and TypeScript (`node_modules`), as IntelliJ does.
- **`<leader>fm`**: the project's prettier for TypeScript and JavaScript (IntelliJ's Automatic Prettier mode);
  templates and styles go through their language server. Saving changes nothing.
- **Unit tests** run with Nx in a terminal (`:ToggleTerm`): `npx nx test <project>`.

## html5 Clients (AngularJS)

The `*-html5/client` folders are AngularJS written in TypeScript:

- **TypeScript** through `ts_ls` (the client's own TypeScript), **ESLint** with the client's `.eslintrc.js`.
- **Templates** are plain HTML (HTML server: tags, attributes, closing tags). No language server knows AngularJS
  templates - no completion of `ng-*` attributes or scope variables.
- **`<leader>fm`**: Prettier is not enabled for these projects in IntelliJ, so the language server formats them;
  turn on Automatic Prettier there (Settings → Languages & Frameworks → JavaScript → Prettier) and GreyKnight
  follows with the client's `.prettierrc.js`.

## Working Next to IntelliJ

- Both can have the same repository open. GreyKnight never writes `.idea`; its jdtls index lives in Neovim's data
  directory, Eclipse's `.project` / `.classpath` / `.settings` there too - none of them in the repository.
- Java files keep their line endings (CRLF in a Windows checkout).
- The coding agent (`<leader>tt`, `<leader>aa` - OpenCode on the work laptop) works in the same repository.
- IntelliJ stays the place for exact reformatting (`Ctrl+Alt+L`), refactorings across many modules and its
  Maven and database tools.

## Troubleshooting

| Symptom | What to do |
|---|---|
| "jdtls needs Java 21+" | Install a JDK 21+ (or add one in IntelliJ: Project Structure → SDKs); one in a folder of your own: `JDTLS_JAVA_HOME` or `GREYKNIGHT_JDK_DIRS`. Then reopen the file |
| Which JDKs and Maven settings jdtls got | `:lua =require("integrations.jdtls").config(vim.fs.normalize(vim.fn.expand("%:p"))).settings.java.configuration` in a Java file |
| Imports stay unresolved | Wait for the import (notifications); after `pom.xml` changes `:JdtUpdateConfig`; still wrong: `:JdtRestart` |
| The index is broken | `:lua require("jdtls.setup").wipe_data_and_restart()` - a fresh import (minutes) |
| `.project`, `.classpath`, `.settings`, `.factorypath` untracked in a repository | Left by GreyKnight before 2026-10-20: delete them (`git clean -n` shows them first), then wipe the index as above |
| What jdtls did | `:lua require("jdtls.setup").show_logs()`; servers and their state: `:checkhealth vim.lsp` |
| A server is missing | `:Mason` shows what is installed; the next matching file installs it again |
| Template without Angular help | Is it a `*.component.html` inside ngx-his, and did `npm ci` run? |

## Quick Reference

| Key | Action |
|---|---|
| `gd` / `gr` / `K` | Definition / references / docs |
| `Ctrl+Click` | Declaration; on it its usages (IntelliJ's) |
| `<leader><Tab>` / `<C-o>` | Recent buffers (Ctrl+Tab) / back where you came from (Navigate Back) |
| `<leader>e` then `R` | Files by regex or glob (Go to File's `*`): `.*Test\.java$`, `*.component.html`; with a `/` the path |
| `<leader>mm` / `<leader>ml` | Bookmark this line / the bookmarks (IntelliJ's F11 is step into here; Shift+F11 lists) |
| `<leader>ca` / `<leader>rn` | Code action / rename |
| `<leader>rt` / `<leader>rT` | Run the test class / test at the cursor |
| `<leader>dt` | Debug the test at the cursor |
| `F5` / `<leader>da` | Debug: start or IntelliJ's remote configurations / attach |
| `F9` / `F10` / `F11` / `F12` | Breakpoint / over / into / out |
| `<leader>dr` / `<leader>du` | Debug REPL (test output) / debug UI |
| `<leader>fm` | Format (selection: only those lines) |
| `<leader>xx` | All problems |
| `<leader>gg` | Lazygit |
| `<leader>gd` | GreyKnight docs, this one included |
