import QtQuick
import QtQuick.Layouts

// The empty conversation stays focused, while Work and Codex explain the
// extra capability the user just switched on.
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge && bridge.desktopEnabled ? "work" : WorkspaceMode.current
    readonly property string headline: mode === "codex" ? "What should we build?"
                                      : mode === "work" ? "What should we do?"
                                      : "Where should we begin?"

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 5

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
            visible: root.mode !== "chat"
            text: root.mode === "codex"
                ? "Inspect, edit, run, and test code with your local Ollama model."
                : "Control the desktop, launch apps, and run local commands."
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.caption
            elide: Text.ElideRight
        }
    }
}
