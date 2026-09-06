import QtQuick
import QtQuick.Layouts

/*!
    The quiet starting point for each workspace mode.

    Chat stays intentionally close to the sparse ChatGPT-style home screen.
    Work and Codex add only one restrained line of context so the user always
    understands what kind of agent is active without turning the empty state
    into a dashboard.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge && bridge.desktopEnabled ? "work" : WorkspaceMode.current
    readonly property string headline: mode === "work" ? "What should I do on your screen?"
                                      : mode === "codex" ? "What are we building?"
                                      : "Where should we begin?"
    readonly property string detail: mode === "work"
        ? "Inspect the desktop, use apps, and run local commands with your approval settings."
        : mode === "codex"
            ? "Project-aware coding with local files, commands, edits, and tests."
            : ""

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline + (root.detail ? ". " + root.detail : "")

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 680)
        spacing: 9

        Text {
            Layout.fillWidth: true
            text: root.headline
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 600 ? 25 : 28
            font.weight: Font.Medium
            font.letterSpacing: -0.45
        }

        Text {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.caption
            lineHeight: 1.35
        }
    }
}
