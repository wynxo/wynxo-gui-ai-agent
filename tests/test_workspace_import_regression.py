"""Startup-level regressions for the workspace controller.

These tests stay deliberately tiny: an error in a Qt Property decorator can make
Wynxo die while importing, before the normal GUI smoke test even creates a
window. Keep an explicit import guard so that class-definition failures are
reported immediately.
"""


def test_workspace_controller_imports_cleanly():
    from wynxo.workspace import WorkspaceController

    assert WorkspaceController.__name__ == "WorkspaceController"
