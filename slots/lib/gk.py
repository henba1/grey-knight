"""Helpers for GreyKnight's explorer script slots - the context and Neovim's dialogs (USAGE.md, Script slots).

    import gk
    for path in gk.marked() or [gk.cursor()]:     # the marked items, else the one under the cursor
        print(path)
    if gk.confirm(f"Delete {len(gk.marked())} files?"):
        ...
    name = gk.ask("New name:", default="notes.md")  # None when the dialog was closed
    color = gk.choose("Color:", ["red", "green"])   # None when the dialog was closed

Each question is a line on stdout (::gk::...), the answer a line on stdin (lua/config/slots.lua).
"""
import io
import os
import sys

__all__ = ["cursor", "marked", "folder", "root", "confirm", "ask", "choose", "notify", "warn", "error", "open", "refresh"]


def cursor():
    """The item under the cursor."""
    return os.environ.get("GK_CURSOR", "")


def marked():
    """The marked items, in the order they were marked (empty when nothing is marked)."""
    listing = os.environ.get("GK_MARKED")
    if not listing:
        return list(sys.argv[1:])
    with io.open(listing, encoding="utf-8") as f:  # io.open: open() below is the request to Neovim
        return [line.rstrip("\r\n") for line in f if line.strip()]


def folder():
    """The folder the cursor is in (its item, on a folder)."""
    return os.environ.get("GK_DIR", os.getcwd())


def root():
    """The tree's root - the working directory of the run."""
    return os.environ.get("GK_ROOT", os.getcwd())


def _send(kind, text=""):
    sys.stdout.write("::gk::%s::%s\n" % (kind, str(text).replace("\r", " ").replace("\n", " ")))
    sys.stdout.flush()


def _answer(kind, text):
    _send(kind, text)
    line = sys.stdin.readline()
    return line.rstrip("\r\n") if line else ""


def confirm(question):
    """A Yes / No dialog in Neovim; True for Yes."""
    return _answer("confirm", question).strip().lower().startswith("y")


def ask(prompt, default=""):
    """A text box in Neovim; the text, or None when the dialog was closed without an answer."""
    if default:
        _send("default", default)
    answer = _answer("input", prompt)
    return answer if answer != "" else None


def choose(prompt, options):
    """A choice in Neovim; the option, or None when the dialog was closed."""
    options = [str(o) for o in options]
    for option in options:
        _send("option", option)
    answer = _answer("select", prompt)
    return answer if answer in options else None


def notify(message):
    """A notification in Neovim."""
    _send("notify", message)


def warn(message):
    _send("warn", message)


def error(message):
    _send("error", message)


def open(path, line=None):  # noqa: A001 - the name a script reads best
    """The file in Neovim's code window (a relative path: from the tree's root)."""
    _send("open", "%s:%d" % (path, line) if line else path)


def refresh():
    """The tree read again now (it is after every run anyway)."""
    _send("refresh")
