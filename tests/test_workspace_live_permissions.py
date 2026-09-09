"""The workspace must not freeze permissions when a task starts."""
import threading

from PySide6.QtCore import QCoreApplication

from wynxo.storage import Store
from wynxo.workspace import WorkspaceController

APP = QCoreApplication.instance() or QCoreApplication([])


class ConnectedDesktop:
    def status(self):
        return {"connected": True, "available": True, "backend": "test", "detail": "on"}

    def disconnect(self):
        return None

    def active_window(self):
        return {"title": "Test", "detail": "test"}


def test_workspace_passes_a_live_permission_provider_to_the_engine(tmp_path, monkeypatch):
    bridge = WorkspaceController(
        store=Store(tmp_path / "history.sqlite3"),
        desktop=ConnectedDesktop(),
        autoconnect=False,
    )
    bridge._online = True
    bridge._model_capabilities = ["completion", "tools", "vision"]
    bridge.newTaskMode("work")
    captured = {}

    class SpyEngine:
        def __init__(self, *args, **kwargs):
            pass

        def run(self, *args, **kwargs):
            captured.update(kwargs)
            return []

    def synchronous_job(fn, result=None, failure=None, event=None):
        fn(threading.Event(), lambda payload: None)
        return None

    monkeypatch.setattr("wynxo.workspace.PlanningAgentEngine", SpyEngine)
    monkeypatch.setattr("wynxo.workspace.OllamaClient", lambda endpoint: None)
    monkeypatch.setattr(bridge, "_job", synchronous_job)

    bridge.send("do a task")

    provider = captured["permission_mode"]
    assert callable(provider)
    assert provider() == "safe"

    # setPermissionMode deliberately works while a run is active. The provider
    # captured by the worker must observe the new value immediately rather than
    # returning the mode that existed when send() started the task.
    bridge.setPermissionMode("manual")
    assert provider() == "manual"
    bridge.setPermissionMode("full")
    assert provider() == "full"

    bridge._busy = False
    bridge.shutdown()
