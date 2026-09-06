"""Task-scoped Chat / Work / Wynxi mode state.

The base Controller intentionally stays focused on conversation, Ollama and
runtime state. WorkspaceController adds the product-level behavior used by the
shell: a new task starts unlocked, choosing Chat or Work locks that task's mode,
and Wynxi creates a permanently coding-focused task. Modes are persisted in the
existing private settings table so old databases need no migration.
"""
from __future__ import annotations

import time

from PySide6.QtCore import Property, Signal, Slot

from .controller import Controller, AgentEngine, OllamaClient, _blank_metrics


class WorkspaceController(Controller):
    modeChanged = Signal()
    VALID_TASK_MODES = {"chat", "work", "codex"}

    def __init__(self, *args, **kwargs):
        self._task_mode = "chat"
        self._task_mode_locked = False
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
        # Controller.newTask() resets conversation state but intentionally knows
        # nothing about product state, so reset that layer before choosing.
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
        # A Work chat should feel like a Work chat when reopened. Reconnect the
        # desktop only for that mode; Chat and Wynxi never gain visual control
        # just because a portal session happens to exist.
        if self._task_mode == "work" and not self.desktopEnabled and not self._connecting:
            self.toggleDesktop()

    @Slot(str)
    def send(self, text):
        was_new = not self._task_id
        # Sending without touching the chooser means Chat, and locks it just as
        # firmly as clicking Chat first.
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
