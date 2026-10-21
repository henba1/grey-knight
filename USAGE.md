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
8. [Running Scripts & REPL](#running-scripts-repl)
9. [Terminal](#terminal)
10. [Git](#git)
11. [Search & Replace](#search-replace)
12. [Windows & Splits](#windows-splits)
13. [Buffers](#buffers)
14. [Harpoon (Quick File Switching)](#harpoon-quick-file-switching)
15. [Flash (Jump Navigation)](#flash-jump-navigation)
16. [Surround](#surround)
17. [Diagnostics & Trouble](#diagnostics-trouble)
18. [Debugging (DAP)](#debugging-dap)
19. [Hex Editor](#hex-editor)
20. [Sessions](#sessions)
21. [Oil (Filesystem Editing)](#oil-filesystem-editing)
22. [Markdown Rendering](#markdown-rendering)
23. [Tips & Tricks](#tips-tricks)
24. [When Something Goes Wrong](#when-something-goes-wrong)
25. [Mode Reference](#mode-reference)
26. [Java and Angular](#java-and-angular)

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
| `<BS>` / `-` | cd .. — one folder up: the tree **and** Neovim's working directory |
| `h` | Close the folder (the cursor goes to its parent) |
| `l` / `Enter` | Open file (or toggle folder expand) |
| `.` | cd here — the folder under the cursor (on a file: its folder) becomes Neovim's working directory |
| `H` / `I` | Toggle hidden / ignored files |
| `<leader>/` | Grep inside the tree |
| `<C-t>` | Drop a terminal at the current dir |

**Search** - three kinds; the search box's title says which one runs:

| Key | Action |
|-----|--------|
| `/` | Search files: every file and folder below the root, the text matches the path (`config/ex` finds `lua/config/explorer.lua`) |
| `D` | Search folders: only folders, the text matches a folder's name - `java` finds `src/main/java` and `src/test/java`, not every package folder below them. No file is shown |
| `S` | Search the current view: only the rows the tree shows when you start - the open folders' contents; closed folders are not looked into. The text matches the names |
| `<M-s>` (Alt+s) | While typing: the next search (files → folders → current view), the typed text stays |
| `<Esc>` | One step back: typing → the search box → the list (the results stay) → the tree, the cursor where it was before the search → the explorer closes |

`/`, `D` and `S` work in the list and in the search box once you stop typing (`<Esc>`). During a search they switch
to that search and keep the text: search everything with `/`, then `<Esc>` `D` for only the folders. Matches show
up in the tree under their folders. `Enter` (or `l`) on one goes back to the tree with the cursor on it - `Enter`
again opens a file; the next `/` is a file search again. Lowercase text ignores case; `^x` / `x$` match names
(paths, in file search) that start / end with x, `!x` leaves them out.

**Filesystem ops**

| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | Mark / unmark the item, then go to the next / previous one; `V` … `<Tab>` marks a range, `<C-a>` all |
| `m` | Move the marked items into the folder under the cursor (asks first). Nothing marked: marks the item under the cursor |
| `c` | Copy the marked items into the folder under the cursor. Nothing marked: marks the item under the cursor |
| `r` | Rename, or move to a typed path: relative from the working directory (as shown), absolute as typed (`/home/…`, `~/…`, `C:\…`, `\\server\share\…`) |
| `C` | Copy to a typed path: relative from the item's folder, absolute as typed |
| `a` | New file or dir (trailing `/` makes a directory) - in the folder under the cursor, or at an absolute path |
| `d` | Delete the marked items, else the one under the cursor (to system trash; permanent fallback if no trash). The cursor stays on its item; when that one went, on the next one. Open files of what was deleted are closed - in a folder too |
| `y` | Yank the paths of the marked items (else the one under the cursor) to the clipboard |
| `p` | Paste yanked files into the folder under the cursor (copies) |

**Moving with the tree**: `m` on a file marks it; go to the target folder (or any file in it) and press `m`
again - it moves there after a yes, open buffers and language servers follow (for a folder: those of the files
in it). `c` instead copies it. Mark more with `<Tab>` first to move them together; `m` in the file's own folder
unmarks it. A typed path that names an existing folder (or ends in `/` or `\`) takes the item under its own name,
like `mv`; nothing is overwritten. Marks stay through searches and in the tree: `/` for the files, `<Tab>` on each,
`D` for the target folder, `m` there. A file with unsaved changes (or a folder with such a file) stays where it is
for `m` and `r` - save them (`:w`) or drop them (`:e!`) first.

**Typing in the prompts** - `r`, `C`, `a` and every other input dialog (the agent's questions too) - works like
a shell prompt:

| Key | Action |
|-----|--------|
| `<C-a>` / `<C-e>` | Start / end of the line |
| `<C-b>` / `<C-f>` | A character back / forward |
| `<M-b>` / `<M-f>` | A word back / forward |
| `<C-d>` | Delete the character under the cursor |
| `<C-k>` / `<C-u>` | Delete everything after / before the cursor (`<C-a><C-k>`: the whole line) |
| `<C-w>` | Delete the word before the cursor |

**Tree structure**

| Key | Action |
|-----|--------|
| `Z` | Collapse all folders under the root |
| `u` | Refresh the tree |
| `]g` / `[g` | Next / prev git-changed file |

**Changing the root**: `.` makes the folder under the cursor the working directory, `<BS>` or `-`
goes one folder up (`cd ..`). Both move the tree **and** Neovim's working directory, so pickers,
terminals and runs start there too; a message shows the new directory. (Snacks' own `.` / `<BS>`
moved only the tree.) `Snacks.explorer({ cwd = "/path" })` still opens a one-off rooted view.

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
| `Backspace` | v | Shrink selection |

These run Neovim's own node selection (`:h v_an`), with the LSP's selection ranges where a file type has no
treesitter parser. Neovim's own keys for it, `an` / `in`, are mini.ai's "next" textobjects here (`vin(`
selects inside the next parentheses).

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
| `<leader>ca` | Code action (quick fix, refactor) - the cursor on the marked code |
| `[d` | Previous diagnostic (error/warning), its message in a float |
| `]d` | Next diagnostic |
| `<leader>fm` | Format file (or selection in visual mode) |

The keys come with a server that can do what they ask: where none finds definitions (plain HTML, a Python file
with only ruff running), `gd` stays Vim's - the first use of the word in the file - and `K` Vim's keyword lookup.

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

**Signature help** shows function parameters as you type inside `()`.

Sources (in priority order): LSP → Snippets → Buffer words → File paths

---

## AI Assistant (Qwen Code)

Grey Knight drives the **local Qwen Code** CLI as an agentic coding agent, running it in a
persistent terminal window inside the editor. It is fully local — Qwen3.8-27B on the rig via
llama.cpp, zero cloud. For coding, start a coding launcher on the AI Dashboard's Models page:
`qwen38official-q6-text-think-mtp-128k` (official weights) or `qwen38alt-q6-text-think-mtp-128k`
(the uncensored "alternative" build), both without a chat persona, thinking on, 128k context.
`<leader>am` shows which model the rig is running (README.md → LLM Configuration).

**Qwen Code or OpenCode.** The agent is Qwen Code by default. The environment variable
`GREYKNIGHT_AGENT=opencode` switches to OpenCode (`qwen` pins Qwen Code); unset, GreyKnight takes
Qwen Code where it is installed, else OpenCode, so kali and the pi keep Qwen Code without any setting.
The keys, `@path` references, ask/edit and `<leader>rf` work the same with both. A new OpenCode agent
gets its first prompt pasted once it has started; `<leader>ac` sends `/new` there, and `<leader>am`
points to `/models` (OpenCode picks its model itself).

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50 split) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal-split AI agent |
| `<leader>tv` | n | Vertical-split AI agent |
| `<leader>t1` | n | Agent #1 (its own session) |
| `<leader>t2` | n | Agent #2 (its own session) |
| `<leader>t3` | n | Agent #3 (its own session) |
| `<leader>ac` | n | Fresh conversation in the main agent (`/clear`) |
| `<leader>am` | n | Which model the rig runs right now: name and context size (several launchers share the port) |
| `<leader>aa` | n | Ask about the current file (prompts for the question) |
| `<leader>aa` | v | Ask about the selected code (prompts for the question) |
| `<leader>ae` | v | Let the agent change the selected code (prompts for the instruction) |
| `<leader>rf` | n | Send the last failed run to the agent: command, exit code, output and code locations ([When it fails](#when-it-fails)) |

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
- `<leader>aa` / `<leader>ae` ask for your question / instruction, then send one prompt with
  the file as `@path` (Qwen Code reads it itself) plus the selected lines and their line
  numbers. A running agent gets it as one bracketed paste (multi-line safe); a new agent
  starts with it (`qwen -i`).
- Going to the agent window (`Ctrl+l`, a click, `<leader>tt`) puts you straight into terminal mode, as
  every terminal window does ([Terminal](#terminal)): type away. Inside it, `Esc Esc` gives normal mode
  (scroll, copy); the next time you come back it is terminal mode again - unless the agent has exited (a
  key would close its window). Qwen Code's input box can have a vim mode of its own (`general.vimMode` in
  `~/.qwen/settings.json`, `/vim` toggles it): a single `Esc` there puts that box into its NORMAL mode,
  which Neovim neither sees nor changes - `i` gets back to typing.

> Tip: for multi-agent work, keep agent #1 on one task and `<leader>t2` for another.

---

## Running Scripts & REPL

The `<leader>r` keys (and `F6`) are Grey Knight's bash + python workbench. Every run is a **task**
(overseer.nvim): a backend, a frontend and an e2e run can go side by side, and running a script
again replaces its previous run. Output appears in a **real terminal** at the bottom, so everything
interactive works: `input()`, `getpass`, `read -p`, `sudo` prompts, curses. (`:!python3 %` has no
terminal: `input()` fails there with `EOFError`.) The cursor goes to the output while the program
runs (type your input there) and back to the code when it ends. The bar above the output shows
RUNNING / DONE / FAILED, the exit code, the run time and what to do next.

### Running

| Key | Mode | Action |
|-----|------|--------|
| `F6` / `<leader>rr` | n | Run the current file (saved first) with its remembered arguments |
| `<leader>ra` | n | Edit the file's arguments, then run. Shell syntax: quotes, globs, `< input.txt`. Remembered per file across sessions |
| `<leader>rR` | n | Run as root: `sudo` asks for the password in the output |
| `<leader>rp` | n | Pick a project script and run it from the project root (with its remembered arguments) |
| `<leader>rP` | n | The same, editing its arguments first |
| `<leader>rs` | v | Run the selection as a script of its own (dedented, so a block out of a function runs) |
| `<leader>rc` | n | Run the `# %%` cell at the cursor (no cells: the whole file) |
| `<leader>rx` | n | Trace run of a shell script: `bash -x` prints every command before it runs |
| `<leader>rt` | n | pytest the current file (Java: the test class, TestNG / JUnit) |
| `<leader>rT` | n | pytest the test at the cursor (`file::TestClass::test_name`; Java: the test method) |

**Project scripts** are the `*.sh` files, executables and runnable `*.py` files (`#!` line or
`if __name__ == "__main__"`) in the project root and in `scripts/`, `bin/` and `tools/`; the project
is the git repository of the current file. They run from the project root, like `./launch.sh` in a
shell, and the picker marks the ones that are running.

### Tasks

| Key | Action |
|-----|--------|
| `<leader>rl` | Run the shown (or last) task again |
| `<leader>rk` | Stop it (the output stays) |
| `<leader>rw` | Watch: run it again whenever you save a file in its folder (toggle) |
| `<leader>ro` | Show / hide the output |
| `<leader>rL` | Task list: every task with status and duration; `<CR>` actions (restart, stop, open output, watch, ...), `o` open the output, `dd` remove, `?` help |
| `<leader>rO` | Task templates of the project: make targets, npm scripts, `.vscode/tasks.json`, shell commands |

The statusline shows how many tasks are running, done and failed.

### When it fails

- The failing line is **marked in your code** with the error. Python: the innermost frame in your
  own code gets the exception; bash/sh: the `line N` the shell reports; pytest: the failing assert
  with its `assert 0 == 4` detail. Snippets and cells point at the lines in the file.
- The quickfix list has every frame: `]q` / `[q` walk them, `<leader>xq` lists them (Trouble).
- `<CR>` on an error line in the output jumps to that line of code.
- `<leader>rf` sends the failed run to the **Qwen Code agent**: the command, the exit code, the last
  output and the code locations (as `@file`), asking it to find and fix the cause.

**Which interpreter:** Python files use the project's virtualenv (`$VIRTUAL_ENV`, else the
nearest `.venv/` or `venv/` between the file and your home directory), then the `#!` line, then
`python3` (Windows: `python`, and no `#!` line - there is no `/usr/bin/env`; a virtualenv's python is
`Scripts\python.exe`). Shell scripts use their `#!` line, else `bash`; other files run when they have a `#!`
line. A venv directly in your home (`~/venv` with pwntools, ...) is a toolbox, not a project
environment: activate it before starting nvim to use it everywhere. pyright and the debugger
pick the same virtualenv.

**Where:** programs run in Neovim's current directory (the project root), like in VS Code.
Selections and cells run from a temp file; Python snippets can still import the modules that
sit next to the file.

### Cells

`# %%` lines split a file into cells (the marker of VS Code, Jupytext and Spyder), handy for a
scratch file full of snippets:

```python
# %% load
hosts = open("hosts.txt").read().split()

# %% check
for host in hosts:
    print(host, len(host))
```

`<leader>rc` runs the cell at the cursor as a script; `<leader>rE` sends it to the REPL, where
the variables of earlier cells are still there.

### REPL

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ri` | n | Open / hide the REPL of the buffer's language: IPython (from the project's venv when it has one), else python3 (Windows: python; before Python 3.13 the code goes in through `exec()` of a temp file); bash for shell scripts (Linux) |
| `<leader>re` | n | Send the current line |
| `<leader>re` | v | Send the selection |
| `<leader>rE` | n | Send the `# %%` cell |

Python code reaches the REPL as **one bracketed paste**: blank lines inside functions do not end
the block, and a snippet with `input()` waits for you instead of being fed the next line of the
snippet. The cursor stays in the code, so you can keep sending. Use the REPL to keep state
between snippets, `<leader>rs` / `<leader>rc` for a clean run.

---

## Terminal

The `<leader>t*` keys above launch the coding agent (**Qwen Code** or OpenCode, see [AI Assistant](#ai-assistant-qwen-code)). For a Python or bash **REPL** use
`<leader>ri` ([Running Scripts & REPL](#running-scripts-repl)). For a plain **shell** use
`:2ToggleTerm`, and send shell lines straight into it with:

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ts` | v | Send selected lines to shell terminal #2 |
| `<leader>tl` | n | Send current line to shell terminal #2 |

In a terminal, `Ctrl+L` belongs to the program: it clears a shell. `Ctrl+h` / `Ctrl+j` / `Ctrl+k` jump to
the next window; for the right one, leave terminal mode with `Esc Esc`, then `Ctrl+l`.

Going to a terminal window - a shell, the REPL, an agent - puts you in terminal mode right away, also when
you left it in normal mode; not when its program has exited (a key would close the window then).

**Example workflow:**
1. `:2ToggleTerm` → open shell terminal #2 (e.g. ssh into a target)
2. Navigate to your notes / script
3. Select command lines with `V`
4. `<leader>ts` → the commands run in that shell, line by line

### Inside the AI Dashboard (web)

When GreyKnight runs in a workspace of the AI Dashboard's **Dev Environment** (the browser page
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
| `<leader>gv` | Diffview (side-by-side diffs) |
| `<leader>gh` | File history (all commits for current file) |

### Gitsigns (Gutter)

When editing files in a git repo, you'll see markers in the left gutter:
- **Green bar** — added lines
- **Blue bar** — changed lines  
- **Red triangle** — deleted lines

And keys for those changes (in files of a git repository):

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next / previous change (in diff mode, Diffview: Vim's next / previous difference) |
| `<leader>gs` | Stage the change at the cursor - on a staged one: unstage it. Visual: stage the selected lines |
| `<leader>gr` | Undo the change at the cursor (back to what git has; `u` brings it back). Visual: the selected lines |
| `<leader>gp` | Show the change in a popup: what the lines were |
| `<leader>gb` | Who changed the line, when, and the commit (blame) |

Committing stays with Lazygit (`<leader>gg`): stage what belongs together with `<leader>gs` while you look at it, then
commit there.

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

Harpoon pins the few files you are working on right now (say `app.py`, `utils.py` and
`run_e2e.sh`) to numbered slots, and `<leader>1` ... `<leader>4` jump straight to them from
anywhere. It is quicker than the buffer list (`<leader>fb`) or finding files (`<leader>ff`) because
the slots do not move: slot 2 stays `utils.py` until you change it.

| Key | Action |
|-----|--------|
| `<leader>ha` | Pin the current file: it gets the first free slot, and a message tells you which |
| `<leader>1` ... `<leader>4` | Jump to the file in slot 1 ... 4 |
| `<leader>hh` | Open the Harpoon menu: the list, one file per line |

**The menu is an editable buffer.** Each line is a slot: move lines to reorder the slots (`dd`,
then `p`), delete a line to unpin a file, `<CR>` opens the file under the cursor. Closing the menu
(`q` or `Esc`) keeps your edits; `u` before closing undoes a mistake.

**One list per project, kept across sessions.** Every working directory (`:pwd`, usually the
project root) has its own list, stored in `~/.local/share/nvim/harpoon/`. Pins and menu edits are
written there at once, so they survive even when the session is killed; start Neovim in the
project again and your pins are still there.

**Workflow:** start a task, pin the 2-4 files it touches (`<leader>ha` in each), then move between
them with `<leader>1-4` instead of searching.

-----|--------|
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

Grey Knight debugs **Python** (debugpy) and **bash** (bashdb, from Mason's bash-debug-adapter)
through nvim-dap, plus C/C++ with **CodeLLDB**, whose adapter binary Mason ensures. Set breakpoints,
then press `F5`. The program gets a real terminal (the **console** pane of the DAP UI), so `input()`
and `read` work while debugging: type the answer there. Python uses the same interpreter as `F6`
(the project's virtualenv); programs run in Neovim's current directory. While a session is stopped,
variable values appear next to the code.

Every session gets a fresh console: a program terminal left over from an earlier session (bashdb's
sometimes outlives it) is stopped first. A program whose session still runs keeps its terminal, and
the new one opens in a split.

### Starting a session

| Key / Command | Action |
|---------------|--------|
| `F5` | Debug the current file (Python or bash), or continue a stopped session. With a `.vscode/launch.json` in the project, pick one of its configurations. Java: pick a main class or one of IntelliJ's Remote JVM Debug configurations |
| `<leader>dl` / `<leader>dL` | Debug the current file / with arguments (prompt) |
| `<leader>dt` | Debug the test at the cursor (pytest; Java: TestNG / JUnit) |
| `<leader>da` | Attach: connect to a script started with `python -m debugpy.listen` (port prompt); Java: to a JVM - one of IntelliJ's Remote JVM Debug configurations, or host:port |

C/C++: the CodeLLDB binary itself is ensured via Mason, but its command
surface (`:CodelldbLaunch` / `:CodelldbAttach`) ships with the
`porkfly/codelldb.nvim` plugin, which needs GitHub access to sync —
unavailable from this network for now.

### Controlling a session

| Key | Action |
|-----|--------|
| `F5` | Continue |
| `Shift+F5` / `<leader>dq` | Stop |
| `<leader>dR` | Restart |
| `F10` / `F11` / `F12` | Step over / into / out |
| `<leader>dc` | Run to the cursor |
| `F9` / `<leader>db` | Toggle breakpoint at the cursor line |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dp` | Log point: prints a message (with `{expressions}`) instead of stopping |
| `<leader>de` | Python: stop on every raised exception, also caught ones (toggle; default: uncaught only) |
| `<leader>dh` | Value of the expression under the cursor |
| `<leader>dr` | REPL — evaluate expressions in the stopped frame |
| `<leader>du` | Toggle DAP UI (variables, stack, watches, console) |

> `Shift+F5` needs a terminal that sends it (not all do over SSH or in the browser); `<leader>dq`
> always works.

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
| `s` on dashboard | Restore the session of this directory (and branch) |
| `<leader>ps` | Save session now - also with no file open |
| `<leader>pl` | Load session for current directory |
| `<leader>pd` | Delete a session (pick one) |
| `:Persisted clean` | Delete the sessions of folders and branches that no longer exist |

**How it works:**
1. Open nvim in a project, work on files
2. Quit with `:qa` — session auto-saves
3. Reopen nvim in same directory — press `s` on dashboard or `<leader>pl`
4. All your files, splits, tabs and cursor positions are restored

**What a session keeps:** files, splits, tabs and help windows. Not kept: terminals - agents, REPLs and shells
start again with their keys (a restored one would run its program again, outside them) - and the explorer
(`<leader>e`). Quitting with no file open (from the start screen, a picker) keeps the session there was; only
`<leader>ps` saves then. No sessions are saved for the home folder itself, `/` and `/tmp`.

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

**Folders opened as files** (`nvim <folder>`, `:e <folder>`) open in the explorer, with that folder as the root -
Oil opens only with `-` and `<leader>o`.

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

### Reading These Docs in Neovim
`<leader>gd` picks README, CHEATSHEET or this guide and opens it read-only in a split; `q` closes it.
In any markdown file, `gd` or `Enter` on a link follows it: a `#heading` in the same file (like the
table of contents above), another file - a name with spaces written `<my notes.md>` or `my%20notes.md` - or a
URL. `Ctrl+o` jumps back. `gO` lists all headings of the file; `Enter` on one jumps there.

### Centered Scrolling
`Ctrl+d` / `Ctrl+u` keeps the cursor centered on screen. Same for search with `n`/`N`.

### Quick Save
`<leader>w` saves instantly. No `:w Enter` needed.

### Copy to System Clipboard
Yank and paste use the system clipboard (`unnamedplus`). On your own machine Neovim picks the tool itself
(wl-clipboard, xclip / xsel, the Windows clipboard). Over SSH a yank goes to the clipboard of the computer in
front of you via OSC 52, and `p` pastes the last yank made in nvim - text copied on that computer comes in with
the terminal's paste (`Ctrl+Shift+V` / right-click). Reading the clipboard over OSC 52 works in few terminals; in
the others (Windows Terminal) every `p` used to wait 10 seconds.

### Which-key
Press `<leader>` and **wait** — a popup shows all available keybindings grouped by category.

### Format on Save
Files auto-format when you save. To format manually: `<leader>fm`. In projects you also open in IntelliJ
(an `.idea` folder) saving does what IntelliJ's Actions on Save do - by default nothing; Java files get that
default everywhere (see [Java and Angular](#java-and-angular)).

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

## When Something Goes Wrong

| What happened | Where to look |
|---------------|---------------|
| Your program failed | The failing line is marked in the code; `]q` / `[q` walk the traceback, `<CR>` on an error line in the output jumps there, `<leader>rf` sends it to Qwen ([When it fails](#when-it-fails)) |
| Errors and warnings of the project | `<leader>xx` (Trouble): LSP diagnostics and the marks of your runs; `<leader>xq`: the quickfix list of the last failed run |
| A notification flashed by | `<leader>un`: the notification history of this session |
| A key or command raised a Lua error | `<leader>um`: `:messages` |
| Something went wrong in an earlier session | `<leader>ue`: the error log `~/.local/state/nvim/greyknight.log` |
| A plugin, language server or tool misbehaves | `:checkhealth` (or `:checkhealth overseer`, `dap`, `vim.lsp`), `:Lazy` (plugins), `:Mason` (servers, debuggers), `:LspInfo`, `:LspLog` |
| The debugger | `:DapShowLog` |
| Qwen Code | its window; debug logs in `~/.qwen/debug/` |

**The error log** keeps every warning and error notification of every session (with time, source
and a line per session start) and, when Neovim exits, the Lua errors from `:messages`. It is plain
text, trimmed to the last 2000 lines when it grows past 512 KB, so it is also the file to read (or
send) when something broke and you did not see why.

**Tests:** `tests/run.sh` runs the whole test suite headless (about ten seconds; the dev suite
starts real python, bash and debugger processes) and exits with status 1 when anything fails. Run
it after changing the config. On Windows: `tests\run.ps1` - each suite in a minimized Neovim window
(a headless one gets no terminal output there), the bash tests skipped. Some tests only:
`GK_TEST_ONLY='Explorer workflow,Session' tests/run.sh smoke` runs the tests whose names contain one of the
comma-separated pieces, `GK_TEST_SKIP` all but those.

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

## Java and Angular

GreyKnight works on a project you also open in IntelliJ IDEA the way IntelliJ does: it reads IntelliJ's settings
(`lua/integrations/intellij.lua`, never writing them), so nothing drifts apart. Without IntelliJ it works on its
own ([below](#without-intellij)). The workflow for the G3 repositories, step by step:
[G3-DEVELOPMENT.md](G3-DEVELOPMENT.md).

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

---

*See [CHEATSHEET.md](CHEATSHEET.md) for a compact keybinding-only reference.*
