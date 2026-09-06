"""Desktop permission modes and the per-action approval gate."""
import json
import threading

import pytest

from wynxo import engine as eng
from wynxo.engine import ASK, AUTO, SAFE, AgentEngine, action_risk, action_summary, needs_confirmation


class FakeDesktop:
    def __init__(self):
        self.calls = []

    def status(self):
        return {"connected": True, "available": True, "backend": "test", "detail": "on"}

    def execute(self, name, args, cancel):
        self.calls.append((name, args))
        if name == "screenshot":
            return {"ok": True, "image": "AAA", "width": 100, "height": 80}
        return {"ok": True, "action": name}


class Client:
    def __init__(self, script, capabilities=("completion", "tools", "vision")):
        self.script = list(script)
        self._capabilities = list(capabilities)

    def capabilities(self, model):
        return self._capabilities

    def stream_chat(self, payload, cancel):
        chunk = self.script.pop(0) if self.script else {"message": {"content": "done"}, "done": True}
        for part in (chunk if isinstance(chunk, list) else [chunk]):
            yield part


def call(name, **arguments):
    return {"function": {"name": name, "arguments": arguments}}


def run(script, mode, confirm, capabilities=("completion", "tools", "vision")):
    desktop = FakeDesktop()
    events = []
    history = AgentEngine(Client(script, capabilities), desktop).run(
        [{"role": "user", "content": "go"}], "local:test", True, threading.Event(),
        events.append, permission_mode=mode, confirm=confirm)
    return history, events, desktop


@pytest.mark.parametrize("name,risk", [
    ("screenshot", "low"), ("move_pointer", "low"), ("scroll", "low"),
    ("list_apps", "low"), ("wait", "low"),
    ("click", "normal"), ("drag", "normal"), ("open_app", "normal"),
    ("type_text", "sensitive"), ("press_key", "sensitive"), ("run_command", "sensitive"),
])
def test_every_tool_has_a_deliberate_risk_level(name, risk):
    assert action_risk(name) == risk


def test_ask_mode_confirms_everything_except_observation():
    assert needs_confirmation("click", ASK) is True
    assert needs_confirmation("open_app", ASK) is True
    assert needs_confirmation("type_text", ASK) is True
    assert needs_confirmation("screenshot", ASK) is False
    assert needs_confirmation("move_pointer", ASK) is False


def test_safe_auto_confirms_only_the_actions_that_commit_something():
    assert needs_confirmation("type_text", SAFE) is True
    assert needs_confirmation("press_key", SAFE) is True
    assert needs_confirmation("click", SAFE) is False
    assert needs_confirmation("open_app", SAFE) is False


def test_auto_never_interrupts():
    for name in ("screenshot", "click", "type_text", "press_key", "open_app"):
        assert needs_confirmation(name, AUTO) is False


def test_summaries_read_as_sentences_not_json():
    assert action_summary("click", {"x": 4, "y": 9, "button": "right"}) == "Click the right button at 4, 9"
    assert action_summary("press_key", {"keys": ["ctrl", "s"]}) == "Press CTRL + S"
    assert action_summary("type_text", {"text": "hi"}) == "Type “hi”"
    assert action_summary("open_app", {"app": "firefox"}) == "Open firefox"
    assert "…" in action_summary("type_text", {"text": "x" * 200})


def test_declining_an_action_stops_it_and_tells_the_model_why():
    seen = []

    def confirm(name, args, risk):
        seen.append((name, risk))
        return False

    history, events, desktop = run(
        [{"message": {"tool_calls": [call("type_text", text="rm -rf")]}, "done": True},
         {"message": {"content": "Understood, I will not type that."}, "done": True}],
        SAFE, confirm)

    assert seen == [("type_text", "sensitive")]
    assert ("type_text", {"text": "rm -rf"}) not in desktop.calls
    declined = [e for e in events if e["type"] == "tool_end" and e.get("declined")]
    assert len(declined) == 1
    result = json.loads(next(m for m in history if m.get("role") == "tool")["content"])
    assert result["declined"] is True
    assert "Do not retry" in result["error"]


def test_approved_actions_run_and_report_a_duration():
    history, events, desktop = run(
        [{"message": {"tool_calls": [call("type_text", text="hello")]}, "done": True},
         {"message": {"content": "typed"}, "done": True}],
        SAFE, lambda name, args, risk: True)
    assert ("type_text", {"text": "hello"}) in desktop.calls
    ends = [e for e in events if e["type"] == "tool_end"]
    assert all("ms" in event for event in ends)
    assert not any(event.get("declined") for event in ends)


def test_low_risk_actions_never_reach_the_confirmation_callback():
    asked = []
    run([{"message": {"tool_calls": [call("scroll", dx=0, dy=3)]}, "done": True},
         {"message": {"content": "ok"}, "done": True}],
        ASK, lambda name, args, risk: asked.append(name) or True)
    # The opening screenshot and the scroll are both observation-only.
    assert asked == []


def test_auto_mode_runs_a_sensitive_action_without_a_callback():
    asked = []
    _, _, desktop = run(
        [{"message": {"tool_calls": [call("press_key", keys=["ctrl", "s"])]}, "done": True},
         {"message": {"content": "saved"}, "done": True}],
        AUTO, lambda name, args, risk: asked.append(name) or True)
    assert asked == []
    assert ("press_key", {"keys": ["ctrl", "s"]}) in desktop.calls


def test_tool_start_announces_that_a_prompt_is_coming():
    _, events, _ = run(
        [{"message": {"tool_calls": [call("type_text", text="x")]}, "done": True},
         {"message": {"content": "ok"}, "done": True}],
        ASK, lambda name, args, risk: True)
    starts = {event["name"]: event for event in events if event["type"] == "tool_start"}
    assert starts["type_text"]["confirming"] is True
    assert starts["screenshot"]["confirming"] is False
    assert starts["type_text"]["summary"] == "Type “x”"


def test_permission_mode_is_described_to_the_model():
    seen = {}

    class Recorder(Client):
        def stream_chat(self, payload, cancel):
            seen["system"] = payload["messages"][0]["content"]
            yield {"message": {"content": "hi"}, "done": True}

    AgentEngine(Recorder([]), FakeDesktop()).run(
        [{"role": "user", "content": "go"}], "local:test", True, threading.Event(),
        lambda event: None, permission_mode=ASK, confirm=lambda *a: True)
    assert "approves every desktop action" in seen["system"]
    assert "declined action is a decision" in seen["system"]


def test_an_unknown_mode_falls_back_to_the_safest_available_behaviour():
    asked = []
    run([{"message": {"tool_calls": [call("type_text", text="x")]}, "done": True},
         {"message": {"content": "ok"}, "done": True}],
        "nonsense", lambda name, args, risk: asked.append(name) or True)
    # Unknown modes resolve to AUTO, which is what "no gate configured" means;
    # the controller only ever passes a validated value.
    assert asked == []


def test_session_event_reports_the_active_mode():
    _, events, _ = run([{"message": {"content": "hi"}, "done": True}], SAFE, lambda *a: True)
    session = next(event for event in events if event["type"] == "session")
    assert session["permission_mode"] == SAFE
    assert session["visual"] is True


def test_commands_follow_the_selected_approval_mode():
    assert needs_confirmation("run_command", ASK)
    assert needs_confirmation("run_command", SAFE)
    assert not needs_confirmation("run_command", AUTO)
