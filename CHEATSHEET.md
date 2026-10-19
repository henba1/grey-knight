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
> Unset, GreyNight takes Qwen Code where it is installed, else OpenCode.
>
> The agent runs the local **Qwen Code** CLI in a persistent terminal. It inherits the
> project's cwd and any `QWEN.md`/`AGENTS.md` context automatically. `aa`/`ae` send the file
> as `@path` plus the selected lines and your question/instruction as one prompt (a new agent
> starts with it via `qwen -i`). `tt` is a true toggle — the agent process stays alive when
> hidden, so re-opening re-attaches the same session. Inside the agent: type normally;
> `Esc Esc` exits terminal mode back to the editor.

## Run / Tasks / REPL — `<F6>` / `<leader>r` (bash + python)

Every run is a task (overseer.nvim): scripts run side by side, running one again replaces its old
run. Output in a real terminal at the bottom (`input()`, `read`, `sudo` prompts work); the cursor
goes there while it runs and back to the code when it ends. Errors are marked in the code.

| Key | Mode | Action |
|-----|------|--------|
| `<F6>` / `<leader>rr` | n | Run file with its remembered args (project `.venv` python, else `#!` / python3 / bash) |
| `<leader>ra` | n | Edit the file's args, then run (shell syntax; remembered across sessions) |
| `<leader>rR` | n | Run file as root (sudo) |
| `<leader>rp` / `rP` | n | Project script (./, scripts/, bin/, tools/) / with args |
| `<leader>rs` | v | Run selection as a script of its own (dedented) |
| `<leader>rc` | n | Run the `# %%` cell at the cursor |
| `<leader>rx` | n | Trace run of a shell script (`bash -x`) |
| `<leader>rt` / `rT` | n | pytest the file / the test at the cursor |
| `<leader>rl` | n | Run again (restart) |
| `<leader>rw` | n | Watch: re-run on save (toggle) |
| `<leader>rk` | n | Kill |
| `<leader>ro` | n | Show / hide the output |
| `<leader>rL` | n | Task list (`<CR>` actions, `o` output, `dd` remove, `?` help) |
| `<leader>rf` | n | Send the failed run (command, output, code) to the agent: fix it |
| `<leader>rO` | n | Task templates: make, npm, `.vscode/tasks.json`, shell |
| `<leader>ri` | n | REPL toggle (IPython / python3 / bash) |
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
| `H`/`I` | Toggle hidden / ignored |
| `a` | New file or dir (trailing `/` = dir) |
| `r` | Rename |
| `d` | Delete (system trash; permanent fallback) |
| `c` | Copy selected → current dir |
| `m` | Move selected → current dir |
| `y`/`p` | Yank / paste paths |
| `Z` | Collapse all folders |
| `u` | Refresh tree |
| `]g`/`[g` | Next / prev git-changed |

> The tree shows Neovim's working directory: `.`, `<BS>` and `-` change both (a message shows the new one).

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

## Git — `<leader>g`

