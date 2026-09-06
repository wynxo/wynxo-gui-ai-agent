"""Controller behaviour that the interface depends on."""
import threading
import time
from datetime import datetime

import pytest
from PySide6.QtCore import QCoreApplication

from wynxo import context as ctx
from wynxo.controller import Controller, Messages, group_for
from wynxo.engine import ASK, AUTO, SAFE
from wynxo.storage import Store

APP = QCoreApplication.instance() or QCoreApplication([])


class IdleDesktop:
    def __init__(self, connected=False):
        self.connected = connected
        self.captures = []

    def status(self):
        return {"connected": self.connected, "available": True,
                "backend": "test", "detail": "Off"}

    def disconnect(self):
        self.connected = False

    def capture(self, kind="screen", cancel=None):
        self.captures.append(kind)
        return {"ok": True, "image": "AAA", "width": 640, "height": 480, "detail": "Full screen"}

    def active_window(self):
        return {"title": "Firefox", "detail": "X11"}


def controller(tmp_path, **kwargs):
    store = Store(tmp_path / "history.sqlite3")
    return Controller(store=store, desktop=kwargs.pop("desktop", IdleDesktop()),
                      autoconnect=False, **kwargs)


# ------------------------------------------------------------------ sidebar
def test_conversations_group_by_age():
    # Buckets are calendar days, so the reference point is fixed at midday to
    # keep the test independent of when it happens to run.
    now = datetime(2026, 3, 15, 12, 0).timestamp()
    assert group_for(now, now) == "Today"
    assert group_for(now - 2 * 3600, now) == "Today"
    assert group_for(now - 26 * 3600, now) == "Yesterday"
    assert group_for(now - 4 * 86400, now) == "Previous 7 days"
    assert group_for(now - 20 * 86400, now) == "Previous 30 days"
    assert group_for(now - 200 * 86400, now) == "Older"


def test_task_groups_put_pinned_first_and_respect_search(tmp_path):
    bridge = controller(tmp_path)
    alpha = bridge.store.create_conversation("Alpha notes")
    bridge.store.create_conversation("Beta plan")
    bridge.store.set_pinned(alpha["id"], True)
    bridge._refresh_tasks()

    groups = bridge.taskGroups
    assert groups[0]["title"] == "Pinned"
    assert groups[0]["items"][0]["title"] == "Alpha notes"

    bridge.setSearch("beta")
    titles = [item["title"] for group in bridge.taskGroups for item in group["items"]]
    assert titles == ["Beta plan"]

    bridge.setSearch("")
    assert len([i for g in bridge.taskGroups for i in g["items"]]) == 2
    bridge.shutdown()


# -------------------------------------------------------------- attachments
def test_attaching_and_removing_local_context(tmp_path):
    bridge = controller(tmp_path)
    source = tmp_path / "notes.md"
    source.write_text("# Title\ncontent", encoding="utf-8")

    bridge.attachPath(str(source))
    assert bridge.attachmentCount == 1
    assert bridge.attachments[0]["title"] == "notes.md"
    assert bridge.contextUsed > 0

    bridge.removeAttachment(bridge.attachments[0]["id"])
    assert bridge.attachmentCount == 0

    bridge.attachPath(str(source))
    bridge.clearAttachments()
    assert bridge.attachmentCount == 0
    bridge.shutdown()


def test_attaching_a_missing_file_explains_itself_instead_of_raising(tmp_path):
    bridge = controller(tmp_path)
    bridge.attachPath(str(tmp_path / "ghost.txt"))
    assert bridge.attachmentCount == 0
    assert bridge.errorTitle == "That file could not be attached"
    assert "does not exist" in bridge.error
    bridge.shutdown()


def test_file_urls_from_a_drop_are_accepted(tmp_path):
    bridge = controller(tmp_path)
    source = tmp_path / "dropped.txt"
    source.write_text("hi", encoding="utf-8")
    bridge.attachPath("file://" + str(source))
    assert bridge.attachmentCount == 1
    bridge.shutdown()


