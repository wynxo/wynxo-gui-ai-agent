"""Qt bridge. Network and desktop work never block the GUI thread."""
from __future__ import annotations

import json
import threading
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import (
    QAbstractListModel, QModelIndex, QObject, Property, Qt, QThread, Signal, Slot,
)
from PySide6.QtGui import QColor, QGuiApplication

from .desktop import DesktopController
from .engine import AgentEngine, OllamaClient
from .storage import Store


def _bounded_int(value, low, high, default):
    try:
        return max(low, min(int(value), high))
    except (TypeError, ValueError):
        return default


def _bounded_float(value, low, high, default):
    try:
        return max(low, min(float(value), high))
    except (TypeError, ValueError):
        return default


class Messages(QAbstractListModel):
    ROLES = {Qt.UserRole + 1: b"speaker", Qt.UserRole + 2: b"body", Qt.UserRole + 3: b"thought"}

    def __init__(self, parent=None):
        super().__init__(parent)
        self.items = []

    def roleNames(self):
        return self.ROLES

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.items)

    def data(self, index, role):
        if not index.isValid() or not 0 <= index.row() < len(self.items):
            return None
        return self.items[index.row()].get(self.ROLES.get(role, b"").decode(), "")

    def replace(self, messages):
        self.beginResetModel()
        self.items = [
            {"speaker": m["role"], "body": m.get("content", ""), "thought": m.get("thinking", "")}
            for m in messages if m.get("role") in ("user", "assistant")
            and (m.get("content") or m.get("thinking")) and not m.get("images")
        ]
        self.endResetModel()

    def append(self, speaker, body="", thought=""):
        row = len(self.items)
        self.beginInsertRows(QModelIndex(), row, row)
        self.items.append({"speaker": speaker, "body": body, "thought": thought})
        self.endInsertRows()

    def stream(self, field, text):
        if not self.items or self.items[-1]["speaker"] != "assistant":
            self.append("assistant")
        self.items[-1][field] += text
        index = self.index(len(self.items) - 1)
        self.dataChanged.emit(index, index, [Qt.UserRole + (2 if field == "body" else 3)])


class Job(QThread):
    event = Signal(dict)
    result = Signal(object)
    failed = Signal(str)

    def __init__(self, function, parent=None):
        super().__init__(parent)
        self.function = function
        self.cancel = threading.Event()

    def run(self):
        try:
            self.result.emit(self.function(self.cancel, self.event.emit))
        except Exception as exc:
            self.failed.emit(str(exc) or type(exc).__name__)


