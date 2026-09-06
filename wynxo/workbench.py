"""What Wynxo is doing, beside the conversation.

Three surfaces share this module because they answer one question — *what is
happening on my machine right now* — and because none of them needs Qt:

* :class:`TerminalSession` is the transcript every command writes into, whether
  Wynxo ran it or you typed it. It is append-only and bounded; a command that
  never stops talking cannot grow it without limit.
* :func:`build_tree` and :func:`read_preview` walk the workspace folder for the
  file browser. Every path is resolved and checked against the root, so a
  symlink out of the project is refused rather than followed.
* :func:`normalise_url` is the only way an address reaches the built-in
  browser. Nothing but ``http`` and ``https`` gets through, and a word that is
  not an address is rejected instead of being handed to a search engine — this
  application does not talk to services the user did not choose.
"""
from __future__ import annotations

import os
from pathlib import Path
from urllib.parse import urlsplit

from . import markdown as md

# ------------------------------------------------------------------ terminal
COMMAND, OUTPUT, EXIT, NOTE = "command", "output", "exit", "note"

# One command's output is capped where the tool caps it, so the panel and the
# model see the same text. The block count is what keeps a long session from
# growing without limit; the oldest blocks scroll out of history.
MAX_OUTPUT = 32000
MAX_BLOCKS = 600

AGENT, USER = "agent", "you"


def _clip(text: str, limit: int) -> tuple[str, bool]:
    return (text[:limit], True) if len(text) > limit else (text, False)


class TerminalSession:
    """An append-only transcript of commands and their output.

    Blocks are the unit of display: a command line, the output it produced, and
    the line that closes it. Output arrives in fragments, so the open output
    block is mutated in place rather than appended to the list — a list model
    can then repaint one row instead of rebuilding the view on every read.
    """

    def __init__(self):
        self.blocks: list[dict] = []
        self._command_index: int | None = None
        self._output_index: int | None = None

    # -------------------------------------------------------------- reading
    @property
    def running(self) -> bool:
        return self._command_index is not None

    @property
    def output_index(self) -> int | None:
        """Where :meth:`write` will put the next fragment, if a block is open."""
        return self._output_index

    @property
    def command_index(self) -> int | None:
        return self._command_index

    def transcript(self) -> str:
        lines = []
        for block in self.blocks:
            if block["kind"] == COMMAND:
                lines.append(f"$ {block['text']}")
            elif block["kind"] == OUTPUT:
                lines.append(block["text"].rstrip("\n"))
            else:
                lines.append(block["text"])
        return "\n".join(line for line in lines if line) + "\n" if lines else ""

    # -------------------------------------------------------------- writing
    def start(self, command: str, cwd: str = "", source: str = AGENT) -> dict:
        """Open a command block. Always appends exactly one block."""
        if self.running:
            # A previous command that never reported back would otherwise leave
            # a row spinning for the rest of the session.
            self.finish(error="Interrupted by the next command", status="stopped")
        block = {"kind": COMMAND, "text": str(command).strip(), "cwd": str(cwd),
                 "source": source if source in (AGENT, USER) else AGENT,
                 "status": "running", "code": 0, "ms": 0, "truncated": False}
        self.blocks.append(block)
        self._command_index = len(self.blocks) - 1
        self._output_index = None
        return block

    def open_output(self) -> dict:
        """Append an empty output block. Appends exactly one block."""
        block = {"kind": OUTPUT, "text": "", "cwd": "", "source": AGENT,
                 "status": "running", "code": 0, "ms": 0, "truncated": False}
        self.blocks.append(block)
        self._output_index = len(self.blocks) - 1
        return block

    def write(self, text: str) -> dict | None:
        """Add a fragment to the open output block, mutating it in place."""
        if self._output_index is None or not text:
            return None
        block = self.blocks[self._output_index]
        block["text"], clipped = _clip(block["text"] + str(text), MAX_OUTPUT)
        block["truncated"] = block["truncated"] or clipped
        return block

    def finish(self, code: int = 0, error: str = "", ms: int = 0, status: str = "") -> dict:
        """Close the open command with a result line. Appends exactly one block."""
        if not status:
            status = "ok" if not error and not code else "failed"
        detail = []
        if ms:
            detail.append(f"{ms / 1000:.1f}s" if ms >= 1000 else f"{int(ms)}ms")
        if error:
            summary = str(error).strip()
        elif code:
            summary = f"Exited with status {int(code)}"
        else:
            summary = "Done"
        block = {"kind": EXIT, "text": " · ".join([summary] + detail), "cwd": "",
                 "source": AGENT, "status": status, "code": int(code), "ms": int(ms),
                 "truncated": False}
        if self._command_index is not None:
            self.blocks[self._command_index]["status"] = status
            self.blocks[self._command_index]["ms"] = int(ms)
        self.blocks.append(block)
        self._command_index = None
        self._output_index = None
        return block

    def note(self, text: str, status: str = "note") -> dict:
        """Append a line that is not a command — an app launch, a page opened."""
        block = {"kind": NOTE, "text": str(text), "cwd": "", "source": AGENT,
                 "status": status, "code": 0, "ms": 0, "truncated": False}
        self.blocks.append(block)
        return block

    def overflow(self) -> int:
        """How many blocks at the front are over the limit and can be dropped."""
        return max(0, len(self.blocks) - MAX_BLOCKS)

    def drop_front(self, count: int) -> None:
        count = max(0, min(int(count), len(self.blocks)))
        if not count:
            return
        del self.blocks[:count]
        if self._command_index is not None:
            self._command_index = max(0, self._command_index - count)
        if self._output_index is not None:
            self._output_index = max(0, self._output_index - count)

    def clear(self) -> None:
        self.blocks.clear()
        self._command_index = None
        self._output_index = None


