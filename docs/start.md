# GreyKnight - Getting started

> The first launch, the start screen, the modes, tips - and what to do when something goes wrong.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [First Launch](#first-launch) · [Dashboard](#dashboard) · [Mode Reference](#mode-reference) · [Reading These Docs in Neovim](#reading-these-docs-in-neovim) · [Which-key](#which-key) · [Centered Scrolling](#centered-scrolling) · [Quick Save](#quick-save) · [Recovering from Mistakes](#recovering-from-mistakes) · [When Something Goes Wrong](#when-something-goes-wrong)

## First Launch

```bash
nvim                    # opens dashboard
nvim .                  # opens dashboard + file explorer
nvim file.py            # opens specific file directly
```

On first launch:
- Lazy.nvim auto-installs all 38 plugins
- Mason auto-installs LSP servers when you open a file
- Treesitter auto-compiles parsers on first file open per language

Started in Neovim's own program folder - a Windows shortcut whose *Start in* is `C:\dev\tools\nvim\bin`, a
double-click on `nvim.exe` - GreyKnight works in your home folder instead: terminals and agents start in Neovim's
folder, and nobody works in that one. Open a project from there (`<leader>e`, `.` on its folder) before you start an
agent, or `<leader>ac` afterwards ([the agent keeps its folder](agent.md#context)).

---

## Dashboard

The Grey Knight dashboard is the start screen.

| Key | Action |
|-----|--------|
| `f` | Find file (fuzzy picker) |
| `n` | New empty file |
| `g` | Find text (grep) |
| `r` | Recent files |
| `c` | Edit nvim config |
| `s` | Restore last session |
| `a` | Open AI agent (Qwen Code) |
| `L` | Open Lazy plugin manager |
| `q` | Quit |
| `1-8` | Open numbered recent file/project |

**Reopen dashboard anytime:** `<leader>;` (Space + semicolon)

---

## Mode Reference

| Mode | How to Enter | Purpose |
|------|-------------|---------|
| **Normal** | `Esc` | Navigation, commands |
| **Insert** | `i`, `a`, `o` | Typing text |
| **Visual** | `v` (char), `V` (line), `Ctrl+v` (block) | Selecting text |
| **Command** | `:` | Running ex commands |
| **Terminal** | `:ToggleTerm` | Shell inside nvim (`<leader>t*` = Qwen agent) |

---

## Reading These Docs in Neovim
`<leader>gd` picks README, CHEATSHEET, a topic of this guide (its index first, then the topics as one reads them) or
the G3 guide and opens it read-only in a split; `q` closes it. In any markdown file, `gd` or `Enter` on a link follows
it: a `#heading` in the same file (like the contents at the top of a topic), another file - a name with spaces
written `<my notes.md>` or `my%20notes.md` - or a URL. `Ctrl+o` jumps back. `gO` lists all headings of the file;
`Enter` on one jumps there.

---

## Which-key
Press `<leader>` and **wait** — a popup shows all available keybindings grouped by category.

---

## Centered Scrolling
`Ctrl+d` / `Ctrl+u` keeps the cursor centered on screen. Same for search with `n`/`N`.

---

## Quick Save
`<leader>w` saves instantly. No `:w Enter` needed.

---

## Recovering from Mistakes
- `u` — undo (persists across sessions via undofile)
- `:earlier 5m` — go back 5 minutes in edit history
- `:later 5m` — go forward

---

## When Something Goes Wrong

| What happened | Where to look |
|---------------|---------------|
| Your program failed | The failing line is marked in the code; `]q` / `[q` walk the traceback, `<CR>` on an error line in the output jumps there, `<leader>rf` sends it to Qwen ([When it fails](run-debug.md#when-it-fails)) |
| Errors and warnings of the project | `<leader>xx` (Trouble): LSP diagnostics and the marks of your runs; `<leader>xq`: the quickfix list of the last failed run |
| A notification flashed by | `<leader>un`: the notification history of this session |
| A key or command raised a Lua error | `<leader>um`: `:messages` |
| Something went wrong in an earlier session | `<leader>ue`: the error log `~/.local/state/nvim/greyknight.log` |
| A plugin, language server or tool misbehaves | `:checkhealth` (or `:checkhealth overseer`, `dap`, `vim.lsp`), `:Lazy` (plugins), `:Mason` (servers, debuggers), `:LspInfo`, `:LspLog` |
| The debugger | `:DapShowLog` |
| Qwen Code | its window; debug logs in `~/.qwen/debug/` |

**The error log** keeps every warning and error notification of every session (with time, source
and a line per session start) and, when Neovim exits, the Lua errors from `:messages` - each whole: a
callback's, an autocommand's with the Lua error and its traceback below the header. It is plain
text, trimmed to the last 2000 lines when it grows past 512 KB, so it is also the file to read (or
send) when something broke and you did not see why. Notices of what was done on purpose are shown but
not logged - "Big file detected" (a big file opens without treesitter, language servers and folds), and
"Client ... quit with exit code ..." while Neovim quits (it ends the language servers; on Windows each
reports exit code 1). A server that ends while you work is logged.

**Tests:** `tests/run.sh` runs the whole test suite headless (about ten seconds; the dev suite
starts real python, bash and debugger processes) and exits with status 1 when anything fails. Run
it after changing the config. On Windows: `tests\run.ps1` - each suite in a minimized Neovim window
(a headless one gets no terminal output there), the bash tests skipped. Some tests only:
`GK_TEST_ONLY='Explorer workflow,Session' tests/run.sh smoke` runs the tests whose names contain one of the
comma-separated pieces, `GK_TEST_SKIP` all but those. A test run leaves your state alone: it neither
reads nor writes your history (jumps, marks, recent files) and writes no harpoon lists, sessions, picker
history, run arguments or error log entries; each suite gets temp, state and cache folders of its own,
deleted afterwards (language servers' temp folders, `lsp.log`, `dap.log`).
