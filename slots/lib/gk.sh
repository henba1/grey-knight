# Helpers for GreyKnight's explorer script slots in bash - the context and Neovim's dialogs (USAGE.md, Script slots)
#
#   source "$GK_LIB/gk.sh"
#   mapfile -t files < <(gk_marked)                 # the marked items, one per line
#   [ ${#files[@]} -eq 0 ] && files=("$GK_CURSOR")  # else the one under the cursor
#   if gk_confirm "Delete ${#files[@]} files?"; then ...; fi
#   name=$(gk_ask "New name:" "notes.md")           # empty when the dialog was closed
#   color=$(gk_choose "Color:" red green)
#
# Each question is a line on stdout (::gk::...), the answer a line on stdin (lua/config/slots.lua).

gk_marked() { [ -n "$GK_MARKED" ] && [ -s "$GK_MARKED" ] && grep -v '^$' "$GK_MARKED"; return 0; }

# Requests go to the script's own output, also from inside $( ... ), whose output the caller captures - a question
# asked there went into the variable, and the script waited for an answer to a question no one saw: the output it
# had when this file was sourced, kept on a free descriptor
exec {_GK_OUT}>&1
_gk_send() { printf '::gk::%s::%s\n' "$1" "${2//$'\n'/ }" >&"$_GK_OUT"; }

_gk_answer() {
  _gk_send "$1" "$2"
  local answer=""
  IFS= read -r answer
  printf '%s' "${answer%$'\r'}"
}

# Yes / No in Neovim: the exit status says yes (0) or no (1)
gk_confirm() { local a; a=$(_gk_answer confirm "$*"); [[ "${a,,}" == y* ]]; }

# A text box: prints the text (nothing when the dialog was closed); $2 fills it
gk_ask() { [ -n "$2" ] && _gk_send default "$2"; _gk_answer input "$1"; }

# A choice of the arguments after the prompt: prints the option (nothing when closed)
gk_choose() {
  local prompt="$1" option
  shift
  for option in "$@"; do _gk_send option "$option"; done
  _gk_answer select "$prompt"
}

gk_notify() { _gk_send notify "$*"; }
gk_warn() { _gk_send warn "$*"; }
gk_error() { _gk_send error "$*"; }

# The file in Neovim's code window; $2: the line
gk_open() { _gk_send open "$1${2:+:$2}"; }

gk_refresh() { _gk_send refresh ""; }
