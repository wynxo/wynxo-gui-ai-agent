from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "wynxo" / "ui" / "Wynxo"


def source(name: str) -> str:
    return (QML / name).read_text(encoding="utf-8")


def test_plan_components_are_registered():
    qmldir = source("qmldir")
    assert "PlanPanel 1.0 PlanPanel.qml" in qmldir
    assert "PlanTaskRow 1.0 PlanTaskRow.qml" in qmldir


def test_plan_reads_real_persisted_conversation_steps():
    plan = source("PlanPanel.qml")
    assert "bridge.messageModel" in plan
    assert 'required property string kind' in plan
    assert 'required property var steps' in plan
    assert 'kind === "activity"' in plan
    # Plan must not invent task text from the prompt: the stored activity rows
    # reconstructed by Controller.Messages are its source of truth.
    assert "derive_title" not in plan
    assert "split(" not in plan


def test_plan_row_exposes_agent_execution_states():
    row = source("PlanTaskRow.qml")
    for label in ("Completed", "Running", "Waiting", "Failed", "Skipped", "Pending"):
        assert label in row
    assert "Theme.stateColor" in row
    assert "StatusDot" in row


def test_workspace_auto_opens_plan_only_for_multistep_runs():
    dock = source("WorkspaceDock.qml")
    assert "userSelectedWorkspaceTab" in dock
    assert "onActivityChanged" in dock
    assert "steps.length >= 2" in dock
    assert "root.planSelected = true" in dock
    assert "root.dock.setVisible(true)" in dock
    # Once the user picks a workspace surface, automatic selection is disabled.
    assert "if (!bridge || !root.dock || root.userSelectedWorkspaceTab)" in dock


def test_plan_and_activity_remain_separate_surfaces():
    dock = source("WorkspaceDock.qml")
    rail = source("DockTabBar.qml")
    assert "sourceComponent: PlanPanel {}" in dock
    assert "sourceComponent: ActivityPanel {}" in dock
    assert 'Accessible.name: "Plan"' in rail
    assert 'modelData.id === "activity"' in rail
