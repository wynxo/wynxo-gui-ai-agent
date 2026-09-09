"""The fresh-task reading block must stay truly centred."""
from pathlib import Path


MAIN = Path(__file__).resolve().parents[1] / "wynxo" / "ui" / "Main.qml"


def test_home_primary_surfaces_use_explicit_centering_lanes():
    text = MAIN.read_text(encoding="utf-8")

    # Qt Quick Layouts may clamp a preferred-width child yet still place its
    # layout cell at the left edge. The rendered homescreen exposed exactly
    # that failure. The primary surfaces therefore live in full-width lanes and
    # centre themselves with anchors, outside Layout's horizontal placement.
    for identifier in ("homeIntro", "composer", "homeStarters"):
        marker = f"id: {identifier}\n"
        assert marker in text, identifier
        block = text.split(marker, 1)[1].split("}", 1)[0]
        assert "anchors.horizontalCenter: parent.horizontalCenter" in block, identifier
        assert "width: Math.min(Theme.readingWidth, parent.width)" in block, identifier

    assert "id: composerLane\n" in text
    lane = text.split("id: composerLane\n", 1)[1].split("Composer {", 1)[0]
    assert "Layout.fillWidth: true" in lane


def test_composer_does_not_rely_on_layout_alignment_for_centering():
    text = MAIN.read_text(encoding="utf-8")
    composer = text.split("id: composer\n", 1)[1].split("onSubmitted:", 1)[0]
    assert "Layout.alignment: Qt.AlignHCenter" not in composer
    assert "Layout.preferredWidth" not in composer
    assert "Layout.maximumWidth" not in composer
    assert "anchors.horizontalCenter: parent.horizontalCenter" in composer
