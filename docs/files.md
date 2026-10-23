# GreyKnight - Files: the tree, oil, harpoon, bookmarks

> The file tree (explorer) with its searches, moves and script slots; oil to edit a folder like a buffer; harpoon and bookmarks to come back quickly.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [File Explorer](#file-explorer) · [Script slots](#script-slots) · [Oil (Filesystem Editing)](#oil-filesystem-editing) · [Harpoon (Quick File Switching)](#harpoon-quick-file-switching) · [Bookmarks](#bookmarks)

## File Explorer

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

**Search** - three kinds, fuzzy or by regex; the search box's title says which one runs:

| Key | Action |
|-----|--------|
| `/` | Search files: every file and folder below the root, the text matches the path (`config/ex` finds `lua/config/explorer.lua`) |
| `D` | Search folders: only folders, the text matches a folder's name - `java` finds `src/main/java` and `src/test/java`, not every package folder below them. No file is shown |
| `S` | Search the current view: only the rows the tree shows when you start - the open folders' contents; closed folders are not looked into. The text matches the names |
| `R` | Search files by regex: `.*\.sh$` finds every shell script below the root; a glob too (`*.sh`) - see below |
| `<M-r>` (Alt+r) | While searching: the file / folder search by regex, or fuzzy again - the typed text stays, and so does the choice until you switch back |
| `<C-a>` | In a search: mark its matches - the files of a file search, the folders of a folder search, not the folders shown above them (again: unmark). `m` / `c` / `d` then act on all of them |
| `<M-s>` (Alt+s) | While typing: the next search (files → folders → current view), the typed text stays |
| `<Esc>` | One step back: typing → the search box → the list (the results stay) → the tree, the cursor where it was before the search → the explorer closes |

**By regex** (`R`, or `Alt+r` during a file or folder search) the text goes to `fd`: a Rust regex - as in
ripgrep: `\d` `\w` `\b` `(a|b)` `{2,3}` `(?i)`, no lookaround or backreferences. It matches the **name**
(`^test_.*\.py$`), or - when it has a `/` - the **path below the tree's root**: `^src/.*\.ts$` from the root,
`sub/.*\.(ts|bash)$` anywhere below it (on Windows a `/` matches `\` too). A text with a `*` and nothing only a
regex has (`\ ^ $ ( ) | +`, `.*`) is a **glob**: `*.sh`, `test_*.py`, `*.{sh,bash}`; with a `/` relative to the
root as in `.gitignore` (`src/*.ts`, `**/test/*.py`). Lowercase text ignores case, a capital makes it count.
The title says how the text was read - `Search files (regex)`, `(glob)` - and what is wrong with a regex `fd`
cannot read: `(regex: unclosed group)`.

`/`, `D` and `S` work in the list and in the search box once you stop typing (`<Esc>`). During a search they switch
to that search and keep the text: search everything with `/`, then `<Esc>` `D` for only the folders. Matches show
up in the tree under their folders. `Enter` (or `l`) on one goes back to the tree with the cursor on it - `Enter`
again opens a file; the next `/` is a file search again. Lowercase text ignores case; `^x` / `x$` match names
(paths, in file search) that start / end with x, `!x` leaves them out.

**Filesystem ops**

| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | Mark / unmark the item, then go to the next / previous one; `V` … `<Tab>` marks a range, `<C-a>` all (in a search: its matches) |
| `m` | Move the marked items into the folder under the cursor (asks first). Nothing marked: marks the item under the cursor |
| `c` | Copy the marked items into the folder under the cursor. Nothing marked: marks the item under the cursor |
| `r` | Rename, or move to a typed path: relative from the working directory (as shown), absolute as typed (`/home/…`, `~/…`, `C:\…`, `\\server\share\…`) |
| `%` | Rename the marked items by regex (else the one under the cursor): `s/regex/replacement/` on their names - see below |
| `@` | To the agent: the marked items (else the one under the cursor) as `@path` in its prompt - typed, not sent ([The file tree and the agent](agent.md#the-file-tree-and-the-agent)) |
| `C` | Copy to a typed path: relative from the item's folder, absolute as typed |
| `a` | New file or dir (trailing `/` makes a directory) - in the folder under the cursor, or at an absolute path |
| `d` | Delete the marked items, else the one under the cursor (to system trash; permanent fallback if no trash). The cursor stays on its item; when that one went, on the next one. Open files of what was deleted are closed - in a folder too |
| `y` | Yank the paths of the marked items (else the one under the cursor) to the clipboard |
| `p` | Paste yanked files into the folder under the cursor (copies) |

**Right-click** an item for a file menu, as in an IDE - the cursor goes to the clicked row first (the focus too,
when another window had it):

| Entry | Same as |
|-------|---------|
| Open / Open to the side / Open below | `Enter` / a vertical / a horizontal split |
| New file or folder… / Rename… / Delete | `a` / `r` / `d` (Delete: the marked, else this one) |
| Copy / Paste | `y` / `p` - the paths to the clipboard; the copied files into the folder under the cursor |
| Copy to… | `C` |
| Copy path / Copy relative path | The path (the marked: one per line) to the clipboard, absolute or from the working directory |
| Open with system app | The file (a folder: the file manager) in the desktop's app for it |
| Make working directory | `.` |
| Send to agent as @path | `@` |
| Show / Hide hidden files | `H` |

Below the last row the menu is about the tree's folder: the cursor goes to the root, and Open, Rename, Delete and
Copy to are left out (Delete stays when items are marked - it deletes those). Outside the explorer a right-click
shows Neovim's own menu as before.

**Moving with the tree**: `m` on a file marks it; go to the target folder (or any file in it) and press `m`
again - it moves there after a yes, open buffers and language servers follow (for a folder: those of the files
in it). `c` instead copies it. Mark more with `<Tab>` first to move them together; `m` in the file's own folder
unmarks it. A typed path that names an existing folder (or ends in `/` or `\`) takes the item under its own name,
like `mv`; nothing is overwritten. Marks stay through searches and in the tree: `/` for the files, `<Tab>` on each,
`D` for the target folder, `m` there. A file with unsaved changes (or a folder with such a file) stays where it is
for `m` and `r` - save them (`:w`) or drop them (`:e!`) first.

**Renaming by regex** (`%`): `s/regex/replacement/` on the names of the marked items, as `sed` does it - the first
match, `g` every one, `i` ignores case; any delimiter after the `s` (`s#a/b#c#`). The regex is the search's (Rust
regex, as ripgrep's); the replacement takes `$1`, `${name}`, `$0` (the whole match), `$$` (a `$`). A list of the
new names shows first, then a yes. A name that would leave its folder, be another's too or land on something that
exists stays as it is (each says why); open buffers, bookmarks and harpoon slots follow, as with `r`. The last
substitution comes back as the default. Together: `R` `.*\.txt$`, `Ctrl+a`, `%` `s/\.txt$/.md/`.

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

**Folders you may not read** (another user's, Windows' old junctions in your home folder like `Anwendungsdaten`)
open empty; the first time a message says why. The rest of the tree works as before.

> Delete is **trash-first**: it shells to `trash`/`gio trash`/`kioclient` when present,
> so `d` is recoverable on most desktops. Without a trash backend it falls back to a
> permanent `:delete` — check with `:checkhealth snacks` before deleting anything precious.
> Where the trash refuses — `gio` does for everything in `/tmp` ("Trashing on system internal mounts is
> not supported") — `d` asks once more: delete for good, or keep it. A link goes, never what it points to.

---

## Script slots

In the explorer `!1` … `!9` run a script of yours on what the tree shows - the item under the cursor and the
marked items (`<Tab>`). `!!` lists the slots with their descriptions and runs the one you pick. The output shows
in the run window below the code (as for `<leader>rr`: exit status, `<leader>rl` again); the cursor stays in the
tree, and the tree is read again when the script ends.

A slot is a file named `<n>-<name>.<ext>` (n = 1 … 9) in one of two folders:

| Folder | |
|--------|---|
| `slots/` in this config (`~/.config/nvim/slots`, Windows `%LOCALAPPDATA%\nvim\slots`) | in git: on every machine. `1-info.py` is slot 1 |
| `~/.local/share/nvim/slots` (Windows `%LOCALAPPDATA%\nvim-data\slots`) | yours, not in git - it wins a number both have |

`.py` runs everywhere, `.sh` on Linux, `.ps1` on Windows (PowerShell), an executable file on Linux. No shell
runs in between: names with spaces, `&`, `%`, `^` or `[ ]` reach the script whole. The script's first comment line
is its description in `!!`. Slot 1, `1-info.py`, prints path, type, size, date and permissions of the marked items
(of the one under the cursor when nothing is marked) - on Windows the attributes instead of the owner.

**What a script gets** - both, the cursor's item and the marked ones; the script takes what it needs:

| | |
|---|---|
| arguments | the marked items, in the order you marked them |
| `GK_MARKED` | a file with the marked items, one per line (empty when nothing is marked) |
| `GK_CURSOR` | the item under the cursor |
| `GK_DIR` / `GK_ROOT` | the folder the cursor is in (its item, on a folder) / the tree's root - the working directory |
| `GK_SLOT` / `GK_LIB` | its number / the helpers' folder (`gk.py` - already on `PYTHONPATH` -, `gk.sh`, `gk.ps1`) |

**Asking you** - the script prints a request line and reads the answer as a line from its input; the helpers do
both. A script that deletes or overwrites asks first, the way it wants to:

| Request (a line the script prints) | In Neovim | Answer (a line the script reads) |
|---|---|---|
| `::gk::confirm::<question>` | a Yes / No dialog | `y` or `n` |
| `::gk::input::<prompt>` - a `::gk::default::<text>` line before it fills the box | a text box | the text |
| `::gk::select::<prompt>` - the `::gk::option::<text>` lines before it are the choices | a choice | the option |
| `::gk::notify::<message>` (`::gk::warn::`, `::gk::error::`) | a notification | - |
| `::gk::open::<path>` or `::gk::open::<path>:<line>` | the file in the code window | - |
| `::gk::refresh::` | the tree read again now | - |

A dialog closed without an answer answers an empty line (`n` for Yes / No). One line per request: the terminal
between script and Neovim turns tabs into cursor moves on Windows, so nothing is split within a line.

Python - `gk.cursor()`, `gk.marked()`, `gk.folder()`, `gk.root()`, `gk.confirm()`, `gk.ask()`, `gk.choose()`,
`gk.notify()`, `gk.open()`, `gk.refresh()`:

```python
# Delete the marked files (the one under the cursor when none is marked) - after a yes
import os
import gk

files = gk.marked() or [gk.cursor()]
if gk.confirm(f"Delete {len(files)} files?"):
    for f in files:
        os.remove(f)
```

bash - `source "$GK_LIB/gk.sh"`: `gk_marked` (one per line), `gk_confirm` (its exit status), `gk_ask`,
`gk_choose`, `gk_notify`, `gk_open`, `gk_refresh`. PowerShell - `. (Join-Path $env:GK_LIB 'gk.ps1')`:
`Get-GkMarked`, `Confirm-Gk`, `Read-Gk`, `Select-Gk`, `Send-GkNotify`, `Open-Gk`, `Update-GkTree`.

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

**Renaming:** Edit the filename and save. Moved or renamed this way - a file or a folder, open or not - a
file keeps its bookmarks and its harpoon slot, as with the explorer's `r` and `m`.

**Folders opened as files** (`nvim <folder>`, `:e <folder>`) open in the explorer, with that folder as the root -
Oil opens only with `-` and `<leader>o`.

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

**Slots follow their files.** Renamed or moved with the explorer (`r`, `m` - also with its folder) or in
an oil buffer, a pinned file keeps its slot. A slot whose file is gone (deleted, moved outside Neovim)
says so and opens nothing - it used to open an empty new file at the old path; `dd` in the menu
(`<leader>hh`) unpins it.

**Workflow:** start a task, pin the 2-4 files it touches (`<leader>ha` in each), then move between
them with `<leader>1-4` instead of searching.

---

## Bookmarks

Bookmarks mark **lines** to come back to, as IntelliJ's do: the function you are fixing, the config value you keep
checking, the place a bug shows. Harpoon keeps a few files at fixed numbers; bookmarks are places in files, as many
as you like, and they can have a name.

| Key | Action |
|-----|--------|
| `<leader>mm` | Set a bookmark on the cursor's line (a `⚑` in the sign column), or remove the one there |
| `<leader>mr` / `<C-F11>` | Name the bookmark on this line - it is set first if there is none; an empty name takes the name away |
| `<leader>ml` / `<S-F11>` | The project's bookmarks in a list: name, file, line and its text, with a preview. `Enter` opens the file at the line, `dd` / `Ctrl+x` deletes, typing filters |
| `<leader>mn` / `<leader>mp` | Next / previous bookmark, in file and line order, from file to file; after the last comes the first |

`Ctrl+o` comes back from a bookmark you went to. IntelliJ's `F11` is the debugger's step into here (`F5` and its
neighbours are the debug keys); `Shift+F11` and `Ctrl+F11` are as in IntelliJ - most terminals send them the way
Neovim calls `<F23>` and `<F35>`, mapped too (PuTTY: [Over SSH (PuTTY)](ssh.md#over-ssh-putty)).

**They stay with their lines.** A bookmark moves with its line while you edit above it, and with the line when you
move it (`:m`, visual `J` / `K`). A line cut and put back elsewhere (`dd`, `p`) or replaced as a whole (a formatter,
`:%!`) keeps its bookmark too: it follows the line's text, spaces aside. Delete the line and save, and the bookmark
goes with it (`u` before saving brings both back). Changed outside Neovim - a `git pull`, another editor - a file's
bookmarks find their lines again by their text when you open it. (A line too short to know it by - an `end`, a
`}` - is not looked for.)

**They stay with their files.** Renamed or moved with the explorer (`r`, `m` - a file not open, a whole folder
too), in an oil buffer or with `:file` / `:saveas`, a file keeps its bookmarks. The bookmarks of a deleted file stay in the list,
marked *file gone* - after checking out another branch it may come back: `Enter` on one only says so (it opened an
empty new file), next / previous skip them, `dd` removes them.

**One set per project, kept across sessions.** Every working directory (`:pwd`) has its own, kept in
`~/.local/share/nvim/bookmarks.json` (Windows: `%LOCALAPPDATA%\nvim-data\bookmarks.json`) and written at once, so
they survive a killed session too. Change the directory and the signs and the list are that project's.
