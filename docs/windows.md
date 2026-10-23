# GreyKnight - Windows, buffers, terminals, sessions

> Splits and moving between them, resizing, buffers, terminal windows, sessions per project.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [Windows & Splits](#windows-splits) · [Buffers](#buffers) · [Terminal](#terminal) · [Sessions](#sessions)

## Windows & Splits

### Creating Splits

| Command | Action |
|---------|--------|
| `:vs` | Vertical split (side by side) |
| `:sp` | Horizontal split (top/bottom) |
| `:vs file.py` | Open file in vertical split |

### The window bar

Each file window has a bar of its own on top - the statusline at the bottom is one for all windows:

```
 lua/config/winbar.lua ●                                   ◫  ⊟  ×
```

The file (relative to the working directory), `●` while it has unsaved changes, and three buttons to click:

| Button | Action |
|--------|--------|
| `◫` | Split right - the same file in a new window beside it |
| `⊟` | Split below |
| `×` | Close, as in an IDE: the window; the last file window stays where it is and closes its file instead (asks first about unsaved changes) - Neovim does not quit |

The window with the cursor shows it brighter. Not on the explorer, pickers, terminals, the agent, help, quickfix,
floating windows or the start screen; a diff's or a following window's own bar (`<leader>af`) takes its place.

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

In a terminal too - but not in an agent's window, where they are the agent's ([Terminal](#terminal)).

`Alt+←` `Alt+→` `Alt+↑` `Alt+↓` (`<M-Left>` …) do the same in the editor - for a terminal that sends Ctrl+arrows as
plain arrows, as PuTTY does by default ([Over SSH (PuTTY)](ssh.md#over-ssh-putty)). In a terminal they stay the shell's.

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
| `<leader><Tab>` | Recent buffers, IntelliJ's Ctrl+Tab (below) |
| `<C-^>` | The buffer before this one, at once; again goes back |
| `<C-o>` / `<C-i>` | Back / forward through the places you jumped to, from file to file (IntelliJ's Navigate Back / Forward) |
| `<leader>fb` | Buffer picker (see all open buffers) |
| `<leader>fr` | Recent files - also the ones closed, of earlier sessions |
| `<leader>bd` | Close current buffer |

**Recent buffers** (`<leader><Tab>`) lists the open files in the order you used them, this one first, and starts on
the one before it: `<leader><Tab>`, `Enter` goes back there. `Tab` goes further back, `Shift+Tab` forward again,
typing filters, `dd` (`Ctrl+x`) closes a buffer. `Ctrl+Tab` opens it too where the terminal passes Ctrl+Tab on
(a GUI, WezTerm); Windows Terminal and kitty switch their own tabs with it. After a restart (a restored session)
the files you have not gone to yet keep the order you last used them in (Neovim's recent files).

---

## Terminal

The `<leader>t*` keys above launch the coding agent (**Qwen Code** or OpenCode, see [AI Assistant](agent.md#ai-assistant-qwen-code)). For a Python or bash **REPL** use
`<leader>ri` ([Running Scripts & REPL](run-debug.md#running-scripts-repl)). For a plain **shell** use
`:2ToggleTerm`, and send shell lines straight into it with:

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ts` | v | Send selected lines to shell terminal #2 |
| `<leader>tl` | n | Send current line to shell terminal #2 |

In a terminal, `Ctrl+h` / `Ctrl+j` / `Ctrl+k` / `Ctrl+l` jump to the next window and `Ctrl+Up/Down/Left/Right`
resize it, as everywhere else. Every other key is the program's: the shell's own `Ctrl+A` / `Ctrl+E`, `Alt+B` /
`Alt+F`, `Ctrl+W`, `Ctrl+U`, `Ctrl+R` work as typed. To clear the shell type `clear` (`cls` in cmd.exe) - `Ctrl+L`
is the window on the right.

**An agent's window** (Claude Code, OpenCode, Qwen Code - `<leader>tt`, `t1` ...) has a keyboard of its own: only the
ways out stay GreyKnight's - `Ctrl+h` / `Ctrl+j` / `Ctrl+k` / `Ctrl+l` (the next window) and `Esc Esc` (normal mode;
Neovim's own `Ctrl+\ Ctrl+n` as well). Every other key is the agent's: `Ctrl+←` / `Ctrl+→` move through its prompt
word by word instead of resizing the window. To resize it: `Esc Esc`, then `Ctrl+arrows` - or from the window next
to it.

Going to a terminal window - a shell, the REPL, an agent, a run's output, the debug console, `:terminal` - puts
you in terminal mode right away, also when you left it in normal mode; not when its program has exited (a key
would close the window then).

The statusline names a terminal by what runs in it: an agent by its name (`OpenCode`, `Qwen Code #2` - with
`- in <folder>` when it works elsewhere than Neovim), any other by its program and number (`pwsh #2`, `bash`).

**Example workflow:**
1. `:2ToggleTerm` → open shell terminal #2 (e.g. ssh into a target)
2. Navigate to your notes / script
3. Select command lines with `V`
4. `<leader>ts` → the commands run in that shell, line by line

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
