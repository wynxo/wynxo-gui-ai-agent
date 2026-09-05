"""Explicitly enabled desktop control; no shell commands are accepted from models.

X11 uses XTEST and Pillow. Wayland uses a long-lived XDG RemoteDesktop portal
session, with Screenshot portal captures. Wayland v1 supports one monitor;
mixed-monitor screenshot coordinates cannot be inferred reliably from this API.
Portal interfaces: https://flatpak.github.io/xdg-desktop-portal/docs/
"""
from __future__ import annotations

import asyncio
import base64
import concurrent.futures
import configparser
import importlib.util
import io
import math
import os
from pathlib import Path
import shutil
import subprocess
import threading
import time
from urllib.parse import unquote, urlparse
import uuid


class DesktopError(RuntimeError):
    """An unsupported, unapproved, or failed desktop action."""


class DesktopCancelled(DesktopError):
    """The user stopped the current action."""


def _check(cancel: threading.Event | None) -> None:
    if cancel is not None and cancel.is_set():
        raise DesktopCancelled("Desktop action stopped.")


def _pause(seconds: float, cancel: threading.Event | None) -> None:
    if cancel is None:
        time.sleep(seconds)
    elif cancel.wait(seconds):
        raise DesktopCancelled("Desktop action stopped.")


def _number(value, name: str, minimum: float, maximum: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise DesktopError(f"{name} must be a number.")
    value = float(value)
    if not math.isfinite(value) or not minimum <= value <= maximum:
        raise DesktopError(f"{name} must be between {minimum:g} and {maximum:g}.")
    return value


def _integer(value, name: str, minimum: int, maximum: int) -> int:
    number = _number(value, name, minimum, maximum)
    if not number.is_integer():
        raise DesktopError(f"{name} must be an integer.")
    return int(number)


def _png_result(picture, backend: str) -> dict:
    output = io.BytesIO()
    picture.convert("RGB").save(output, format="PNG")
    return {"ok": True, "image": base64.b64encode(output.getvalue()).decode("ascii"),
            "width": picture.width, "height": picture.height, "mime_type": "image/png",
            "backend": backend, "coordinate_space": "screenshot pixels"}


_KEYSYMS = {
    "ctrl": 0xFFE3, "control": 0xFFE3, "alt": 0xFFE9,
    "shift": 0xFFE1, "super": 0xFFEB, "meta": 0xFFEB, "win": 0xFFEB,
    "enter": 0xFF0D, "return": 0xFF0D, "escape": 0xFF1B, "esc": 0xFF1B,
    "tab": 0xFF09, "backspace": 0xFF08, "delete": 0xFFFF, "del": 0xFFFF,
    "insert": 0xFF63, "home": 0xFF50, "end": 0xFF57,
    "pageup": 0xFF55, "pagedown": 0xFF56,
    "left": 0xFF51, "up": 0xFF52, "right": 0xFF53, "down": 0xFF54,
    "space": 0x20, "capslock": 0xFFE5,
    **{f"f{i}": 0xFFBD + i for i in range(1, 25)},
}


def _keysym(key: str) -> int:
    if not isinstance(key, str) or not key:
        raise DesktopError("Each key must be a key name or a single character.")
    if key.lower() in _KEYSYMS:
        return _KEYSYMS[key.lower()]
    if len(key) == 1:
        if key in "\n\r\t":
            return {"\n": 0xFF0D, "\r": 0xFF0D, "\t": 0xFF09}[key]
        if not key.isprintable():
            raise DesktopError("Unsupported control character.")
        return ord(key) if ord(key) < 256 else 0x01000000 | ord(key)
    raise DesktopError(f"Unknown key: {key[:40]}")


def _qt_monitor_layout() -> list[dict]:
    # Called once from the GUI thread, never from the portal event loop.
    try:
        from PySide6.QtGui import QGuiApplication
        if QGuiApplication.instance():
            return [{"x": s.geometry().x(), "y": s.geometry().y(),
                     "width": s.geometry().width(), "height": s.geometry().height()}
                    for s in QGuiApplication.screens()]
    except ImportError:
        pass
    return []


def _application_inventory() -> list[dict]:
    roots = [Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))]
    roots += [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    seen, result = set(), []
    for root in roots:
        directory = root / "applications"
        for path in sorted(directory.glob("**/*.desktop")):
            app_id = str(path.relative_to(directory)).replace("/", "-")
            if app_id in seen:
                continue
            seen.add(app_id)  # Hidden user overrides also mask system entries.
            config = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                config.read(path, encoding="utf-8")
                section = config["Desktop Entry"]
                if section.get("Type") != "Application" or section.getboolean("Hidden", False):
                    continue
                if section.getboolean("NoDisplay", False) or not section.get("Name"):
                    continue
                desktops = set(os.environ.get("XDG_CURRENT_DESKTOP", "").split(":"))
                only = set(filter(None, section.get("OnlyShowIn", "").split(";")))
                excluded = set(filter(None, section.get("NotShowIn", "").split(";")))
                if (only and not only.intersection(desktops)) or excluded.intersection(desktops):
                    continue
                if section.get("TryExec") and not shutil.which(section["TryExec"]):
                    continue
                if not section.get("Exec") and not section.getboolean("DBusActivatable", False):
                    continue
                result.append({"id": app_id, "name": section["Name"],
                               "description": section.get("Comment", "")[:200], "path": str(path)})
            except (OSError, KeyError, ValueError, configparser.Error):
                continue
    return sorted(result, key=lambda app: app["name"].casefold())


class DesktopController:
    """Synchronous interface for Qt workers. Construction never grants control.

    Call connect() only after the user enables desktop control. ``execute``
    raises DesktopError; connect() reports any error in its returned status.
    Input and screenshot operations are serialized, with interruptible waits.
    """

    def __init__(self, *, monitor_layout: list[dict] | None = None, backend=None):
        self._lock = threading.RLock()
        self._enabled = False
        self._detail = "Desktop control is off. Enable it to connect."
        if backend is not None:
            self._backend = backend
        elif os.environ.get("XDG_SESSION_TYPE") == "wayland" or os.environ.get("WAYLAND_DISPLAY"):
            self._backend = _PortalBackend(monitor_layout if monitor_layout is not None else _qt_monitor_layout())
        elif os.environ.get("DISPLAY"):
            self._backend = _X11Backend()
        else:
            self._backend = None
        self._size: tuple[int, int] | None = None

    def status(self) -> dict:
        backend = self._backend
        available = bool(backend and backend.available)
        connected = bool(self._enabled and backend and backend.connected)
        detail = self._detail
        if backend is None:
            detail = "No graphical Linux session found. Chat is still available."
        elif not available:
            detail = backend.unavailable_reason
        elif self._enabled and not backend.connected:
            detail = "Desktop access ended. Enable control to reconnect."
        return {"backend": backend.name if backend else "unavailable", "available": available,
                "connected": connected, "detail": detail}

    def connect(self) -> dict:
        with self._lock:
            if self.status()["connected"]:
                return self.status()
            if not self.status()["available"]:
                return self.status()
            try:
                self._backend.connect()
                self._enabled = True
                self._detail = self._backend.detail
            except Exception as exc:
                self._enabled = False
                self._detail = str(exc) or type(exc).__name__
            return self.status()

    def disconnect(self) -> None:
        # Revoke the permission gate immediately, even while an action holds
        # the lock. The worker should also receive its cancellation Event.
        self._enabled = False
        with self._lock:
            if self._backend:
                self._backend.disconnect()
            self._size = None
            self._detail = "Desktop control is off."

    def _permission(self, cancel) -> None:
        _check(cancel)
        if not self.status()["connected"]:
            raise DesktopError("Desktop control is off. Enable it before running desktop actions.")

    def _point(self, args: dict) -> tuple[float, float]:
        if not self._size:
            raise DesktopError("Take a screenshot before using pointer coordinates.")
        return (_number(args.get("x"), "x", 0, self._size[0] - 1),
                _number(args.get("y"), "y", 0, self._size[1] - 1))

    def execute(self, name: str, args: dict, cancel: threading.Event | None = None) -> dict:
        if not isinstance(args, dict):
            raise DesktopError("Tool arguments must be an object.")
        with self._lock:
            _check(cancel)
            if name == "list_apps":
                apps = [{k: v for k, v in a.items() if k != "path"} for a in _application_inventory()]
                return {"ok": True, "apps": apps}
            self._permission(cancel)
            if name == "screenshot":
                picture = self._backend.screenshot(cancel)
                self._permission(cancel)
                self._size = picture.size
                return _png_result(picture, self._backend.name)
            if name == "wait":
                seconds = _number(args.get("seconds", 1), "seconds", 0, 10)
                _pause(seconds, cancel)
            elif name == "open_app":
                self._open_app(args, cancel)
            elif name == "move_pointer":
                self._backend.move(*self._point(args), cancel)
            elif name == "click":
                point = self._point(args)
                button = args.get("button", "left")
                if button not in ("left", "middle", "right"):
                    raise DesktopError("button must be left, middle, or right.")
                count = _integer(args.get("count", 1), "count", 1, 3)
                self._backend.move(*point, cancel)
                for _ in range(count):
                    self._permission(cancel)
                    try:
                        self._backend.button(button, True, cancel)
                        _pause(0.045, cancel)
                    finally:
                        self._backend.button(button, False, None)
                    _pause(0.065, cancel)
            elif name == "drag":
                raw = args.get("points")
                if not isinstance(raw, list) or not 2 <= len(raw) <= 500:
                    raise DesktopError("A drag needs 2 to 500 [x, y] points.")
                if any(not isinstance(p, (list, tuple)) or len(p) != 2 for p in raw):
                    raise DesktopError("Each drag point must be [x, y].")
                points = [self._point({"x": p[0], "y": p[1]}) for p in raw]
                duration = _number(args.get("duration", 1), "duration", 0.1, 10)
                self._backend.move(*points[0], cancel)
                try:
                    self._backend.button("left", True, cancel)
                    # Interpolate even two-point drags to produce actual strokes.
                    segments = max(len(points) - 1, int(duration * 60))
                    for step in range(1, segments + 1):
                        self._permission(cancel)
                        position = step / segments * (len(points) - 1)
                        index = min(int(position), len(points) - 2)
                        fraction = position - index
                        x = points[index][0] + (points[index + 1][0] - points[index][0]) * fraction
                        y = points[index][1] + (points[index + 1][1] - points[index][1]) * fraction
                        self._backend.move(x, y, cancel)
                        _pause(duration / segments, cancel)
                finally:
                    self._backend.button("left", False, None)
            elif name == "type_text":
                value = args.get("text")
                if not isinstance(value, str) or not 1 <= len(value) <= 4000:
                    raise DesktopError("text must contain 1 to 4000 characters.")
                syms = [_keysym(character) for character in value]
                self._backend.validate_keys(syms)
                for sym in syms:
                    self._permission(cancel)
                    self._chord([sym], cancel)
            elif name == "press_key":
                keys = args.get("keys")
                if not isinstance(keys, list) or not 1 <= len(keys) <= 5:
                    raise DesktopError("keys must contain 1 to 5 key names.")
                syms = [_keysym(key) for key in keys]
                if len(set(syms)) != len(syms):
                    raise DesktopError("A key chord cannot contain duplicate keys.")
                self._backend.validate_keys(syms)
                self._chord(syms, cancel)
            elif name == "scroll":
                dx = _integer(args.get("dx", 0), "dx", -30, 30)
                dy = _integer(args.get("dy", 0), "dy", -30, 30)
                self._backend.scroll(dx, dy, cancel)
            else:
                raise DesktopError(f"Unknown desktop tool: {str(name)[:60]}")
            self._permission(cancel)
            return {"ok": True, "action": name}

    def _chord(self, syms, cancel) -> None:
        pressed = []
        try:
            for sym in syms:
                self._permission(cancel)
                pressed.append(sym)
                self._backend.key(sym, True, cancel)
            _pause(0.025, cancel)
        finally:
            # Never let cancellation skip key releases.
            failures = []
            for sym in reversed(pressed):
                try:
                    self._backend.key(sym, False, None)
                except Exception as exc:
                    failures.append(exc)
            if failures:
                self._enabled = False
                raise DesktopError("Keyboard release failed; desktop control has been disabled.") from failures[0]

    def _open_app(self, args, cancel):
        requested = args.get("app")
        if not isinstance(requested, str) or not requested.strip() or len(requested) > 200:
            raise DesktopError("app must be a name or ID from list_apps.")
        query = requested.strip().casefold()
        matches = [a for a in _application_inventory()
                   if query in (a["id"].casefold(), a["name"].casefold(), a["id"].removesuffix(".desktop").casefold())]
        if len(matches) != 1:
            raise DesktopError("Choose an exact installed application name or ID from list_apps.")
        launcher = shutil.which("gio")
        if not launcher:
            raise DesktopError("Install libglib2.0-bin (gio) to launch applications.")
        self._permission(cancel)
        # gio interprets the installed desktop entry; model text never becomes
        # an executable, a shell expression, a file path, or a command argument.
        process = subprocess.run([launcher, "launch", matches[0]["path"]],
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, timeout=10, check=False)
        if process.returncode:
            raise DesktopError(f"Could not open {matches[0]['name']} (launcher exit {process.returncode}).")


class _X11Backend:
    name = "X11 / XTEST"
    detail = "Connected to X11. Screenshot coordinates cover the desktop."

    def __init__(self):
        self.available = all(importlib.util.find_spec(p) is not None for p in ("Xlib", "PIL"))
        self.unavailable_reason = "Install the app dependencies (python-xlib and Pillow) for X11 control."
        self.connected = False
        self._display = None
        self._held = {}

    def connect(self):
        from Xlib import display
        self._display = display.Display()
        if not self._display.has_extension("XTEST"):
            self._display.close()
            self._display = None
            raise DesktopError("This X server does not support the XTEST input extension.")
        self.connected = True

    def disconnect(self):
        if self._display:
            for sym in list(self._held):
                try:
                    self.key(sym, False, None)
                except Exception:
                    pass
            self._display.close()
        self._display = None
        self.connected = False

    def screenshot(self, cancel):
        from PIL import ImageGrab
        _check(cancel)
        return ImageGrab.grab(xdisplay=os.environ.get("DISPLAY", ""))

    def move(self, x, y, cancel):
        from Xlib import X
        from Xlib.ext import xtest
        _check(cancel)
        xtest.fake_input(self._display, X.MotionNotify, x=round(x), y=round(y))
        self._display.sync()

    def button(self, button, down, cancel):
        from Xlib import X
        from Xlib.ext import xtest
        _check(cancel)
        code = {"left": 1, "middle": 2, "right": 3}[button]
        xtest.fake_input(self._display, X.ButtonPress if down else X.ButtonRelease, code)
        self._display.sync()

    def _mapping(self, sym):
        # Xlib's second tuple field is the keymap column. Columns 0/1 are
        # unshifted/shifted in the current group; other groups need XKB support.
        mappings = [(code, index) for code, index in self._display.keysym_to_keycodes(sym) if index in (0, 1)]
        if not mappings:
            raise DesktopError("A character is unavailable in the active X11 keyboard layout. Use the matching layout or Wayland portal.")
        return min(mappings, key=lambda pair: pair[1])

    def validate_keys(self, syms):
        for sym in syms:
            self._mapping(sym)

    def key(self, sym, down, cancel):
        from Xlib import X
        from Xlib.ext import xtest
        _check(cancel)
        if down:
            code, column = self._mapping(sym)
            shift = self._display.keysym_to_keycode(_KEYSYMS["shift"]) if column == 1 else None
            # Record first so a subsequent error can still release the keys.
            self._held[sym] = (code, shift)
            if shift:
                xtest.fake_input(self._display, X.KeyPress, shift)
            xtest.fake_input(self._display, X.KeyPress, code)
        else:
            held = self._held.pop(sym, None)
            if held:
                code, shift = held
                xtest.fake_input(self._display, X.KeyRelease, code)
                if shift:
                    xtest.fake_input(self._display, X.KeyRelease, shift)
        self._display.sync()

    def scroll(self, dx, dy, cancel):
        from Xlib import X
        from Xlib.ext import xtest
        for delta, negative, positive in ((dy, 4, 5), (dx, 6, 7)):
            for _ in range(abs(delta)):
                _check(cancel)
                code = negative if delta < 0 else positive
                try:
                    xtest.fake_input(self._display, X.ButtonPress, code)
                finally:
                    xtest.fake_input(self._display, X.ButtonRelease, code)
                self._display.sync()


class _PortalBackend:
    name = "Wayland / Desktop portal"
    detail = "Connected through the desktop portal. Screenshot permission is managed separately by your desktop."
    _DEST = "org.freedesktop.portal.Desktop"
    _PATH = "/org/freedesktop/portal/desktop"
    _REMOTE = "org.freedesktop.portal.RemoteDesktop"
    _CAST = "org.freedesktop.portal.ScreenCast"
    _SHOT = "org.freedesktop.portal.Screenshot"
    _REQUEST = "org.freedesktop.portal.Request"
    _SESSION = "org.freedesktop.portal.Session"

    def __init__(self, monitor_layout):
        self.available = all(importlib.util.find_spec(p) is not None for p in ("dbus_next", "PIL"))
        self.unavailable_reason = "Install the app dependencies (dbus-next and Pillow) for Wayland control."
        self.connected = False
        self.layout = monitor_layout
        self._loop = None
        self._thread = None
        self._bus = None
        self._session = None
        self._stream = None
        self._logical_size = None
        self._pixel_size = None
        self._requests = {}
        self._early = {}

    def _ensure_loop(self):
        if self._loop is None:
            self._loop = asyncio.new_event_loop()
            self._thread = threading.Thread(target=self._loop.run_forever, name="wynxo-desktop-portal", daemon=True)
            self._thread.start()

    def _run(self, coroutine, cancel=None, timeout=35):
        self._ensure_loop()
        future = asyncio.run_coroutine_threadsafe(coroutine, self._loop)
        deadline = time.monotonic() + timeout
        try:
            while True:
                _check(cancel)
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise DesktopError("The desktop portal did not respond in time.")
                try:
                    return future.result(timeout=min(0.05, remaining))
                except concurrent.futures.TimeoutError:
                    continue
        except BaseException:
            future.cancel()
            raise

    async def _init_bus(self):
        if self._bus is not None:
            return
        from dbus_next.aio import MessageBus
        from dbus_next import Message
        self._bus = await MessageBus().connect()
        self._bus.add_message_handler(self._signal)
        reply = await self._bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                           interface="org.freedesktop.DBus", member="AddMatch", signature="s",
                           body=[f"type='signal',sender='{self._DEST}',path_namespace='{self._PATH}'"]))
        self._check_reply(reply)

    @staticmethod
    def _unwrap(value):
        if hasattr(value, "value"):
            return _PortalBackend._unwrap(value.value)
        if isinstance(value, dict):
            return {k: _PortalBackend._unwrap(v) for k, v in value.items()}
        if isinstance(value, (tuple, list)):
            return [_PortalBackend._unwrap(v) for v in value]
        return value

    def _signal(self, message):
        from dbus_next import MessageType
        if message.message_type != MessageType.SIGNAL:
            return
        if message.interface == self._SESSION and message.member == "Closed" and message.path == self._session:
            self.connected = False
            self._session = None
            self._pixel_size = None
        if message.interface == self._REQUEST and message.member == "Response":
            future = self._requests.get(message.path)
            if future is not None and not future.done():
                future.set_result(message.body)
            elif len(self._early) < 32:
                self._early[message.path] = message.body

    @staticmethod
    def _check_reply(reply):
        from dbus_next import MessageType
        if reply is None or reply.message_type == MessageType.ERROR:
            detail = ": ".join(str(item) for item in reply.body) if reply else "No reply"
            raise DesktopError(f"Desktop portal: {detail[:400]}")
        return reply.body

    async def _call(self, interface, member, signature="", body=None, path=None):
        from dbus_next import Message
        reply = await asyncio.wait_for(self._bus.call(Message(destination=self._DEST, path=path or self._PATH,
                            interface=interface, member=member, signature=signature, body=body or [])), 15)
        return self._check_reply(reply)

    async def _request(self, interface, member, signature, prefix, options, timeout=120):
        from dbus_next import Variant
        token = "wynxo_" + uuid.uuid4().hex
        options = {**options, "handle_token": Variant("s", token)}
        sender = self._bus.unique_name.lstrip(":").replace(".", "_")
        predicted = f"{self._PATH}/request/{sender}/{token}"
        future = asyncio.get_running_loop().create_future()
        self._requests[predicted] = future  # Subscribe BEFORE issuing the method.
        actual = predicted
        try:
            returned = await self._call(interface, member, signature, [*prefix, options])
            actual = returned[0]
            if actual != predicted:
                self._requests[actual] = future
                if actual in self._early and not future.done():
                    future.set_result(self._early.pop(actual))
            response, result = await asyncio.wait_for(future, timeout)
            if response != 0:
                raise DesktopError("Desktop permission was cancelled." if response == 1 else "The desktop portal denied this request.")
            return self._unwrap(result)
        except (asyncio.CancelledError, asyncio.TimeoutError):
            try:
                await self._call(self._REQUEST, "Close", path=actual)
            except Exception:
                pass
            raise
        finally:
            self._requests.pop(predicted, None)
            self._requests.pop(actual, None)
            self._early.pop(actual, None)

    def connect(self):
        if len(self.layout) != 1:
            raise DesktopError("Wayland desktop control currently requires one monitor. Disconnect extra displays, restart Wynxo, or use an X11 session.")
        self._run(self._connect(), timeout=135)

    async def _connect(self):
        from dbus_next import Variant
        await self._init_bus()
        try:
            created = await self._request(self._REMOTE, "CreateSession", "a{sv}", [],
                                          {"session_handle_token": Variant("s", "wynxo_" + uuid.uuid4().hex)})
            self._session = created["session_handle"]
            await self._request(self._REMOTE, "SelectDevices", "oa{sv}", [self._session], {"types": Variant("u", 3)})
            await self._request(self._CAST, "SelectSources", "oa{sv}", [self._session],
                                {"types": Variant("u", 1), "multiple": Variant("b", False)})
            result = await self._request(self._REMOTE, "Start", "osa{sv}", [self._session, ""], {})
            if result.get("devices", 0) & 3 != 3:
                raise DesktopError("Allow both keyboard and pointer access in the desktop permission dialog.")
            streams = result.get("streams", [])
            if len(streams) != 1:
                raise DesktopError("Select exactly one monitor in the desktop sharing dialog.")
            self._stream, properties = streams[0]
            logical = properties.get("logical_size", properties.get("size"))
            expected = self.layout[0]
            if logical is None:
                logical = [expected["width"], expected["height"]]
            if len(logical) != 2 or any(not isinstance(v, (int, float)) or v <= 0 for v in logical):
                raise DesktopError("The desktop portal returned invalid monitor dimensions.")
            self._logical_size = tuple(logical)
            self._pixel_size = None
            self.connected = True
        except BaseException:
            await self._disconnect()
            raise

    def disconnect(self):
        self.connected = False
        if self._loop:
            self._run(self._disconnect(), timeout=20)

    async def _disconnect(self):
        session, self._session = self._session, None
        self.connected = False
        self._pixel_size = None
        if session and self._bus:
            try:
                await self._call(self._SESSION, "Close", path=session)
            except Exception:
                pass

    def screenshot(self, cancel):
        return self._run(self._screenshot(), cancel, timeout=125)

    async def _screenshot(self):
        from dbus_next import Variant
        from PIL import Image
        self._pixel_size = None  # A failed capture must invalidate old coordinates.
        result = await self._request(self._SHOT, "Screenshot", "sa{sv}", [""],
                                     {"interactive": Variant("b", False), "modal": Variant("b", False)})
        uri = urlparse(result.get("uri", ""))
        if uri.scheme != "file" or uri.netloc not in ("", "localhost"):
            raise DesktopError("The portal did not return a local screenshot file.")
        path = Path(unquote(uri.path))
        if path.stat().st_size > 80 * 1024 * 1024:
            raise DesktopError("Screenshot exceeds the 80 MB limit.")
        with Image.open(path) as raw:
            raw.load()
            picture = raw.convert("RGB")
        width, height = self._logical_size
        sx, sy = picture.width / width, picture.height / height
        if abs(sx - sy) > max(sx, sy) * 0.025:
            raise DesktopError("Screenshot geometry does not match the shared monitor. Reconnect desktop control with a single display.")
        self._pixel_size = picture.size
        return picture

    def _notify(self, member, signature, values, cancel):
        _check(cancel)
        if not self.connected or not self._session:
            raise DesktopError("The desktop sharing session ended. Reconnect to continue.")
        return self._run(self._call(self._REMOTE, member, "oa{sv}" + signature,
                                   [self._session, {}, *values]), cancel, timeout=18)

    def move(self, x, y, cancel):
        if not self._pixel_size or not self._logical_size:
            raise DesktopError("Take a screenshot before moving the pointer.")
        lx = x * self._logical_size[0] / self._pixel_size[0]
        ly = y * self._logical_size[1] / self._pixel_size[1]
        self._notify("NotifyPointerMotionAbsolute", "udd", [self._stream, lx, ly], cancel)

    def button(self, button, down, cancel):
        code = {"left": 0x110, "right": 0x111, "middle": 0x112}[button]
        self._notify("NotifyPointerButton", "iu", [code, int(down)], cancel)

    def validate_keys(self, syms):
        pass  # The compositor resolves XKB/Unicode keysyms.

    def key(self, sym, down, cancel):
        self._notify("NotifyKeyboardKeysym", "iu", [sym, int(down)], cancel)

    def scroll(self, dx, dy, cancel):
        if dy:
            self._notify("NotifyPointerAxisDiscrete", "ui", [0, dy], cancel)
        if dx:
            self._notify("NotifyPointerAxisDiscrete", "ui", [1, dx], cancel)
