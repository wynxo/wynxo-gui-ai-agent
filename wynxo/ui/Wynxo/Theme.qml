pragma Singleton
import QtQuick

/*!
    Wynxo's interface tokens.

    A neutral graphite workspace keeps the chrome visible without turning every
    panel into a card. Warm accent is reserved for focus and action state.
*/
QtObject {
    id: theme

    property var bridge: null
    readonly property bool ready: bridge !== null

    // ---------------------------------------------------------- foundation
    readonly property color background:      "#1b1b1b"
    readonly property color backgroundSoft:  "#141414"
    readonly property color surface:         "#222222"
    readonly property color surfaceRaised:   "#292929"
    readonly property color surfaceHover:    "#303030"
    readonly property color surfaceSelected: "#353535"
    readonly property color surfaceSunken:   "#111111"
    readonly property color scrim:           "#cc080808"

    readonly property color borderSubtle: "#353535"
    readonly property color borderStrong: "#4a4a4a"

    readonly property color textPrimary:   "#f2f2ee"
    readonly property color textSecondary: "#c8c8c2"
    readonly property color textMuted:     "#92928c"
    readonly property color textInverse:   "#111111"

    // Claude-like warmth as the default focus colour; Appearance can replace it.
    readonly property color accent: ready && bridge.accentColor ? bridge.accentColor : "#d97757"
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.12)
    readonly property color accentEdge: Qt.rgba(accent.r, accent.g, accent.b, 0.44)
    readonly property color onAccent: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.56
                                      ? "#101010" : "#f7f6f2"

    readonly property color success: "#7acb96"
    readonly property color warning: "#d7ab5d"
    readonly property color danger:  "#e58476"
    readonly property color info:    "#82abdd"
    readonly property color successMuted: "#17231c"
    readonly property color warningMuted: "#282116"
    readonly property color dangerMuted:  "#2a1a18"

    readonly property var codePalette: ({
        "text": "#e0dfda", "keyword": "#d5a6e6", "string": "#9dca9d",
        "number": "#dbaa7a", "comment": "#898983", "function": "#8dbbdd",
        "builtin": "#84c9bf", "punctuation": "#9c9c95"
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
    readonly property int r3: 11
    readonly property int r4: 14
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
