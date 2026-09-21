# Grey Knight Neovim — Cheatsheet

> Leader = `Space` | Open this: `nvim ~/.config/nvim/CHEATSHEET.md`

## AI (Qwen Code) — `<leader>a`

| Key | Mode | Action |
|-----|------|--------|
| `<leader>tt` | n | Toggle AI agent (vertical 50/50) |
| `<leader>tf` | n | Floating AI agent |
| `<leader>th` | n | Horizontal AI agent |
| `<leader>tv` | n | Vertical AI agent |
| `<leader>t1/t2/t3` | n | Named agents #1/#2/#3 |
| `<leader>ac` | n | New AI session |
| `<leader>aa` | n/v | Ask AI (about file / selection) |
| `<leader>ae` | v | AI edit selection |

> The agent runs the local **Qwen Code** CLI in a persistent terminal. It inherits the
> project's cwd and any `QWEN.md`/`AGENTS.md` context automatically. `aa`/`ae` prepend the
> current file / selection to the prompt. `tt` is a true toggle — the agent process stays
> alive when hidden, so re-opening re-attaches the same session. Inside the agent: type
> normally; `Esc Esc` exits terminal mode back to the editor.

## File Explorer — `<leader>e`

The filesystem tree (snacks explorer). Focus moves with `<C-h>`/`<C-l>`; all ops run in the
explorer pane once focused.

| Key | Action |
|-----|--------|
| `h`/`<BS>` | Up one directory |
| `l`/`Enter` | Open file / toggle folder |
| `.` | Jump to current file's dir |
| `H`/`I` | Toggle hidden / ignored |
| `a` | New file or dir (trailing `/` = dir) |
| `r` | Rename |
| `d` | Delete (system trash; permanent fallback) |
| `c` | Copy selected → current dir |
| `m` | Move selected → current dir |
| `y`/`p` | Yank / paste paths |
| `Z` | Collapse all folders |
| `u` | Refresh tree |
| `]g`/`[g` | Next / prev git-changed |

> Changing the root: `:cd /path` then `<leader>e` (it anchors to nvim's cwd).

## Find (Snacks Picker) — `<leader>f`

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fc` | Commands |
| `<leader>fs` | LSP symbols |
| `<leader>fd` | Diagnostics |
| `<leader>fk` | Keymaps |
| `<leader>/` | Grep open buffers |
| `<leader>f:` | Command history |

## File Navigation

| Key | Action |
|-----|--------|
| `<leader>e` | File explorer (snacks) |
| `-` | Oil (edit fs as buffer) |
| `<leader>o` | Oil float |
| `s` | Flash jump |
| `S` | Flash treesitter select |
| `<leader>1-4` | Harpoon files 1-4 |
| `<leader>ha` | Harpoon add file |
| `<leader>hh` | Harpoon menu |

## Git — `<leader>g`

| Key | Action |
|-----|--------|
| `<leader>gg` | Lazygit |
| `<leader>gl` | Git log |
| `<leader>gd` | Diffview |
| `<leader>gh` | File history |

## Terminal — `<leader>t`

Shell terminals (the `<leader>t*` agent keys above launch Qwen Code, not a shell).

| Key | Action |
|-----|--------|
| `<leader>ts` | Send selection → shell term #2 (visual) |
| `<leader>tl` | Send line → shell term #2 |

## Trouble / Diagnostics — `<leader>x`

| Key | Action |
|-----|--------|
| `<leader>xx` | All diagnostics |
| `<leader>xX` | Buffer diagnostics |
| `<leader>xl` | Location list |
| `<leader>xq` | Quickfix list |

## LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | References |
| `gi` | Implementation |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>D` | Type definition |
| `[d` / `]d` | Prev/next diagnostic |
| `<leader>fm` | Format buffer |

## Debug (DAP) — `<leader>d`

| Key | Action |
|-----|--------|
| `<F5>` | Continue |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dr` | DAP REPL |
| `<leader>du` | Toggle DAP UI |

## Hacker Specials

| Key | Action |
|-----|--------|
| `<leader>hx` | Hex toggle (binary view) |
| `<leader>sr` | Search & replace (grug-far) |
| `<leader>sw` | S&R current word |

## Session — `<leader>p`

| Key | Action |
|-----|--------|
| `<leader>ps` | Save session |
| `<leader>pl` | Load session (cwd) |
| `<leader>pd` | Delete session |

## Editing

| Key | Mode | Action |
|-----|------|--------|
| `sa`/`sd`/`sr` | n | Surround add/delete/replace |
| `J`/`K` | v | Move selection down/up |
| `<leader>p` | x | Paste without yank |
| `<leader>d` | n/v | Delete to void register |
| `<leader>bd` | n | Delete buffer |

## Windows / Buffers

| Key | Action |
|-----|--------|
| `<C-h/j/k/l>` | Navigate windows (also from terminal) |
| `<C-Up/Down/Left/Right>` | Resize windows |
| `<S-h>` / `<S-l>` | Prev/next buffer |

## Config Structure

```
~/.config/nvim/
├── init.lua                  ← entry point (4 lines)
├── CHEATSHEET.md             ← this file
├── lua/config/
│   ├── options.lua           ← vim opts + language toggles
│   ├── lazy.lua              ← lazy.nvim bootstrap
│   ├── keymaps.lua           ← global keymaps
│   └── autocmds.lua          ← autocommands
└── lua/plugins/
    ├── ai.lua                ← Qwen Code agent (toggleterm)
    ├── colorscheme.lua       ← Cyberdream
    ├── completion.lua         ← blink.cmp
    ├── editor.lua            ← flash, harpoon, oil, mini, trouble, etc
    ├── hacker.lua            ← hex, toggleterm, DAP
    ├── lsp.lua               ← LSP, Mason, Treesitter, conform
    ├── session.lua           ← persisted.nvim
    └── snacks.lua            ← picker, explorer, dashboard, notify
```

## Docs
| `<leader>gd` | Read GreyNight docs (README, CHEATSHEET, USAGE) — readonly, `q` to close |
