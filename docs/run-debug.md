# GreyKnight - Running and debugging

> Scripts as tasks in a real terminal, the REPL, errors marked in the code, LaTeX builds, debugging Python and bash.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [Running Scripts & REPL](#running-scripts-repl) · [Debugging (DAP)](#debugging-dap)

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
line. Windows runs no `#!` line at all (no `/bin/bash` there): shell scripts run with Git for Windows'
bash (Git Bash) - not with the `bash.exe` of WSL, which takes no Windows paths. A venv directly in your
home (`~/venv` with pwntools, ...) is a toolbox, not a project environment: activate it before starting
nvim to use it everywhere. pyright and the debugger pick the same virtualenv.

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

### LaTeX

| Key | Action |
|-----|--------|
| `<leader>lb` | Build the document of the current file once (`latexmk`, saved first) |
| `<leader>lw` | Watch: `latexmk -pvc` builds it again on every save, and the preview shows the PDF (toggle). On a PDF or an image: the preview of that file, no build |
| `<leader>le` | The last build's errors in the quickfix window |

**The document** of a `.tex` file is the one its `% !TEX root = ../main.tex` line names, else the file
itself when it has a `\documentclass`, else the `main.tex` of the nearest folder above it - so `<leader>lw`
in a section file of a thesis or a talk watches the whole document. In the file tree the keys act on the item under
its cursor (a folder: its `main.tex`); in a terminal, on the file you used before it. latexmk runs in the document's folder
with its `latexmkrc`, and opens no PDF viewer (`-view=none`): over SSH there is none.

**Errors** go where a failed run's go: onto their lines in the code and into the quickfix list (`]q` /
`[q`, `<leader>xq`). Only the last pdflatex run of a build counts, each error once; an undefined command is
named (`Undefined control sequence. \badmacro`) - beamer reports every error of a frame at its
`\end{frame}`, the name says which line it was. One notification per build says how it went.

**The preview** starts with the watch's first build and stops with it: the PDF as pictures on
http://localhost:8000, in the browser of any machine - over SSH tunnel the port to your own
(`ssh -L 8000:localhost:8000 <host>`, PowerShell and PuTTY alike). Each build swaps the pictures in place,
the scroll position stays; the pages that changed in it are outlined and listed in the bar at the top
(**only changed** hides the rest). Two views: the **overview** of all pages, and **one slide** at a time as large as the
window, with a strip of the others below - a click on a page or `S`; `←` `→` / Space go on, `Esc` back. It needs `pdftoppm` (poppler-utils) and Python; another port:
`require("devsuite.latex").preview_port = 8001`. The PDF is the one latexmk writes - with
`$out_dir = 'build'` in the `latexmkrc`, `build/main.pdf`.

**A PDF or an image** (png, jpg, gif, svg, webp, bmp, avif, ico): `<leader>lw` on it - in its window or in the file
tree - shows that file in the preview, without a build; it is new there whenever the file changes. An image is the
browser's own (at its size, nothing rendered); a PDF gets the overview and the one-slide view, and **Open PDF** in the
bar opens the file itself in the browser's PDF viewer. `<leader>lw` again stops it.

**latexmk** comes from the PATH, else from TeX Live's own install folders (`~/texlive/<year>`,
`/usr/local/texlive/<year>`, the newest year); pdflatex and biber from the same TeX Live.

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
the new one opens in a split. When a session ends, the DAP UI closes; while the program in the console
is still running, it closes once that program has exited (closing it first crashed Neovim on Windows
now and then).

bash-debug-adapter leaves a file in `/tmp` after each session (`vscode-bash-debug-fifo-<number>`,
bashdb's goodbye). It draws that name at random from 10,000, and a session that drew a taken one
hung. The leftovers are deleted before each bash session.

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
> always works. Most terminals send it the way Neovim calls `<F17>` - mapped too; PuTTY: [Over SSH (PuTTY)](ssh.md#over-ssh-putty).
