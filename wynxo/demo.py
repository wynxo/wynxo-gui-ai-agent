"""Deterministic demo state for UI previews and screenshots.

``python -m wynxo --ui-preview`` and ``--snapshot`` run the real QML with a
controller whose backend calls are replaced by fixed data. Nothing here touches
the user's history, Ollama, or the desktop: it exists so screenshots show the
actual renderer rather than a mock-up.
"""
from __future__ import annotations

import tempfile
import time
from pathlib import Path

from . import context as ctx
from . import markdown as md
from .controller import Controller
from .storage import Store

ANSWER = """**Firefox** is focused, with `pytest` running in a terminal behind it.
Two tests fail on the same assertion.

### What's failing

| Test | Reason |
| --- | --- |
| `test_context_window` | expected 8192, got 16384 |
| `test_keep_alive` | keep-alive not forwarded |

Same root cause: the options are built before the preset is applied.

```python
def build_options(preset: str, overrides: dict) -> dict:
    # Apply the preset first, then let explicit overrides win.
    options = dict(PRESETS[preset])
    options.update({k: v for k, v in overrides.items() if v is not None})
    return options
```

Want me to open the file and make the change?"""

THINKING = """The user asked what is on screen. I have a screenshot, so I should
describe what is actually visible rather than guess. Two failing tests are
readable in the terminal pane. Both mention runtime options, so the likely cause
is ordering in the options builder. I will summarise, then offer to edit rather
than editing without being asked."""

CONVERSATIONS = [
    ("Debug the failing runtime tests", 0, True),
    ("Draw a mountain scene in KolourPaint", 2400, False),
    ("Summarise this design document", 9000, False),
    ("Plan the 1.0 release", 30 * 3600, False),
    ("Rename the screenshots folder", 32 * 3600, False),
    ("Explain this stack trace", 5 * 86400, False),
    ("Compare two CSV exports", 12 * 86400, False),
    ("Set up a Python project", 40 * 86400, False),
]

CATALOG = [
    {"name": "qwen2.5vl:7b", "family": "qwen2vl", "parameters": "7.6B", "quantization": "Q4_K_M",
     "sizeLabel": "5.6 GB", "sizeBytes": 6_000_000_000, "capabilities": ["completion", "tools", "vision"],
     "favorite": True, "loaded": True, "selected": True},
    {"name": "gemma3:4b", "family": "gemma3", "parameters": "4.3B", "quantization": "Q4_K_M",
     "sizeLabel": "3.3 GB", "sizeBytes": 3_500_000_000, "capabilities": ["completion", "vision"],
     "favorite": True, "loaded": False, "selected": False},
    {"name": "llama3.2:3b", "family": "llama", "parameters": "3.2B", "quantization": "Q4_K_M",
     "sizeLabel": "2.0 GB", "sizeBytes": 2_100_000_000, "capabilities": ["completion", "tools"],
     "favorite": False, "loaded": False, "selected": False},
    {"name": "qwen3:8b", "family": "qwen3", "parameters": "8.2B", "quantization": "Q4_K_M",
     "sizeLabel": "5.2 GB", "sizeBytes": 5_400_000_000, "capabilities": ["completion", "tools", "thinking"],
     "favorite": False, "loaded": False, "selected": False},
    {"name": "deepseek-r1:7b", "family": "qwen2", "parameters": "7.6B", "quantization": "Q4_K_M",
     "sizeLabel": "4.7 GB", "sizeBytes": 4_900_000_000, "capabilities": ["completion", "thinking"],
     "favorite": False, "loaded": False, "selected": False},
    {"name": "nomic-embed-text:latest", "family": "nomic-bert", "parameters": "137M",
     "quantization": "F16", "sizeLabel": "274 MB", "sizeBytes": 274_000_000,
     "capabilities": ["embedding"], "favorite": False, "loaded": False, "selected": False},
]