# --------------------------------------------------------------------- files
# Folders that are always noise in a file browser: caches, build output and
# dependency trees nobody opens by hand.
IGNORED = {
    ".git", ".hg", ".svn", "node_modules", "__pycache__", ".venv", "venv", "env",
    ".mypy_cache", ".pytest_cache", ".ruff_cache", ".tox", ".cache", ".idea",
    ".gradle", "target", "dist", "build", ".next", ".parcel-cache", ".DS_Store",
}
MAX_ENTRIES = 400
MAX_ROWS = 3000
PREVIEW_BYTES = 256 * 1024


class WorkspaceError(RuntimeError):
    """A path could not be read, or is outside the workspace."""


def human_size(count: int) -> str:
    size = float(count)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" or size >= 10 else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} GB"


def resolve_root(path: str | Path | None) -> Path:
    """The folder the browser is rooted at: the project, or your home folder."""
    candidate = Path(path).expanduser() if path else Path.home()
    try:
        candidate = candidate.resolve()
    except OSError:
        return Path.home()
    return candidate if candidate.is_dir() else Path.home()


def inside(root: Path, target: Path) -> bool:
    """Whether ``target`` really lives under ``root`` once symlinks are followed."""
    try:
        return os.path.commonpath([root.resolve(), target.resolve()]) == str(root.resolve())
    except (OSError, ValueError):
        return False


def language_for(path: str | Path) -> str:
    """The highlighter's name for this file, or "" for plain text."""
    name = Path(path).name
    suffix = Path(name).suffix.lstrip(".").lower()
    if not suffix:
        # Dotfiles and toolchain files carry their language in the name.
        stem = name.lower().lstrip(".")
        return md.normalise_language({"bashrc": "shell", "zshrc": "shell",
                                      "profile": "shell", "makefile": "shell",
                                      "dockerfile": "shell"}.get(stem, ""))
    return md.normalise_language(suffix)


def list_dir(directory: str | Path, show_hidden: bool = False,
             limit: int = MAX_ENTRIES) -> list[dict]:
    """One folder's children: folders first, then files, both by name."""
    target = Path(directory)
    try:
        with os.scandir(target) as scan:
            found = list(scan)
    except OSError as exc:
        raise WorkspaceError(f"Could not read {target.name or target}: "
                             f"{getattr(exc, 'strerror', None) or exc}") from exc
    entries = []
    for entry in found:
        if entry.name in IGNORED or (not show_hidden and entry.name.startswith(".")):
            continue
        try:
            is_dir = entry.is_dir(follow_symlinks=False)
            size = 0 if is_dir else entry.stat(follow_symlinks=False).st_size
        except OSError:
            continue
        entries.append({"name": entry.name, "path": str(target / entry.name),
                        "dir": is_dir, "size": size})
    entries.sort(key=lambda item: (not item["dir"], item["name"].casefold()))
    return entries[:limit]


