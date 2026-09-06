pragma Singleton
import QtQuick

/*!
    Wynxo's interface tokens.

    The product is intentionally dense and tool-like: one dark canvas, subtle
    separators, compact controls, restrained radius, and a warm focus colour.
    The goal is the same visual hierarchy used by serious coding agents: text
    and state first, chrome second.
*/
QtObject {
    id: theme

    property var bridge: null
    readonly property bool ready: bridge !== null

    // ---------------------------------------------------------- foundation
    readonly property color background:      "#0f0f0f"
    readonly property color backgroundSoft:  "#141414"
    readonly property color surface:         "#191919"
    readonly property color surfaceRaised:   "#202020"
    readonly property color surfaceHover:    "#272727"
    readonly property color surfaceSelected: "#2d2d2d"
    readonly property color surfaceSunken:   "#0a0a0a"
    readonly property color scrim:           "#cc050505"

    readonly property color borderSubtle: "#2f2f2f"
    readonly property color borderStrong: "#424242"

    readonly property color textPrimary:   "#f1f1ec"
    readonly property color textSecondary: "#c8c8c2"
    readonly property color textMuted:     "#93938d"
    readonly property color textInverse:   "#101010"

    // Warm by default, but still user configurable from Appearance.
    readonly property color accent: ready && bridge.accentColor ? bridge.accentColor : "#d97757"
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.11)
    readonly property color accentEdge: Qt.rgba(accent.r, accent.g, accent.b, 0.42)
    readonly property color onAccent: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.56
                                      ? "#101010" : "#f7f6f2"

    readonly property color success: "#78c995"
    readonly property color warning: "#d6aa5a"
    readonly property color danger:  "#e68173"
    readonly property color info:    "#80a9dc"
    readonly property color successMuted: "#142019"
    readonly property color warningMuted: "#241f15"
    readonly property color dangerMuted:  "#251816"

    readonly property var codePalette: ({
        "text": "#deddd7", "keyword": "#d5a6e6", "string": "#9bc89b",
        "number": "#d9a878", "comment": "#85857f", "function": "#8ab8db",
        "builtin": "#82c7bd", "punctuation": "#999992"
    })

    // -------------------------------------------------------------- rhythm
    readonly property bool compact: ready && bridge.density === "Compact"
    readonly property real scale: compact ? 0.94 : 1.0

    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24
    readonly property int s7: 32
    readonly property int s8: 48

    readonly property int r1: 5
    readonly property int r2: 7
    readonly property int r3: 10
    readonly property int r4: 12
    readonly property int rPill: 999

    readonly property int control: compact ? 30 : 32
    readonly property int controlSmall: compact ? 26 : 28
    readonly property int rowHeight: compact ? 32 : 35
    readonly property int gutter: compact ? 16 : 22
    readonly property int readingWidth: 860

    // ---------------------------------------------------------- typography
    readonly property string sansFamily: ready && bridge.systemFont ? systemSans : "Inter"
    readonly property string monoFamily: "JetBrains Mono"
    property string systemSans: "Inter"

    readonly property int display: Math.round(30 * scale)
    readonly property int title:   Math.round(17 * scale)
    readonly property int heading: Math.round(14 * scale)
    readonly property int body:    Math.round(14 * scale)
    readonly property int label:   Math.round(12.5 * scale)
    readonly property int caption: Math.round(11.5 * scale)
    readonly property int micro:   Math.round(10 * scale)

    // ------------------------------------------------------------- motion
    readonly property bool reducedMotion: ready && bridge.reducedMotion
    readonly property int fast: reducedMotion ? 0 : 90
    readonly property int base: reducedMotion ? 0 : 130
    readonly property int slow: reducedMotion ? 0 : 170
    readonly property int easing: Easing.OutCubic

    function stateColor(name) {
        if (name === "done") return success;
        if (name === "failed") return danger;
        if (name === "declined") return warning;
        if (name === "waiting") return warning;
        return accent;
    }

    function alpha(base, amount) {
        return Qt.rgba(base.r, base.g, base.b, amount);
    }
}
