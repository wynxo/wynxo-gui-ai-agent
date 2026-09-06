import QtQuick
import QtQuick.Layouts

/*!
    The empty state is deliberately almost invisible. The workspace and project
    already live in the sidebar/header; this surface only asks for the task.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property string headline: mode === "work" ? "What should I do?"
                                      : mode === "codex" ? "What do you want to build?"
                                      : "What do you want to work on?"
    readonly property string detail: mode === "codex" && !(bridge && bridge.projectPath)
        ? "Open a project to let Wynxi inspect, edit, run and test it."
        : mode === "work" && !(bridge && bridge.desktopEnabled)
            ? "Screen control will be requested when Work starts."
            : ""

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline + (root.detail ? ". " + root.detail : "")

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 760)
        spacing: Theme.s2

        Text {
            Layout.fillWidth: true
            text: root.headline
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 620 ? 25 : 29
            font.weight: Font.Medium
            font.letterSpacing: -0.55
        }

        Text {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.caption
            elide: Text.ElideRight
        }
    }
}
