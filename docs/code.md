# GreyKnight - Code: editing, language servers, completion, diagnostics

> Editing, the language servers (go to definition, rename, code actions), completion, diagnostics and Trouble, formatting - and Java / Angular.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [Editing](#editing) · [Surround](#surround) · [Code Intelligence (LSP)](#code-intelligence-lsp) · [Autocompletion](#autocompletion) · [Diagnostics & Trouble](#diagnostics-trouble) · [Format on Save](#format-on-save) · [Todo Comments](#todo-comments) · [Multiple Cursors (sort of)](#multiple-cursors-sort-of) · [Markdown Rendering](#markdown-rendering) · [Hex Editor](#hex-editor) · [Java and Angular](#java-and-angular)

## Editing

### Basic Movement

| Key | Action |
|-----|--------|
| `h/j/k/l` | Left/down/up/right |
| `w/b` | Next/previous word |
| `0/$` | Start/end of line |
| `gg/G` | Top/bottom of file |
| `Ctrl+d` | Half page down (centered) |
| `Ctrl+u` | Half page up (centered) |
| `{/}` | Previous/next paragraph |
| `%` | Jump to matching bracket |

### Editing Operations

| Key | Mode | Action |
|-----|------|--------|
| `i/a` | n | Insert before/after cursor |
| `o/O` | n | New line below/above |
| `dd` | n | Delete line |
| `yy` | n | Copy line |
| `p/P` | n | Paste after/before |
| `u` | n | Undo |
| `Ctrl+r` | n | Redo |
| `ciw` | n | Change inner word |
| `ci"` | n | Change inside quotes |
| `J/K` | v | Move selected lines down/up |
| `<leader>p` | v | Paste without overwriting clipboard |
| `<leader>d` | v | Delete the selection without copying it (in normal mode `<leader>d` starts the debug keys) |
| `J` | n | Join lines (cursor stays put) |
| `<leader>w` | n | Save file |
| `<leader>q` | n | Quit window |
| `<leader>Q` | n | Force quit all |

### Incremental Selection (Treesitter)

| Key | Mode | Action |
|-----|------|--------|
| `Ctrl+Space` | n | Start selection (smart, treesitter-aware) |
| `Ctrl+Space` | v | Expand selection to parent node |
| `Backspace` | v | Shrink the selection back the way it grew, node by node |

These run Neovim's own node selection (`:h v_an`), with the LSP's selection ranges where a file type has no
treesitter parser. Neovim's own keys for it, `an` / `in`, are mini.ai's "next" textobjects here (`vin(`
selects inside the next parentheses).

---

## Surround

Add, delete, or change surrounding characters. The keys start with `gs` - `s` alone is Flash's jump, and with
surround's own `sa`/`sd`/`sr` a quick `s` then `d` (to jump to a word starting with d) deleted a surrounding instead.

| Key | Action | Example |
|-----|--------|---------|
| `gsa` + motion + char | Add surround | `gsaiw"` → surround word with `"` |
| `gsd` + char | Delete surround | `gsd"` → remove surrounding `"` |
| `gsr` + old + new | Replace surround | `gsr"'` → change `"` to `'` |

**Examples:**
- Cursor on `hello` → `gsaiw"` → `"hello"`
- Cursor inside `"hello"` → `gsd"` → `hello`
- Cursor inside `"hello"` → `gsr"'` → `'hello'`
- Visual select `hello world` → `gsa"` → `"hello world"`

---

## Code Intelligence (LSP)

Works automatically when you open a supported file. Mason installs the LSP server on first use.

| Key | Action |
|-----|--------|
| `K` | Hover documentation (show function signature, docs) |
| `gd` | Go to definition |
| `Ctrl+Click` | As in IntelliJ: on a name go to its declaration; on the declaration itself its usages |
| `gD` | Go to declaration |
| `gr` | Find all references |
| `gi` | Go to implementation |
| `<leader>D` | Go to type definition |
| `<leader>rn` | Rename symbol (project-wide) |
| `<leader>ca` | Code action (quick fix, refactor) - the cursor on the marked code |
| `[d` | Previous diagnostic (error/warning), its message in a float |
| `]d` | Next diagnostic |
| `<leader>fm` | Format file (or selection in visual mode) |

The keys come with a server that can do what they ask: where none finds definitions (plain HTML, a Python file
with only ruff running), `gd` stays Vim's - the first use of the word in the file - and `K` Vim's keyword lookup.

The servers are set up with Neovim's own `vim.lsp.config` / `vim.lsp.enable`, over nvim-lspconfig's defaults for each
(the older `require("lspconfig")` setup is deprecated and goes with nvim-lspconfig v3). A file outside any project
gets its servers too; for lua_ls its folder is the workspace then - without one it marks nothing. A buffer without a
file (a scratch buffer with a filetype) or one named by a URL (netrw's `scp://`, `diffview://`) gets none.
`:checkhealth vim.lsp` (`:LspInfo`) shows what runs where, `:LspLog` opens the log. `:LspRestart` restarts a server
(none named: those of this buffer), `:LspStop` stops it, `:LspStart` starts it here again - Neovim 0.12's own
`:lsp restart` / `stop` / `enable` work too (nvim-lspconfig no longer defines the `:Lsp…` commands there; these are the
config's).

**Ctrl+Click** does what it does in IntelliJ. On a name it goes to the declaration (`Ctrl+o` comes back, as after
`gd`). On the declaration itself it shows the usages, without the declaration: in the quickfix list, or straight there
when there is only one. Two servers naming the same place (angularls and ts_ls in a `.ts` file) make one jump, not a
list. Where no server finds definitions it is `gd`, in a help file it follows the link. A click
after the end of a line, on a space or a sign only moves the cursor. The terminal must pass Ctrl+Click on to Neovim -
Windows Terminal, kitty, GNOME Terminal and Konsole do (they open links on it only where they see a URL).

### Inline Diagnostics

Errors and warnings appear inline next to the code (via tiny-inline-diagnostic).
No need to look at a separate panel for simple errors.

---

## Autocompletion

Completion appears automatically as you type.

| Key | Action |
|-----|--------|
| `Tab` / `Down` / `Ctrl+n` | Pick the next item (it is inserted right away) |
| `Shift+Tab` / `Up` / `Ctrl+p` | Pick the previous item |
| `Enter` | Accept the item you picked; with nothing picked it is a normal Enter (new line) |
| `Ctrl+Space` | Manually trigger completion menu |
| `Ctrl+e` | Dismiss completion menu |
| `Ctrl+b/f` | Scroll docs up/down |

Nothing is preselected, so `Enter` at the end of a line never takes a suggestion you did not
choose. **Ghost text** shows a grey preview of the top suggestion: `Tab` takes it, `Enter` ignores it.
`Esc` right after `Enter` - before the item went in - leaves the text as `Tab` showed it.

**Signature help** shows function parameters as you type inside `()`.

Sources (in priority order): LSP → Snippets → Buffer words → File paths

---

## Diagnostics & Trouble

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle all diagnostics (Trouble panel) |
| `<leader>xX` | Buffer-only diagnostics |
| `<leader>xl` | Location list |
| `<leader>xq` | Quickfix list |
| `[d` | Jump to previous error/warning |
| `]d` | Jump to next error/warning |

Inline diagnostics appear automatically next to your code.
Trouble gives you a project-wide panel for all issues.

---

## Format on Save
Files auto-format when you save. A file the formatter cannot read yet (an unfinished script) is saved as it
is, without a message - `<leader>fm` says why it fails, `:ConformInfo` has the details. To format manually:
`<leader>fm`. JavaScript and TypeScript use the project's own prettier (`node_modules`), else the language
server. Lua is saved as written - your alignment stays - unless the project formats with stylua (a
`stylua.toml`); `<leader>fm` formats it anyway (stylua there, else the language server). On Windows formatters
run without cmd.exe in between, so folders named with spaces, `&` or `^` work (cmd.exe split such paths, and
Volta's `node` passes them through it). In projects you also open in IntelliJ
(an `.idea` folder) saving does what IntelliJ's Actions on Save do - by default nothing; Java files get that
default everywhere (see [Java and Angular](#java-and-angular)).

---

## Todo Comments
`TODO`, `FIXME`, `HACK`, `NOTE` in comments are highlighted automatically.
Find all todos: `<leader>fd` → look for todo-comment diagnostics.

---

## Multiple Cursors (sort of)
Neovim doesn't have native multi-cursor, but:
- `<leader>rn` renames a symbol everywhere (LSP)
- `<leader>sr` does project-wide search & replace
- `.` repeats the last edit
- Visual block mode (`Ctrl+v`) + `I` inserts on multiple lines

---

## Markdown Rendering

Markdown files render with:
- Formatted headings
- Code block highlighting
- Bullet points
- Bold/italic styling

Spell check is enabled automatically for `.md` files.

---

## Hex Editor

| Key | Action |
|-----|--------|
| `<leader>hx` | Toggle hex view on current buffer |

Useful for binary analysis. Toggle back with the same key.

---

## Java and Angular

GreyKnight works on a project you also open in IntelliJ IDEA the way IntelliJ does: it reads IntelliJ's settings
(`lua/integrations/intellij.lua`, never writing them), so nothing drifts apart. Without IntelliJ it works on its
own ([below](#without-intellij)). The workflow for the G3 repositories, step by step:
[G3-DEVELOPMENT.md](../G3-DEVELOPMENT.md).

| | From IntelliJ |
|---|---|
| JDK | The project's SDK (`.idea/misc.xml` and IntelliJ's JDK table): errors, runs and tests use the JDK IntelliJ uses. jdtls itself runs on IntelliJ's newest JDK 21+ (`JDTLS_JAVA_HOME` first, when set) |
| Maven | IntelliJ's Maven home, settings file and local repository (Settings → Build Tools → Maven). jdtls imports with Maven, never with Gradle |
| Saving | IntelliJ's Actions on Save (reformat, also "only changed lines"; optimize imports) and Prettier's "Run on save" - by default nothing happens |
| `<leader>fm` | IntelliJ's Reformat Code: the project's prettier where IntelliJ runs it (JS / TS in Automatic mode), else the language server |
| Debugging | IntelliJ's Remote JVM Debug configurations of your recent projects: `F5` in a Java file offers them next to the main classes, `<leader>da` attaches |

Approximate: IntelliJ's own formatter cannot run while IntelliJ is open, so jdtls formats Java with a profile
close to IntelliJ's default style (`resources/intellij-java-format.xml`) - format a selection (`V` … then
`<leader>fm`) to touch only those lines. Imports follow IntelliJ's default layout (others, `javax`, `java`,
statics; `*` from 5 classes / 3 static names).

**Java** (jdtls through nvim-jdtls): open a `.java` file. The first time, Mason installs jdtls, java-debug-adapter
and java-test, and the first import of a G3 repository takes a few minutes; later starts reuse it (the index
lives in Neovim's data directory). `gd`, `gr`, `K` and `<leader>ca` (organize imports, extract variable /
method, ...) work as in every language; `<leader>rt` / `<leader>rT` run the test class / the test at the cursor
(TestNG or JUnit), `<leader>dt` debugs it. Passed tests get a ✔️ next to them, failed ones a diagnostic with the
message; the test output (TestNG's summary, stack traces) is in the debug REPL (`<leader>dr`). The classpath of
a G3 module is too long for Windows' command line: the JVM gets it in a file, as in IntelliJ.

**Angular** (ngx-his): a `*.component.html` in an Angular workspace (`angular.json` or `nx.json`) is
`htmlangular` - angularls knows the component in its template, with the project's own Angular and TypeScript;
ESLint runs with the project's config. **AngularJS** (the `*-html5/client` folders): TypeScript through ts_ls,
ESLint with the client's config, templates as plain HTML - no language server knows AngularJS templates.
Their servers install themselves with the first file that needs them.

### Without IntelliJ

On Linux, on a machine without IntelliJ, or in a repository IntelliJ has not imported as a Maven project
there (no Maven settings in `.idea/workspace.xml`), GreyKnight takes what the machine has, as the `mvn`
command line does (`lua/integrations/jdtls.lua`):

- **Project JDK:** `JAVA_HOME`, else the `java` on the `PATH`; a project on another Java version gets an installed
  JDK of that version.
- **jdtls** runs on `JDTLS_JAVA_HOME`, else on `JAVA_HOME` or the `java` on the `PATH` when it is 21+, else on the
  newest JDK 21+ installed - next to those (JDKs unpacked side by side), in `/usr/lib/jvm`, SDKMAN, `~/.jdks`,
  `C:\Program Files\Java`, Eclipse Adoptium, ... or in the folders `GREYKNIGHT_JDK_DIRS` names (separated like
  `PATH`).
- **Maven:** the settings of the `mvn` on the `PATH` (else `MAVEN_HOME` / `M2_HOME`): its `conf/settings.xml` and
  `~/.m2/settings.xml`.

Outside IntelliJ projects (no `.idea`) GreyKnight keeps its own behavior: formatting on save and `<leader>fm`
with conform's formatters. Java files get IntelliJ's defaults there too: nothing on save, `<leader>fm` through
jdtls with the IntelliJ-like profile.
