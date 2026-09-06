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
    readonly property color background:      "#0c0c0d"
    readonly property color backgroundSoft:  "#0f0f11"
    readonly property color surface:         "#131315"
    readonly property color surfaceRaised:   "#1a1a1d"
    readonly property color surfaceHover:    "#212125"
    readonly property color surfaceSelected: "#2a2a30"
    readonly property color surfaceSunken:   "#0a0a0b"
    readonly property color scrim:           "#c00a0a0b"

    readonly property color borderSubtle: "#232326"
    readonly property color borderStrong: "#36363d"

    readonly property color textPrimary:   "#f4f2ee"
    readonly property color textSecondary: "#a5a29b"
    readonly property color textMuted:     "#6d6b66"
    readonly property color textInverse:   "#101011"

    readonly property color accent: ready && bridge.accentColor ? bridge.accentColor : "#e9e3d6"
    readonly property color accentHover: Qt.lighter(accent, 1.08)
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.14)
    readonly property color accentEdge: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    // Text placed on top of the accent, picked for contrast rather than guessed.
    readonly property color onAccent: (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) > 0.55
                                      ? "#101011" : "#f6f5f2"

    readonly property color success: "#7bd69b"
    readonly property color warning: "#e6bb54"
    readonly property color danger:  "#e8796a"
    readonly property color info:    "#82a9e8"
    readonly property color successMuted: "#1b2620"
    readonly property color warningMuted: "#2a2519"
    readonly property color dangerMuted:  "#2b1d1b"

    // Code colours are handed to the Python highlighter so both agree exactly.
    readonly property var codePalette: ({
        "text": "#d6d4cf", "keyword": "#c3a6f0", "string": "#93cfa6",
        "number": "#dcae7d", "comment": "#66645f", "function": "#8bbdea",
        "builtin": "#79cabf", "punctuation": "#8b8984"
    })

    // -------------------------------------------------------------- rhythm
    readonly property bool compact: ready && bridge.density === "Compact"
    readonly property real scale: compact ? 0.86 : 1.0

    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24
    readonly property int s7: 32
    readonly property int s8: 48

    readonly property int r1: 6
    readonly property int r2: 10
    readonly property int r3: 14
    readonly property int r4: 18
    readonly property int rPill: 999

    // Minimum hit target, kept above 32px even in compact density.
    readonly property int control: compact ? 32 : 36
    readonly property int controlSmall: compact ? 28 : 32
    readonly property int rowHeight: compact ? 34 : 40
    readonly property int gutter: compact ? 16 : 24
    readonly property int readingWidth: 760

    // ---------------------------------------------------------- typography
    readonly property string sansFamily: ready && bridge.systemFont ? systemSans : "Inter"
    readonly property string monoFamily: "JetBrains Mono"
    property string systemSans: "Inter"

    readonly property int display: Math.round(34 * scale)
    readonly property int title:   Math.round(21 * scale)
    readonly property int heading: Math.round(15 * scale)
    readonly property int body:    Math.round(14 * scale)
    readonly property int label:   Math.round(13 * scale)
    readonly property int caption: Math.round(11.5 * scale)
    readonly property int micro:   Math.round(10 * scale)

    // ------------------------------------------------------------- motion
    readonly property bool reducedMotion: ready && bridge.reducedMotion
    readonly property int fast: reducedMotion ? 0 : 120
    readonly property int base: reducedMotion ? 0 : 170
    readonly property int slow: reducedMotion ? 0 : 220
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