| Key | Action |
|-----|--------|
| `<leader>gg` | Lazygit |
| `<leader>gl` | Git log |
| `<leader>gv` | Diffview (side-by-side diffs) |
| `<leader>gh` | File history |

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
| `gD` | Go to declaration |
| `gr` | References |
| `gi` | Implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>D` | Type definition |
| `[d` / `]d` | Prev/next diagnostic |
| `<leader>fm` | Format buffer |

> Neovim's own LSP keys work too: `grn` rename, `grr` references, `gra` code action, `gO` symbols.
> Because of them `gr` waits a moment before it runs; `grr` is the instant one.

## Debug — `<F5>` / `<leader>d` (Python + bash)

Breakpoints first, then `F5`. Python via debugpy, bash via bashdb; the program's input goes in the
DAP console pane; variable values show next to the code while stopped. Full workflow: USAGE.md,
"Debugging (DAP)". C/C++'s `:Codelldb*` surface is pending `porkfly/codelldb.nvim` syncing.

| Key | Action |
|-----|--------|
| `<F5>` | Debug this file / Continue (with `.vscode/launch.json`: pick a config) |
| `<S-F5>` / `<leader>dq` | Stop |
| `<F9>` / `<leader>db` | Toggle breakpoint |
| `<F10>` / `<F11>` / `<F12>` | Step over / into / out |
| `<leader>dl` / `dL` | Launch this file / with args |
| `<leader>dt` | Debug the pytest test at the cursor |
| `<leader>de` | Stop on every raised exception (toggle; default: uncaught only) |
| `<leader>dc` | Run to cursor |
| `<leader>dh` | Value under cursor |
| `<leader>dB` / `dp` | Conditional breakpoint / log point |
| `<leader>dR` | Restart |
| `<leader>da` | Attach: debugpy listener (port prompt) |
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
| `<leader>ps` | Save session |
| `<leader>pl` | Load session (cwd) |
| `<leader>pd` | Delete session |

## Editing

| Key | Mode | Action |
|-----|------|--------|
| `sa`/`sd`/`sr` | n | Surround add/delete/replace |
| `J`/`K` | v | Move selection down/up |
| `<leader>p` | x | Paste without yank |
| `J` | n | Join lines, the cursor stays |
| `<C-Space>` | n / x | Select the node at the cursor / grow the selection (treesitter) |
| `<BS>` | x | Shrink the selection |
| `<leader>d` | x | Delete the selection without yanking |
| `<leader>bd` | n | Delete buffer |

## Windows / Buffers

| Key | Action |
|-----|--------|
| `<C-h/j/k/l>` | Navigate windows (from a terminal only `<C-h/j/k>`: there `<C-l>` clears the shell) |
| `<C-Up/Down/Left/Right>` | Resize windows |
| `<S-h>` / `<S-l>` | Prev/next buffer |
| `<Esc><Esc>` | Leave terminal mode (back to normal mode) |

## Config Structure

```
~/.config/nvim/
├── init.lua                  ← entry point
├── CHEATSHEET.md             ← this file
├── lua/config/
│   ├── options.lua           ← vim opts + language toggles
│   ├── lazy.lua              ← lazy.nvim bootstrap
│   ├── keymaps.lua           ← global keymaps
│   ├── autocmds.lua          ← autocommands
│   ├── explorer.lua          ← explorer keys: cd here (.), cd .. (<BS>, -)
│   ├── mdlinks.lua           ← markdown links: gd / Enter follow them
│   └── errorlog.lua          ← error log (<leader>ue)
├── lua/devsuite/             ← bash + python dev suite
│   ├── runner.lua            ← what to run: file / args / sudo / project scripts / cell / pytest
│   ├── tasks.lua             ← runs as overseer tasks: output window, args, watch, fix with Qwen
│   ├── errors.lua            ← tracebacks + bash errors -> quickfix + marks in the code
│   ├── repl.lua              ← IPython / python3 / bash REPL
│   ├── debug.lua             ← Python (debugpy) + bash (bashdb) debugging, F5
│   └── util.lua              ← venv, #!, cells, dedent
├── lua/integrations/
│   ├── agent.lua             ← coding agent terminals: Qwen Code or OpenCode
│   └── aidash.lua            ← AI Dashboard bridge
├── lua/plugins/
│   ├── ai.lua                ← toggleterm (agents, REPLs)
│   ├── colorscheme.lua       ← Cyberdream
│   ├── completion.lua        ← blink.cmp
│   ├── devsuite.lua          ← overseer.nvim (task engine)
│   ├── editor.lua            ← flash, harpoon, oil, mini, trouble, etc
│   ├── hacker.lua            ← hex, DAP
│   ├── lsp.lua               ← LSP, Mason, Treesitter, conform
│   ├── session.lua           ← persisted.nvim
│   └── snacks.lua            ← picker, explorer, dashboard, notify
└── tests/                    ← tests/run.sh runs them all
    ├── run.sh
    ├── harness.lua
    ├── smoke_test.lua
    └── devsuite_test.lua
```

## Docs

| Key | Action |
|-----|--------|
| `<leader>gd` | Read GreyNight docs (README, CHEATSHEET, USAGE): read-only, `q` closes |
| `gd` / `Enter` | On a link in a markdown file: follow it (heading, other file, URL) |
| `Ctrl+o` | Back to where you came from |
| `gO` | All headings of the file (outline); `Enter` jumps |
