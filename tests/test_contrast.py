"""Colour contrast. Text has to be readable, not merely present.

The palette lives in Theme.qml, so the values are read from there rather than
duplicated here: a token that drifts fails this test.
"""
import re
from pathlib import Path

import pytest

THEME = Path(__file__).resolve().parents[1] / "wynxo" / "ui" / "Wynxo" / "Theme.qml"

# WCAG 2.1: 4.5:1 for body text, 3:1 for large text and non-text indicators.
BODY = 4.5
LARGE = 3.0


def tokens() -> dict[str, str]:
    """Literal colours declared in Theme.qml."""
    text = THEME.read_text(encoding="utf-8")
    found = dict(re.findall(r'property color (\w+):\s*"(#[0-9a-fA-F]{6})"', text))
    # `accent` is a binding with a literal fallback, so it needs its own read.
    found["accent"] = re.search(r'bridge\.accentColor : "(#[0-9a-fA-F]{6})"', text).group(1)
    return found


def code_palette() -> dict[str, str]:
    text = THEME.read_text(encoding="utf-8")
    block = text[text.index("codePalette"):text.index("// -------------------------------------------------------------- rhythm")]
    return dict(re.findall(r'"(\w+)":\s*"(#[0-9a-fA-F]{6})"', block))


def theme_accents() -> dict[str, str]:
    from wynxo.controller import Controller
    return dict(Controller.THEMES)


def relative_luminance(colour: str) -> float:
    channels = [int(colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    channels = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(a: str, b: str) -> float:
    first, second = relative_luminance(a), relative_luminance(b)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)


def test_the_reference_implementation_matches_known_values():
    assert contrast("#ffffff", "#000000") == pytest.approx(21.0, abs=0.01)
    assert contrast("#777777", "#ffffff") == pytest.approx(4.48, abs=0.02)


SURFACES = ["background", "backgroundSoft", "surface", "surfaceRaised", "surfaceHover"]


@pytest.mark.parametrize("ink", ["textPrimary", "textSecondary", "textMuted"])
@pytest.mark.parametrize("surface", SURFACES)
def test_body_text_meets_aa_on_every_surface(ink, surface):
    palette = tokens()
    assert contrast(palette[ink], palette[surface]) >= BODY, \
        f"{ink} on {surface} is {contrast(palette[ink], palette[surface]):.2f}:1"


@pytest.mark.parametrize("ink", ["success", "warning", "danger", "info", "accent"])
@pytest.mark.parametrize("surface", SURFACES)
def test_status_colours_meet_aa_on_every_surface(ink, surface):
    palette = tokens()
    assert contrast(palette[ink], palette[surface]) >= BODY


def test_every_accent_theme_is_legible_as_small_text():
    palette = tokens()
    accents = theme_accents()
    assert len(accents) >= 5
    for name, value in accents.items():
        for surface in SURFACES:
            assert contrast(value, palette[surface]) >= BODY, \
                f"{name} on {surface} is {contrast(value, palette[surface]):.2f}:1"


def test_syntax_colours_are_readable_in_a_code_block():
    palette = tokens()
    for name, value in code_palette().items():
        # Code sits on the sunken surface inside its card.
        assert contrast(value, palette["surfaceSunken"]) >= BODY, \
            f"{name} is {contrast(value, palette['surfaceSunken']):.2f}:1"


def test_python_and_qml_agree_on_the_syntax_palette():
    from wynxo.markdown import DEFAULT_PALETTE
    assert set(DEFAULT_PALETTE) == set(code_palette())


def test_borders_are_visible_against_their_surfaces():
    palette = tokens()
    # Borders are non-text, so the lower bar applies — but they must be seen.
    assert contrast(palette["borderStrong"], palette["surface"]) >= 1.3
    assert contrast(palette["borderSubtle"], palette["background"]) >= 1.15


def test_text_on_the_accent_is_readable():
    palette = tokens()
    for name, value in theme_accents().items():
        # Theme.onAccent picks the dark ink above this luminance threshold.
        ink = "#101011" if relative_luminance(value) > 0.28 else "#f6f5f2"
        assert contrast(ink, value) >= LARGE, f"onAccent against {name}"
