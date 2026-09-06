"""Task-scoped Chat / Work / Wynxi behavior."""
from PySide6.QtCore import QCoreApplication

from wynxo.storage import Store
from wynxo.workspace import WorkspaceController

APP = QCoreApplication.instance() or QCoreApplication([])


class IdleDesktop:
    def __init__(self, connected=False):
        self.connected = connected

    def status(self):
        return {"connected": self.connected, "available": True,
                "backend": "test", "detail": "Off"}

    def connect(self):
        self.connected = True
        return self.status()

    def disconnect(self):
        self.connected = False

    def active_window(self):
        return {"title": "Terminal", "detail": "test"}


def controller(tmp_path, connected=False):
    return WorkspaceController(
        store=Store(tmp_path / "history.sqlite3"),
        desktop=IdleDesktop(connected), autoconnect=False,
    )


def test_new_wynxo_task_starts_unlocked_and_chat_choice_locks(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.taskMode == "chat"
    assert bridge.taskModeLocked is False
    assert bridge.productName == "Wynxo"

    assert bridge.setTaskMode("chat") is True
    assert bridge.taskMode == "chat"
    assert bridge.taskModeLocked is True
    assert bridge.setTaskMode("codex") is False
    bridge.shutdown()


def test_wynxi_starts_as_locked_coding_task(tmp_path):
    bridge = controller(tmp_path)
    bridge.newTaskMode("codex")
    assert bridge.taskMode == "codex"
    assert bridge.taskModeLocked is True
    assert bridge.productName == "Wynxi"
    bridge.shutdown()


def test_first_send_persists_chat_mode_and_reopen_restores_it(tmp_path, monkeypatch):
    bridge = controller(tmp_path)
    bridge._online = True
    bridge._model_capabilities = ["completion", "tools"]
    monkeypatch.setattr(bridge, "_start_run", lambda history: None)

    bridge.send("hello from a permanent chat")
    task_id = bridge.taskId
    assert task_id
    assert bridge.taskModeLocked is True
    assert bridge.store.get_setting(f"task_mode:{task_id}") == "chat"

    bridge.newTaskMode("codex")
    assert bridge.taskMode == "codex"
    bridge.openTask(task_id)
    assert bridge.taskMode == "chat"
    assert bridge.taskModeLocked is True
    assert bridge.productName == "Wynxo"
    bridge.shutdown()


def test_reopening_saved_wynxi_task_restores_wynxi(tmp_path):
    bridge = controller(tmp_path)
    task = bridge.store.create_conversation("Fix the parser", "qwen3:8b")
    bridge.store.set_messages(task["id"], [{"role": "user", "content": "Fix parser"}])
    bridge.store.set_setting(f"task_mode:{task['id']}", "codex")

    bridge.openTask(task["id"])
    assert bridge.taskMode == "codex"
    assert bridge.taskModeLocked is True
    assert bridge.productName == "Wynxi"
    bridge.shutdown()


def test_work_mode_is_task_scoped(tmp_path):
    bridge = controller(tmp_path, connected=True)
    assert bridge.setTaskMode("work") is True
    assert bridge.taskMode == "work"
    assert bridge.taskModeLocked is True

    # A fresh Wynxo task never inherits Work merely because the desktop portal
    # is still connected; visual control is enabled only by the task mode.
    bridge.newTask()
    assert bridge.taskMode == "chat"
    assert bridge.taskModeLocked is False
    bridge.shutdown()
