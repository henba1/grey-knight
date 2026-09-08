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
7. [AI Assistant (Avante)](#ai-assistant-avante)
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
| `a` | Open AI chat (Avante) |
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

| Key | Action |
|-----|--------|
| `<leader>e` | Toggle file explorer (left sidebar) |
| `Ctrl+h` | Move focus to explorer |
| `Ctrl+l` | Move focus back to editor |
| `Enter` | Open file / expand folder |
| `a` | Create new file |
| `d` | Delete file |
| `r` | Rename file |

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

## AI Assistant (Avante)

Avante provides a Cursor-style AI sidebar powered by your local LLM.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>at` | n | Toggle AI sidebar |
| `<leader>ac` | n | Start new AI chat |
| `<leader>aa` | n | Ask AI about current file |
| `<leader>aa` | v | Ask AI about selected code |
| `<leader>ae` | v | Ask AI to edit selected code |

### Using Avante

1. **Toggle sidebar:** `<leader>at`
2. **Type your question** in the input area at the bottom
3. **Press Enter** to send
4. AI responds with code suggestions, explanations, or edits
5. **Apply suggestions** — Avante can directly edit your files in agentic mode

### Agentic Mode

Avante runs in agentic mode by default. The AI can:
- Read files in your project
- Search your codebase
- Edit files directly
- Run shell commands
- Get LSP diagnostics

### Project Context

Place an `avante.md` file in your project root to give the AI context:

```markdown
# Project: MyApp

## Your Role
Expert Python developer.

## Tech Stack
Python 3.11, asyncio, FastAPI

## Coding Standards
- Type hints on all functions
- Docstrings for public methods
```

---

## Terminal

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle terminal (horizontal split) |
| `<leader>tf` | Floating terminal |
| `<leader>th` | Horizontal split terminal |
| `<leader>tv` | Vertical split terminal |
| `<leader>t1` | Terminal #1 (named, persistent) |
| `<leader>t2` | Terminal #2 |
| `<leader>t3` | Terminal #3 |

### Inside a Terminal

| Key | Action |
|-----|--------|
| `Esc Esc` | Exit terminal mode (back to normal mode) |
| `Ctrl+h/j/k/l` | Navigate to other windows |
| `<leader>tt` | Hide terminal (from normal mode) |

### Send to Terminal (Pentesting Workflow)

Great for sending code snippets to a running REPL or shell:

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ts` | v | Send selected lines to terminal #1 |
| `<leader>tl` | n | Send current line to terminal #1 |

**Example workflow:**
1. `<leader>t1` → open terminal, start `python3`
2. Navigate to code
3. Select lines with `V`
4. `<leader>ts` → code appears in the Python REPL

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

Works for **all** windows: editor splits, explorer, terminal, Avante sidebar.

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
- Also works in Avante AI chat panel

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
| **Terminal** | `<leader>tt` | Shell inside nvim |

---

*See [CHEATSHEET.md](CHEATSHEET.md) for a compact keybinding-only reference.*
