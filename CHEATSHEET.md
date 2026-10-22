# Grey Knight Neovim — Cheatsheet

> Leader = `Space` | Open this: `nvim ~/.config/nvim/CHEATSHEET.md` or `<leader>gd`
> On a link: `gd` or `Enter` follows it, `Ctrl+o` jumps back. `gO` lists all headings.

**Contents:** [General](#general) · [AI](#ai-qwen-code-or-opencode-leadera) · [Run](#run-tasks-repl-f6-leaderr-bash-python) · [Explorer](#file-explorer-leadere) · [Find](#find-snacks-picker-leaderf) · [Navigation](#file-navigation) · [Git](#git-leaderg) · [Terminal](#terminal-leadert) · [Errors](#errors-logs) · [Trouble](#trouble-diagnostics-leaderx) · [LSP](#lsp) · [Debug](#debug-f5-leaderd-python-bash) · [Hacker](#hacker-specials) · [Session](#session-leaderp) · [Editing](#editing) · [Windows](#windows-buffers) · [Structure](#config-structure) · [Docs](#docs)

## General

| Key | Action |
|-----|--------|
| `<leader>w` | Save |
| `<leader>Q` | Quit all **without saving** (`:qa!`) |
| `<leader>;` | Dashboard |
| `<Esc>` | Clear the search highlight |
| `<C-d>` / `<C-u>` | Half a page down / up, cursor centered |
| `n` / `N` | Next / previous search hit, centered |

## AI (Qwen Code or OpenCode) — `<leader>a`

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal AI agent |
| `<leader>tv` | n | Vertical AI agent |
| `<leader>t1` / `<leader>t2` / `<leader>t3` | n | Agents #1/#2/#3 (each its own session) |
| `<leader>ac` | n | New AI session (`/clear` in Qwen Code, `/new` in OpenCode) |
| `<leader>am` | n | Which model the rig runs right now (Qwen Code; OpenCode: `/models`) |
| `<leader>aa` | n/v | Ask AI about the file / selection (asks for the question) |
| `<leader>ae` | v | AI edit selection (asks for the instruction) |
| `<leader>rf` | n | Send the last failed run (command, output, code) to the agent: fix it |

> **Which agent:** Qwen Code by default; the environment variable `GREYKNIGHT_AGENT=opencode` switches to OpenCode.
> Unset, GreyKnight takes Qwen Code where it is installed, else OpenCode.
>
> The agent runs the local **Qwen Code** CLI in a persistent terminal. It inherits the
> project's cwd and any `QWEN.md`/`AGENTS.md` context automatically. `aa`/`ae` send the file
> as `@path` plus the selected lines and your question/instruction as one prompt (a new agent
> starts with it via `qwen -i`). `tt` is a true toggle — the agent process stays alive when
> hidden, so re-opening re-attaches the same session. Going to the agent's window (`Ctrl+l`, a click) puts
> you in terminal mode, as every terminal window does: type away. `Esc Esc` gives normal mode there (scroll, copy).

## Run / Tasks / REPL — `<F6>` / `<leader>r` (bash + python)

Every run is a task (overseer.nvim): scripts run side by side, running one again replaces its old
run. Output in a real terminal at the bottom (`input()`, `read`, `sudo` prompts work); the cursor
goes there while it runs and back to the code when it ends. Errors are marked in the code.

| Key | Mode | Action |
|-----|------|--------|
| `<F6>` / `<leader>rr` | n | Run file with its remembered args (project `.venv` python, else `#!` / python3 / bash; Windows: python) |
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
| `H`/`I` | Toggle hidden / ignored |
| `<Tab>`/`<S-Tab>` | Mark / unmark, then next / prev (`V`…`<Tab>`: a range, `<C-a>`: all) |
| `m` | Move the marked into the folder under the cursor (nothing marked: mark this one) |
| `c` | Copy the marked into the folder under the cursor (nothing marked: mark this one) |
| `r` | Rename / move to a typed path (absolute too: `/…`, `~/…`, `C:\…`) |
| `C` | Copy to a typed path |
| `a` | New file or dir (trailing `/` = dir; absolute paths too) |
| `d` | Delete the marked, else this one (system trash; where it refuses, e.g. `/tmp`: asks to delete for good) — the cursor stays put |
| `y`/`p` | Yank paths / paste them as copies into the folder |
| `Z` | Collapse all folders |
| `u` | Refresh tree |
| `]g`/`[g` | Next / prev git-changed |
| `!1` … `!9` | Script slot 1 … 9 on the cursor's item and the marked ones (`!1`: path, size, permissions) |
| `!!` | The script slots: pick one to run |

> Script slots: files `<n>-<name>.py` (`.sh` Linux, `.ps1` Windows) in `slots/` here or in
> `~/.local/share/nvim/slots`; a script can ask you through dialogs - see USAGE.md, [Script slots](USAGE.md#script-slots).

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

> Harpoon pins the 2-4 files of your current task to slots 1-4, per project, kept across sessions.

## Bookmarks — `<leader>m`

| Key | Action |
|-----|--------|
| `<leader>mm` | Set / remove a bookmark on this line (`⚑` in the sign column) |
| `<leader>mr` / `<C-F11>` | Name the bookmark on this line (sets one if there is none; an empty name takes the name away) |
| `<leader>ml` / `<S-F11>` | The project's bookmarks: `Enter` opens the file at the line, `dd` / `Ctrl+x` deletes |
| `<leader>mn` / `<leader>mp` | Next / previous bookmark - in file and line order, file to file, round at the ends |

> Lines to come back to, any number of them, per project (Neovim's directory), kept across sessions. A bookmark
> moves with its line as you edit - moved, cut and put back (`dd`, `p`), reformatted too; delete the line and save,
> it is gone. Changed outside Neovim (git pull), a file's bookmarks find their lines again by their text; renamed or
> moved (explorer `r` / `m`, `:file`), they go along; a deleted file's stay listed as *file gone* (`dd` removes them).
> IntelliJ's F11 is the debugger's step into here.

## Git — `<leader>g`

| Key | Action |
|-----|--------|
| `<leader>gg` | Lazygit |
| `<leader>gl` | Git log |
| `<leader>gv` | Diffview (side-by-side diffs) |
| `<leader>gh` | File history |
| `]c` / `[c` | Next / previous change in the file (in diff mode: Vim's) |
| `<leader>gs` | Stage the change at the cursor (again: unstage); visual: the selected lines |
| `<leader>gr` | Undo the change at the cursor (`u` brings it back); visual: the selected lines |
| `<leader>gp` | Show the change (what it was) |
| `<leader>gb` | Who changed the line, when, in which commit (blame) |

> The change keys work in files of a git repository; the gutter shows their changes.

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
| `<leader>fm` | Format buffer / selection (IntelliJ projects: like its Reformat Code, see USAGE.md) |

> Neovim's own LSP keys work too: `grn` rename, `grr` references, `gra` code action, `gO` symbols.
> Because of them `gr` waits a moment before it runs; `grr` is the instant one. The keys come only with a server
> that can do them: where none finds definitions, `gd` (and `K`) stay Vim's.

## Debug — `<F5>` / `<leader>d` (Python + bash)

Breakpoints first, then `F5`. Python via debugpy, bash via bashdb; the program's input goes in the
DAP console pane; variable values show next to the code while stopped. Full workflow: USAGE.md,
"Debugging (DAP)". C/C++'s `:Codelldb*` surface is pending `porkfly/codelldb.nvim` syncing.

| Key | Action |
|-----|--------|
| `<F5>` | Debug this file / Continue (with `.vscode/launch.json`: pick a config; Java: main classes + IntelliJ's remote configs) |
| `<S-F5>` / `<leader>dq` | Stop |
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
| `<C-Up/Down/Left/Right>` | Resize windows - a terminal too |
| `<S-h>` / `<S-l>` | Prev/next buffer |
| `<leader><Tab>` | Recent buffers (IntelliJ's Ctrl+Tab): starts on the one before this - `Enter` goes back, `Tab` / `Shift+Tab` further back / forward. `Ctrl+Tab` too where the terminal passes it on |
| `<C-^>` | The buffer before this one, at once (again: back) |
| `<C-o>` / `<C-i>` | Back / forward through the places you jumped to, file to file (IntelliJ's Navigate Back / Forward) |
| `<Esc><Esc>` | Leave terminal mode (back to normal mode); going to a terminal window (shell, REPL, agent, a run's output) enters it again |

In a terminal every other key is the program's: bash's `Ctrl+A/E`, `Alt+B/F`, `Ctrl+W/U/R` work as typed.

## Config Structure

```
~/.config/nvim/
├── init.lua                  ← entry point
├── CHEATSHEET.md             ← this file
├── lua/config/
│   ├── options.lua           ← vim opts + language toggles
│   ├── clipboard.lua         ← over SSH: copy with OSC 52, paste the last copy
│   ├── lazy.lua              ← lazy.nvim bootstrap
│   ├── keymaps.lua           ← global keymaps
│   ├── autocmds.lua          ← autocommands
│   ├── explorer.lua          ← explorer keys: cd here (.), cd .. (<BS>, -), m / c through the tree, typed paths,
│   │                            search files / folders / the current view (/, D, S)
│   ├── mdlinks.lua           ← markdown links: gd / Enter follow them
│   ├── slots.lua             ← explorer script slots: !1 … !9, !!, the scripts' dialogs
│   ├── bookmarks.lua         ← bookmarks: lines to come back to, per project (<leader>mm, <leader>ml)
│   ├── navigate.lua          ← Ctrl+Click: the declaration, on it its usages (IntelliJ's)
│   ├── switcher.lua          ← recent buffers in the order of use (<leader><Tab>, IntelliJ's Ctrl+Tab)
│   └── errorlog.lua          ← error log (<leader>ue)
├── lua/devsuite/             ← bash + python dev suite
│   ├── runner.lua            ← what to run: file / args / sudo / project scripts / cell / pytest
│   ├── tasks.lua             ← runs as overseer tasks: output window, args, watch, fix with Qwen
│   ├── errors.lua            ← tracebacks + bash errors -> quickfix + marks in the code
│   ├── repl.lua              ← IPython / python / bash REPL
│   ├── debug.lua             ← Python (debugpy) + bash (bashdb) debugging, F5
│   └── util.lua              ← venv, #!, cells, dedent
├── lua/integrations/
│   ├── agent.lua             ← coding agent terminals: Qwen Code or OpenCode
│   ├── aidash.lua            ← AI Dashboard bridge
│   ├── intellij.lua          ← IntelliJ's settings: JDK, Maven, on save, reformat, remote debug
│   ├── jdtls.lua             ← Java: jdtls with IntelliJ's settings, else the machine's JDKs and Maven
│   ├── mason.lua             ← Mason packages on first use (Java, Angular)
│   └── web.lua               ← Angular / AngularJS servers
├── lua/plugins/
│   ├── ai.lua                ← toggleterm (agents, REPLs)
│   ├── colorscheme.lua       ← Cyberdream
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
| `<leader>gd` | Read GreyKnight docs (README, CHEATSHEET, USAGE, G3-DEVELOPMENT): read-only, `q` closes |
| `gd` / `Enter` | On a link in a markdown file: follow it (heading, other file, URL) |
| `Ctrl+o` | Back to where you came from |
| `gO` | All headings of the file (outline); `Enter` jumps |
