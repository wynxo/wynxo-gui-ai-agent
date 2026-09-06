#!/usr/bin/env python3
"""Install an isolated, removable Wynxo copy without administrator privileges."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid
import venv

APP_ID = "io.github.wynxo.Wynxo"
MARKER = ".wynxo-install.json"
MANIFEST = "manifest.json"


def absolute(value: str | Path) -> Path:
    path = Path(os.path.abspath(os.path.expanduser(str(value))))
    if any(ord(char) < 32 for char in str(path)):
        raise ValueError("Installation paths cannot contain control characters.")
    return path


def xdg_path(variable: str, fallback: str) -> Path:
    value = os.environ.get(variable, "")
    return absolute(value if value and Path(value).is_absolute() else Path.home() / fallback)


def default_root() -> Path:
    return xdg_path("XDG_DATA_HOME", ".local/share") / "wynxo-app"


def exists(path: Path) -> bool:
    return os.path.lexists(path)


def owned_root(root: Path) -> dict:
    marker = root / MARKER
    if root.is_symlink() or not root.is_dir() or marker.is_symlink() or not marker.is_file():
        raise ValueError(f"Refusing to modify an unowned installation path: {root}")
    try:
        content = json.loads(marker.read_text())
    except (OSError, ValueError) as exc:
        raise ValueError(f"Invalid Wynxo ownership marker: {marker}") from exc
    if content.get("app") != APP_ID or content.get("uid") != os.getuid():
        raise ValueError(f"Installation is not owned by this user: {root}")
    return content


@contextmanager
def install_lock(root: Path):
    lock = root / ".install.lock"
    try:
        fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError as exc:
        raise ValueError(f"Another operation may be running. Lock: {lock}") from exc
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(str(os.getpid()))
        yield
    finally:
        lock.unlink(missing_ok=True)


def atomic_write(path: Path, data: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".wynxo-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def atomic_link(path: Path, target: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent / f".wynxo-{uuid.uuid4().hex}"
    try:
        temporary.symlink_to(target)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def fingerprint(path: Path) -> dict | None:
    if path.is_symlink():
        return {"kind": "symlink", "target": os.readlink(path)}
    if path.is_file():
        return {"kind": "file", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    if exists(path):
        return {"kind": "other"}
    return None


def read_manifest(root: Path) -> dict:
    path = root / MANIFEST
    if not exists(path):
        return {"files": {}, "releases": []}
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Unsafe install manifest: {path}")
    result = json.loads(path.read_text())
    if not isinstance(result.get("files"), dict) or not isinstance(result.get("releases"), list):
        raise ValueError("Invalid install manifest.")
    return result


def points_into(path: Path, root: Path) -> bool:
    """Is this a link Wynxo made into its own installation?

    A symlink into ``root`` cannot belong to another application: nothing else
    installs into Wynxo's directory. This is what lets a launcher be reclaimed
    after its manifest has gone, without weakening the check for a real file
    that somebody else owns.
    """
    if not path.is_symlink():
        return False
    target = Path(os.readlink(path))
    if not target.is_absolute():
        target = path.parent / target
    return root == target or root in absolute(target).parents


def check_managed(path: Path, old: dict, root: Path | None = None) -> None:
    actual = fingerprint(path)
    expected = old.get("files", {}).get(str(path))
    if actual is None or (expected is not None and actual == expected):
        return
    # Losing the install root strands the launcher: the manifest that proved
    # it was ours went with it. Refusing forever leaves no way forward, and
    # the uninstaller has nothing to remove either, so adopt what is provably
    # Wynxo's own rather than deadlocking the user out of their own app.
    if points_into(path, root) if root is not None else False:
        return
    raise ValueError(
        f"Refusing to overwrite a file Wynxo does not recognise: {path}\n"
        f"If it is left over from an older Wynxo, remove it and install again.")


def _snapshot(paths: list[Path]) -> dict:
    snapshots = {}
    for path in paths:
        if path.is_symlink():
            snapshots[path] = ("link", os.readlink(path))
        elif path.is_file():
            snapshots[path] = ("file", path.read_bytes(), path.stat().st_mode & 0o777)
        elif exists(path):
            raise ValueError(f"Expected a file or symlink: {path}")
        else:
            snapshots[path] = None
    return snapshots


def _restore(snapshots: dict) -> None:
    for path, state in reversed(list(snapshots.items())):
        if state is None:
            path.unlink(missing_ok=True)
        elif state[0] == "link":
            atomic_link(path, state[1])
        else:
            atomic_write(path, state[1], state[2])


def _copy_source(source: Path, destination: Path) -> None:
    destination.mkdir()
    for name in ("pyproject.toml", "README.md", "LICENSE", "install.py", "uninstall.py"):
        shutil.copy2(source / name, destination / name)
    for name in ("wynxo", "assets"):
        shutil.copytree(source / name, destination / name, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))


def _build_environment(release: Path) -> None:
    environment = release / "venv"
    print("Creating an isolated Python environment…", flush=True)
    try:
        venv.EnvBuilder(with_pip=True).create(environment)
    except Exception as exc:
        raise RuntimeError("Python venv support is required. On Debian/Ubuntu: sudo apt install python3-venv") from exc
    python = environment / "bin/python"
    print("Installing Wynxo and its GUI dependencies (first install may take a few minutes)…", flush=True)
    subprocess.run([str(python), "-m", "pip", "install", "--disable-pip-version-check", str(release / "source")], check=True)
    subprocess.run([str(python), "-c", "import wynxo, PySide6, httpx, dbus_next, PIL, Xlib"], check=True)


def desktop_argument(value: Path) -> str:
    # Escape both the Desktop Entry string layer and its Exec argument layer.
    argument = str(value).replace("%", "%%")
    for old, new in (("\\", "\\\\"), ('"', '\\"'), ("`", "\\`"), ("$", "\\$")):
        argument = argument.replace(old, new)
    return '"' + argument.replace("\\", "\\\\") + '"'


def install(source: Path, root: Path | None = None, bin_dir: Path | None = None) -> Path:
    source = absolute(source)
    root = absolute(root or default_root())
    bin_dir = absolute(bin_dir or Path.home() / ".local/bin")
    data = xdg_path("XDG_DATA_HOME", ".local/share")
    desktop = data / "applications" / f"{APP_ID}.desktop"
    icon = data / "icons/hicolor/scalable/apps" / f"{APP_ID}.svg"
    launcher_link = bin_dir / "wynxo"
    if not (source / "wynxo/__main__.py").is_file():
        raise ValueError("Run this installer from a complete Wynxo checkout.")
    if root == source or root in source.parents or source in root.parents:
        raise ValueError("Install directory must be outside the source checkout.")
    if bin_dir == root or root in bin_dir.parents:
        raise ValueError("Launcher directory must be outside the installation directory.")
    fresh = not exists(root)
    if fresh:
        root.mkdir(parents=True)
        atomic_write(root / MARKER, json.dumps({"app": APP_ID, "uid": os.getuid(), "format": 1}).encode())
    owned_root(root)
    release = None
    try:
        with install_lock(root):
            old = read_manifest(root)
            internal = [root / "wynxo", root / "uninstall.py", root / "current"]
            external = [launcher_link, desktop, icon]
            for path in internal + external:
                check_managed(path, old, root)
            # Changing install destinations should never strand launchers from a prior install.
            previous_external = set(old.get("external", []))
            if previous_external and previous_external != {str(p) for p in external}:
                raise ValueError("Install destinations changed; uninstall the existing copy first (your data is kept).")
            releases = root / "releases"
            if releases.is_symlink() or (exists(releases) and not releases.is_dir()):
                raise ValueError(f"Unsafe releases directory: {releases}")
            releases.mkdir(exist_ok=True)
            release_id = uuid.uuid4().hex
            release = releases / release_id
            release.mkdir()
            atomic_write(release / ".wynxo-release", APP_ID.encode())
            _copy_source(source, release / "source")
            _build_environment(release)
            snapshots = _snapshot(internal + external + [root / MANIFEST])
            try:
                launcher = (
                    "#!/bin/sh\nset -eu\n"
                    f"export WYNXO_INSTALL_ROOT={shlex.quote(str(root))}\n"
                    'if [ "${1-}" = "--uninstall" ]; then\n'
                    '  shift\n'
                    '  exec "$WYNXO_INSTALL_ROOT/current/venv/bin/python" "$WYNXO_INSTALL_ROOT/uninstall.py" --install-root "$WYNXO_INSTALL_ROOT" "$@"\n'
                    'fi\n'
                    'exec "$WYNXO_INSTALL_ROOT/current/venv/bin/python" -m wynxo "$@"\n'
                )
                atomic_write(root / "wynxo", launcher.encode(), 0o755)
                atomic_link(root / "uninstall.py", "current/source/uninstall.py")
                atomic_link(root / "current", f"releases/{release_id}")
                atomic_link(launcher_link, str(root / "wynxo"))
                atomic_write(icon, (source / "assets/wynxo.svg").read_bytes())
                # The QuickBar action gives desktops something to bind a
                # custom keyboard shortcut to, since Linux has no portable
                # way for an application to claim a global hotkey itself.
                entry = (
                    "[Desktop Entry]\nType=Application\nVersion=1.0\nName=Wynxo\n"
                    "Comment=Your local AI workbench\n"
                    f"Exec={desktop_argument(root / 'wynxo')}\n"
                    f"Icon={str(icon).replace(chr(92), chr(92) * 2)}\n"
                    "Terminal=false\nCategories=Utility;Development;\nKeywords=AI;Ollama;Assistant;Copilot;\n"
                    "StartupWMClass=wynxo\n"
                    "Actions=QuickBar;NewChat;\n"
                    "\n[Desktop Action QuickBar]\nName=Quick bar\n"
                    f"Exec={desktop_argument(root / 'wynxo')} --quick\n"
                    "\n[Desktop Action NewChat]\nName=New chat\n"
                    f"Exec={desktop_argument(root / 'wynxo')}\n"
                )
                atomic_write(desktop, entry.encode())
                manifest = {
                    "files": {str(path): fingerprint(path) for path in internal + external},
                    "external": [str(path) for path in external],
                    "releases": old.get("releases", []) + [release_id],
                    "data_dirs": old.get("data_dirs", [
                        str(data / "wynxo"), str(xdg_path("XDG_CONFIG_HOME", ".config") / "wynxo"),
                        str(xdg_path("XDG_CACHE_HOME", ".cache") / "wynxo"),
                    ]),
                }
                atomic_write(root / MANIFEST, json.dumps(manifest, indent=2).encode())
            except BaseException:
                _restore(snapshots)
                raise
    except BaseException:
        if release is not None and release.is_dir() and not release.is_symlink():
            shutil.rmtree(release)
        if fresh:
            owned_root(root)
            shutil.rmtree(root)
        raise
    # Old releases are retained so upgrades never remove files used by a running app.
    return launcher_link


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-root", type=Path, default=default_root(), help="App directory (default: XDG_DATA_HOME/wynxo-app)")
    parser.add_argument("--bin-dir", type=Path, default=Path.home() / ".local/bin", help="Launcher directory (default: ~/.local/bin)")
    args = parser.parse_args(argv)
    if sys.platform != "linux":
        parser.error("Wynxo currently supports Linux.")
    if sys.version_info < (3, 10):
        parser.error("Python 3.10 or newer is required.")
    if os.geteuid() == 0:
        parser.error("Run this installer as your normal user, without sudo.")
    try:
        launcher = install(Path(__file__).resolve().parent, args.install_root, args.bin_dir)
    except (Exception, KeyboardInterrupt) as exc:
        print(f"\nInstall failed; previous installation preserved.\n{exc}", file=sys.stderr)
        return 1
    print(f"\nWynxo installed. Open Wynxo from your application menu or run:\n  {shlex.quote(str(launcher))}")
    if str(launcher.parent) not in os.environ.get("PATH", "").split(os.pathsep):
        print(f"Your shell PATH does not include {launcher.parent}; the application menu still works.")
    print(f"Remove it any time: {shlex.quote(str(launcher))} --uninstall")
    print("Ollama and models are managed separately. Your model files are never changed by this installer.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
