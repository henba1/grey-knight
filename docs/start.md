# GreyKnight - Getting started

> The first launch, the start screen, the modes, tips - and what to do when something goes wrong.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [First Launch](#first-launch) · [Dashboard](#dashboard) · [Mode Reference](#mode-reference) · [Easy Mode](#easy-mode) · [Reading These Docs in Neovim](#reading-these-docs-in-neovim) · [Which-key](#which-key) · [Centered Scrolling](#centered-scrolling) · [Quick Save](#quick-save) · [Recovering from Mistakes](#recovering-from-mistakes) · [When Something Goes Wrong](#when-something-goes-wrong)

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
| `e` | Easy mode on / off (below) |
| `a` | Open the AI agent (Qwen Code or OpenCode) |
| `L` | Open Lazy plugin manager |
| `q` | Quit |
| `1-8` | Open numbered recent file/project |

**Reopen dashboard anytime:** `<leader>;` (Space + semicolon)

### The look: OLED or GreyKnight

By default cyberdream's neon sits on true black `#000000` - on an OLED screen those pixels stay off. Floats, the
cursor line and the selection are near-black so they still stand apart, and the text is a little off white
(`#e8e8e8`) - pure white on pure black glares. Cyberdream's own look, the same neon on its grey `#16181a`, is one
command away:

| Command / setting | What |
|-------------------|------|
| `:GreyKnightStyle greyknight` / `:GreyKnightStyle oled` | Switch the look now (theme and start screen) and keep it for this machine (`greyknight-style` in Neovim's data folder) |
| `:GreyKnightStyle` | Which look is on |
| `vim.g.greyknight_style = "greyknight"` (in `init.lua`), `GREYKNIGHT_STYLE=greyknight` | Choose it before the kept choice - for every start, whatever `:GreyKnightStyle` kept |
| `:CyberdreamToggleMode` | Light and back: cyberdream's own light look in either style |

---

## Mode Reference

| Mode | How to Enter | Purpose |
|------|-------------|---------|
| **Normal** | `Esc` | Navigation, commands |
| **Insert** | `i`, `a`, `o` | Typing text |
| **Visual** | `v` (char), `V` (line), `Ctrl+v` (block) | Selecting text |
| **Command** | `:` | Running ex commands |
| **Terminal** | `:ToggleTerm` | Shell inside nvim (`<leader>t*` = Qwen agent) |
| **Easy** | `Alt+N` (any mode), `e` on the start screen, `:EasyMode` | A plain text editor's keys ([below](#easy-mode)) |

## Easy Mode

`Alt+N` switches **easy mode** on and off: windows with a file behave like a plain text editor (Notepad, VS
Code) - you are always typing, and the keys are the usual ones. **EASY** in the bar above each file window says it
is on; a click on it switches it off. It lasts for this session; terminals, the file tree, pickers and the agent's
pane keep their own keys.

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save (a new file: asks for a name) |
| `Ctrl+Z` / `Ctrl+Y` | Undo / redo |
| `Shift+arrows`, `Shift+Home/End`, `Ctrl+Shift+arrows` | Select; typing replaces the selection, an arrow ends it; the mouse selects too |
| `Ctrl+A` | Select all |
| `Ctrl+C` / `Ctrl+X` | Copy / cut the selection - without one, the line |
| `Ctrl+V` | Paste (Windows Terminal pastes its own clipboard: what you copied on Windows) |
| `Ctrl+F` | Find (`Enter` jumps there) |
| `Ctrl+R` | Replace in this file (grug-far - as in IntelliJ) |
| `Ctrl+G` | Go to line |
| `Ctrl+/` | Comment / uncomment the line or the selection |
| `Tab` / `Shift+Tab` | Indent / outdent the selection (`Shift+Tab`: the line) |
| `Ctrl+Backspace` / `Ctrl+Del` | Delete the word before / after |
| `Ctrl+O` / `Ctrl+N` / `Ctrl+W` | Open a file (picker) / new file / close the file (asks about unsaved changes) |
| `Esc` | Normal mode for **one** command - `Space f f`, `:w`, `Ctrl+H/J/K/L` to another window - then typing again |
| `F1` | These keys |

In easy mode only `Ctrl+C` / `Ctrl+X` reach the clipboard - text you type over or delete does not. Over SSH a copy
goes to your own computer's clipboard (OSC 52). `Alt+N` again (or `:EasyMode off`) brings Neovim's keys back as they
were. `:EasyMode on` / `off` switch it from a command.

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