def build_tree(root: str | Path, expanded=(), show_hidden: bool = False,
               limit: int = MAX_ROWS) -> list[dict]:
    """A flattened tree: only folders you opened are walked into.

    Rows carry their depth so the view can indent them without nesting models,
    and their POSIX-relative path so expansion survives a refresh.
    """
    base = Path(root)
    opened = {str(item) for item in expanded}
    rows: list[dict] = []

    def walk(directory: Path, prefix: str, depth: int) -> None:
        if len(rows) >= limit or depth > 12:
            return
        try:
            children = list_dir(directory, show_hidden)
        except WorkspaceError:
            return
        for child in children:
            if len(rows) >= limit:
                return
            relative = f"{prefix}/{child['name']}" if prefix else child["name"]
            is_open = child["dir"] and relative in opened
            rows.append({
                "name": child["name"], "path": child["path"], "rel": relative,
                "dir": child["dir"], "depth": depth, "expanded": is_open,
                "subtitle": "" if child["dir"] else human_size(child["size"]),
            })
            if is_open:
                walk(Path(child["path"]), relative, depth + 1)

    walk(base, "", 0)
    return rows


def read_preview(path: str | Path, root: str | Path | None = None) -> dict:
    """A file's text for the preview pane, or an honest reason there is none."""
    target = Path(path).expanduser()
    blank = {"ok": False, "name": target.name, "path": str(target), "text": "",
             "language": "", "lines": 0, "bytes": 0, "truncated": False,
             "binary": False, "image": False, "subtitle": "", "error": ""}
    if root is not None and not inside(Path(root), target):
        return {**blank, "error": "That file is outside the workspace folder."}
    try:
        size = target.stat().st_size
    except OSError as exc:
        return {**blank, "error": f"Could not read {target.name}: "
                                  f"{getattr(exc, 'strerror', None) or exc}"}
    if target.is_dir():
        return {**blank, "error": "That is a folder."}
    blank["bytes"] = size
    from . import context as ctx  # Imported here to keep this module Qt-free at import time.
    if ctx.is_image_path(target):
        return {**blank, "ok": True, "image": True,
                "subtitle": " · ".join(filter(None, ("Image", human_size(size))))}
    try:
        with open(target, "rb") as handle:
            data = handle.read(PREVIEW_BYTES + 1)
    except OSError as exc:
        return {**blank, "error": f"Could not read {target.name}: "
                                  f"{getattr(exc, 'strerror', None) or exc}"}
    if b"\x00" in data[:8192]:
        return {**blank, "binary": True,
                "subtitle": human_size(size),
                "error": f"{target.name} is a binary file, so there is nothing to show."}
    truncated = len(data) > PREVIEW_BYTES
    text = data[:PREVIEW_BYTES].decode("utf-8", errors="replace")
    if truncated:
        # Never cut a line in half; the last one is almost certainly partial.
        text = text[:text.rfind("\n") + 1] if "\n" in text else text
    lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
    detail = [f"{lines} lines" if lines != 1 else "1 line", human_size(size)]
    if truncated:
        detail.append("first " + human_size(PREVIEW_BYTES))
    return {**blank, "ok": True, "text": text, "language": language_for(target),
            "lines": lines, "truncated": truncated, "subtitle": " · ".join(detail)}


# ------------------------------------------------------------------- browser
def normalise_url(text: str) -> str:
    """Turn what a person or a model typed into an address, or refuse it.

    Only ``http`` and ``https`` are accepted: ``file:`` would let a page read
    the user's disk, and ``javascript:`` and ``data:`` are script injection with
    a friendlier syntax. A word that is not an address is an error rather than a
    search — this application does not send what you typed to a search engine.
    """
    raw = " ".join(str(text or "").split())
    if not raw:
        return ""
    if len(raw) > 2048:
        raise ValueError("That address is too long")
    if "://" in raw or raw.split(":", 1)[0].lower() in ("javascript", "data", "file", "about", "blob"):
        parsed = urlsplit(raw)
        if parsed.scheme.lower() not in ("http", "https"):
            raise ValueError("The built-in browser opens http and https pages only")
        if not parsed.netloc:
            raise ValueError("That address is missing a site name")
        return raw
    host = raw.split("/", 1)[0].split(":", 1)[0]
    if " " in raw or ("." not in host and host.lower() != "localhost"):
        raise ValueError("Enter a web address, such as example.com")
    return "https://" + raw


def url_label(url: str) -> str:
    """The site name, for a tab title or an activity row."""
    try:
        host = urlsplit(str(url)).netloc
    except ValueError:
        return ""
    return host[4:] if host.lower().startswith("www.") else host
