"""The side panel as the interface sees it: terminal, files and browser."""
import time

import pytest
from PySide6.QtCore import QCoreApplication

from wynxo import webview
from wynxo.controller import Controller
from wynxo.engine import ASK, AUTO
from wynxo.storage import Store

APP = QCoreApplication.instance() or QCoreApplication([])


class IdleDesktop:
    def status(self):
        return {"connected": False, "available": True, "backend": "test", "detail": "Off"}

    def disconnect(self):
        pass


@pytest.fixture
def controller(tmp_path):
    """Build controllers that outlive the test body.

    Qt deletes a job thread through the event loop, so a controller Python
    collects while a deferred delete is still queued takes the next
    ``processEvents`` down with it. Holding every controller until teardown, and
    flushing the loop before dropping it, keeps that out of the tests.
    """
    made = []

    def build(**kwargs):
        # Out of the way, so the file tree tests only see what they created.
        store = Store(tmp_path / "state" / "history.sqlite3")
        bridge = Controller(store=store, desktop=IdleDesktop(), autoconnect=False, **kwargs)
        made.append(bridge)
        return bridge

    yield build
    for bridge in made:
        bridge.shutdown()
        APP.processEvents()
        bridge.store.close()


@pytest.fixture
def project(tmp_path):
    """A workspace folder of its own, with none of the test's own scaffolding."""
    path = tmp_path / "project"
    path.mkdir()
    return path


