"""The QML module must stay consistent: every declared type exists and loads."""
import os
from pathlib import Path
import re
import subprocess
import sys

import pytest

UI = Path(__file__).resolve().parents[1] / "wynxo" / "ui"
MODULE = UI / "Wynxo"


def declared_types():
    types = {}
    for line in (MODULE / "qmldir").read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[0] == "singleton":
            types[parts[1]] = parts[3]
        elif len(parts) == 3 and parts[0] != "module":
            types[parts[0]] = parts[2]
    return types


def test_every_declared_type_has_a_file():
    for name, filename in declared_types().items():
        assert (MODULE / filename).is_file(), f"{name} points at a missing {filename}"


def test_every_component_file_is_declared():
    declared = set(declared_types().values())
    for path in MODULE.glob("*.qml"):
        assert path.name in declared, f"{path.name} is not listed in qmldir"


def test_no_component_hard_codes_a_colour():
    """Colour belongs to Theme.qml; scattered hex values are the thing the
    redesign removed, so keep them out."""
    # Only assignments count; a hex string shown to the user (a placeholder in
    # the accent field, say) is content rather than a styling decision.
    hex_colour = re.compile(r'\b(color|ink|tone|tint|activeTint|fill|stroke|'
                            r'accentColor|foreground|background)\s*:\s*"#[0-9a-fA-F]{3,8}"')
    offenders = []
    for path in list(MODULE.glob("*.qml")) + [UI / "Main.qml"]:
        if path.name == "Theme.qml":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if hex_colour.search(line):
                offenders.append(f"{path.name}:{number}")
    assert offenders == [], "hard-coded colours: " + ", ".join(offenders)


def test_fonts_are_bundled_with_their_licences():
    fonts = {path.name for path in (UI / "fonts").glob("*.ttf")}
    assert "Inter-Regular.ttf" in fonts
    assert "JetBrainsMono-Regular.ttf" in fonts
    licences = {path.name for path in (UI / "fonts").glob("*LICENSE*")}
    assert len(licences) >= 2


def test_main_window_stays_usable_at_its_minimum_size():
    text = (UI / "Main.qml").read_text(encoding="utf-8")
    minimum_width = int(re.search(r"minimumWidth:\s*(\d+)", text).group(1))
    minimum_height = int(re.search(r"minimumHeight:\s*(\d+)", text).group(1))
    assert minimum_width <= 600 and minimum_height <= 560


@pytest.mark.skipif(not os.environ.get("WYNXO_QML_SMOKE"), reason="needs a Qt platform plugin")
def test_the_interface_loads_headless():
    environment = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    result = subprocess.run([sys.executable, "-m", "wynxo", "--smoke-test"],
                            capture_output=True, text=True, timeout=120, env=environment)
    assert result.returncode == 0, result.stderr
    assert "failed to load" not in result.stderr


def test_the_theme_follows_the_bridge_by_binding_not_assignment():
    """A one-time assignment silently stops tracking; the preview runner and a
    live accent change both depend on this staying a binding."""
    text = (UI / "Main.qml").read_text(encoding="utf-8")
    assert 'Binding { target: Theme; property: "bridge"; value: bridge }' in text
    assert "Theme.bridge = bridge" not in text


def test_renderers_are_told_when_the_palette_changes():
    """Markdown and code are rendered in Python, so a theme change has to
    invalidate what is already on screen."""
    for name in ("Markdown.qml", "CodeBlock.qml"):
        text = (MODULE / name).read_text(encoding="utf-8")
        assert "onPaletteChanged" in text, f"{name} ignores palette changes"
    controller = (Path(__file__).resolve().parents[1] / "wynxo" / "controller.py").read_text()
    assert controller.count("self.paletteChanged.emit()") == 2


def test_interactive_components_carry_accessible_names():
    """A screen reader should not meet a wall of unnamed rectangles."""
    required = {
        "WButton.qml", "IconButton.qml", "Chip.qml", "Toggle.qml", "Segmented.qml",
        "Composer.qml", "AppSidebar.qml", "UserMessage.qml", "AssistantMessage.qml",
        "ToolActivity.qml", "Meter.qml",
    }
    for name in sorted(required):
        text = (MODULE / name).read_text(encoding="utf-8")
        assert "Accessible." in text, f"{name} exposes nothing to assistive technology"


def test_status_is_never_carried_by_colour_alone():
    """Activity rows pair colour with an icon, a word and motion."""
    text = (MODULE / "ToolActivity.qml").read_text(encoding="utf-8")
    for word in ('"waiting for you"', '"declined"', "modelData.icon", "pulsing:"):
        assert word in text


def test_reduced_motion_gates_every_behaviour_and_looping_animation():
    offenders = []
    for path in list(MODULE.glob("*.qml")) + [UI / "Main.qml"]:
        lines = path.read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("Behavior on ") and "enabled:" not in line:
                window = " ".join(lines[number - 1:number + 2])
                if "enabled: !Theme.reducedMotion" not in window:
                    offenders.append(f"{path.name}:{number}")
            if stripped.startswith("SequentialAnimation on ") or stripped.startswith("RotationAnimator on "):
                window = " ".join(lines[number - 1:number + 4])
                if "reducedMotion" not in window and "animate" not in window:
                    offenders.append(f"{path.name}:{number}")
    assert offenders == [], "ungated animation: " + ", ".join(offenders)
