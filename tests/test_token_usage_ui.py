"""The composer token display is part of the product, not screenshot decoration."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "wynxo" / "ui" / "Wynxo"


def test_composer_pins_token_usage_next_to_run_controls():
    composer = (MODULE / "Composer.qml").read_text(encoding="utf-8")
    assert "TokenUsage {" in composer
    assert composer.index("TokenUsage {") < composer.index("ModelPicker {")
    assert 'compact: root.tight' in composer


def test_token_usage_has_live_count_rate_and_every_requested_period():
    qml = (MODULE / "TokenUsage.qml").read_text(encoding="utf-8")
    for feature in (
        "bridge.liveOutputTokens",
        "bridge.liveTokenRate",
        '"today"',
        '"week"',
        '"month"',
        '"allTime"',
        '"TODAY"',
        '"THIS WEEK"',
        '"THIS MONTH"',
        '"ALL TIME"',
        '" tokens/s"',
    ):
        assert feature in qml


def test_live_and_period_token_numbers_animate_and_honor_reduced_motion():
    qml = (MODULE / "TokenUsage.qml").read_text(encoding="utf-8")
    assert "Behavior on displayedTokens" in qml
    assert "Behavior on displayedRate" in qml
    assert "function revealTotal()" in qml
    assert "SequentialAnimation {" in qml
    assert "PauseAnimation { duration: stat.index * 45 }" in qml
    assert 'property: "displayedTotal"' in qml
    assert "to: stat.targetTotal" in qml
    assert "if (Theme.reducedMotion)" in qml
    # Property Behaviors in this control must still become instant when the
    # user enables reduced motion. The staggered card reveal is skipped by
    # revealTotal() entirely in that mode.
    behavior_count = qml.count("Behavior on ")
    assert behavior_count >= 5
    assert qml.count("enabled: !Theme.reducedMotion") >= behavior_count


def test_usage_control_is_accessible_and_transient_not_permanent_glass():
    qml = (MODULE / "TokenUsage.qml").read_text(encoding="utf-8")
    assert 'Accessible.name: "Token usage"' in qml
    assert "Popover {" in qml
    # Idle toolbar state is transparent; glass/outline arrives only for hover,
    # focus or the open popover.
    assert 'usageButton.hovered ? 0.32 : 0.0' in qml