def settle(bridge, predicate, timeout=10.0):
    """Drive the event loop until a worker thread has reported back."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        APP.processEvents()
        if predicate():
            return True
        time.sleep(0.01)
    return False


def rows(bridge):
    model = bridge.terminal
    return [{role.decode(): model.data(model.index(row, 0), key)
             for key, role in model.ROLES.items()}
            for row in range(model.rowCount())]


# ----------------------------------------------------------------- the shell
def test_the_panel_remembers_how_you_left_it(controller):
    bridge = controller()
    assert bridge.panelOpen is True          # visible on a first run, or nobody finds it
    assert bridge.panelTab == "terminal"
    bridge.setPanelTab("files")
    bridge.setPanelOpen(False)
    bridge.setPanelWidth(520)

    again = controller()
    assert (again.panelOpen, again.panelTab, again.panelWidth) == (False, "files", 520)


def test_the_panel_width_stays_within_something_usable(controller, tmp_path):
    bridge = controller()
    bridge.setPanelWidth(10)
    assert bridge.panelWidth == 300
    bridge.setPanelWidth(4000)
    assert bridge.panelWidth == 780


def test_an_unknown_tab_is_ignored_rather_than_shown(controller, tmp_path):
    bridge = controller()
    bridge.setPanelTab("nonsense")
    assert bridge.panelTab == "terminal"
    assert [tab["id"] for tab in bridge.panelTabs] == ["terminal", "files", "browser"]


def test_a_run_never_moves_the_panel_you_chose(controller, tmp_path):
    """The panel counts what happened; it does not take the view from you."""
    bridge = controller()
    bridge.setPanelTab("files")
    bridge._on_event({"type": "tool_start", "name": "run_command",
                      "args": {"command": "ls"}, "summary": "Run ls"})
    assert bridge.panelTab == "files"
    assert bridge.panelOpen is True
    assert bridge.panelUnseen == 1
    assert [tab["unseen"] for tab in bridge.panelTabs][0] == 1

    # Looking at the tab is what clears it.
    bridge.setPanelTab("terminal")
    assert bridge.panelUnseen == 0


def test_nothing_is_counted_against_the_tab_you_are_watching(controller, tmp_path):
    bridge = controller()
    bridge.setPanelTab("terminal")
    bridge._on_event({"type": "tool_start", "name": "run_command", "args": {"command": "ls"}})
    assert bridge.panelUnseen == 0


# -------------------------------------------------------------- the terminal
def test_a_model_command_streams_into_the_transcript(controller, tmp_path):
    bridge = controller()
    bridge._on_event({"type": "tool_start", "name": "run_command",
                      "args": {"command": "echo hi", "cwd": str(tmp_path)}})
    bridge._on_event({"type": "tool_output", "name": "run_command", "text": "hi\n"})
    bridge._on_event({"type": "tool_end", "name": "run_command", "ms": 40,
                      "result": {"ok": True, "exit_code": 0, "output": "hi\n"}})

    recorded = rows(bridge)
    assert [row["kind"] for row in recorded] == ["command", "output", "exit"]
    assert recorded[0]["text"] == "echo hi"
    assert recorded[0]["source"] == "agent"
    assert recorded[1]["text"] == "hi\n"
    assert recorded[2]["status"] == "ok"


def test_a_refused_command_is_recorded_as_refused(controller, tmp_path):
    bridge = controller()
    bridge._on_event({"type": "tool_start", "name": "run_command",
                      "args": {"command": "rm -rf /"}, "confirming": True})
    bridge._on_event({"type": "tool_end", "name": "run_command", "declined": True,
                      "result": {"ok": False, "declined": True, "error": "The user declined this action."}})
    recorded = rows(bridge)
    assert recorded[0]["status"] == "declined"
    assert "declined" in recorded[-1]["text"]


def test_apps_and_pages_are_noted_but_clicks_are_not(controller, tmp_path):
    bridge = controller()
    bridge._on_event({"type": "tool_start", "name": "open_app", "args": {"app": "kcalc.desktop"}})
    bridge._on_event({"type": "tool_start", "name": "click", "args": {"x": 5, "y": 5}})
    bridge._on_event({"type": "tool_start", "name": "open_url",
                      "args": {"url": "https://example.com"}})
    texts = [row["text"] for row in rows(bridge)]
    assert texts == ["Opening kcalc.desktop", "Showing https://example.com in the browser panel"]


def test_your_own_command_runs_in_the_workspace_and_reports_back(controller, tmp_path):
    bridge = controller()
    bridge.openProject(str(tmp_path))
    bridge.runTerminalCommand("echo hello && pwd")
    assert bridge.terminalBusy is True
    assert settle(bridge, lambda: not bridge.terminalBusy)

    recorded = rows(bridge)
    assert recorded[0]["source"] == "you"
    assert "hello" in recorded[1]["text"]
    assert str(tmp_path.resolve()) in recorded[1]["text"]
    assert recorded[-1]["status"] == "ok"


def test_a_failing_command_keeps_its_exit_status(controller, tmp_path):
    bridge = controller()
    bridge.runTerminalCommand("exit 3")
    assert settle(bridge, lambda: not bridge.terminalBusy)
    assert rows(bridge)[-1]["status"] == "failed"
    assert "3" in rows(bridge)[-1]["text"]


def test_only_one_of_your_commands_runs_at_a_time(controller, tmp_path):
    bridge = controller()
    bridge.runTerminalCommand("sleep 5")
    bridge.runTerminalCommand("echo second")
    assert [row["text"] for row in rows(bridge) if row["kind"] == "command"] == ["sleep 5"]
    bridge.stopTerminalCommand()
    assert settle(bridge, lambda: not bridge.terminalBusy)
    assert rows(bridge)[-1]["status"] == "stopped"


def test_stop_reaches_the_panel_command_too(controller, tmp_path):
    bridge = controller()
    bridge.runTerminalCommand("sleep 5")
    bridge.stop()
    assert settle(bridge, lambda: not bridge.terminalBusy)
    assert rows(bridge)[-1]["status"] == "stopped"


def test_an_empty_command_is_not_a_command(controller, tmp_path):
    bridge = controller()
    bridge.runTerminalCommand("   ")
    assert bridge.terminalEmpty is True


def test_clearing_empties_the_transcript_and_its_badge(controller, tmp_path):
    bridge = controller()
    bridge.setPanelTab("files")
    bridge._on_event({"type": "tool_start", "name": "run_command", "args": {"command": "ls"}})
    assert bridge.panelUnseen == 1
    bridge.clearTerminal()
    assert bridge.terminalEmpty is True and bridge.panelUnseen == 0


def test_the_model_reports_insertions_rather_than_resetting(controller, tmp_path):
    """A repaint of the whole list on every fragment would make it unreadable."""
    bridge = controller()
    inserted, changed, reset = [], [], []
    bridge.terminal.rowsInserted.connect(lambda parent, first, last: inserted.append((first, last)))
    bridge.terminal.dataChanged.connect(lambda a, b, roles: changed.append(a.row()))
    bridge.terminal.modelReset.connect(lambda: reset.append(True))

    bridge.terminal.start("tail -f log")
    bridge.terminal.write("one\n")
    bridge.terminal.write("two\n")
    assert inserted == [(0, 0), (1, 1)]
    assert changed == [1, 1]
    assert reset == []


def test_the_transcript_is_copied_as_a_whole(controller, tmp_path):
    bridge = controller()
    bridge.terminal.start("echo hi")
    bridge.terminal.write("hi\n")
    bridge.terminal.finish(code=0)
    assert bridge.terminal.transcript() == "$ echo hi\nhi\nDone\n"


# ----------------------------------------------------------------- the files
def test_the_tree_follows_the_project_and_forgets_the_old_one(controller, tmp_path):
    first, second = tmp_path / "one", tmp_path / "two"
    (first / "src").mkdir(parents=True)
    (first / "src" / "a.py").write_text("a = 1\n", encoding="utf-8")
    second.mkdir()
    (second / "b.txt").write_text("b\n", encoding="utf-8")

    bridge = controller()
    bridge.openProject(str(first))
    bridge.toggleFolder("src")
    assert [row["name"] for row in bridge.fileRows] == ["src", "a.py"]

    bridge.openProject(str(second))
    assert [row["name"] for row in bridge.fileRows] == ["b.txt"]
    assert bridge.previewActive is False


def test_opening_a_file_previews_it_with_highlighting(controller, tmp_path):
    (tmp_path / "app.py").write_text("def go():\n    return 1\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(tmp_path))
    bridge.openInPanel(str(tmp_path / "app.py"))

    assert bridge.previewActive and bridge.previewName == "app.py"
    assert bridge.previewLanguage == "Python"
    assert "<span" in bridge.previewHtml and "def" in bridge.previewHtml
    assert bridge.previewIsImage is False

    bridge.closePreview()
    assert bridge.previewActive is False and bridge.previewHtml == ""


def test_a_file_outside_the_workspace_is_not_previewed(controller, tmp_path):
    project = tmp_path / "project"
    project.mkdir()
    secret = tmp_path / "secret.txt"
    secret.write_text("nope\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(project))
    bridge.openInPanel(str(secret))
    assert bridge.previewHtml == "" and "outside" in bridge.previewError


def test_a_theme_change_repaints_the_preview(controller, tmp_path):
    (tmp_path / "app.py").write_text("import os\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(tmp_path))
    bridge.openInPanel(str(tmp_path / "app.py"))
    before = bridge.previewHtml
    bridge.setCodePalette({**bridge._code_palette, "keyword": "#ff0000"})
    assert bridge.previewHtml != before and "#ff0000" in bridge.previewHtml


def test_a_file_from_the_tree_can_go_straight_to_the_composer(controller, tmp_path):
    (tmp_path / "notes.md").write_text("# Notes\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(tmp_path))
    bridge.attachFromPanel(str(tmp_path / "notes.md"))
    assert [item["title"] for item in bridge.attachments] == ["notes.md"]


def test_dotfiles_are_a_setting_that_sticks(controller, project):
    (project / ".env").write_text("A=1\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(project))
    assert bridge.fileRows == []
    bridge.setShowHiddenFiles(True)
    assert [row["name"] for row in bridge.fileRows] == [".env"]

    again = controller()
    assert again.showHiddenFiles is True


def test_collapsing_a_folder_forgets_what_was_open_inside_it(controller, project):
    (project / "a" / "b").mkdir(parents=True)
    (project / "a" / "b" / "c.txt").write_text("c\n", encoding="utf-8")
    bridge = controller()
    bridge.openProject(str(project))
    bridge.toggleFolder("a")
    bridge.toggleFolder("a/b")
    assert [row["name"] for row in bridge.fileRows] == ["a", "b", "c.txt"]
    bridge.toggleFolder("a")
    bridge.toggleFolder("a")
    assert [row["name"] for row in bridge.fileRows] == ["a", "b"]


# --------------------------------------------------------------- the browser
def test_an_address_typed_in_the_panel_is_completed(controller, tmp_path):
    bridge = controller()
    bridge.navigate("example.com/docs")
    assert bridge.browserUrl == "https://example.com/docs"
    assert bridge.browserLabel == "example.com"


def test_an_address_that_is_not_a_page_says_so_and_changes_nothing(controller, tmp_path):
    bridge = controller()
    bridge.navigate("https://example.com")
    complaints = []
    bridge.toast.connect(complaints.append)
    bridge.navigate("file:///etc/passwd")
    assert bridge.browserUrl == "https://example.com"
    assert complaints and "http" in complaints[0]


def test_the_model_can_show_a_page_without_reading_it(controller, tmp_path):
    bridge = controller()
    result = bridge._browse("https://docs.python.org/3/")
    APP.processEvents()
    assert result["ok"] and result["url"] == "https://docs.python.org/3/"
    assert "not read" in result["output"]
    assert bridge.browserUrl == "https://docs.python.org/3/"


def test_a_missing_web_engine_is_reported_rather_than_hidden(controller, tmp_path, monkeypatch):
    bridge = controller()
    opened = []
    monkeypatch.setattr("wynxo.notify.open_url", lambda url: opened.append(url) or True)
    bridge._browser_ready = False
    result = bridge._browse("https://example.com")
    APP.processEvents()
    assert "own browser" in result["output"]
    assert opened == ["https://example.com"]


def test_the_browser_switch_can_be_turned_off_from_the_environment(monkeypatch):
    webview.reset()
    monkeypatch.setenv("WYNXO_NO_BROWSER", "1")
    assert webview.available() is False
    assert webview.initialize() is False
    webview.reset()


# ------------------------------------------------------------------ the tool
def test_open_url_is_only_offered_when_something_can_show_a_page():
    from wynxo.engine import TOOLS
    assert "open_url" in {tool["function"]["name"] for tool in TOOLS}


def test_showing_a_page_needs_approval_only_where_everything_else_does():
    from wynxo.engine import action_risk, action_summary, needs_confirmation

    assert action_risk("open_url") == "normal"
    assert needs_confirmation("open_url", ASK) is True
    assert needs_confirmation("open_url", AUTO) is False
    assert action_summary("open_url", {"url": "https://www.example.com/a"}) \
        == "Show example.com in the browser panel"
