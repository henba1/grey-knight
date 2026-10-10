# Grey Knight Neovim — Usage Guide

> Leader key = `Space` throughout this guide.
> `<leader>ff` means press `Space` then `f` then `f`.

---

## Table of Contents

1. [First Launch](#first-launch)
2. [Dashboard](#dashboard)
3. [File Navigation](#file-navigation)
4. [Editing](#editing)
5. [Code Intelligence (LSP)](#code-intelligence-lsp)
6. [Autocompletion](#autocompletion)
7. [AI Assistant (Qwen Code)](#ai-assistant-qwen-code)
8. [Terminal](#terminal)
9. [Git](#git)
10. [Search & Replace](#search--replace)
11. [Windows & Splits](#windows--splits)
12. [Buffers](#buffers)
13. [Harpoon (Quick File Switching)](#harpoon-quick-file-switching)
14. [Flash (Jump Navigation)](#flash-jump-navigation)
15. [Surround](#surround)
16. [Diagnostics & Trouble](#diagnostics--trouble)
17. [Debugging (DAP)](#debugging-dap)
18. [Hex Editor](#hex-editor)
19. [Sessions](#sessions)
20. [Oil (Filesystem Editing)](#oil-filesystem-editing)
21. [Markdown Rendering](#markdown-rendering)
22. [Tips & Tricks](#tips--tricks)

---

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

## File Navigation

### Fuzzy Finder (Snacks Picker)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files by name |
| `<leader>fg` | Live grep (search file contents) |
| `<leader>fb` | List open buffers |
| `<leader>fr` | Recent files |
| `<leader>fs` | LSP symbols (functions, classes) |
| `<leader>fd` | Diagnostics (errors, warnings) |
| `<leader>fc` | Commands |
| `<leader>fk` | Search all keymaps |
| `<leader>f:` | Command history |
| `<leader>/` | Grep only in open buffers |

Inside the picker:
- Type to filter
- `Enter` to select
- `Esc` to cancel
- `Ctrl+j/k` to move up/down

### File Explorer

`<leader>e` toggles the explorer (left sidebar). Focus moves between panes with
`Ctrl+h` / `Ctrl+l`. Every file operation below runs **in the explorer pane** once it
has focus.

**Navigate**

| Key | Action |
|-----|--------|
| `h` / `<BS>` | Up one directory (parent) |
| `l` / `Enter` | Open file (or toggle folder expand) |
| `.` | Jump to the current file's directory |
| `H` / `I` | Toggle hidden / ignored files |
| `<leader>/` | Grep inside the tree |
| `<C-t>` | Drop a terminal at the current dir |

**Filesystem ops**

| Key | Action |
|-----|--------|
| `a` | New file or dir (trailing `/` makes a directory) |
| `r` | Rename file / dir |
| `d` | Delete (to system trash; permanent fallback if no trash) |
| `c` | Copy selected → current dir (or prompt a target path) |
| `m` | Move selected → current dir (falls back to rename when nothing selected) |
| `y` | Yank selected paths to clipboard |
| `p` | Paste yanked files into current dir |

**Tree structure**

| Key | Action |
|-----|--------|
| `Z` | Collapse all folders under the root |
| `u` | Refresh the tree |
| `]g` / `[g` | Next / prev git-changed file |

**"Change the root"**: the explorer has no dedicated chroot key. To work a different
tree root, `cd` nvim there first (`:cd /path`), then open with `<leader>e` — it anchors
to nvim's cwd. Or navigate the existing tree with `h`/`l`. `Snacks.explorer()` also
accepts `{ cwd = "/path" }` if you want a one-off rooted view.

> Delete is **trash-first**: it shells to `trash`/`gio trash`/`kioclient` when present,
> so `d` is recoverable on most desktops. Without a trash backend it falls back to a
> permanent `:delete` — check with `:checkhealth snacks` before deleting anything precious.

---

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
| `<leader>d` | n/v | Delete to void (don't copy) |
| `J` | n | Join lines (cursor stays put) |
| `<leader>w` | n | Save file |
| `<leader>q` | n | Quit window |
| `<leader>Q` | n | Force quit all |

### Incremental Selection (Treesitter)

| Key | Mode | Action |
|-----|------|--------|
| `Ctrl+Space` | n | Start selection (smart, treesitter-aware) |
| `Ctrl+Space` | v | Expand selection to parent node |
| `Backspace` | v | Shrink selection |

---

## Code Intelligence (LSP)

Works automatically when you open a supported file. Mason installs the LSP server on first use.

| Key | Action |
|-----|--------|
| `K` | Hover documentation (show function signature, docs) |
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Find all references |
| `gi` | Go to implementation |
| `<leader>D` | Go to type definition |
| `<leader>rn` | Rename symbol (project-wide) |
| `<leader>ca` | Code action (quick fix, refactor) |
| `[d` | Previous diagnostic (error/warning) |
| `]d` | Next diagnostic |
| `<leader>fm` | Format file (or selection in visual mode) |

### Inline Diagnostics

Errors and warnings appear inline next to the code (via tiny-inline-diagnostic).
No need to look at a separate panel for simple errors.

---

## Autocompletion

Completion appears automatically as you type.

| Key | Action |
|-----|--------|
| `Tab` | Select next completion item |
| `Shift+Tab` | Select previous item |
| `Enter` | Accept selected completion |
| `Ctrl+Space` | Manually trigger completion menu |
| `Ctrl+e` | Dismiss completion menu |
| `Ctrl+b/f` | Scroll docs up/down |

**Ghost text** shows a grey preview of the top suggestion. Press `Tab` to accept it.

**Signature help** shows function parameters as you type inside `()`.

Sources (in priority order): LSP → Snippets → Buffer words → File paths

---

## AI Assistant (Qwen Code)

Grey Knight drives the **local Qwen Code** CLI as an agentic coding agent, running it in a
persistent terminal window inside the editor. It is fully local — same backend as everything
else (Qwen 3.8 27B on the rig), zero cloud.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50 split) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal-split AI agent |
| `<leader>tv` | n | Vertical-split AI agent |
| `<leader>t1` | n | Named agent #1 |
| `<leader>t2` | n | Named agent #2 |
| `<leader>t3` | n | Named agent #3 |
| `<leader>ac` | n | Start a fresh agent session |
| `<leader>aa` | n | Ask about the current file |
| `<leader>aa` | v | Ask about the selected code |
| `<leader>ae` | v | Ask the agent to edit the selected code |

### Using the agent

1. **Open:** `<leader>tt` (or `tf`/`th`/`tv` for float/split orientation). Default is a
   **vertical 50/50** split.
2. **Type a prompt** in the terminal and press **Enter**
3. The agent (Qwen Code) responds and, in agentic mode, can read files, edit code, and
   run commands inside your project

> **Session persistence:** the agent terminal keeps its process alive when the pane is
> hidden, so toggling with `<leader>tt` **re-attaches the same live session** instead of
> restarting it. Conversational context accumulates within one live agent.

### Context

- The agent inherits the **current working directory** and any project
  `QWEN.md` / `AGENTS.md` context files **automatically**.
- `<leader>aa` / `<leader>ae` additionally **prepend** the current file (or the visual
  selection) to the prompt so the agent knows exactly what you're pointing at.
- Inside the agent window, `Esc Esc` exits terminal mode back to the editor.

> Tip: for multi-agent work, keep agent #1 on one task and `<leader>t2` for another.

---

## Terminal

The `<leader>t*` keys above launch **Qwen Code** agents. For a plain **shell** (e.g. a
Python REPL) use `:ToggleTerm`, or send snippets straight into a running shell with:

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ts` | v | Send selected lines to shell terminal #2 |
| `<leader>tl` | n | Send current line to shell terminal #2 |

**Example workflow:**
1. `:2ToggleTerm` → open shell terminal #2, start `python3`
2. Navigate to code
3. Select lines with `V`
4. `<leader>ts` → code appears in the Python REPL

### Inside the AI Dashboard (web)

When GreyNight runs in a workspace of the AI Dashboard's **Dev Environment** (the browser page
shows a tmux session on the Pi), an optional bridge (`lua/integrations/aidash.lua`) lets the
editor use the browser for what a terminal can't do. It only loads there — the session sets
`AIDASH_URL`/`AIDASH_TOKEN`; everywhere else nothing changes.

| Key / Command | Action |
|---------------|--------|
| `<leader>Wp` · `:AidashPreview [port] [path]` | Show a dev server (`127.0.0.1:<port>` on the Pi) next to the editor — no port: pick from the listening ones |
| `gx` · `:AidashOpen <url>` | `localhost:<port>` URLs become a preview, others a link in the page |
| `<leader>Wd` · `:AidashDownload [file]` | Download the current file (or oil entry) to the computer in front of you |
| `<leader>Wu` · `:AidashUpload [dir]` | Upload files from that computer into the current folder |
| `:AidashNotify <message>` | A notification in the browser (also when the tab is in the background) |

Clipboard: `"+y` lands in the computer's clipboard (OSC 52, as over SSH); paste from it with
`Ctrl+Shift+V`. Shells in the same session have the same bridge as a command: `aidash preview 5173`,
`npm run build; aidash notify "build done"`.

---

## Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open Lazygit (full git TUI) |
| `<leader>gl` | Git log |
| `<leader>gd` | Diffview (side-by-side diffs) |
| `<leader>gh` | File history (all commits for current file) |

### Gitsigns (Gutter)

When editing files in a git repo, you'll see markers in the left gutter:
- **Green bar** — added lines
- **Blue bar** — changed lines  
- **Red triangle** — deleted lines

---

## Search & Replace

| Key | Action |
|-----|--------|
| `/` | Search in current file (vim native) |
| `n/N` | Next/previous match (centered) |
| `Esc` | Clear search highlight |
| `<leader>fg` | Live grep across project |
| `<leader>/` | Grep only open buffers |
| `<leader>sr` | Project-wide search & replace (grug-far) |
| `<leader>sw` | Search & replace current word |

### grug-far (Project Search & Replace)

`<leader>sr` opens a full search & replace interface:
- Type search pattern (supports regex)
- Type replacement
- Preview all matches across the project
- Apply selectively or all at once

---

## Windows & Splits

### Creating Splits

| Command | Action |
|---------|--------|
| `:vs` | Vertical split (side by side) |
| `:sp` | Horizontal split (top/bottom) |
| `:vs file.py` | Open file in vertical split |

### Navigating Windows

| Key | Action |
|-----|--------|
| `Ctrl+h` | Focus left window |
| `Ctrl+l` | Focus right window |
| `Ctrl+j` | Focus window below |
| `Ctrl+k` | Focus window above |

Works for **all** windows: editor splits, explorer, terminal, Qwen agent.

### Resizing Windows

| Key | Action |
|-----|--------|
| `Ctrl+←` | Narrower |
| `Ctrl+→` | Wider |
| `Ctrl+↑` | Taller |
| `Ctrl+↓` | Shorter |

### Closing

| Key | Action |
|-----|--------|
| `<leader>q` | Close current window |
| `<leader>Q` | Force quit all windows |

---

## Buffers

Files open as **buffers** (like browser tabs). One visible at a time per window.

| Key | Action |
|-----|--------|
| `Shift+h` | Previous buffer |
| `Shift+l` | Next buffer |
| `<leader>fb` | Buffer picker (see all open buffers) |
| `<leader>bd` | Close current buffer |

---

## Harpoon (Quick File Switching)

Mark up to 4 files for instant switching. Persists across sessions.

| Key | Action |
|-----|--------|
| `<leader>ha` | Add current file to harpoon |
| `<leader>hh` | Open harpoon menu |
| `<leader>1` | Jump to harpoon file 1 |
| `<leader>2` | Jump to harpoon file 2 |
| `<leader>3` | Jump to harpoon file 3 |
| `<leader>4` | Jump to harpoon file 4 |

**Workflow:** Open your 3-4 most-used files, `<leader>ha` each one, then `<leader>1-4` to instantly jump between them.

---

## Flash (Jump Navigation)

| Key | Mode | Action |
|-----|------|--------|
| `s` | n/v | Flash jump — type 2 chars, jump to match |
| `S` | n/v | Flash treesitter — select by syntax node |
| `r` | o | Remote flash (operator-pending) |
| `R` | o/v | Treesitter search |

**Example:** Press `s`, type `de` → all occurrences of "de" get labels, press the label to jump there.

---

## Surround

Add, delete, or change surrounding characters.

| Key | Action | Example |
|-----|--------|---------|
| `sa` + motion + char | Add surround | `saiw"` → surround word with `"` |
| `sd` + char | Delete surround | `sd"` → remove surrounding `"` |
| `sr` + old + new | Replace surround | `sr"'` → change `"` to `'` |

**Examples:**
- Cursor on `hello` → `saiw"` → `"hello"`
- Cursor inside `"hello"` → `sd"` → `hello`
- Cursor inside `"hello"` → `sr"'` → `'hello'`
- Visual select `hello world` → `sa"` → `"hello world"`

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

## Debugging (DAP)

| Key | Action |
|-----|--------|
| `F5` | Start / continue debugging |
| `F10` | Step over |
| `F11` | Step into |
| `F12` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint (enter condition) |
| `<leader>dr` | Open DAP REPL |
| `<leader>du` | Toggle DAP UI (variables, stack, etc.) |

Supported: Python (debugpy), C/C++ (codelldb)

---

## Hex Editor

| Key | Action |
|-----|--------|
| `<leader>hx` | Toggle hex view on current buffer |

Useful for binary analysis. Toggle back with the same key.

---

## Sessions

Sessions auto-save when you quit nvim. Separate sessions per directory + git branch.

| Key | Action |
|-----|--------|
| `s` on dashboard | Restore previous session |
| `<leader>ps` | Save session manually |
| `<leader>pl` | Load session for current directory |
| `<leader>pd` | Delete a session |

**How it works:**
1. Open nvim in a project, work on files
2. Quit with `:qa` — session auto-saves
3. Reopen nvim in same directory — press `s` on dashboard or `<leader>pl`
4. All your files, splits, and cursor positions are restored

---

## Oil (Filesystem Editing)

Oil lets you edit your filesystem like a buffer.

| Key | Action |
|-----|--------|
| `-` | Open parent directory in Oil |
| `Enter` | Open file / enter directory |
| `q` | Close Oil |
| `-` (again) | Go up one more directory |
| `<leader>o` | Open Oil in floating window |

**Creating files:** Just type a new filename on a blank line and save (`:w`).

**Deleting files:** Delete the line and save.

**Renaming:** Edit the filename and save.

---

## Markdown Rendering

Markdown files render with:
- Formatted headings
- Code block highlighting
- Bullet points
- Bold/italic styling

Spell check is enabled automatically for `.md` files.

---

## Tips & Tricks

### Centered Scrolling
`Ctrl+d` / `Ctrl+u` keeps the cursor centered on screen. Same for search with `n`/`N`.

### Quick Save
`<leader>w` saves instantly. No `:w Enter` needed.

### Copy to System Clipboard
The config uses OSC 52 for clipboard — copy in nvim works in your local clipboard even over SSH.

### Which-key
Press `<leader>` and **wait** — a popup shows all available keybindings grouped by category.

### Format on Save
Files auto-format when you save. To format manually: `<leader>fm`.

### Todo Comments
`TODO`, `FIXME`, `HACK`, `NOTE` in comments are highlighted automatically.
Find all todos: `<leader>fd` → look for todo-comment diagnostics.

### Multiple Cursors (sort of)
Neovim doesn't have native multi-cursor, but:
- `<leader>rn` renames a symbol everywhere (LSP)
- `<leader>sr` does project-wide search & replace
- `.` repeats the last edit
- Visual block mode (`Ctrl+v`) + `I` inserts on multiple lines

### Recovering from Mistakes
- `u` — undo (persists across sessions via undofile)
- `:earlier 5m` — go back 5 minutes in edit history
- `:later 5m` — go forward

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

*See [CHEATSHEET.md](CHEATSHEET.md) for a compact keybinding-only reference.*