def test_images_are_dropped_when_the_model_cannot_see(tmp_path, monkeypatch):
    bridge = controller(tmp_path)
    bridge._online = True
    bridge._model_capabilities = ["completion"]
    bridge._attachments = [ctx.make(ctx.IMAGE, "shot.png", image="AAA", width=8, height=8),
                           ctx.make(ctx.FILE, "a.py", path="/tmp/a.py", text="print(1)")]
    monkeypatch.setattr(bridge, "_start_run", lambda history: None)
    bridge.send("look at this")

    payloads = [m for m in bridge._history if m.get("images")]
    assert payloads == []
    assert any("a.py" in str(m.get("content", "")) for m in bridge._history)
    assert bridge.attachmentCount == 0
    bridge.shutdown()


def test_images_reach_a_vision_model(tmp_path, monkeypatch):
    bridge = controller(tmp_path)
    bridge._online = True
    bridge._model_capabilities = ["completion", "vision"]
    bridge._attachments = [ctx.make(ctx.IMAGE, "shot.png", image="AAA", width=8, height=8)]
    monkeypatch.setattr(bridge, "_start_run", lambda history: None)
    bridge.send("what is this")
    assert any(m.get("images") == ["AAA"] for m in bridge._history)
    bridge.shutdown()


def test_capture_failures_offer_a_route_to_the_settings(tmp_path):
    class BrokenDesktop(IdleDesktop):
        def capture(self, kind="screen", cancel=None):
            raise RuntimeError("Portal denied the request")

    bridge = controller(tmp_path, desktop=BrokenDesktop())
    bridge._capture_busy = False
    bridge._capture("screen")
    for _ in range(200):
        APP.processEvents()
        if bridge.errorTitle:
            break
        time.sleep(0.01)
    assert bridge.errorTitle == "Screen capture failed"
    assert [action["action"] for action in bridge.errorActions] == ["desktop"]
    bridge.shutdown()


# ------------------------------------------------------- capability warnings
def test_capability_warning_covers_images_tools_vision_and_thinking(tmp_path):
    bridge = controller(tmp_path, desktop=IdleDesktop(connected=True))
    bridge._online = True

    bridge._model_capabilities = ["completion", "tools", "vision"]
    assert bridge.capabilityWarning == ""

    bridge._model_capabilities = ["completion", "tools"]
    assert "cannot click or type" in bridge.capabilityWarning

    bridge._model_capabilities = ["completion"]
    assert "does not advertise tool calling" in bridge.capabilityWarning

    bridge._attachments = [ctx.make(ctx.IMAGE, "a.png", image="AAA")]
    assert "cannot read images" in bridge.capabilityWarning

    bridge._attachments = []
    bridge._model_capabilities = ["completion", "tools", "vision"]
    bridge._think = True
    assert "does not support thinking" in bridge.capabilityWarning
    bridge.shutdown()


def test_capability_warning_is_silent_while_probing(tmp_path):
    bridge = controller(tmp_path)
    bridge._online = True
    bridge._capability_probe_active = True
    bridge._attachments = [ctx.make(ctx.IMAGE, "a.png", image="AAA")]
    assert bridge.capabilityWarning == ""
    bridge.shutdown()


