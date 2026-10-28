# Grey Knight Neovim — Cheatsheet

> Leader = `Space` | Open this: `nvim ~/.config/nvim/CHEATSHEET.md` or `<leader>gd`
> On a link: `gd` or `Enter` follows it, `Ctrl+o` jumps back. `gO` lists all headings.
> How it all works, a file per topic: [the guide](docs/README.md).

**Contents:** [General](#general) · [Easy mode](#easy-mode-altn) · [AI](#ai-qwen-code-opencode-or-claude-code-leadera) · [Run](#run-tasks-repl-f6-leaderr-bash-python) · [LaTeX](#latex-leaderl) · [Explorer](#file-explorer-leadere) · [Find](#find-snacks-picker-leaderf) · [Navigation](#file-navigation) · [Git](#git-leaderg) · [Terminal](#terminal-leadert) · [Errors](#errors-logs) · [Trouble](#trouble-diagnostics-leaderx) · [LSP](#lsp) · [Debug](#debug-f5-leaderd-python-bash) · [Hacker](#hacker-specials) · [Session](#session-leaderp) · [Editing](#editing) · [Windows](#windows-buffers) · [Structure](#config-structure) · [Docs](#docs)

## General

| Key | Action |
|-----|--------|
| `<leader>w` | Save |
| `<leader>Q` | Quit all **without saving** (`:qa!`) |
| `<leader>;` | Dashboard |
| `Alt+N` / `:EasyMode` | Easy mode on / off: a plain text editor's keys in file windows ([below](#easy-mode-altn)) |
| `:GreyKnightStyle oled` / `greyknight` | The look: neon on true black (OLED) or on cyberdream's grey - kept for this machine |
| `<Esc>` | Clear the search highlight |
| `<C-d>` / `<C-u>` | Half a page down / up, cursor centered |
| `n` / `N` | Next / previous search hit, centered |

## Easy Mode — `Alt+N`

File windows as in a plain text editor: always typing, the usual keys. **EASY** in the window bar (a click: off);
for this session; the status line says EASY, not INSERT. Terminals, the tree, pickers and the agent's pane keep their
keys: a click into the tree, then `Enter` or a double click opens a file - typing again there.

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save (a new file: asks for a name) |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo, word by word |
| `Tab` / `Up` `Down` `Enter` / `Esc` | Suggestions: take the grey one / pick one, take it (unpicked: `Enter` is a new line) / close them |
| `Shift+arrows`, `Shift+Home/End`, `Ctrl+Shift+arrows`, `Shift+click` | Select; typing replaces the selection, an arrow ends it; the mouse selects too, a double click a word |
| `Home` | The first character of the line, again: its start |
| `Ctrl+A` | Select all |
| `Ctrl+C` / `Ctrl+X` | Copy / cut the selection - without one, the line |
| `Ctrl+V` | Paste (Windows Terminal pastes its own clipboard: what you copied on Windows) |
| `Ctrl+F` | Find (`Enter` jumps there) |
| `Ctrl+R` | Replace in this file (grug-far - as in IntelliJ) |
| `Ctrl+G` | Go to line |
| `Ctrl+/` | Comment / uncomment the line or the selection |
| `Tab` / `Shift+Tab` | Indent / outdent the selection (`Shift+Tab`: the line) |
| `Ctrl+Backspace` / `Ctrl+Del` | Delete the word before / after (at a line's end: the line break) |
| `Ctrl+O` / `Ctrl+N` / `Ctrl+W` | Open a file (picker) / new file / close the file (asks about unsaved changes) |
| `Esc` | Suggestions open: close them; else normal mode for **one** command - `Space f f`, `:w`, `Ctrl+H/J/K/L` to another window - then typing again |
| `F1` | These keys |

## AI (Qwen Code, OpenCode or Claude Code) — `<leader>a`

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal AI agent |
| `<leader>tv` | n | Vertical AI agent |
| `<leader>t1` / `<leader>t2` / `<leader>t3` | n | Agents #1/#2/#3 (each its own session) |
| `<leader>ac` | n | New AI session (`/clear` in Qwen Code and Claude Code, `/new` in OpenCode) - an agent working in another folder (started before a `cd`) starts anew in Neovim's |
| `<leader>am` | n | Which model the rig runs right now (Qwen Code; OpenCode: `/models`, Claude Code: `/model`) |
| `<leader>aa` | n/v | Ask AI about the file / selection (asks for the question) |
| `<leader>ae` | v | AI edit selection (asks for the instruction) |
| `<leader>ad` | n | What changed since the agent started: the files, their diffs; `Enter` side by side, `Ctrl+x` / `dd` take one back |
| `]c` / `[c` | n | In a file the agent edited: its next / previous change (shown in the buffer: old lines red, new green) |
| `<leader>ay` / `<leader>an` | n/v | Keep / revert the agent's change at the cursor (visual: the selection's; off a change: the only one, or the cursor goes to the nearest) - reverted on disk too |
| `<leader>aY` / `<leader>aN` | n | Keep / revert all of the agent's changes in the file |
| `<leader>ar` | n | Every change of the agent's to review: `Enter` goes there, `Ctrl+y` keeps, `Ctrl+x` reverts |
| `<leader>af` | n | This window follows the agent: each edit opens here as it lands (again: stops) |
| `<leader>av` | n | Speak a prompt to the agent - again stops; you see it before it is sent (`:VoiceCancel` drops it) |
| `<leader>aV` | n | Dictate at the cursor - again stops (in a terminal: typed in) |
| `<leader>rf` | n | Send the last failed run (command, output, code) to the agent: fix it |

> **Which agent:** Qwen Code by default; the environment variable `GREYKNIGHT_AGENT=opencode` switches to OpenCode,
> `GREYKNIGHT_AGENT=claude` to Claude Code. Unset, GreyKnight takes Qwen Code where it is installed, else OpenCode,
> else Claude Code.
>
> The agent runs the local **Qwen Code** CLI in a persistent terminal. It inherits the
> project's cwd and any `QWEN.md`/`AGENTS.md` context automatically. `aa`/`ae` send the file
> as `@path` plus the selected lines and your question/instruction as one prompt (a new agent
> starts with it via `qwen -i`). `tt` is a true toggle — the agent process stays alive when
> hidden, so re-opening re-attaches the same session. Going to the agent's window (`Ctrl+l`, a click) puts
> you in terminal mode, as every terminal window does: type away. `Esc Esc` gives normal mode there (scroll, copy).

**The agent works in the editor** (both agents, started with `<leader>t*`): ask "where is the bookmarks code?" and
it opens the file tree on it (or a search there), marks files there, shows code at a line, lists places in the
quickfix list, asks the language servers (definitions, usages, symbols, diagnostics) - `/mcp` shows `greyknight`.
**Its edits show in your buffers** - the old lines red above the new green ones - to keep (`<leader>ay`, or click
**✓ Accept** under the change) or revert (`<leader>an`, **✗ Reject**); `<leader>af` makes a window follow it from edit to edit. Qwen Code also gets the
open files, cursor and selection as context (`/ide status`: Neovim) and shows **each edit as a diff** before it
writes it (when it asks for permission: `/approval-mode default`):

| Key (in the diff) | Action |
|-----|--------|
| `ga` / `:w` | Accept the change - Qwen Code writes it (edit the right side first if you like) |
| `q` | Reject it (closing the tab too) |
| `do` / `]c` / `[c` | Take one change back / next / previous change |

> Only agents started here are connected (`vim.g.greyknight_agent_link = false`: none); the agents' settings files
> stay as they are ([docs/agent.md → The agent in your editor](docs/agent.md#the-agent-in-your-editor)). An agent you are not
> looking at says when it is **done** or **waits for your answer** (a notification).
>
> **Speech to text** on this machine: `:VoiceInstall` downloads whisper.cpp and a model once (checked by sha256);
> `$GREYKNIGHT_STT_URL` - set by hand - transcribes on a server instead. Over SSH the microphone is on your computer:
> `Win+H` (Windows' voice typing) types into PuTTY.

## Run / Tasks / REPL — `<F6>` / `<leader>r` (bash + python)

Every run is a task (overseer.nvim): scripts run side by side, running one again replaces its old
run. Output in a real terminal at the bottom (`input()`, `read`, `sudo` prompts work); the cursor
goes there while it runs and back to the code when it ends. Errors are marked in the code.

| Key | Mode | Action |
|-----|------|--------|
| `<F6>` / `<leader>rr` | n | Run file with its remembered args (project `.venv` python, else `#!` / python3 / bash; Windows: python, Git Bash) |
| `<leader>ra` | n | Edit the file's args, then run (shell syntax; remembered across sessions) |
| `<leader>rR` | n | Run file as root (sudo) |
| `<leader>rp` / `rP` | n | Project script (./, scripts/, bin/, tools/) / with args |
| `<leader>rs` | v | Run selection as a script of its own (dedented) |
| `<leader>rc` | n | Run the `# %%` cell at the cursor |
| `<leader>rx` | n | Trace run of a shell script (`bash -x`) |
| `<leader>rt` / `rT` | n | pytest the file / the test at the cursor (Java: TestNG / JUnit through jdtls) |
| `<leader>rl` | n | Run again (restart) |
| `<leader>rw` | n | Watch: re-run on save (toggle) |
| `<leader>rk` | n | Kill |
| `<leader>ro` | n | Show / hide the output |
| `<leader>rL` | n | Task list (`<CR>` actions, `o` output, `dd` remove, `?` help) |
| `<leader>rf` | n | Send the failed run (command, output, code) to the agent: fix it |
| `<leader>rO` | n | Task templates: make, npm, `.vscode/tasks.json`, shell |
| `<leader>ri` | n | REPL toggle (IPython / python / bash) |
| `<leader>re` | n/v | Send line / selection to the REPL |
| `<leader>rE` | n | Send the `# %%` cell to the REPL |

> After a failed run the failing line is marked in the code: `]q`/`[q` walk the traceback, `<CR>` on
> an error line in the output jumps there, `<leader>xq` lists them. Python reaches the REPL as one
> bracketed paste (blank lines in functions fine, `input()` waits for you). A venv directly in your
> home (`~/venv`) is only used when activated before starting nvim.

## LaTeX — `<leader>l`

The document of the file: its `% !TEX root = ...` line, the file itself (`\documentclass`) or the
`main.tex` above it. Errors are marked in the code and go to the quickfix list, as a failed run's do.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>lb` | n | Build once (`latexmk`, saved first) |
| `<leader>lw` | n | Watch: `latexmk -pvc` builds on every save, the PDF on http://localhost:8000 - changed pages marked (toggle). On a PDF or an image: that file in the browser, no build |
| `<leader>le` | n | The last build's errors (quickfix) |
| `<leader>lo` | n | The open previews and their addresses - all of them on http://localhost:8000/ (one port for up to 20) |

## File Explorer — `<leader>e`

The filesystem tree (snacks explorer). Focus moves with `<C-h>`/`<C-l>`; all ops run in the
explorer pane once focused.

| Key | Action |
|-----|--------|
| `<BS>`/`-` | cd .. — one folder up (tree **and** working directory) |
| `h` | Close the folder (cursor to its parent) |
| `l`/`Enter` | Open file / toggle folder |
| `.` | cd here — the folder under the cursor becomes the working directory |
| `/` | Search files (the text matches the path below the root) |
| `D` | Search folders — by name, no files shown |
| `S` | Search the current view — only the rows the tree shows (closed folders not looked into) |
| `R` | Search files by regex — `.*\.sh$` (the name; with a `/` the path below the root), a glob too: `*.sh` |
| `<M-r>` | While searching: file / folder search by regex ↔ fuzzy (the text stays; the choice too) |
| `<C-a>` | In a search: mark its matches (not the folders above them) — then `m` / `c` / `d` on all |
| `H`/`I` | Toggle hidden / ignored |
| `<Tab>`/`<S-Tab>` | Mark / unmark, then next / prev (`V`…`<Tab>`: a range, `<C-a>`: all; in a search its matches) |
| `m` | Move the marked into the folder under the cursor (nothing marked: mark this one) |
| `c` | Copy the marked into the folder under the cursor (nothing marked: mark this one) |
| `r` | Rename / move to a typed path (absolute too: `/…`, `~/…`, `C:\…`) |
| `%` | Rename the marked by regex: `s/(\d+)\.txt$/$1.md/` (as sed: `g`, `i`; `$1` `${name}` `$0`) — new names listed first |
| `@` | To the agent: the marked (else this one) as `@path` in its prompt — typed, not sent |
| `C` | Copy to a typed path |
| `a` | New file or dir (trailing `/` = dir; absolute paths too) |
| `d` | Delete the marked, else this one (system trash; where it refuses, e.g. `/tmp`: asks to delete for good) — the cursor stays put |
| `y`/`p` | Yank paths / paste them as copies into the folder |
| Right-click | File menu on the clicked row: open (split), new, rename, delete, copy / paste, copy (relative) path, system app, cwd, to the agent, hidden files |
| `Z` | Collapse all folders |
| `u` | Refresh tree |
| `]g`/`[g` | Next / prev git-changed |
| `!1` … `!9` | Script slot 1 … 9 on the cursor's item and the marked ones (`!1`: path, size, permissions) |
| `!!` | The script slots: pick one to run |

> Script slots: files `<n>-<name>.py` (`.sh` Linux, `.ps1` Windows) in `slots/` here or in
> `~/.local/share/nvim/slots`; a script can ask you through dialogs - see [docs/files.md → Script slots](docs/files.md#script-slots).

> The tree shows Neovim's working directory: `.`, `<BS>` and `-` change both (a message shows the new one).
> Move by the tree: `m` on the file, then `m` on the target folder (`c` there: copy). On a file the target is its
> folder; `m` in the file's own folder unmarks it. Nothing is overwritten. Marks stay through searches: `/` and
> `<Tab>` the files, `D` the target folder, `m` there. Open files go along (a folder's too); a file with unsaved
> changes stays for `m` / `r` (`:w` or `:e!` first); `d` closes the open files it deleted.
>
> The prompts (`r`, `C`, `a` — every input dialog) edit like a shell: `<C-a>`/`<C-e>` start/end, `<C-b>`/`<C-f>` a
> character, `<M-b>`/`<M-f>` a word, `<C-d>` delete the character, `<C-k>` delete to the end, `<C-u>` to the start,
> `<C-w>` a word.
>
> Search: the search box's title says which search runs. `/` `D` `S` work in the box too once you stop typing
> (`<Esc>`); during a search they switch to that search with the same text (`/` … `<Esc>` `D`: only the folders).
> `<M-s>` (Alt+s) switches while typing (files → folders → current view). `<Esc>` steps back: box → list (results
> stay) → the tree, the cursor where it was → closed. `Enter` on a match: the tree, the cursor on it (`Enter` again
> opens it). `^x` / `x$`: names (paths for files) starting / ending with x.
>
> Regex (`R`, `<M-r>`): fd's Rust regex, as ripgrep's (`\d \w \b (a|b) {2,3} (?i)`) — against the name, with a `/`
> against the path below the root (`^src/.*\.ts$`). `*` and no regex syntax: a glob (`*.sh`, `*.{sh,bash}`;
> with `/` relative to the root). Lowercase ignores case. The title: `(regex)`, `(glob)`, `(regex: <error>)`.

## Find (Snacks Picker) — `<leader>f`

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fc` | Commands |
| `<leader>fs` | LSP symbols |
| `<leader>fd` | Diagnostics |
| `<leader>fk` | Keymaps |
| `<leader>/` | Grep open buffers |
| `<leader>f:` | Command history |

## File Navigation

| Key | Action |
|-----|--------|
| `<leader>e` | File explorer (snacks) |
| `-` | Oil: edit the folder as a buffer (in the explorer `-` is cd ..) |
| `<leader>o` | Oil float |
| `s` | Flash jump |
| `S` | Flash treesitter select |
| `<leader>1-4` | Harpoon files 1-4 |
| `<leader>ha` | Harpoon pin file (tells you its slot) |
| `<leader>hh` | Harpoon menu (edit the list: reorder / delete lines, `q` keeps the edits) |

> Harpoon pins the 2-4 files of your current task to slots 1-4, per project, kept across sessions. A slot follows
> its file renamed or moved (explorer `r` / `m`, oil); one of a deleted file says so and opens nothing.

## Bookmarks — `<leader>m`

| Key | Action |
|-----|--------|
| `<leader>mm` | Set / remove a bookmark on this line (`⚑` in the sign column) |
| `<leader>mr` / `<C-F11>` | Name the bookmark on this line (sets one if there is none; an empty name takes the name away) |
| `<leader>ml` / `<S-F11>` | The project's bookmarks: `Enter` opens the file at the line, `dd` / `Ctrl+x` deletes |
| `<F23>` / `<F35>` | Shift+F11 / Ctrl+F11 as most terminals send them (Neovim's names for them) |
| `<leader>mn` / `<leader>mp` | Next / previous bookmark - in file and line order, file to file, round at the ends |

> Lines to come back to, any number of them, per project (Neovim's directory), kept across sessions. A bookmark
> moves with its line as you edit - moved, cut and put back (`dd`, `p`), reformatted too; delete the line and save,
> it is gone. Changed outside Neovim (git pull), a file's bookmarks find their lines again by their text; renamed or
> moved (explorer `r` / `m`, oil, `:file`), they go along; a deleted file's stay listed as *file gone* (`dd` removes them).
> IntelliJ's F11 is the debugger's step into here.

## Git — `<leader>g`

| Key | Action |
|-----|--------|
| `<leader>gg` | Lazygit |
| `<leader>gl` | Git log |
| `<leader>gv` | Review the changes: VS Code's diff (codediff), live - an agent's edits show up as they land; `t` inline, `-` stage the file, `q` close |
| `<leader>gh` | File history |
| `]c` / `[c` | Next / previous change in the file (in diff mode: Vim's) |
| `<leader>gs` | Stage the change at the cursor (again: unstage); visual: the selected lines |
| `<leader>gr` | Undo the change at the cursor (`u` brings it back); visual: the selected lines |
| `<leader>gp` | Show the change (what it was) |
| `<leader>gb` | Who changed the line, when, in which commit (blame) |

> The change keys work in files of a git repository; the gutter shows their changes. In a codediff review they work on
> the change at the cursor too (`<leader>gu` unstages it). Diffs color the old side red and the new side green, the
> changed words within a line stronger; where codediff's library cannot be downloaded, `<leader>gv` / `<leader>gh` are
> Diffview's (it says so once).

## Terminal — `<leader>t`

Shell terminals (the `<leader>t*` agent keys above launch Qwen Code, not a shell; for a
Python/bash REPL use `<leader>ri`).

| Key | Action |
|-----|--------|
| `<leader>ts` | Send selection → shell term #2 (visual) |
| `<leader>tl` | Send line → shell term #2 |

## Errors & Logs

| Key / Command | Shows |
|---------------|-------|
| `]q` / `[q`, `<leader>xq` | Errors of the last failed run (traceback frames) |
| `<leader>xx` | All diagnostics: LSP + marks of your runs |
| `<leader>un` | Notification history (this session) |
| `<leader>um` | `:messages` (Lua errors of keys and commands) |
| `<leader>ue` | Error log of all sessions (`~/.local/state/nvim/greyknight.log`) |
| `:checkhealth` | Plugins, LSP, DAP, overseer health |
| `tests/run.sh` | All tests; exit status 1 on failure |
| `tests\run.ps1` | The same on Windows (bash tests skipped) |
| `GK_TEST_ONLY='Explorer,Session' tests/run.sh smoke` | Only the tests whose names contain a piece (`GK_TEST_SKIP`: all but those) |

## Trouble / Diagnostics — `<leader>x`

| Key | Action |
|-----|--------|
| `<leader>xx` | All diagnostics |
| `<leader>xX` | Buffer diagnostics |
| `<leader>xl` | Location list |
| `<leader>xq` | Quickfix list |

## LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `Ctrl+Click` | As in IntelliJ: on a name its declaration; on the declaration its usages (just one: there). No server: `gd`, in help the tag |
| `gD` | Go to declaration |
| `gr` | References |
| `gi` | Implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>D` | Type definition |
| `[d` / `]d` | Prev/next diagnostic |
| `<leader>fm` | Format buffer / selection (IntelliJ projects: like its Reformat Code, see [docs/code.md](docs/code.md#java-and-angular)) |

> A server this machine's security software blocks (a company laptop's Defender): `GREYKNIGHT_LSP_OFF=lua_ls`
> (comma-separated) leaves it out there - [docs/code.md](docs/code.md#code-intelligence-lsp).
>
> Neovim's own LSP keys work too: `grn` rename, `grr` references, `gra` code action, `gO` symbols.
> Because of them `gr` waits a moment before it runs; `grr` is the instant one. The keys come only with a server
> that can do them: where none finds definitions, `gd` (and `K`) stay Vim's.

## Debug — `<F5>` / `<leader>d` (Python + bash)

Breakpoints first, then `F5`. Python via debugpy, bash via bashdb; the program's input goes in the
DAP console pane; variable values show next to the code while stopped. Full workflow: [docs/run-debug.md →
Debugging (DAP)](docs/run-debug.md#debugging-dap). C/C++'s `:Codelldb*` surface is pending `porkfly/codelldb.nvim` syncing.

| Key | Action |
|-----|--------|
| `<F5>` | Debug this file / Continue (with `.vscode/launch.json`: pick a config; Java: main classes + IntelliJ's remote configs) |
| `<S-F5>` / `<leader>dq` | Stop (`<F17>`: Shift+F5 as most terminals send it) |
| `<F9>` / `<leader>db` | Toggle breakpoint |
| `<F10>` / `<F11>` / `<F12>` | Step over / into / out |
| `<leader>dl` / `dL` | Launch this file / with args |
| `<leader>dt` | Debug the test at the cursor (pytest / Java: TestNG, JUnit) |
| `<leader>de` | Stop on every raised exception (toggle; default: uncaught only) |
| `<leader>dc` | Run to cursor |
| `<leader>dh` | Value under cursor |
| `<leader>dB` / `dp` | Conditional breakpoint / log point |
| `<leader>dR` | Restart |
| `<leader>da` | Attach: debugpy listener (port prompt) / Java: IntelliJ's Remote JVM Debug configs |
| `<leader>dr` / `du` | DAP REPL / toggle DAP UI |

## Hacker Specials

| Key | Action |
|-----|--------|
| `<leader>hx` | Hex toggle (binary view) |
| `<leader>sr` | Search & replace (grug-far) |
| `<leader>sw` | S&R current word |

## Session — `<leader>p`

| Key | Action |
|-----|--------|
| `<leader>ps` | Save session (also with no file open) |
| `<leader>pl` | Load session (cwd) |
| `<leader>pd` | Delete session (pick one) |
| `:Persisted clean` | Delete the sessions of folders / branches that are gone |

> Saved when Neovim quits, one per folder + git branch: files, splits, tabs, help - no terminals, no explorer.
> Quitting with no file open keeps the old session; none for `~`, `/`, `/tmp`. Restore: `s` on the start screen.

## Editing

| Key | Mode | Action |
|-----|------|--------|
| `gsa`/`gsd`/`gsr` | n (`gsa`: v too) | Surround add/delete/replace (`s` is Flash's jump) |
| `J`/`K` | v | Move selection down/up |
| `<leader>p` | x | Paste without yank |
| `J` | n | Join lines, the cursor stays |
| `<C-Space>` | n / x | Select the node at the cursor / grow the selection (treesitter, else LSP) |
| `<BS>` | x | Shrink the selection (back to the node you grew from) |
| `<leader>d` | x | Delete the selection without yanking |
| `<leader>bd` | n | Delete buffer |

## Windows / Buffers

| Key | Action |
|-----|--------|
| `<C-h/j/k/l>` | Navigate windows - from a terminal too (clear the shell with `clear` / `cls`) |
| `<C-Up/Down/Left/Right>` | Resize windows - a terminal too, not an agent's (there they are the agent's: word by word in its prompt) |
| `<M-Up/Down/Left/Right>` | Resize windows in the editor (Alt+arrows: for PuTTY's default keys, which send Ctrl+arrows as plain arrows) |
| `<S-h>` / `<S-l>` | Prev/next buffer |
| `<leader><Tab>` | Recent buffers (IntelliJ's Ctrl+Tab): starts on the one before this - `Enter` goes back, `Tab` / `Shift+Tab` further back / forward. `Ctrl+Tab` too where the terminal passes it on |
| `<C-^>` | The buffer before this one, at once (again: back) |
| `<C-o>` / `<C-i>` | Back / forward through the places you jumped to, file to file (IntelliJ's Navigate Back / Forward) |
| `<Esc><Esc>` | Leave terminal mode (back to normal mode); going to a terminal window (shell, REPL, agent, a run's output) enters it again |

In a terminal every other key is the program's: bash's `Ctrl+A/E`, `Alt+B/F`, `Ctrl+W/U/R` work as typed. In an
agent's window (Claude Code, OpenCode, Qwen Code) only the ways out stay Neovim's - `<C-h/j/k/l>`, `<Esc><Esc>`,
`<C-\><C-n>`; every other key, Ctrl+arrows too, is the agent's.

Each file window has a bar on top (the statusline is one for all): the file, `●` when it has unsaved changes, and
buttons to click - `◫` split right, `⊟` split below, `×` close. Close closes the window; the last file window stays
and closes its file instead (asks about unsaved changes) - Neovim does not quit. Not on the tree, pickers, terminals,
the agent, help or quickfix.

> Over SSH from **PuTTY**: its default keys send Ctrl+arrows as plain arrows and Shift/Ctrl+F11 as F11. In PuTTY set
> Terminal → Keyboard: arrow keys *xterm-style bitmap*, function keys *Xterm 216+*; Connection → Data: terminal type
> *xterm-256color* ([docs/ssh.md → Over SSH (PuTTY)](docs/ssh.md#over-ssh-putty)). Home / End as PuTTY sends them (`<Find>` / `<Select>`) work.

## Config Structure

```
~/.config/nvim/
├── init.lua                  ← entry point
├── CHEATSHEET.md             ← this file
├── docs/                     ← the guide, a file per topic: start, agent, files, windows, find, code,
│                                run-debug, git, ssh (docs/README.md: the topics)
├── lua/config/
│   ├── options.lua           ← vim opts + language toggles
│   ├── clipboard.lua         ← over SSH: copy with OSC 52, paste the last copy
│   ├── lazy.lua              ← lazy.nvim bootstrap
│   ├── keymaps.lua           ← global keymaps
│   ├── autocmds.lua          ← autocommands
│   ├── explorer.lua          ← explorer keys: cd here (.), cd .. (<BS>, -), m / c through the tree, typed paths,
│   │                            search files / folders / the current view (/, D, S), by regex or glob (R),
│   │                            rename by regex (%)
│   ├── mdlinks.lua           ← markdown links: gd / Enter follow them
│   ├── slots.lua             ← explorer script slots: !1 … !9, !!, the scripts' dialogs
│   ├── bookmarks.lua         ← bookmarks: lines to come back to, per project (<leader>mm, <leader>ml)
│   ├── navigate.lua          ← Ctrl+Click: the declaration, on it its usages (IntelliJ's)
│   ├── switcher.lua          ← recent buffers in the order of use (<leader><Tab>, IntelliJ's Ctrl+Tab)
│   ├── putty.lua             ← over SSH from PuTTY with its default keys: once a word on the settings
│   ├── gitdiff.lua           ← git diffs (<leader>gv, <leader>gh) - codediff (VS Code's diff), else Diffview
│   ├── termname.lua          ← a terminal's name in the statusline: an agent's, else its program and number
│   ├── style.lua             ← the look: OLED (true black) or cyberdream's grey (:GreyKnightStyle)
│   ├── winbar.lua            ← a bar per file window: its name, split right / below and close buttons
│   ├── easymode.lua          ← easy mode (Alt+N): a plain text editor's keys in file windows
│   └── errorlog.lua          ← error log (<leader>ue)
├── lua/devsuite/             ← bash + python dev suite
│   ├── runner.lua            ← what to run: file / args / sudo / project scripts / cell / pytest
│   ├── tasks.lua             ← runs as overseer tasks: output window, args, watch, fix with Qwen
│   ├── errors.lua            ← tracebacks + bash errors -> quickfix + marks in the code
│   ├── latex.lua             ← latexmk: build / watch, its errors -> quickfix + marks in the code
│   ├── repl.lua              ← IPython / python / bash REPL
│   ├── debug.lua             ← Python (debugpy) + bash (bashdb) debugging, F5
│   └── util.lua              ← venv, #!, cells, dedent
├── lua/integrations/
│   ├── agent.lua             ← coding agent terminals: Qwen Code, OpenCode or Claude Code
│   ├── agent_link.lua        ← agents reach into this Neovim: their settings, the servers attached, context
│   ├── agent_server.lua      ← the MCP server agents start (nvim -l): relays to this Neovim
│   ├── agent_tools.lua       ← the agent's editor tools: file tree, open at a line, quickfix, LSP, diagnostics
│   ├── agent_ide.lua         ← Qwen Code's IDE mode: its edits as diffs to accept / reject, the context
│   ├── agent_changes.lua     ← what changed since the agent started (<leader>ad): diffs, take a file back
│   ├── agent_review.lua      ← the agent's edits in their buffers: keep / revert (<leader>ay, an), follow (<leader>af)
│   ├── voice.lua             ← speech to text (<leader>av, <leader>aV): record here, whisper.cpp (:VoiceInstall)
│   ├── aidash.lua            ← AI Dashboard bridge
│   ├── intellij.lua          ← IntelliJ's settings: JDK, Maven, on save, reformat, remote debug
│   ├── jdtls.lua             ← Java: jdtls with IntelliJ's settings, else the machine's JDKs and Maven
│   ├── mason.lua             ← Mason packages on first use (Java, Angular)
│   └── web.lua               ← Angular / AngularJS servers
├── lua/plugins/
│   ├── ai.lua                ← toggleterm (agents, REPLs)
│   ├── colorscheme.lua       ← Cyberdream - on true black, or its own grey (config/style.lua)
│   ├── completion.lua        ← blink.cmp
│   ├── devsuite.lua          ← overseer.nvim (task engine)
│   ├── editor.lua            ← flash, harpoon, oil, mini, trouble, etc
│   ├── hacker.lua            ← hex, DAP
│   ├── java.lua              ← nvim-jdtls
│   ├── lsp.lua               ← LSP, Mason, Treesitter, conform
│   ├── session.lua           ← persisted.nvim
│   └── snacks.lua            ← picker, explorer, dashboard, notify
├── slots/                    ← explorer script slots: 1-info.py; lib/ the helpers gk.py, gk.sh, gk.ps1
└── tests/                    ← tests/run.sh runs them all (Windows: tests\run.ps1)
    ├── run.sh
    ├── run.ps1
    ├── harness.lua
    ├── smoke_test.lua
    └── devsuite_test.lua
```

## Docs

| Key | Action |
|-----|--------|
| `<leader>gd` | Read GreyKnight docs (README, CHEATSHEET, the guide's topics in docs/, G3-DEVELOPMENT): read-only, `q` closes |
| `gd` / `Enter` | On a link in a markdown file: follow it (heading, other file, URL) |
| `Ctrl+o` | Back to where you came from |
| `gO` | All headings of the file (outline); `Enter` jumps |
