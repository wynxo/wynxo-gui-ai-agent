import QtQuick
import QtQuick.Layouts

/*!
    The quiet starting point for each task mode.

    A new Wynxo task can choose Chat or Work once. After that choice — and for
    every reopened task — the mode comes from the task itself. Wynxi tasks are
    coding tasks from the moment they are created.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
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