# A 4x3 slate PNG: enough for the inspector preview to render a real image.
_SWATCH = (
    "iVBORw0KGgoAAAANSUhEUgAAAUAAAAC0CAIAAABqhmJGAAAC8UlEQVR42u3csWrbQBzAYblodp0ORghjTJ8sQ56gY4c+"
    "Qp6gQ5+sGGOM8VIwwXOGQEhbN8W2pLv76/umEJNCjv64O90pk7ZdVkCZPhgCEDAgYOAS9dnvrlafX75Yr392+ynQ7wz8"
    "WuAfX9/+KdBvwN0Wq2GwBwYEDOED/vvJ09vv3PIpMMQM3FWx6oW+TVylBHtgQMCAgGEk6tPpySiAGRgQMCBgEDAgYEDA"
    "gIBBwICAAQGDgAEBAwIGBAwCBgQMCBgQMARQX/dji8XK2HVlu11f+iPT6Z1xi+d4/DVQwFVVHQ57I367+bwxCFhCg4AB"
    "AQMCBgQMAgYEDAgYEDAIGEim7uMfXS5X8UZqs1n774IZGBAwIGAQMJBGbQhKNJ1+3O93xiGSpmmveKHfDAxm4N85cQF7"
    "YEDAIGBAwICAAQGDgAEBA5dzlTKsH98fY/+CX7/l/gvudtsiAw7wQr/LZFhCAwIGBAzxeIgV1v3DF4NgBgYEDJSyhHYG"
    "A2ZgQMAgYGAse2By0LYLg/AvA9xSNgMDAgYBAwIGuuQhVlhhntMwdMDFvdDv6hiW0ICAAQGDgAEBA/1wjBRWoXehnX6l"
    "D9ipDFhCAwIGAQNj2QOTA0+DzMCAgAEBAwIGAQMZGOML/S6KIWBy5+9CJzfASZ4lNNgDAwIGBAxj4SFWWO5CC/hKzmnA"
    "EhoQMAgYEDAgYKCqKsdIgbkL/Y4wZ2xmYBAwIGAg/R44qxf6XQtDwJTHXWhLaEDAgIABAYOAgQx4oR8ETH4KvQvt9MsS"
    "GgQMCBgQMHCGh1hheRpkBgYEDAgYGGIPnPCFfpfAMAMDAgZKXEKTA38XOrkBTvLMwGAJDQgYSL8HdpYDBQdMDtyFtoQG"
    "BAwIGBAwCBgQMCBgEDAgYEDAwP9df5VyPm8MX0JN0xoEJrPZJ6MAltCAgAEBg4ABAQMCBgQMAgYEDAgYBAwIGBAwIGAQ"
    "MCBgQMCAgEHAgIABAYOAAQEDAgYEDAIGBAwIGKieAdhQjRZgDb/uAAAAAElFTkSuQmCC"
)

STEPS = [
    {"name": "screenshot", "icon": "eye", "label": "Inspecting the screen",
     "summary": "Capture the screen", "detail": "{}", "state": "done", "ms": 640,
     "output": "Captured 2560 × 1440 pixels", "risk": "low"},
    {"name": "list_apps", "icon": "grid", "label": "Listing installed apps",
     "summary": "List installed applications", "detail": "{}", "state": "done", "ms": 210,
     "output": "182 applications found", "risk": "low"},
    {"name": "open_app", "icon": "launch", "label": "Opening an application",
     "summary": "Open KolourPaint", "detail": '{"app": "org.kde.kolourpaint"}',
     "state": "done", "ms": 1480, "output": "", "risk": "normal"},
    {"name": "wait", "icon": "clock", "label": "Waiting",
     "summary": "Wait 1.5s", "detail": '{"seconds": 1.5}', "state": "done", "ms": 1500,
     "output": "", "risk": "low"},
    {"name": "click", "icon": "cursor", "label": "Clicking",
     "summary": "Click the left button at 512, 336", "detail": '{"x": 512, "y": 336}',
     "state": "done", "ms": 180, "output": "", "risk": "normal"},
    {"name": "drag", "icon": "paint", "label": "Dragging",
     "summary": "Drag through 24 points", "detail": '{"points": [[420, 620], [512, 470]], "duration": 1.4}',
     "state": "done", "ms": 1420, "output": "", "risk": "normal"},
    {"name": "type_text", "icon": "keyboard", "label": "Typing",
     "summary": "Type “mountains.png”", "detail": '{"text": "mountains.png"}',
     "state": "waiting", "ms": 0, "output": "", "risk": "sensitive"},
]


