"""The fresh-task reading block must stay truly centred."""
from pathlib import Path


MAIN = Path(__file__).resolve().parents[1] / "wynxo" / "ui" / "Main.qml"


def test_home_reading_surfaces_use_a_centered_preferred_width():
    text = MAIN.read_text(encoding="utf-8")
    assert "readonly property real centredReadingWidth: Math.min(Theme.readingWidth, width)" in text

    # Qt Quick Layouts can clamp a fill-width item to maximumWidth while still
    # leaving it at the layout's left edge. The homescreen bug came from exactly
    # that combination. These reading surfaces must opt out of fillWidth and use
    # an explicit preferred width before AlignHCenter can actually centre them.
    for component in ("TaskStart {", "ErrorBanner {", "Composer {", "TaskStarters {"):
        block = text.split(component, 1)[1].split("}", 1)[0]
        assert "Layout.fillWidth: false" in block, component
        assert "Layout.preferredWidth: contentColumn.centredReadingWidth" in block, component
        assert "Layout.alignment: Qt.AlignHCenter" in block, component


def test_home_centering_does_not_return_to_maximum_width_clamping():
    text = MAIN.read_text(encoding="utf-8")
    composer = text.split("Composer {", 1)[1].split("onSubmitted:", 1)[0]
    assert "Layout.maximumWidth" not in composer
    assert "Layout.fillWidth: true" not in composer
