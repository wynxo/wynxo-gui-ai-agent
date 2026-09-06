import threading

from PySide6.QtCore import QCoreApplication

from wynxo.controller import Controller
from wynxo.engine import AgentEngine
from wynxo.storage import Store


APP = QCoreApplication.instance() or QCoreApplication([])


class IdleDesktop:
    def status(self):
        return {"connected": False, "available": True, "backend": "test", "detail": "Off"}

    def disconnect(self):
        return None


class CaptureClient:
    def __init__(self):
        self.requests = []

    def capabilities(self, model):
        return ["completion"]

    def stream_chat(self, payload, cancel):
        self.requests.append(payload)
        yield {"message": {"role": "assistant", "content": "ok"}, "done": True,
               "eval_count": 8, "eval_duration": 400000000,
               "prompt_eval_count": 120, "prompt_eval_cached_count": 80,
               "load_duration": 50000000, "total_duration": 600000000}


def test_engine_passes_local_runtime_controls_and_emits_rich_metrics():
    client = CaptureClient()
    events = []
    history = AgentEngine(client, IdleDesktop()).run(
        [{"role": "user", "content": "hello"}], "local:test", False,
        threading.Event(), events.append, num_ctx=24576, temperature=0.25,
        keep_alive="9m", max_steps=7,
    )
    assert history[-1]["content"] == "ok"
    payload = client.requests[0]
    assert payload["options"] == {"num_ctx": 24576, "temperature": 0.25}
    assert payload["keep_alive"] == "9m"
    metrics = next(event for event in events if event["type"] == "metrics")
    assert metrics["tokens"] == 8
    assert metrics["prompt_tokens"] == 120
    assert metrics["cached_prompt_tokens"] == 80
    assert metrics["tokens_per_second"] == 20.0


def test_store_migrates_and_sorts_pinned_conversations(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    first = store.create_conversation("First")
    second = store.create_conversation("Second")
    store.set_pinned(first["id"], True)
    items = store.list_conversations()
    assert items[0]["id"] == first["id"]
    assert items[0]["pinned"] == 1
    assert next(item for item in items if item["id"] == second["id"])["pinned"] == 0
    store.close()


def test_runtime_presets_are_persisted(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge.applyRuntimePreset("Fast")
    assert bridge.runtimePreset == "Fast"
    assert bridge.numCtx == 8192
    assert bridge.temperature == 0.35
    assert bridge.maxSteps == 12
    assert store.get_setting("runtime_preset") == "Fast"
    assert bridge.saveRuntimeSettings("20000", "0.55", "7m", "24") is True
    assert bridge.runtimePreset == "Custom"
    assert bridge.numCtx == 20000
    assert bridge.keepAlive == "7m"
    bridge.shutdown()


def test_duplicate_clear_and_regenerate_chat_only(tmp_path, monkeypatch):
    store = Store(tmp_path / "history.sqlite3")
    original = store.create_conversation("Original", "local:test")
    messages = [{"role": "user", "content": "hello"}, {"role": "assistant", "content": "old"}]
    store.set_messages(original["id"], messages, "local:test")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge._online = True
    bridge.openTask(original["id"])

    captured = []
    monkeypatch.setattr(bridge, "_start_run", lambda history: captured.append(list(history)))
    bridge.regenerate()
    assert captured == [[{"role": "user", "content": "hello"}]]

    bridge._history = messages
    bridge.messages.replace(messages)
    bridge.duplicateTask()
    assert bridge.taskTitle == "Original copy"
    assert store.get_messages(bridge.taskId) == messages
    bridge.clearTask()
    assert store.get_messages(bridge.taskId) == []
    bridge.shutdown()


def test_archive_filters_and_busy_guard(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    first = store.create_conversation("First")
    second = store.create_conversation("Second")
    store.set_pinned(first["id"], True)
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge.setChatFilter("pinned")
    assert bridge.visibleChatCount == 1
    bridge.openTask(first["id"])
    bridge._busy = True
    bridge.toggleArchive(first["id"])
    assert store.get_conversation(first["id"])["archived"] == 0
    bridge._busy = False
    bridge.toggleArchive(first["id"])
    assert bridge.taskId == ""
    assert bridge.visibleChatCount == 0
    bridge.setChatFilter("archived")
    assert bridge.visibleChatCount == 1
    bridge.setSearch("Second")
    assert bridge.visibleChatCount == 0
    bridge.setSearch("")
    bridge.toggleArchive(first["id"])
    assert bridge.visibleChatCount == 0
    bridge.setChatFilter("all")
    assert bridge.visibleChatCount == 2
    bridge.shutdown()


def test_switch_clears_stale_attachments_and_title_matches_store(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    first = store.create_conversation("First")
    second = store.create_conversation("Second")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge.openTask(first["id"])
    bridge._attachments = [{"id": "old", "kind": "file"}]
    bridge._error = "Old failure"
    bridge.openTask(second["id"])
    assert bridge.attachments == []
    assert bridge.error == ""
    bridge.renameTaskById(second["id"], "x" * 180)
    assert bridge.taskTitle == store.get_conversation(second["id"])["title"]
    bridge.shutdown()


def test_unsent_drafts_and_attachments_follow_each_chat(tmp_path, monkeypatch):
    store = Store(tmp_path / "history.sqlite3")
    first = store.create_conversation("First")
    second = store.create_conversation("Second")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    bridge.setDraft("New chat draft")
    bridge.openTask(first["id"])
    assert bridge.draftText == ""
    bridge.setDraft("First draft")
    bridge._attachments = [{"id": "first", "kind": "file"}]
    bridge.openTask(second["id"])
    assert bridge.draftText == ""
    assert bridge.attachments == []
    bridge.setDraft("Second draft")
    bridge.openTask(first["id"])
    assert bridge.draftText == "First draft"
    assert bridge.attachments[0]["id"] == "first"
    bridge.newTask()
    assert bridge.draftText == "New chat draft"
    bridge._online = True
    monkeypatch.setattr(bridge, "_start_run", lambda history: None)
    bridge.send("New chat draft")
    bridge.newTask()
    assert bridge.draftText == ""
    bridge.openTask(second["id"])
    assert bridge.draftText == "Second draft"
    bridge.deleteTask(second["id"])
    assert second["id"] not in bridge._drafts
    bridge.shutdown()
