# GreyKnight - Remote: over SSH, PuTTY, the clipboard, the dashboard's Dev Environment

> Working on a machine over SSH - from PuTTY or Windows Terminal - and inside the project dashboard's browser terminal.
> [All topics](README.md) · every key on one page: [CHEATSHEET](../CHEATSHEET.md) · Leader = `Space`

**In this file:** [Over SSH (PuTTY)](#over-ssh-putty) · [Copy to System Clipboard](#copy-to-system-clipboard) · [Inside the AI Dashboard (web)](#inside-the-ai-dashboard-web)

## Over SSH (PuTTY)
PuTTY's default keyboard settings send some keys so that Neovim cannot tell them from others: **Ctrl+arrows come as
plain arrows**, Shift+F11 and Ctrl+F11 as `F11` (step into), Shift+F5 as another F-key, Home and End as the old
VT220 keys Find and Select (those work anyway now). Three settings fix it - in PuTTY: *Change Settings*, then *Save*
the session (or *Default Settings* for new ones):

| Where in PuTTY | Setting |
|---|---|
| Terminal → Keyboard → Shift/Ctrl/Alt with the arrow keys | **xterm-style bitmap** |
| Terminal → Keyboard → The Function keys and keypad | **Xterm 216+** |
| Connection → Data → Terminal-type string | **xterm-256color** |

| Key | PuTTY's defaults | With the settings |
|---|---|---|
| `Ctrl+arrows` (resize) | plain arrows - use `Alt+arrows` | work |
| `Shift+F5` (stop debugging) | another F-key - use `<leader>dq` | work |
| `Shift+F11` / `Ctrl+F11` (bookmarks) | `F11`, step into - use `<leader>ml` / `<leader>mr` | work |
| `Home` / `End` | work | work |
| `Alt` keys (`Alt+r`, `Alt+s`), `Ctrl+Space` | work | work |

GreyKnight says so once on a machine when a session looks like PuTTY's defaults (over SSH, terminal type `xterm`).
Most terminals send Shift and Ctrl with an F-key as xterm does, and Neovim names those keys as terminfo does:
Shift+F5 `<F17>`, Shift+F11 `<F23>`, Ctrl+F11 `<F35>` - both names are mapped. PuTTY cannot take a copy over
OSC 52: a yank stays in Neovim (`p` pastes it there); to copy out select with the mouse while holding Shift (PuTTY
copies what you select), and paste with right-click. Windows Terminal with the `ssh` of Windows 10/11 sends every
key as itself out of the box and takes OSC 52 copies.

---

## Copy to System Clipboard
Yank and paste use the system clipboard (`unnamedplus`). On your own machine Neovim picks the tool itself
(wl-clipboard, xclip / xsel, the Windows clipboard). Over SSH a yank goes to the clipboard of the computer in
front of you via OSC 52, and `p` pastes the last yank made in nvim - text copied on that computer comes in with
the terminal's paste (`Ctrl+Shift+V` / right-click). Reading the clipboard over OSC 52 works in few terminals; in
the others (Windows Terminal) every `p` used to wait 10 seconds.

---

## Inside the AI Dashboard (web)

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
