"""Qt WebEngine is optional, so nothing may assume the browser panel exists.

Qt WebEngine ships with the full PySide6 distribution but not with
PySide6-Essentials, and even when the Python module is present it needs system
libraries a minimal install may not have. Importing it is the only honest test,
so that is what happens here — once, never fatally, and with an escape hatch for
anyone who would rather Wynxo did not embed a browser at all.
"""
from __future__ import annotations

import logging
import os

LOG = logging.getLogger(__name__)

_state: dict = {}


def _switched_off() -> bool:
    return os.environ.get("WYNXO_NO_BROWSER", "").strip().lower() in {"1", "true", "yes", "on"}


def available() -> bool:
    """Whether a page can be rendered inside Wynxo rather than handed outside."""
    if "available" not in _state:
        _state["available"] = False if _switched_off() else _probe()
    return _state["available"]


def _probe() -> bool:
    try:
        from PySide6 import QtWebEngineQuick  # noqa: F401
    except Exception as exc:  # ImportError, or a missing shared library.
        LOG.info("Qt WebEngine is unavailable; pages will open in your own browser: %s", exc)
        return False
    return True


def initialize() -> bool:
    """Start Qt WebEngine, between the application and the QML engine.

    Returns whether the built-in view can be used. A failure here is not an
    error the user needs to see: the browser panel falls back to handing pages
    to their own browser, and says so.
    """
    if not available():
        return False
    if _state.get("initialized"):
        return True
    try:
        from PySide6 import QtWebEngineQuick
        QtWebEngineQuick.initialize()
    except Exception as exc:
        LOG.warning("Qt WebEngine could not start: %s", exc)
        _state["available"] = False
        return False
    _state["initialized"] = True
    return True


def reset() -> None:
    """Forget what was probed. Only tests need this."""
    _state.clear()
