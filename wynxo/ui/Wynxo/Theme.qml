pragma Singleton
import QtQuick

/*!
    The single source of truth for colour, spacing, radius, type and motion.

    Nothing else in the interface hard-codes a hex value. Main.qml attaches the
    Python bridge once, and every derived token re-evaluates from there, so an
    accent change or a density change propagates without any imperative code.
*/
QtObject {
    id: theme

    property var bridge: null
    readonly property bool ready: bridge !== null

    // ---------------------------------------------------------- foundation
    // Near-black canvas and sidebar with a restrained graphite surface ladder.
    // The contrast is intentionally subtle so the app reads like one polished
    // desktop workspace rather than a stack of separate cards.
    readonly property color background:      "#181818"
    readonly property color backgroundSoft:  "#111111"
    readonly property color surface:         "#202020"
    readonly property color surfaceRaised:   "#2b2b2b"
    readonly property color surfaceHover:    "#323232"
    readonly property color surfaceSelected: "#383838"
    readonly property color surfaceSunken:   "#0d0d0d"
    readonly property color scrim:           "#cc070707"

    readonly property color borderSubtle: "#373737"
    readonly property color borderStrong: "#4a4a4a"

    readonly property color textPrimary:   "#f4f4f4"
    readonly property color textSecondary: "#c3c3c3"
    readonly property color textMuted:     "#8f8f8f"
    readonly property color textInverse:   "#111111"

    readonly property color accent: ready && bridge.accentColor ? bridge.accentColor : "#b6a2f5"
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
    readonly property color accentEdge: Qt.rgba(accent.r, accent.g, accent.b, 0.34)
    // Text placed on top of the accent, picked for contrast rather than guessed.
    readonly property color onAccent: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.55
                                      ? "#101011" : "#f6f5f2"

    readonly property color success: "#7bd69b"
    readonly property color warning: "#e6bb54"
    readonly property color danger:  "#ef8476"
    readonly property color info:    "#82a9e8"
    readonly property color successMuted: "#17231c"
    readonly property color warningMuted: "#262116"
    readonly property color dangerMuted:  "#271a18"

    // Code colours are handed to the Python highlighter so both agree exactly.
    readonly property var codePalette: ({
        "text": "#d6d4cf", "keyword": "#c3a6f0", "string": "#93cfa6",
        "number": "#dcae7d", "comment": "#7b7974", "function": "#8bbdea",
        "builtin": "#79cabf", "punctuation": "#8b8984"
    })

    // -------------------------------------------------------------- rhythm
    readonly property bool compact: ready && bridge.density === "Compact"
    readonly property real scale: compact ? 0.92 : 1.0

    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24
    readonly property int s7: 32
    readonly property int s8: 48

    readonly property int r1: 5
    readonly property int r2: 8
    readonly property int r3: 16
    readonly property int r4: 22
    readonly property int rPill: 999

    // Minimum hit target, kept at or above 32px even in compact density.
    readonly property int control: compact ? 32 : 34
    readonly property int controlSmall: compact ? 28 : 30
    readonly property int rowHeight: compact ? 34 : 40
    readonly property int gutter: compact ? 16 : 24
    readonly property int readingWidth: 780

    // ---------------------------------------------------------- typography
    readonly property string sansFamily: ready && bridge.systemFont ? systemSans : "Inter"
    readonly property string monoFamily: "JetBrains Mono"
    property string systemSans: "Inter"

    readonly property int display: Math.round(34 * scale)
    readonly property int title:   Math.round(19 * scale)
    readonly property int heading: Math.round(15 * scale)
    readonly property int body:    Math.round(15 * scale)
    readonly property int label:   Math.round(13 * scale)
    readonly property int caption: Math.round(12 * scale)
    readonly property int micro:   Math.round(10.5 * scale)

    // ------------------------------------------------------------- motion
    // Motion reports state changes and nothing else: no ambient animation, no
    // easing long enough to be waited on.
    readonly property bool reducedMotion: ready && bridge.reducedMotion
    readonly property int fast: reducedMotion ? 0 : 120
    readonly property int base: reducedMotion ? 0 : 160
    readonly property int slow: reducedMotion ? 0 : 200
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
