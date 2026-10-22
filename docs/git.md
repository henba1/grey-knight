# GreyKnight - Git

> Lazygit, codediff (VS Code's diff) for reviews, gitsigns in the files.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

## Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open Lazygit (full git TUI) |
| `<leader>gl` | Git log |
| `<leader>gv` | Review the changes - VS Code's diff (codediff), live: what an agent writes shows up as it lands |
| `<leader>gh` | File history (all commits for current file) |

### Reviewing changes (codediff)

`<leader>gv` opens **codediff** - VS Code's diff in Neovim (its algorithm, in a native library): a tab with the
changed files on the left (`Changes`, `Staged Changes`) and the selected file side by side, the old side red and the
new side green, the changed words within a line in a stronger shade - like a pull request on GitHub. It stays in step
with the disk: let an agent work and watch its changes land.

| Key (in the review) | Action |
|---------------------|--------|
| `Enter` (list) | Show that file's diff |
| `]c` / `[c` · `]f` / `[f` | Next / previous change · file |
| `t` | Side by side / inline (one window, the old lines above the new) |
| `-` | Stage / unstage the file |
| `<leader>gs` / `<leader>gu` / `<leader>gr` | Stage / unstage / discard the change at the cursor (as `<leader>gs` / `<leader>gr` in a file) |
| `gc` | Fold the unchanged lines (compact) |
| `g?` | All its keys |
| `q` | Close it |

`:CodeDiff main` compares with a branch, `:CodeDiff --staged` the staged changes, `:CodeDiff pr 12` a merge request
(GitLab too, without its CLI), `:CodeDiff history` the commits. The library is downloaded once, on the first use. Where
that download does not work (a company's download filter refused it on the work laptop) `<leader>gv` / `<leader>gh`
open **Diffview** instead - it says so once - with the same colors: the old side as deletions (red).

### Gitsigns (Gutter)

When editing files in a git repo, you'll see markers in the left gutter:
- **Green bar** — added lines
- **Blue bar** — changed lines  
- **Red triangle** — deleted lines

And keys for those changes (in files of a git repository):

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next / previous change (in a diff - codediff, the agent's, Diffview: the next / previous difference) |
| `<leader>gs` | Stage the change at the cursor - on a staged one: unstage it. Visual: stage the selected lines |
| `<leader>gr` | Undo the change at the cursor (back to what git has; `u` brings it back). Visual: the selected lines |
| `<leader>gp` | Show the change in a popup: what the lines were |
| `<leader>gb` | Who changed the line, when, and the commit (blame) |

Committing stays with Lazygit (`<leader>gg`): stage what belongs together with `<leader>gs` while you look at it, then
commit there.
