# GreyKnight - Testbook: workflows to try by hand

> Longer runs through the editor that tie several features together - what the automatic tests cannot see: your
> screen, your microphone, your company's network. Each says what to do and what you should see.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [1. The agent edits, you review](#1-the-agent-edits-you-review) · [2. The tree and the agent](#2-the-tree-and-the-agent)
· [3. Find, understand, rename](#3-find-understand-rename) · [4. A run fails, the agent fixes it](#4-a-run-fails-the-agent-fixes-it)
· [5. Debugging Python](#5-debugging-python) · [6. Tests: run, debug one](#6-tests-run-debug-one)
· [7. Java at work (Windows)](#7-java-at-work-windows) · [8. Git: from a change to a commit](#8-git-from-a-change-to-a-commit)
· [9. Search and replace across the project](#9-search-and-replace-across-the-project) · [10. Files: rename by regex, things follow](#10-files-rename-by-regex-things-follow)
· [11. Speech to text](#11-speech-to-text) · [12. Another project while the agent runs](#12-another-project-while-the-agent-runs)
· [13. The look, a session, SSH](#13-the-look-a-session-ssh)

Tip: a throwaway git repository for these - a few Python files with a function that calls another, a test file, a
bash script. When something is off: `<leader>un` (notifications), `<leader>um` (`:messages`), `<leader>ue` (the error
log).

## 1. The agent edits, you review

1. Open a file, `<leader>tt` - Windows: OpenCode asks for its mode, take `D`. In Qwen Code `Shift+Tab` until it says
   *auto-accept edits* (else it asks with a diff first - try that too).
2. Back in the code window (`Ctrl+h`), `<leader>af`: its bar says *follows the agent*.
3. Go to the agent (`Ctrl+l`): *"add a docstring to every function in <a file that is not open> and rename one
   variable"*.
4. **Expect:** the following window switches to that file as the edit lands, the cursor on the change; old lines red
   above, new ones green, the changed words stronger; your cursor stays in the agent.
5. In that window: `]c` / `[c` go from change to change, the keys show at the end of the one under the cursor.
   `<leader>an` on one - it is gone from the buffer **and the file** (`:e` shows it); `<leader>ay` on another.
6. `<leader>ar`: what still waits, all files - `Ctrl+y` keeps, `Ctrl+x` reverts. `<leader>ad`: everything changed since
   the agent started, side by side with `Enter`.
7. Ask the agent *"which of your edits did I revert?"* - **expect** it to name them (it reads the review).
8. `<leader>gv`: the same changes as git sees them (codediff); `<leader>gs` stages a hunk.

## 2. The tree and the agent

1. `<leader>e`, `Tab` on two or three files, `@` - **expect** `@path @path ` in the agent's prompt, not sent; type
   *"explain what these do"*, `Enter`.
2. Ask: *"mark every file in the tree that imports <a module>"* - **expect** the tree to open its folders and mark
   them.
3. In the tree: `m` on a folder moves the marked there; the open buffers go along.
4. Ask: *"where is <a function> defined? show me"* - **expect** the tree on the file, or the code at the line, lit up.

## 3. Find, understand, rename

1. `<leader>ff` to a file, on a function call `gd` (or `Ctrl+Click`) - **expect** its definition.
2. `Ctrl+Click` on the definition - **expect** its usages (one only: straight there); `gr` the same as a list.
3. `K` on it (the docs), `<leader>rn` - a new name: **expect** every file changed, the unsaved ones marked.
4. `Ctrl+o` back where you came from, `<leader><Tab>` through the recent buffers.
5. Break something on purpose: `]d` / `[d` go to the diagnostics, `<leader>ca` offers a fix, `<leader>xx` lists all.

## 4. A run fails, the agent fixes it

1. In a Python file raise an error a few calls deep; `F6` - **expect** the output pane, the failing lines marked in the
   code.
2. `]q` / `[q` walk the traceback; `Enter` on an error line in the output jumps there.
3. `<leader>rf` - **expect** the agent to get the command, the output and the code places; let it fix it.
4. **Expect** its fix in your buffer for review (workflow 1); keep it, `<leader>rl` runs again - green.
5. `<leader>rw` (re-run on save), change something, `:w` - it runs; `<leader>rw` again stops that.

## 5. Debugging Python

1. A script with a loop and `input()`. `F9` on a line in the loop, `F5`.
2. **Expect** it to stop there, the variables' values next to the code; the input goes into the DAP console pane.
3. `F10` / `F11` / `F12` (over, into, out); `<leader>dh` on a variable shows its value.
4. `<leader>dB` - a condition like `i == 3` - `F5`: **expect** it to stop only then.
5. `<leader>dc` on a line further down (run to cursor); `<leader>dr` - evaluate something in the REPL.
6. `<leader>de` (stop on every raised exception), raise one inside a `try` - **expect** a stop there; `<S-F5>` ends it.

## 6. Tests: run, debug one

1. In a test file `<leader>rt` (all its tests), on one test `<leader>rT` - **expect** results per test, failures
   marked at their lines.
2. Make one fail, `<leader>dt` on it - **expect** the debugger in that test; step into the code under test (`F11`).

## 7. Java at work (Windows)

1. Open a G3 project class ([G3 development](../G3-DEVELOPMENT.md)) - **expect** jdtls on IntelliJ's JDK, no errors once
   the Maven import is done (the first one takes a while).
2. `gd` on a dependency's class (into the library), `Ctrl+Click` for usages, `<leader>fs` for the symbols.
3. `<leader>rt` on a TestNG class, `<leader>dt` on one test; `<leader>da` attaches to IntelliJ's Remote JVM Debug.
4. `<leader>fm` formats as IntelliJ would; ask the agent about the class (`<leader>aa`).

## 8. Git: from a change to a commit

1. Change a few lines in two files - the gutter shows them. `]c` to one, `<leader>gp` shows what it was.
2. `<leader>gs` stages one, `<leader>gr` undoes another (`u` brings it back).
3. `<leader>gv`: the review - `t` inline / side by side, `-` stages a file, `q` closes.
4. `<leader>gg`: commit in lazygit. `<leader>gh` - the file's history; `<leader>gb` - who changed this line.

## 9. Search and replace across the project

1. `<leader>fg` a word - **expect** the hits with a preview; `<leader>/` the same in the open buffers.
2. `<leader>sr` (or `<leader>sw` on a word): the replacement, then go through the files - **expect** only the hits to
   change. `u` in a file undoes it there.

## 10. Files: rename by regex, things follow

1. Bookmark a line (`<leader>mm`), pin the file to harpoon (`<leader>ha`).
2. `<leader>e`, `R` with `.*\.py$`, `Ctrl+a` marks the hits, `%` with `s/^/old_/` - **expect** the new names listed
   first, then renamed.
3. **Expect** `<leader>ml` and `<leader>hh` to name the renamed file, `Enter` / `<leader>1` to open it at the line.

## 11. Speech to text

1. On the machine with the microphone (the laptop, the Kali desktop - not over SSH): `:VoiceInstall` once (about
   200 MB; it checks itself on whisper.cpp's sample).
2. `<leader>av`, say *"where are the bookmarks saved?"*, `<leader>av` again - **expect** a box with the text after a
   moment; fix a word, `Enter`: the agent gets it.
3. `<leader>aV` in a markdown file: dictate a sentence - **expect** it at the cursor. `:VoiceCancel` drops a recording.
4. German: `GREYKNIGHT_STT_LANG=de` before starting Neovim (else whisper guesses). Nothing comes: `<leader>un` says why
   (no recorder, no microphone permission). See [speech to text](agent.md#speech-to-text).

## 12. Another project while the agent runs

1. Start Neovim in one folder, `<leader>tt`.
2. `<leader>e`, go to another project, `.` on it - **expect** a warning: the agent still works where it started; its
   statusline says `- in <that folder>`.
3. `<leader>ac` - **expect** it to start anew in the new folder (OpenCode asks for its mode again).

## 13. The look, a session, SSH

1. `:GreyKnightStyle greyknight`, then `oled` - **expect** the colors to switch at once (grey, then true black),
   and to stay so at the next start; `:CyberdreamToggleMode` for the light look.
2. Split a few windows, open files, quit; start in the same folder, `s` on the start screen - **expect** the same
   layout.
3. From PuTTY to kali ([PuTTY's settings](ssh.md#over-ssh-putty)): `Ctrl+arrows` resize, `Shift+F11` lists the
   bookmarks, `y` in Neovim and `Ctrl+V` on Windows - the clipboard comes across.
