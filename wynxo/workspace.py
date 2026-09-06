"""Task-scoped Chat / Work / Wynxi mode state.

The base Controller intentionally stays focused on conversation, Ollama and
runtime state. WorkspaceController adds the product-level behavior used by the
shell: a new task starts unlocked, choosing Chat or Work locks that task's mode,
and Wynxi creates a permanently coding-focused task. Modes are persisted in the
existing private settings table so old databases need no migration.

Wynxo is also the desktop product's network-policy layer. The engine historically
accepted loopback-only Ollama URLs, which made a perfectly normal homelab setup
impossible. The desktop app now accepts explicit HTTP(S) Ollama origins on the
LAN or elsewhere while still rejecting credentials, paths, query strings and
redirects. This keeps the endpoint predictable without pretending every model
has to live on the same machine as the GUI.
"""
from __future__ import annotations

import ipaddress
import time
from urllib.parse import urlsplit

from PySide6.QtCore import Property, Signal, Slot

from . import engine as engine_module
from .controller import Controller, AgentEngine, OllamaClient, _blank_metrics


def validate_workspace_endpoint(endpoint: str) -> str:
    """Validate an explicit Ollama origin without forcing it to loopback.

    Accepted examples include ``http://127.0.0.1:11434``,
    ``http://192.168.1.50:11434`` and ``https://ollama.home.arpa``. A bare host
    is intentionally not guessed: users should be able to see exactly whether
    traffic is HTTP or HTTPS. Redirects remain disabled in :class:`OllamaClient`.
    """
    value = str(endpoint or "").strip()
    if not value or any(ord(c) < 33 for c in value):
        raise ValueError("Enter an Ollama URL such as http://192.168.1.50:11434")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        raise ValueError("Invalid Ollama URL") from exc
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Ollama URL must start with http:// or https://")
    if not parsed.hostname:
        raise ValueError("Ollama URL needs a host name or IP address")
    if parsed.username is not None or parsed.password is not None:
        raise ValueError("Put credentials in a reverse proxy, not in the Ollama URL")
    if parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        raise ValueError("Use the Ollama server origin only, with no path, query, or fragment")
    if port is not None and not 1 <= port <= 65535:
        raise ValueError("Ollama port must be between 1 and 65535")

    host = parsed.hostname
    # urlsplit removes IPv6 brackets, so add them back when rebuilding the
    # origin. Host names are normalized to lower case; IP literals are kept
    # canonical where Python can parse them.
    try:
        address = ipaddress.ip_address(host)
        host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    except ValueError:
        host = host.rstrip(".").lower()
        if not host or len(host) > 253 or any(len(label) > 63 for label in host.split(".")):
            raise ValueError("Invalid Ollama host name")
        allowed = set("abcdefghijklmnopqrstuvwxyz0123456789-._")
        if any(ch not in allowed for ch in host):
            raise ValueError("Invalid Ollama host name")
    return f"{parsed.scheme.lower()}://{host}" + (f":{port}" if port is not None else "")


def endpoint_scope(endpoint: str) -> str:
    """Human-facing scope for the endpoint status shown by the UI."""
    try:
        parsed = urlsplit(validate_workspace_endpoint(endpoint))
        host = parsed.hostname or ""
        if host == "localhost":
            return "local"
        try:
            address = ipaddress.ip_address(host)
        except ValueError:
            lowered = host.lower()
            if lowered.endswith((".local", ".lan", ".home", ".home.arpa", ".internal")):
                return "lan"
            return "remote"
        if address.is_loopback:
            return "local"
        if address.is_private or address.is_link_local:
            return "lan"
        return "remote"
    except Exception:
        return "invalid"


