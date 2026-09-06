"""The preview controller keeps --ui-preview and --snapshot honest.

It exercises the real controller with fixed data, so a change that breaks the
screenshot pipeline fails here rather than in CI's rendering step.
"""
from PySide6.QtCore import QCoreApplication

from wynxo.demo import CATALOG, SCENES, DemoController

APP = QCoreApplication.instance() or QCoreApplication([])


def test_preview_never_touches_the_user_history(tmp_path, monkeypatch):
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("XDG_DATA_HOME", str(home))
    bridge = DemoController("conversation")
    try:
        assert str(bridge.store.path).startswith("/tmp") or "wynxo-preview-" in str(bridge.store.path)
        assert not (home / "wynxo").exists()
    finally:
        bridge.shutdown()


def test_conversation_scene_has_everything_a_screenshot_needs():
    bridge = DemoController("conversation")
    try:
        kinds = [item["kind"] for item in bridge.messages.items]
        assert "user" in kinds and "assistant" in kinds and "activity" in kinds
        answer = next(item for item in bridge.messages.items if item["kind"] == "assistant")
        assert any(block["kind"] == "code" for block in answer["blocks"])
        assert answer["thought"] and answer["thinkSeconds"] > 0
        assert bridge.runMetrics["hasData"] is True
        assert len(bridge.taskGroups) >= 3
        assert bridge.online is True
        assert bridge.modelSupportsVision is True
    finally:
        bridge.shutdown()


def test_desktop_scene_shows_a_pending_approval_and_a_timeline():
    bridge = DemoController("desktop")
    try:
        assert bridge.permissionPending is True
        assert bridge.permissionRisk == "sensitive"
        assert bridge.busy is True
        steps = [step for item in bridge.messages.items if item["kind"] == "activity"
                 for step in item["steps"]]
        assert len(steps) == len(bridge.activity) > 4
        assert any(step["state"] == "waiting" for step in steps)
        assert any(step["state"] == "done" for step in steps)
    finally:
        bridge.shutdown()


def test_empty_and_welcome_scenes():
    empty = DemoController("empty")
    try:
        assert empty.hasMessages is False
        assert empty.onboarded is True
        assert empty.taskTitle == "New chat"
    finally:
        empty.shutdown()

    welcome = DemoController("welcome")
    try:
        assert welcome.onboarded is False
    finally:
        welcome.shutdown()


def test_preview_refresh_stays_offline():
    bridge = DemoController("empty")
    try:
        bridge.refreshModels()
        assert bridge.online is True
        assert [entry["name"] for entry in bridge.modelCatalog] == \
               sorted((entry["name"] for entry in CATALOG),
                      key=lambda name: (name not in ("qwen2.5vl:7b", "gemma3:4b"), name.lower()))
    finally:
        bridge.shutdown()


def test_every_declared_scene_can_be_built():
    for name, scene, overlay in SCENES:
        bridge = DemoController(scene)
        try:
            assert bridge.appVersion
        finally:
            bridge.shutdown()
