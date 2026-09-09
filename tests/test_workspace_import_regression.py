"""Startup-level regressions for the workspace controller.

These tests stay deliberately tiny: an error in a Qt Property decorator can make
Wynxo die while importing, before the normal GUI smoke test even creates a
window. Keep an explicit import guard so that class-definition failures are
reported immediately.
"""
from pathlib import Path


def test_workspace_controller_imports_cleanly():
    import wynxo.workspace as workspace

    assert workspace.WorkspaceController.__name__ == "WorkspaceController"


def test_workspace_does_not_reference_inherited_changed_as_a_local_name():
    import wynxo.workspace as workspace

    source = Path(workspace.__file__).read_text(encoding="utf-8")
    assert "notify=changed" not in source
