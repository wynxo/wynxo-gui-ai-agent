#!/usr/bin/env python3
"""Remove Wynxo; keep conversations/settings unless --purge is given."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import sys

from install import APP_ID, MANIFEST, MARKER, absolute, default_root, exists, fingerprint, install_lock, owned_root, read_manifest


def uninstall(root: Path | None = None, purge: bool = False) -> list[str]:
    root = absolute(root or os.environ.get("WYNXO_INSTALL_ROOT") or default_root())
    if not exists(root):
        return [f"No installation found at {root}."]
    owned_root(root)
    messages = []
    with install_lock(root):
        manifest = read_manifest(root)
        if not (root / MANIFEST).is_file():
            raise ValueError("Installation manifest is missing; refusing to guess which files to remove.")
        releases = root / "releases"
        if releases.is_symlink():
            raise ValueError(f"Refusing to follow a symlink: {releases}")
        remove_releases = []
        for release_id in manifest["releases"]:
            if not isinstance(release_id, str) or len(release_id) != 32 or any(c not in "0123456789abcdef" for c in release_id):
                raise ValueError("Invalid release path in manifest.")
            release = releases / release_id
            if not exists(release):
                continue
            marker = release / ".wynxo-release"
            if release.is_symlink() or not release.is_dir() or marker.is_symlink() or not marker.is_file() or marker.read_text() != APP_ID:
                raise ValueError(f"Refusing to delete an unowned release: {release}")
            remove_releases.append(release)
        data_dirs = []
        if purge:
            for value in manifest.get("data_dirs", []):
                path = absolute(value)
                if path.name != "wynxo" or path == root or path in root.parents or root in path.parents:
                    raise ValueError(f"Unsafe user data path in manifest: {path}")
                data_dirs.append(path)
        internal = {root / "wynxo", root / "uninstall.py", root / "current"}
        external = {absolute(value) for value in manifest.get("external", [])}
        if internal.intersection(external):
            raise ValueError("Invalid external paths in manifest.")
        for path in internal | external:
            actual = fingerprint(path)
            if actual is None:
                continue
            expected = manifest["files"].get(str(path))
            if expected is None or expected != actual:
                messages.append(f"Kept modified or unowned file: {path}")
                continue
            path.unlink()
        for release in remove_releases:
            shutil.rmtree(release)
        if releases.is_dir() and not any(releases.iterdir()):
            releases.rmdir()
        for path in data_dirs:
            if path.is_symlink():
                messages.append(f"Kept user data symlink (target untouched): {path}")
            elif path.is_dir():
                shutil.rmtree(path)
            elif exists(path):
                messages.append(f"Kept unexpected user data file: {path}")
        remaining = [p for p in root.iterdir() if p.name not in {MARKER, MANIFEST, ".install.lock"}]
        if remaining:
            messages.append(f"Kept installation directory because it contains modified or unknown files: {root}")
        else:
            (root / MANIFEST).unlink()
            (root / MARKER).unlink()
    if root.is_dir() and not any(root.iterdir()):
        root.rmdir()
    messages.append("Wynxo removed. Ollama and downloaded models were left untouched.")
    messages.append("Conversations, settings and cache removed." if purge else "Conversations and settings kept. Use --purge when uninstalling to remove them too.")
    return messages


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-root", type=Path, default=Path(os.environ.get("WYNXO_INSTALL_ROOT", str(default_root()))))
    parser.add_argument("--purge", action="store_true", help="Also remove Wynxo conversations, settings and cache; never Ollama models")
    args = parser.parse_args(argv)
    try:
        messages = uninstall(args.install_root, args.purge)
    except (Exception, KeyboardInterrupt) as exc:
        print(f"Uninstall stopped: {exc}", file=sys.stderr)
        return 1
    print("\n".join(messages))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
