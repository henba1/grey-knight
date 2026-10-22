# GreyKnight - Finding: pickers, search and replace, jumps

> Fuzzy pickers for files, words, symbols; search and replace across the project; jumps with flash.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [Fuzzy Finder (Snacks Picker)](#fuzzy-finder-snacks-picker) · [Search & Replace](#search-replace) · [Flash (Jump Navigation)](#flash-jump-navigation)

## Fuzzy Finder (Snacks Picker)

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

## Flash (Jump Navigation)

| Key | Mode | Action |
|-----|------|--------|
| `s` | n/v | Flash jump — type 2 chars, jump to match |
| `S` | n/v | Flash treesitter — select by syntax node |
| `r` | o | Remote flash (operator-pending) |
| `R` | o/v | Treesitter search |

**Example:** Press `s`, type `de` → all occurrences of "de" get labels, press the label to jump there.