# ------------------------------------------------------------- permissioning
def test_permission_mode_is_validated_and_persisted(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.permissionMode == SAFE
    bridge.setPermissionMode(ASK)
    assert bridge.permissionMode == ASK
    assert bridge.permissionModeLabel == "Ask"
    assert bridge.store.get_setting("permission_mode") == ASK
    bridge.setPermissionMode("nonsense")
    assert bridge.permissionMode == ASK
    bridge.shutdown()


def test_a_confirmation_blocks_the_worker_until_the_user_answers(tmp_path):
    bridge = controller(tmp_path)
    answers = []

    def worker():
        answers.append(bridge._confirm_action("type_text", {"text": "hi"}, "sensitive"))

    thread = threading.Thread(target=worker)
    thread.start()
    for _ in range(200):
        APP.processEvents()
        if bridge.permissionPending:
            break
        time.sleep(0.01)
    assert bridge.permissionPending is True
    assert bridge.permissionSummary == "Type “hi”"
    assert bridge.permissionRisk == "sensitive"

    bridge.resolvePermission(True)
    thread.join(3)
    assert answers == [True]
    assert bridge.permissionPending is False
    bridge.shutdown()


def test_declining_is_reported_back_to_the_worker(tmp_path):
    bridge = controller(tmp_path)
    result = []
    thread = threading.Thread(target=lambda: result.append(
        bridge._confirm_action("press_key", {"keys": ["ctrl", "s"]}, "sensitive")))
    thread.start()
    for _ in range(200):
        APP.processEvents()
        if bridge.permissionPending:
            break
        time.sleep(0.01)
    bridge.resolvePermission(False)
    thread.join(3)
    assert result == [False]
    bridge.shutdown()


def test_allow_rest_of_task_stops_prompting_until_the_run_ends(tmp_path):
    bridge = controller(tmp_path)
    first = []
    thread = threading.Thread(target=lambda: first.append(
        bridge._confirm_action("type_text", {"text": "a"}, "sensitive")))
    thread.start()
    for _ in range(200):
        APP.processEvents()
        if bridge.permissionPending:
            break
        time.sleep(0.01)
    bridge.allowRestOfTask()
    thread.join(3)
    assert first == [True]
    # A second action in the same run goes straight through.
    assert bridge._confirm_action("press_key", {"keys": ["a"]}, "sensitive") is True
    assert bridge.permissionPending is False
    bridge.shutdown()


def test_stopping_denies_a_pending_action(tmp_path):
    bridge = controller(tmp_path)
    result = []
    thread = threading.Thread(target=lambda: result.append(
        bridge._confirm_action("click", {"x": 1, "y": 1}, "normal")))
    thread.start()
    for _ in range(200):
        APP.processEvents()
        if bridge.permissionPending:
            break
        time.sleep(0.01)
    bridge.stop()
    thread.join(3)
    assert result == [False]
    bridge.shutdown()


def test_shutdown_releases_a_worker_waiting_on_approval(tmp_path):
    bridge = controller(tmp_path)
    result = []
    thread = threading.Thread(target=lambda: result.append(
        bridge._confirm_action("click", {"x": 1, "y": 1}, "normal")))
    thread.start()
    for _ in range(200):
        APP.processEvents()
        if bridge.permissionPending:
            break
        time.sleep(0.01)
    bridge.shutdown()
    thread.join(3)
    assert result == [False]


# -------------------------------------------------------------- model catalog
def test_catalog_entries_carry_size_and_quantisation(tmp_path):
    bridge = controller(tmp_path)
    entry = Controller._catalog_entry({
        "name": "gemma3:4b", "size": 3_400_000_000,
        "details": {"family": "gemma3", "parameter_size": "4.3B", "quantization_level": "Q4_K_M"},
    })
    assert entry["parameters"] == "4.3B"
    assert entry["quantization"] == "Q4_K_M"
    assert entry["sizeLabel"].endswith("GB")
    bridge.shutdown()


def test_favourite_models_persist_and_sort_first(tmp_path):
    bridge = controller(tmp_path)
    bridge._catalog = [Controller._catalog_entry({"name": name, "size": 1}) for name in ("zeta", "alpha")]
    bridge.toggleFavoriteModel("zeta")
    assert bridge.store.get_setting("favorite_models") == ["zeta"]
    assert bridge.modelCatalog[0]["name"] == "zeta"
    assert bridge.modelCatalog[0]["favorite"] is True
    bridge.toggleFavoriteModel("zeta")
    assert bridge.store.get_setting("favorite_models") == []
    bridge.shutdown()


def test_selecting_a_model_records_it_as_recent(tmp_path):
    bridge = controller(tmp_path)
    bridge.setModel("gemma3:4b")
    bridge.setModel("qwen3:8b")
    assert bridge.store.get_setting("recent_models")[0] == "qwen3:8b"
    assert bridge.store.get_setting("model") == "qwen3:8b"
    bridge.shutdown()


def test_connection_state_drives_the_status_pill(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.connectionState == "offline"
    bridge._online = True
    assert bridge.connectionState == "connected"
    assert bridge.connectionLabel == "Ollama"
    bridge._pulling = True
    assert bridge.connectionState == "downloading"
    bridge._pulling = False
    bridge._probe_active = True
    assert bridge.connectionState == "connecting"
    bridge.shutdown()


# ------------------------------------------------------------------ settings
def test_appearance_settings_persist_and_reject_bad_values(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.setTheme("Ion") is True
    assert bridge.accentColor == Controller.THEMES["Ion"]
    assert bridge.setTheme("Nope") is False

    assert bridge.setAccent("#123456") is True
    assert bridge.accentColor == "#123456"
    assert bridge.setAccent("not a colour") is False
    assert "not valid" in bridge.errorTitle

    bridge.setDensity("Compact")
    assert bridge.store.get_setting("density") == "Compact"
    bridge.setDensity("Roomy")
    assert bridge.density == "Compact"

    bridge.setFlag("reduced_motion", True)
    assert bridge.reducedMotion is True
    assert bridge.store.get_setting("reduced_motion") is True
    bridge.setFlag("not_a_setting", True)
    bridge.shutdown()


def test_legacy_theme_names_migrate(tmp_path):
    store = Store(tmp_path / "history.sqlite3")
    store.set_setting("theme", "Obsidian")
    bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False)
    assert bridge.theme == "Platinum"
    bridge.shutdown()


def test_endpoint_validation_refuses_remote_servers(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.setEndpoint("http://example.com:11434") is False
    assert "not usable" in bridge.errorTitle
    assert bridge.endpoint == "http://127.0.0.1:11434"
    bridge.shutdown()


def test_onboarding_state_round_trips(tmp_path):
    bridge = controller(tmp_path)
    assert bridge.onboarded is False
    bridge.completeOnboarding()
    assert bridge.onboarded is True
    assert bridge.store.get_setting("onboarded") is True
    bridge.resetOnboarding()
    assert bridge.onboarded is False
    bridge.shutdown()


# ------------------------------------------------------------- conversations
def test_branching_forks_history_at_a_message(tmp_path):
    bridge = controller(tmp_path)
    task = bridge.store.create_conversation("Original", "local:test")
    history = [
        {"role": "user", "content": "one"},
        {"role": "assistant", "content": "first"},
        {"role": "user", "content": "two"},
        {"role": "assistant", "content": "second"},
    ]
    bridge.store.set_messages(task["id"], history, "local:test")
    bridge.openTask(task["id"])

    bridge.branchFrom(1)
    assert bridge.taskTitle == "Original branch"
    assert [m["content"] for m in bridge._history] == ["one", "first"]
    # The original is untouched.
    assert len(bridge.store.get_messages(task["id"])) == 4
    bridge.shutdown()


def test_editing_a_message_rewrites_history_and_reruns(tmp_path, monkeypatch):
    bridge = controller(tmp_path)
    bridge._online = True
    task = bridge.store.create_conversation("Chat", "local:test")
    bridge.store.set_messages(task["id"], [
        {"role": "user", "content": "old question"},
        {"role": "assistant", "content": "old answer"},
    ], "local:test")
    bridge.openTask(task["id"])

    started = []
    monkeypatch.setattr(bridge, "_start_run", lambda history: started.append(list(history)))
    bridge.editMessage(0, "new question")
    assert started == [[{"role": "user", "content": "new question"}]]
    assert bridge.store.get_messages(task["id"]) == [{"role": "user", "content": "new question"}]
    bridge.shutdown()


def test_renaming_and_duplicating_by_id(tmp_path):
    bridge = controller(tmp_path)
    task = bridge.store.create_conversation("First", "local:test")
    bridge.store.set_messages(task["id"], [{"role": "user", "content": "hey"}], "local:test")

    bridge.renameTaskById(task["id"], "Renamed")
    assert bridge.store.get_conversation(task["id"])["title"] == "Renamed"

    bridge.duplicateTaskById(task["id"])
    assert bridge.taskTitle == "Renamed copy"
    assert bridge.store.get_messages(bridge.taskId) == [{"role": "user", "content": "hey"}]
    bridge.shutdown()


def test_regenerate_is_blocked_while_the_desktop_is_live(tmp_path):
    bridge = controller(tmp_path, desktop=IdleDesktop(connected=True))
    bridge._online = True
    task = bridge.store.create_conversation("Chat", "local:test")
    bridge.store.set_messages(task["id"], [{"role": "user", "content": "hey"}], "local:test")
    bridge.openTask(task["id"])
    assert bridge.canRegenerate is False
    toasts = []
    bridge.toast.connect(toasts.append)
    bridge.regenerate()
    assert toasts and "screen control" in toasts[0].lower()
    bridge.shutdown()


def test_context_usage_counts_history_and_attachments(tmp_path):
    bridge = controller(tmp_path)
    bridge._history = [{"role": "user", "content": "x" * 400}]
    before = bridge.contextUsed
    bridge._attachments = [ctx.make(ctx.FILE, "a.py", text="y" * 400)]
    assert bridge.contextUsed > before
    assert 0 < bridge.contextFraction < 1
    assert "context" in bridge.contextSummary
    bridge.shutdown()


# -------------------------------------------------------------------- errors
def test_errors_carry_a_title_and_recovery_actions(tmp_path):
    bridge = controller(tmp_path)
    bridge.send("hello")  # offline
    assert bridge.errorTitle == "Ollama isn't connected"
    assert [action["action"] for action in bridge.errorActions] == ["retry", "settings"]
    bridge.clearError()
    assert bridge.error == "" and bridge.errorActions == []
    bridge.shutdown()


# ------------------------------------------------------------ message model
def test_message_model_folds_tool_calls_into_activity_groups(tmp_path):
    bridge = controller(tmp_path)
    bridge.messages.replace([
        {"role": "user", "content": "go"},
        {"role": "assistant", "content": "working"},
        {"role": "tool", "tool_name": "screenshot", "content": '{"ok": true}'},
        {"role": "tool", "tool_name": "click", "content": '{"ok": false, "error": "missed"}'},
        {"role": "assistant", "content": "done"},
    ])
    kinds = [item["kind"] for item in bridge.messages.items]
    assert kinds == ["user", "assistant", "activity", "assistant"]
    steps = bridge.messages.items[2]["steps"]
    assert [step["state"] for step in steps] == ["done", "failed"]
    assert steps[1]["detail"] == "missed"
    bridge.shutdown()


def test_streaming_assistant_text_produces_blocks_and_a_tail(tmp_path):
    bridge = controller(tmp_path)
    bridge.messages.append_message("assistant", streaming=True)
    for chunk in ["Hello\n", "\n", "```python\n", "x = 1\n"]:
        bridge.messages.stream("body", chunk)
    item = bridge.messages.items[-1]
    assert [block["kind"] for block in item["blocks"]] == ["markdown"]
    assert item["tailKind"] == "code"
    assert item["tailLabel"] == "Python"

    bridge.messages.stream("body", "```\n")
    bridge.messages.finish_stream(2.5)
    item = bridge.messages.items[-1]
    assert [block["kind"] for block in item["blocks"]] == ["markdown", "code"]
    assert item["tail"] == ""
    assert item["streaming"] is False
    assert item["thinkSeconds"] == 2.5
    bridge.shutdown()


def test_activity_steps_append_into_one_group_then_update(tmp_path):
    bridge = controller(tmp_path)
    bridge.messages.append_activity({"name": "screenshot", "icon": "eye", "label": "Inspecting",
                                     "summary": "Capture the screen", "state": "running",
                                     "detail": "", "ms": 0, "output": ""})
    bridge.messages.append_activity({"name": "click", "icon": "cursor", "label": "Clicking",
                                     "summary": "Click at 4, 5", "state": "running",
                                     "detail": "", "ms": 0, "output": ""})
    assert len(bridge.messages.items) == 1
    bridge.messages.update_last_step(state="done", ms=120, output="ok")
    steps = bridge.messages.items[0]["steps"]
    assert len(steps) == 2
    assert steps[0]["state"] == "running"
    assert steps[1]["state"] == "done" and steps[1]["ms"] == 120
    bridge.shutdown()


def test_message_roles_expose_everything_the_delegate_requires(tmp_path):
    bridge = controller(tmp_path)
    names = {value.decode() for value in Messages.ROLES.values()}
    for role in ("kind", "body", "thought", "blocks", "tail", "tailKind",
                 "tailLanguage", "tailLabel", "steps", "streaming",
                 "thinkSeconds", "thinkDone", "speaker"):
        assert role in names
    bridge.shutdown()


# -------------------------------------------------------------- highlighting
def test_the_bridge_exposes_theme_aware_rendering(tmp_path):
    bridge = controller(tmp_path)
    bridge.setCodePalette({"keyword": "#ff0000"})
    assert "#ff0000" in bridge.highlight("def f(): pass", "python")
    bridge.setHtmlPalette({"accent": "#00ff00"})
    assert "#00ff00" in bridge.renderMarkdown("a `b` c")
    bridge.shutdown()


def test_reopening_a_chat_folds_attached_context_into_a_chip(tmp_path):
    bridge = controller(tmp_path)
    task = bridge.store.create_conversation("With context", "local:test")
    history = ctx.build_messages([
        ctx.make(ctx.FILE, "main.py", path="/home/me/main.py", text="print(1)\n" * 50),
    ]) + [
        {"role": "user", "content": "What does this do?"},
        {"role": "assistant", "content": "It prints."},
    ]
    bridge.store.set_messages(task["id"], history, "local:test")
    bridge.openTask(task["id"])

    kinds = [item["kind"] for item in bridge.messages.items]
    assert kinds == ["activity", "user", "assistant"]
    assert bridge.messages.items[0]["steps"][0]["summary"] == "main.py"
    # The file body must not reappear as something the user typed.
    assert all("print(1)" not in item["body"] for item in bridge.messages.items)
    bridge.shutdown()


def test_branching_maps_view_rows_past_folded_groups(tmp_path):
    bridge = controller(tmp_path)
    task = bridge.store.create_conversation("Folded", "local:test")
    history = ctx.build_messages([ctx.make(ctx.FILE, "a.py", path="/a.py", text="x")]) + [
        {"role": "user", "content": "first"},
        {"role": "assistant", "content": "reply one"},
        {"role": "tool", "tool_name": "screenshot", "content": '{"ok": true}'},
        {"role": "user", "content": "second"},
        {"role": "assistant", "content": "reply two"},
    ]
    bridge.store.set_messages(task["id"], history, "local:test")
    bridge.openTask(task["id"])
    assert [item["kind"] for item in bridge.messages.items] == \
           ["activity", "user", "assistant", "activity", "user", "assistant"]

    bridge.branchFrom(2)  # the first assistant reply
    assert [m.get("content") for m in bridge._history][-2:] == ["first", "reply one"]
    bridge.shutdown()


def test_context_estimate_is_cached_rather_than_recomputed_per_token(tmp_path):
    bridge = controller(tmp_path)
    bridge._history = [{"role": "user", "content": "x" * 4000}]
    bridge._recount_history_tokens()
    cached = bridge.contextUsed
    assert cached > 0
    # Streaming emits `changed` constantly; reading the property must not walk
    # the whole conversation again.
    bridge._history.append({"role": "assistant", "content": "y" * 4000})
    assert bridge.contextUsed == cached
    bridge._recount_history_tokens()
    assert bridge.contextUsed > cached
    bridge.shutdown()


def test_a_nearly_full_context_window_is_flagged(tmp_path):
    bridge = controller(tmp_path)
    bridge._online = True
    bridge._model_capabilities = ["completion"]
    bridge._num_ctx = 2048
    bridge._history_tokens = 2000
    assert "nearly fills" in bridge.capabilityWarning
    bridge._history_tokens = 100
    assert bridge.capabilityWarning == ""
    bridge.shutdown()


def test_adjacent_chat_navigation_follows_the_sidebar_order(tmp_path):
    bridge = controller(tmp_path)
    made = [bridge.store.create_conversation(name) for name in ("First", "Second", "Third")]
    bridge.store.set_pinned(made[2]["id"], True)
    bridge._refresh_tasks()

    order = [item["id"] for group in bridge.taskGroups for item in group["items"]]
    assert order[0] == made[2]["id"]          # pinned first

    bridge.openAdjacentTask(1)                # nothing open yet
    assert bridge.taskId == order[0]
    bridge.openAdjacentTask(1)
    assert bridge.taskId == order[1]
    bridge.openAdjacentTask(-1)
    assert bridge.taskId == order[0]
    bridge.openAdjacentTask(-1)               # already at the top
    assert bridge.taskId == order[0]
    bridge.shutdown()


def test_recently_used_models_rank_above_the_rest(tmp_path):
    bridge = controller(tmp_path)
    bridge._catalog = [Controller._catalog_entry({"name": name, "size": 1})
                       for name in ("alpha", "beta", "gamma")]
    bridge._models = ["alpha", "beta", "gamma"]
    bridge.setModel("gamma")
    assert [entry["name"] for entry in bridge.modelCatalog][0] == "gamma"
    assert bridge.modelCatalog[0]["recent"] is True
    assert bridge.modelCatalog[1]["recent"] is False
    bridge.shutdown()
