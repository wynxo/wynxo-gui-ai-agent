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
        assert empty.taskTitle == "New task"
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
        names = [entry["name"] for entry in bridge.modelCatalog]
        assert set(names) == {entry["name"] for entry in CATALOG}
        # Selected first, then favourites, then everything else.
        assert names[0] == bridge.model
        favourites = {entry["name"] for entry in CATALOG if entry["favorite"]}
        assert set(names[:len(favourites)]) == favourites
    finally:
        bridge.shutdown()


def test_every_declared_scene_can_be_built():
    for name, scene, overlay in SCENES:
        bridge = DemoController(scene)
        try:
            assert bridge.appVersion
        finally:
            bridge.shutdown()


def test_every_scene_names_a_project_so_the_hierarchy_is_visible():
    """The redesign puts the project above the task list; a screenshot without
    one shows an empty state that never happens after first run."""
    for scene in ("conversation", "desktop", "context", "run"):
        bridge = DemoController(scene)
        try:
            assert bridge.projectName == "wynxo-gui-ai-agent"
            assert bridge.projectParentLabel.endswith("Projects")
            assert len(bridge.recentProjects) >= 2
        finally:
            bridge.shutdown()


def test_the_finished_run_scene_settles_every_step():
    """The activity design ends with a summary line, which only appears when
    nothing is still running or waiting."""
    bridge = DemoController("run")
    try:
        steps = [step for item in bridge.messages.items if item["kind"] == "activity"
                 for step in item["steps"]]
        assert len(steps) > 4
        assert {step["state"] for step in steps} == {"done"}
        assert bridge.messages.items[-1]["kind"] == "assistant"
        # The answer is rendered once: segmented blocks plus the open tail.
        answer = bridge.messages.items[-1]
        assert answer["body"].count("KolourPaint is open") == 1
    finally:
        bridge.shutdown()