class WorkspaceController(Controller):
    modeChanged = Signal()
    VALID_TASK_MODES = {"chat", "work", "codex"}

    def __init__(self, *args, **kwargs):
        self._task_mode = "chat"
        self._task_mode_locked = False
        # The core Ollama transport keeps redirects/proxies disabled; the
        # desktop workspace supplies the less surprising host policy.
        engine_module.validate_endpoint = validate_workspace_endpoint
        super().__init__(*args, **kwargs)

    def _emit_mode(self) -> None:
        self.modeChanged.emit()
        self.changed.emit()

    @staticmethod
    def _mode_key(task_id: str) -> str:
        return f"task_mode:{task_id}"

    def _saved_mode(self, task_id: str) -> str:
        mode = str(self.store.get_setting(self._mode_key(task_id), "chat") or "chat")
        return mode if mode in self.VALID_TASK_MODES else "chat"

    def _persist_task_mode(self, task_id: str | None = None) -> None:
        target = str(task_id or self._task_id or "")
        if target:
            self.store.set_setting(self._mode_key(target), self._task_mode)

    @Property(str, notify=modeChanged)
    def taskMode(self):
        return self._task_mode

    @Property(bool, notify=modeChanged)
    def taskModeLocked(self):
        return bool(self._task_id or self._task_mode_locked)

    @Property(str, notify=modeChanged)
    def productName(self):
        return "Wynxi" if self._task_mode == "codex" else "Wynxo"

    @Property(str, notify=Controller.changed)
    def endpointScope(self):
        return endpoint_scope(self._endpoint)

    @Property(str, notify=Controller.changed)
    def endpointScopeLabel(self):
        return {
            "local": "This computer",
            "lan": "Local network",
            "remote": "Remote server",
            "invalid": "Invalid address",
        }.get(endpoint_scope(self._endpoint), "Server")

    @Property(str, notify=Controller.changed)
    def endpointPrivacyHint(self):
        scope = endpoint_scope(self._endpoint)
        if scope == "local":
            return "Ollama runs on this computer."
        if scope == "lan":
            return "Ollama runs on another device on your local network. Chats, files and screenshots used by the model are sent to that device."
        if scope == "remote":
            return "This Ollama server is outside the local network. Use HTTPS or a trusted private tunnel for sensitive chats, files and screenshots."
        return "Enter a complete Ollama server URL."

    @Slot(str, result=bool)
    def setTaskMode(self, mode):
        """Choose the mode for a blank task exactly once."""
        mode = str(mode or "").strip().lower()
        if mode not in self.VALID_TASK_MODES or self._busy or self._connecting:
            return False
        if self._task_id or self._task_mode_locked:
            return mode == self._task_mode
        self._task_mode = mode
        self._task_mode_locked = True
        self._emit_mode()
        if mode == "work" and not self.desktopEnabled:
            self.toggleDesktop()
        return True

    @Slot(str)
    def newTaskMode(self, mode):
        """Start a fresh task in a product-specific mode."""
        mode = str(mode or "").strip().lower()
        if mode not in self.VALID_TASK_MODES or self._busy:
            return
        super().newTask()
        if self._task_id or self._busy:
            return
        self._task_mode = "chat"
        self._task_mode_locked = False
        if mode == "chat":
            self._emit_mode()
        else:
            self.setTaskMode(mode)

    @Slot()
    def newTask(self):
        if self._busy:
            super().newTask()
            return
        super().newTask()
        if not self._task_id:
            self._task_mode = "chat"
            self._task_mode_locked = False
            self._emit_mode()

    @Slot(str)
    def openTask(self, task_id):
        super().openTask(task_id)
        if self._task_id != task_id:
            return
        self._task_mode = self._saved_mode(task_id)
        self._task_mode_locked = True
        self._emit_mode()
        if self._task_mode == "work" and not self.desktopEnabled and not self._connecting:
            self.toggleDesktop()

    @Slot(str)
    def send(self, text):
        was_new = not self._task_id
        if was_new and not self._task_mode_locked:
            self._task_mode = "chat"
            self._task_mode_locked = True
            self._emit_mode()
        super().send(text)
        if was_new and self._task_id:
            self._persist_task_mode()
            self.modeChanged.emit()

    def _start_run(self, history):
        """Run visual desktop tools only inside a Work task.

        Non-visual local tools still come from the base AgentEngine when the
        model supports tools, which keeps Wynxi useful for project commands.
        """
        self._busy = True
        self._clear_error()
        self._status = "Thinking"
        self._token_rate = "—"
        self._think_started = 0.0
        self._think_seconds = 0.0
        self._turn_had_message = False
        self._activity = []
        self._session_auto = False
        self._run_started = time.monotonic()
        self._run_metrics = _blank_metrics()
        self.activityChanged.emit()
        self._refresh_tasks()
        self.changed.emit()
        engine = AgentEngine(OllamaClient(self._endpoint), self.desktop)
        model = self._model
        enabled = self._task_mode == "work" and self.desktopEnabled
        think = self._think
        num_ctx, temperature = self._num_ctx, self._temperature
        keep_alive, max_steps = self._keep_alive, self._max_steps
        permission_mode, project = self._permission_mode, self._working_directory
        self._run_job = self._job(
            lambda cancel, emit: engine.run(
                list(history), model, enabled, cancel, emit, think=think,
                max_steps=max_steps, num_ctx=num_ctx, temperature=temperature,
                keep_alive=keep_alive, permission_mode=permission_mode,
                project=project, confirm=self._confirm_action),
            self._run_done, self._run_failed, self._on_event,
        )

    @Slot()
    def duplicateTask(self):
        if self._busy or not self._task_id:
            return
        mode = self._task_mode
        previous = self._task_id
        super().duplicateTask()
        if self._task_id and self._task_id != previous:
            self._task_mode = mode
            self._task_mode_locked = True
            self._persist_task_mode()
            self._emit_mode()

    @Slot(str)
    def duplicateTaskById(self, task_id):
        if self._busy:
            return
        mode = self._saved_mode(task_id)
        previous = self._task_id
        super().duplicateTaskById(task_id)
        if self._task_id and self._task_id != previous:
            self._task_mode = mode
            self._task_mode_locked = True
            self._persist_task_mode()
            self._emit_mode()

    @Slot(int)
    def branchFrom(self, row):
        if self._busy or not self._task_id:
            return
        mode = self._task_mode
        previous = self._task_id
        super().branchFrom(row)
        if self._task_id and self._task_id != previous:
            self._task_mode = mode
            self._task_mode_locked = True
            self._persist_task_mode()
            self._emit_mode()
