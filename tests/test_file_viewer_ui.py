"""The built-in file viewer should behave like an editor, not a text dump."""
from pathlib import Path


QML = Path(__file__).resolve().parents[1] / "wynxo" / "ui" / "Wynxo" / "FileViewer.qml"


def source() -> str:
    return QML.read_text(encoding="utf-8")


def test_find_reports_current_match_and_total():
    qml = source()
    for feature in (
        "property int findCount: 0",
        "property int findOrdinal: 0",
        "function recountFindMatches()",
        "function ordinalFor(haystack, query, target)",
        'root.findCount === 0 ? "No matches"',
        'root.findCount + (root.findCountCapped ? "+" : "")',
    ):
        assert feature in qml


def test_find_counting_is_bounded_for_large_repetitive_files():
    qml = source()
    assert "readonly property int maxFindMatches: 10000" in qml
    assert "if (count >= maxFindMatches)" in qml
    assert "findCountCapped = haystack.indexOf(query, cursor) >= 0" in qml


def test_find_updates_after_editing_and_navigation_wraps():
    qml = source()
    assert "if (root.findOpen && findInput.text.length)" in qml
    assert "if (position < 0) position = haystack.indexOf(query);" in qml
    assert "if (position < 0) position = haystack.lastIndexOf(query);" in qml
    assert "enabled: root.findCount > 0" in qml