class Controller(QObject):
    changed = Signal()
    tasksChanged = Signal()
    activityChanged = Signal()
    toast = Signal(str)
    focusComposer = Signal()

    THEMES = {
        "Obsidian": "#b9dfc6",
        "Violet": "#c7b6ff",
        "Ice": "#9fd5ff",
        "Amber": "#f0c27b",
        "Rose": "#f2a7be",
    }

    RUNTIME_PRESETS = {
        "Fast": {"num_ctx": 8192, "temperature": 0.35, "keep_alive": "2m", "max_steps": 12},
        "Balanced": {"num_ctx": 16384, "temperature": 0.7, "keep_alive": "5m", "max_steps": 20},
        "Deep": {"num_ctx": 32768, "temperature": 0.8, "keep_alive": "15m", "max_steps": 40},
    }

    def __init__(self, store=None, desktop=None, autoconnect=True):
        super().__init__()
        self.store = store or Store()
        self.desktop = desktop or DesktopController()
        self.messages = Messages(self)
        self._endpoint = self.store.get_setting("endpoint", "http://127.0.0.1:11434")
        self._model = self.store.get_setting("model", "qwen3.8:27b")
        self._think = self.store.get_setting("think", False)
        self._reduced_motion = self.store.get_setting("reduced_motion", False)
        self._theme = self.store.get_setting("theme", "Obsidian")
        if self._theme not in self.THEMES:
            self._theme = "Obsidian"
        self._accent = self._normalise_accent(self.store.get_setting("accent", self.THEMES[self._theme])) or self.THEMES[self._theme]
        self._solid_background = bool(self.store.get_setting("solid_background", True))
        self._num_ctx = _bounded_int(self.store.get_setting("num_ctx", 16384), 2048, 131072, 16384)
        self._temperature = _bounded_float(self.store.get_setting("temperature", 0.7), 0.0, 2.0, 0.7)
        self._keep_alive = str(self.store.get_setting("keep_alive", "5m")).strip()[:32] or "5m"
        self._max_steps = _bounded_int(self.store.get_setting("max_steps", 20), 1, 100, 20)
        self._runtime_preset = str(self.store.get_setting("runtime_preset", "Balanced"))
        if self._runtime_preset not in self.RUNTIME_PRESETS and self._runtime_preset != "Custom":
            self._runtime_preset = "Custom"
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self._models = []
        self._model_capabilities = []
        self._capability_probe_active = False
        self._capability_probe_generation = 0
        self._capability_error = ""
        self._online = False
        self._busy = False
        self._connecting = False
        self._pulling = False
        self._pull_progress = ""
        self._status = "Ready when you are"
        self._error = ""
        self._activity = []
        self._history = []
        self._task_id = ""
        self._task_title = "New task"
        self._token_rate = "—"
        self._thinking_text = ""
        self._tasks = self.store.list_conversations()
        self._desktop_status = self.desktop.status()
        self._jobs = set()
        self._run_job = None
        self._pull_job = None
        self._probe_active = False
        self._turn_had_message = False
        if autoconnect:
            self.refreshModels()

    def _job(self, fn, result=None, failure=None, event=None):
        job = Job(fn, self)
        if result:
            job.result.connect(result)
        job.failed.connect(failure or self._show_error)
        if event:
            job.event.connect(event)
        job.finished.connect(lambda: self._forget_job(job))
        self._jobs.add(job)
        job.start()
        return job

    def _forget_job(self, job):
        self._jobs.discard(job)
        job.deleteLater()

    @Property(QObject, constant=True)
    def messageModel(self):
        return self.messages

    @Property(str, notify=changed)
    def endpoint(self): return self._endpoint
    @Property(str, notify=changed)
    def model(self): return self._model
    @Property("QStringList", notify=changed)
    def models(self): return self._models
    @Property("QStringList", notify=changed)
    def modelCapabilities(self): return self._model_capabilities
    @Property(bool, notify=changed)
    def modelCapabilitiesLoading(self): return self._capability_probe_active
    @Property(bool, notify=changed)
    def modelSupportsTools(self): return "tools" in self._model_capabilities
    @Property(bool, notify=changed)
    def modelSupportsVision(self): return "vision" in self._model_capabilities
    @Property(bool, notify=changed)
    def modelSupportsThinking(self): return "thinking" in self._model_capabilities
    @Property(str, notify=changed)
    def modelCapabilitySummary(self):
        if self._capability_probe_active:
            return "Checking capabilities…"
        if self._capability_error:
            return "Capabilities unavailable"
        labels = ["Chat"]
        if "tools" in self._model_capabilities:
            labels.append("Tools")
        if "vision" in self._model_capabilities:
            labels.append("Vision")
        if "thinking" in self._model_capabilities:
            labels.append("Thinking")
        return " · ".join(labels)
    @Property(str, notify=changed)
    def modelCapabilityHint(self):
        if self._capability_probe_active:
            return f"Checking what {self._model} can do before desktop work starts."
        if self._capability_error:
            return f"Could not read this model's capabilities: {self._capability_error}"
        tools = "tools" in self._model_capabilities
        vision = "vision" in self._model_capabilities
        if tools and vision:
            return "Ready for visual desktop control: this model advertises both tools and vision."
        if tools:
            return "This model can use non-visual desktop tools, but mouse and keyboard control needs vision too."
        return "Chat is available, but this model does not advertise desktop tool calling."
    @Property(bool, notify=changed)
    def online(self): return self._online
    @Property(bool, notify=changed)
    def busy(self): return self._busy
    @Property(bool, notify=changed)
    def connecting(self): return self._connecting
    @Property(bool, notify=changed)
    def pulling(self): return self._pulling
    @Property(str, notify=changed)
    def pullProgress(self): return self._pull_progress
    @Property(str, notify=changed)
    def status(self): return self._status
    @Property(str, notify=changed)
    def error(self): return self._error
    @Property(bool, notify=changed)
    def hasMessages(self): return bool(self.messages.items)
    @Property(bool, notify=changed)
    def desktopEnabled(self): return bool(self._desktop_status.get("connected"))
    @Property(str, notify=changed)
    def desktopBackend(self): return self._desktop_status.get("backend", "Unavailable")
    @Property(str, notify=changed)
    def desktopDetail(self): return self._desktop_status.get("detail", "Desktop access is off")
    @Property(str, notify=changed)
    def taskTitle(self): return self._task_title
    @Property(str, notify=changed)
    def taskId(self): return self._task_id
    @Property(str, notify=changed)
    def tokenRate(self): return self._token_rate
    @Property(bool, notify=changed)
    def thinking(self): return self._think
    @Property(bool, notify=changed)
    def reducedMotion(self): return self._reduced_motion
    @Property(str, notify=changed)
    def theme(self): return self._theme
    @Property(str, notify=changed)
    def accentColor(self): return self._accent
    @Property(bool, notify=changed)
    def solidBackground(self): return self._solid_background
    @Property(str, notify=changed)
    def thinkingText(self): return self._thinking_text
    @Property(bool, notify=changed)
    def thinkingActive(self): return self._busy and bool(self._thinking_text)
    @Property(int, notify=changed)
    def numCtx(self): return self._num_ctx
    @Property(float, notify=changed)
    def temperature(self): return self._temperature
    @Property(str, notify=changed)
    def keepAlive(self): return self._keep_alive
    @Property(int, notify=changed)
    def maxSteps(self): return self._max_steps
    @Property(str, notify=changed)
    def runtimePreset(self): return self._runtime_preset
    @Property(str, notify=changed)
    def runtimeSummary(self):
        return f"{self._runtime_preset} · {self._num_ctx // 1024}K ctx · T{self._temperature:g} · {self._max_steps} actions"
    @Property(str, notify=changed)
    def runMetricSummary(self):
        metrics = self._run_metrics
        if not metrics.get("tokens") and not metrics.get("prompt_tokens"):
            return "No generation metrics yet"
        seconds = metrics.get("total_ms", 0.0) / 1000.0
        return (f"{metrics.get('tokens', 0)} out · {metrics.get('prompt_tokens', 0)} prompt · "
                f"{metrics.get('tokens_per_second', 0.0):.1f} tok/s · {seconds:.1f}s")
    @Property(bool, notify=changed)
    def canRegenerate(self):
        return bool(self._task_id and self._history and not self._busy and self._online and not self.desktopEnabled)
    @Property(bool, notify=changed)
    def taskPinned(self):
        return any(item.get("id") == self._task_id and bool(item.get("pinned")) for item in self._tasks)
    @Property("QVariantList", notify=tasksChanged)
    def tasks(self): return self._tasks
    @Property("QVariantList", notify=activityChanged)
    def activity(self): return self._activity

    def _refresh_model_capabilities(self):
        self._capability_probe_generation += 1
        generation = self._capability_probe_generation
        model, endpoint = self._model, self._endpoint
        self._model_capabilities = []
        self._capability_error = ""
        if not self._online or not model or model not in self._models:
            self._capability_probe_active = False
            self.changed.emit()
            return
        self._capability_probe_active = True
        self.changed.emit()

        def done(capabilities):
            if generation != self._capability_probe_generation:
                return
            self._capability_probe_active = False
            self._model_capabilities = sorted({
                str(capability).strip().lower()
                for capability in capabilities if str(capability).strip()
            })
            self._capability_error = ""
            self.changed.emit()

        def failed(message):
            if generation != self._capability_probe_generation:
                return
            self._capability_probe_active = False
            self._model_capabilities = []
            self._capability_error = message
            self.changed.emit()

        self._job(lambda cancel, emit: OllamaClient(endpoint).capabilities(model), done, failed)

    @Slot()
    def refreshModels(self):
        if self._probe_active:
            return
        self._probe_active = True
        self._capability_probe_generation += 1
        self._capability_probe_active = False
        self._model_capabilities = []
        self._capability_error = ""
        endpoint = self._endpoint
        def done(models):
            self._probe_active = False
            self._models = [m["name"] for m in models]
            self._online = True
            if self._model not in self._models and self._models:
                self._model = "qwen3.8:27b" if "qwen3.8:27b" in self._models else self._models[0]
                self.store.set_setting("model", self._model)
            self._error = "" if self._models else "Ollama is connected. Download a model in Settings to get started."
            self.changed.emit()
            self._refresh_model_capabilities()
        def failed(message):
            self._probe_active = False
            self._online = False
            self._models = []
            self._model_capabilities = []
            self._capability_probe_active = False
            self._capability_error = ""
            self._error = f"Ollama is unavailable at {endpoint}. Start Ollama, then reconnect. {message}"
            self.changed.emit()
        self._job(lambda cancel, emit: OllamaClient(endpoint).models(), done, failed)

    @Slot(str)
    def setModel(self, model):
        if self._busy or self._pulling or not model.strip(): return
        model = model.strip()
        if model == self._model and self._model_capabilities:
            return
        self._model = model
        self.store.set_setting("model", self._model)
        self._refresh_model_capabilities()

    def _persist_runtime(self):
        for key, value in (("num_ctx", self._num_ctx), ("temperature", self._temperature),
                           ("keep_alive", self._keep_alive), ("max_steps", self._max_steps),
                           ("runtime_preset", self._runtime_preset)):
            self.store.set_setting(key, value)

    @Slot(str)
    def applyRuntimePreset(self, name):
        if self._busy or name not in self.RUNTIME_PRESETS:
            return
        preset = self.RUNTIME_PRESETS[name]
        self._num_ctx = preset["num_ctx"]
        self._temperature = preset["temperature"]
        self._keep_alive = preset["keep_alive"]
        self._max_steps = preset["max_steps"]
        self._runtime_preset = name
        self._persist_runtime()
        self.changed.emit()
        self.toast.emit(f"{name} runtime preset applied")

    @Slot(str, str, str, str, result=bool)
    def saveRuntimeSettings(self, num_ctx, temperature, keep_alive, max_steps):
        if self._busy:
            self.toast.emit("Stop the current task before changing runtime settings.")
            return False
        try:
            ctx = int(str(num_ctx).strip())
            temp = float(str(temperature).strip())
            steps = int(str(max_steps).strip())
        except ValueError:
            self._show_error("Runtime values must be valid numbers.")
            return False
        keep = str(keep_alive).strip()
        if not 2048 <= ctx <= 131072:
            self._show_error("Context size must be between 2048 and 131072 tokens.")
            return False
        if not 0.0 <= temp <= 2.0:
            self._show_error("Temperature must be between 0 and 2.")
            return False
        if not 1 <= steps <= 100:
            self._show_error("Desktop action budget must be between 1 and 100.")
            return False
        if not keep or len(keep) > 32 or any(ch.isspace() for ch in keep):
            self._show_error("Keep-alive must look like 5m, 30s, 0, or -1.")
            return False
        self._num_ctx, self._temperature, self._keep_alive, self._max_steps = ctx, temp, keep, steps
        self._runtime_preset = "Custom"
        self._persist_runtime()
        self._error = ""
        self.changed.emit()
        self.toast.emit("Runtime settings saved")
        return True

    @staticmethod
    def _normalise_accent(value):
        color = QColor(str(value).strip())
        if not color.isValid() or color.alpha() != 255:
            return None
        return color.name(QColor.HexRgb)

    @Slot(str, bool, bool, str, str, bool, result=bool)
    def saveSettings(self, endpoint, thinking, reduced_motion, theme, accent, solid_background):
        if self._busy or self._pulling or self._probe_active:
            self.toast.emit("Wait for the current connection or task to finish.")
            return False
        try:
            OllamaClient(endpoint.strip())
        except Exception as exc:
            self._show_error(str(exc))
            return False
        theme = theme if theme in self.THEMES else "Obsidian"
        accent = self._normalise_accent(accent)
        if accent is None:
            self._show_error("Accent color must be an opaque hex color, such as #b9dfc6.")
            return False
        self._endpoint = endpoint.strip().rstrip("/")
        self._think = thinking
        self._reduced_motion = reduced_motion
        self._theme = theme
        self._accent = accent
        self._solid_background = bool(solid_background)
        for key, value in (("endpoint", self._endpoint), ("think", thinking), ("reduced_motion", reduced_motion),
                           ("theme", theme), ("accent", accent), ("solid_background", self._solid_background)):
            self.store.set_setting(key, value)
        self.changed.emit()
        self.refreshModels()
        self.toast.emit("Settings saved")
        return True

    @Slot()
    def newTask(self):
        if self._busy:
            self.toast.emit("Stop the current task before starting another.")
            return
        self._task_id = ""
        self._task_title = "New task"
        self._history = []
        self.messages.replace([])
        self._activity = []
        self._status = "Ready when you are"
        self._error = ""
        self._token_rate = "—"
        self._thinking_text = ""
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self.activityChanged.emit()
        self.changed.emit()
        self.focusComposer.emit()

    @Slot(str)
    def openTask(self, task_id):
        if self._busy: return
        task = self.store.get_conversation(task_id)
        if not task: return
        self._task_id = task_id
        self._task_title = task["title"]
        self._history = self.store.get_messages(task_id)
        self.messages.replace(self._history)
        self._activity = []
        self._thinking_text = ""
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self._status = "Ready when you are"
        self.activityChanged.emit()
        self.changed.emit()

    @Slot(str)
    def deleteTask(self, task_id):
        if self._busy: return
        self.store.delete_conversation(task_id)
        if task_id == self._task_id: self.newTask()
        self._refresh_tasks()

    @Slot(str)
    def renameTask(self, title):
        if self._task_id and title.strip():
            self._task_title = title.strip()[:120]
            self.store.rename_conversation(self._task_id, self._task_title)
            self._refresh_tasks()
            self.changed.emit()

    def _refresh_tasks(self):
        self._tasks = self.store.list_conversations()
        self.tasksChanged.emit()

    def _start_run(self, history):
        self._busy = True
        self._error = ""
        self._status = "Thinking about your task"
        self._token_rate = "—"
        self._thinking_text = ""
        self._turn_had_message = False
        self._activity = []
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self.activityChanged.emit()
        self._refresh_tasks()
        self.changed.emit()
        engine = AgentEngine(OllamaClient(self._endpoint), self.desktop)
        model, enabled, think = self._model, self.desktopEnabled, self._think
        num_ctx, temperature = self._num_ctx, self._temperature
        keep_alive, max_steps = self._keep_alive, self._max_steps
        self._run_job = self._job(
            lambda cancel, emit: engine.run(list(history), model, enabled, cancel, emit, think=think,
                max_steps=max_steps, num_ctx=num_ctx, temperature=temperature, keep_alive=keep_alive),
            self._run_done, self._run_failed, self._on_event,
        )

    @Slot(str)
    def send(self, text):
        text = text.strip()
        if not text or self._busy or self._connecting: return
        if not self._online:
            self._show_error("Connect to Ollama in Settings before sending a task.")
            return
        if not self._task_id:
            task = self.store.create_conversation(text[:64], self._model)
            self._task_id, self._task_title = task["id"], task["title"]
        self._history.append({"role": "user", "content": text})
        self.store.set_messages(self._task_id, self._history, self._model)
        self.messages.append("user", text)
        self._start_run(list(self._history))

    @Slot()
    def regenerate(self):
        if self._busy or not self._task_id or not self._online:
            return
        if self.desktopEnabled:
            self.toast.emit("Disable desktop control before regenerating so actions are not repeated.")
            return
        history = list(self._history)
        while history and history[-1].get("role") != "user":
            history.pop()
        if not history:
            self.toast.emit("There is no user message to regenerate.")
            return
        self._history = history
        self.store.set_messages(self._task_id, history, self._model)
        self.messages.replace(history)
        self._start_run(history)

    @Slot()
    def duplicateTask(self):
        if self._busy or not self._task_id:
            return
        task = self.store.create_conversation(f"{self._task_title} copy"[:200], self._model)
        self.store.set_messages(task["id"], list(self._history), self._model)
        self._refresh_tasks()
        self.openTask(task["id"])
        self.toast.emit("Task duplicated")

    @Slot()
    def clearTask(self):
        if self._busy or not self._task_id:
            return
        self._history = []
        self.store.set_messages(self._task_id, [], self._model)
        self.messages.replace([])
        self._activity = []
        self._thinking_text = ""
        self._token_rate = "—"
        self._run_metrics = {"tokens": 0, "prompt_tokens": 0, "cached_prompt_tokens": 0,
                             "load_ms": 0.0, "total_ms": 0.0, "tokens_per_second": 0.0}
        self._status = "Ready when you are"
        self.activityChanged.emit()
        self._refresh_tasks()
        self.changed.emit()
        self.toast.emit("Conversation cleared")

    @Slot(str)
    def togglePin(self, task_id):
        task = self.store.get_conversation(task_id)
        if not task:
            return
        self.store.set_pinned(task_id, not bool(task.get("pinned")))
        self._refresh_tasks()
        self.changed.emit()

    def _on_event(self, event):
        kind = event.get("type")
        if kind in ("token", "thinking"):
            if not self._turn_had_message:
                self.messages.append("assistant")
                self._turn_had_message = True
            self.messages.stream("body" if kind == "token" else "thought", event.get("text", ""))
            if kind == "thinking":
                self._thinking_text = (self._thinking_text + event.get("text", ""))[-8000:]
            self._status = "Writing a response" if kind == "token" else "Thinking about your task"
        elif kind == "message_end":
            self._turn_had_message = False
        elif kind == "status":
            self._status = event.get("text", "Working")
        elif kind == "tool_start":
            name = event.get("name", "action")
            args = event.get("args", {})
            detail = json.dumps(args, ensure_ascii=False)
            self._activity.append({"name": name.replace("_", " "), "detail": detail[:180], "state": "running"})
            self._activity = self._activity[-50:]
            self._status = name.replace("_", " ").capitalize()
            self.activityChanged.emit()
        elif kind == "tool_end":
            result = event.get("result", {})
            if self._activity:
                self._activity[-1] = {**self._activity[-1], "state": "failed" if result.get("error") or result.get("ok") is False else "done"}
                self.activityChanged.emit()
        elif kind == "metrics":
            rate = event.get("tokens_per_second", 0)
            previous = self._run_metrics
            self._run_metrics = {
                "tokens": previous.get("tokens", 0) + int(event.get("tokens", 0) or 0),
                "prompt_tokens": int(event.get("prompt_tokens", 0) or 0),
                "cached_prompt_tokens": int(event.get("cached_prompt_tokens", 0) or 0),
                "load_ms": previous.get("load_ms", 0.0) + float(event.get("load_ms", 0.0) or 0.0),
                "total_ms": previous.get("total_ms", 0.0) + float(event.get("total_ms", 0.0) or 0.0),
                "tokens_per_second": float(rate) if isinstance(rate, (int, float)) else 0.0,
            }
            self._token_rate = f"{rate:.1f} tok/s" if isinstance(rate, (int, float)) else "—"
        elif kind == "error":
            self._error = event.get("text", "Something went wrong")
        elif kind == "cancelled":
            self._status = "Stopped"
        self.changed.emit()

    def _run_done(self, history):
        self._history = history
        self.store.set_messages(self._task_id, history, self._model)
        # Keep the rendered stream on screen; storage drops ephemeral screenshots.
        stopped = self._run_job and self._run_job.cancel.is_set()
        self._busy = False
        self._run_job = None
        self._thinking_text = ""
        self._status = "Stopped" if stopped else ("Needs attention" if self._error else "Ready when you are")
        self._refresh_tasks()
        self.changed.emit()

    def _run_failed(self, message):
        self._busy = False
        self._run_job = None
        self._thinking_text = ""
        self._status = "Needs attention"
        self._show_error(message)

    @Slot()
    def stop(self):
        if self._run_job:
            self._run_job.cancel.set()
            self._status = "Stopping…"
            self.changed.emit()

    @Slot()
    def toggleDesktop(self):
        if self._connecting: return
        if self.desktopEnabled:
            self.stop()
            # Revoke input immediately at the desktop backend, independent of generation.
            self._job(lambda cancel, emit: self.desktop.disconnect(), self._desktop_done)
        else:
            if self._busy:
                self.toast.emit("Enable desktop control before starting your task.")
                return
            self._connecting = True
            self.changed.emit()
            self._job(lambda cancel, emit: self.desktop.connect(), self._desktop_done, self._desktop_failed)

    def _desktop_done(self, result):
        self._connecting = False
        self._desktop_status = self.desktop.status()
        if not self.desktopEnabled and result and not result.get("connected"):
            self._show_error(result.get("detail", "Desktop connection was not granted"))
        self.changed.emit()

    def _desktop_failed(self, message):
        self._connecting = False
        self._desktop_status = self.desktop.status()
        self._show_error(message)

    @Slot(str)
    def pullModel(self, model):
        model = model.strip()
        if self._pulling or self._busy or not model: return
        self._pulling = True
        self._pull_progress = "Preparing download…"
        self.changed.emit()
        endpoint = self._endpoint
        def pull(cancel, emit):
            for progress in OllamaClient(endpoint).pull(model, cancel):
                emit(progress)
        def progress(data):
            total, completed = data.get("total", 0), data.get("completed", 0)
            percent = f" · {100 * completed / total:.0f}%" if total else ""
            self._pull_progress = data.get("status", "Downloading") + percent
            self.changed.emit()
        def done(_):
            stopped = self._pull_job and self._pull_job.cancel.is_set()
            self._pulling = False
            self._pull_job = None
            self._pull_progress = "Download stopped" if stopped else "Download complete"
            if not stopped: self.setModel(model)
            self.changed.emit()
            self.refreshModels()
        def failed(message):
            self._pulling = False
            self._pull_job = None
            self._pull_progress = "Download failed"
            self._show_error(message)
        self._pull_job = self._job(pull, done, failed, progress)

    @Slot()
    def cancelPull(self):
        if self._pull_job: self._pull_job.cancel.set()

    @Slot(str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)
        self.toast.emit("Copied to clipboard")

    @Slot()
    def exportTask(self):
        if not self._task_id: return
        from PySide6.QtWidgets import QFileDialog
        target, _ = QFileDialog.getSaveFileName(None, "Export conversation", "wynxo-task.md", "Markdown (*.md)")
        if not target: return
        text = f"# {self._task_title}\n\n"
        for message in self.messages.items:
            text += f"## {'You' if message['speaker'] == 'user' else 'Wynxo'}\n\n"
            if message.get("thought"):
                text += f"<details>\n<summary>Reasoning</summary>\n\n{message['thought']}\n\n</details>\n\n"
            text += f"{message['body']}\n\n"
        try:
            Path(target).write_text(text, encoding="utf-8")
            self.toast.emit("Conversation exported")
        except OSError as exc: self._show_error(str(exc))

    @Slot()
    def clearError(self):
        self._error = ""
        self.changed.emit()

    def _show_error(self, message):
        self._error = message
        self.changed.emit()

    @Slot(result=bool)
    def canClose(self):
        if self._jobs:
            for job in self._jobs: job.cancel.set()
            self._status = "Stopping background work…"
            self.changed.emit()
            return False
        return True

    def shutdown(self):
        for job in list(self._jobs):
            job.cancel.set()
        for job in list(self._jobs):
            job.wait(2000)
        self.desktop.disconnect()
        self.store.close()