class DemoDesktop:
    """A desktop backend that reports a healthy session and never acts."""

    def __init__(self, connected: bool = True):
        self.connected = connected

    def status(self):
        return {"backend": "Wayland / Desktop portal", "available": True,
                "connected": self.connected,
                "detail": "Connected through the desktop portal. Screenshot permission "
                          "is managed separately by your desktop.",
                "remembered": self.connected,
                "stopShortcut": "Ctrl+Alt+Esc" if self.connected else "",
                "stopDetail": ""}

    def connect(self):
        self.connected = True
        return self.status()

    def disconnect(self):
        self.connected = False

    def capture(self, kind="screen", cancel=None):
        raise RuntimeError("Screen capture is disabled in preview mode.")

    def active_window(self):
        return {"title": "Firefox", "detail": "X11"}


class DemoController(Controller):
    """The real controller with its network and desktop edges pinned."""

    def __init__(self, scene: str = "conversation"):
        directory = tempfile.mkdtemp(prefix="wynxo-preview-")
        store = Store(Path(directory) / "preview.sqlite3")
        store.set_setting("onboarded", scene != "welcome")
        store.set_setting("model", "qwen2.5vl:7b")
        store.set_setting("permission_mode", "safe")
        store.set_setting("favorite_models", [entry["name"] for entry in CATALOG if entry["favorite"]])
        theme = {
            "empty-violet": "Violet",
            "empty-ember": "Ember",
            "conversation-ion": "Ion",
        }.get(scene)
        if theme:
            store.set_setting("theme", theme)
        super().__init__(store=store, desktop=DemoDesktop(scene in ("desktop", "conversation", "run")),
                         autoconnect=False)
        self._preview_directory = Path(directory)
        self.scene = scene
        self._seed()

    # Preview mode must never reach the network.
    def refreshModels(self):
        self._apply_catalog()

    def _apply_catalog(self):
        self._online = True
        self._probe_active = False
        self._models = [entry["name"] for entry in CATALOG]
        self._catalog = [dict(entry) for entry in CATALOG]
        self._loaded_models = [entry["name"] for entry in CATALOG if entry["loaded"]]
        self._model_capabilities = ["completion", "tools", "vision"]
        self._model_context_length = 128000
        self._capability_probe_active = False
        self._clear_error()
        self._decorate_catalog()
        self.changed.emit()

    def _seed(self):
        now = time.time()
        created = []
        for title, age, pinned in CONVERSATIONS:
            conversation = self.store.create_conversation(title, "qwen2.5vl:7b")
            self.store.set_messages(conversation["id"], [{"role": "user", "content": title}])
            with self.store._lock, self.store._db:
                self.store._db.execute("UPDATE conversations SET updated_at=?,created_at=?,pinned=? WHERE id=?",
                                       (now - age, now - age, 1 if pinned else 0, conversation["id"]))
            created.append(conversation)
        self._apply_catalog()
        self._refresh_tasks()

        self._working_directory = str(Path.home() / "Projects" / "wynxo-gui-ai-agent")
        self._recent_projects = [self._working_directory,
                                 str(Path.home() / "Projects" / "portal-bridge"),
                                 str(Path.home() / "Projects" / "notes")]
        self._task_id = created[0]["id"]
        self._task_title = created[0]["title"]
        self._num_ctx = 16384
        self._run_metrics = {"tokens": 427, "prompt_tokens": 1243, "cached_prompt_tokens": 792,
                             "load_ms": 812.0, "total_ms": 7360.0, "tokens_per_second": 18.6}
        self._token_rate = "18.6 tok/s"

        if self.scene == "welcome":
            self._task_id = ""
            self._task_title = "New task"
            self._onboarded = False
            self.changed.emit()
            return
        if self.scene.startswith("empty"):
            self._task_id = ""
            self._task_title = "New task"
            self.changed.emit()
            return
        if self.scene.startswith("context"):
            self._seed_context_scene()
            return

        self.messages.append_message("user", "What's on my screen? Can you help me fix it?")
        if self.scene == "desktop":
            self._seed_desktop_scene()
            return
        if self.scene == "run":
            self._seed_finished_run()
            return
        self.messages.append_activity(STEPS[0])
        self.messages.update_last_step(**{k: STEPS[0][k] for k in ("state", "ms", "output")})
        self._seed_answer()
        self.changed.emit()

    def _seed_answer(self):
        row = self.messages.append_message("assistant", streaming=False)
        item = self.messages.items[row]
        item["thought"] = THINKING
        item["thinkSeconds"] = 8.2
        item["thinkDone"] = True
        item["body"] = ANSWER
        item["blocks"] = md.segment(ANSWER)
        self.messages._emit(row, list(Messages_roles()))

    def _seed_finished_run(self):
        """A run that is over: every step settled, one summary line."""
        self._task_title = "Draw a mountain scene in KolourPaint"
        finished = []
        for step in STEPS:
            done = dict(step)
            if done["state"] in ("waiting", "running"):
                done["state"] = "done"
                done["ms"] = 240
            finished.append(done)
        finished[-1]["output"] = "Saved as mountains.png"
        for step in finished:
            self.messages.append_activity(step)
        self._activity = [dict(step) for step in finished]
        self.messages.append_message(
            "assistant",
            "Done. KolourPaint is open with a mountain scene on a 1024 × 768 canvas, "
            "saved to **mountains.png** in your pictures folder.\n\n"
            "The ridge line is a single drag through 24 points; the sun is a filled "
            "ellipse. Say the word if you want the colours changed.")
        self.activityChanged.emit()
        self.changed.emit()

    def _seed_context_scene(self):
        """A new message with local context attached, ready to send."""
        self._task_id = ""
        self._task_title = "New task"
        self._attachments = [
            ctx.from_capture({"ok": True, "image": _SWATCH, "width": 2560, "height": 1440},
                             ctx.SCREENSHOT, title="Screen", detail="Full screen"),
            ctx.make(ctx.FILE, "controller.py", path="/home/you/wynxo/controller.py",
                     text="class Controller:\n    pass\n" * 40, subtitle="1240 lines · 38 KB"),
            ctx.make(ctx.FOLDER, "wynxo", path="/home/you/wynxo",
                     text="ui/\ncontroller.py\nengine.py", subtitle="12 items"),
        ]
        self.attachmentsChanged.emit()
        self.changed.emit()

    def _seed_desktop_scene(self):
        self._task_title = "Draw a mountain scene in KolourPaint"
        self._busy = True
        self._status = "Type “mountains.png”"
        for step in STEPS:
            self.messages.append_activity(step)
        self._activity = [dict(step) for step in STEPS]
        self._pending_permission = {
            "tool": "type_text", "risk": "sensitive",
            "summary": "Type “mountains.png”",
            "detail": '{"text": "mountains.png"}',
        }
        self.activityChanged.emit()
        self.permissionChanged.emit()
        self.changed.emit()

    def shutdown(self):
        super().shutdown()
        try:
            self.store.close()
        except Exception:
            pass


def Messages_roles():
    from .controller import Messages
    return (Messages.BODY, Messages.BLOCKS, Messages.THOUGHT,
            Messages.THINK_SECONDS, Messages.THINK_DONE, Messages.STREAMING)


# Scenes captured by --snapshot, in the order the README presents them.
SCENES = [
    ("01-new-task", "empty", ""),
    ("02-task", "conversation", ""),
    ("03-agent-run", "run", ""),
    ("04-permission", "desktop", ""),
    ("05-context", "context", ""),
    ("06-models", "conversation", "modelPicker"),
    ("07-model-manager", "conversation", "models"),
    ("08-settings", "conversation", "settings"),
    ("09-command-palette", "conversation", "palette"),
    ("10-quick-bar", "empty", "quickbar"),
    ("11-welcome", "welcome", "welcome"),
    ("12-appearance", "conversation", "appearanceSettings"),
    ("13-violet-home", "empty-violet", ""),
    ("14-ember-home", "empty-ember", ""),
    ("15-ion-conversation", "conversation-ion", ""),
    ("16-codex-home", "empty", "modeCodex"),
    ("17-work-home", "empty", "modeWork"),
]
