import QtQuick
import QtQuick.Layouts

/*!
    Quiet empty state: one prompt, one line of context. No dashboard, no cards.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property string headline: mode === "work" ? "What should Wynxo do?"
                                      : mode === "codex" ? "What do you want to build?"
                                      : "What do you want to work on?"
    readonly property string detail: mode === "work"
        ? "Wynxo can inspect and operate the desktop when screen control is enabled."
        : mode === "codex"
            ? (bridge && bridge.projectPath
                ? "Working in " + bridge.projectName
                : "Choose a project folder, then describe the change you want.")
            : (bridge && bridge.projectPath ? "Project · " + bridge.projectName : "Chat with your local model")

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline + ". " + root.detail

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 760)
        spacing: Theme.s3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Mark {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }
            Text {
                text: mode === "codex" ? "Wynxi" : "Wynxo"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.caption
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: mode !== "chat"
                implicitWidth: modeLabel.implicitWidth + Theme.s2 * 2
                implicitHeight: 22
                radius: Theme.r1
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle
                Text {
                    id: modeLabel
                    anchors.centerIn: parent
                    text: mode === "codex" ? "Code" : "Work"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.micro
                }
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: root.headline
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.WordWrap
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 620 ? 25 : 29
            font.weight: Font.Medium
            font.letterSpacing: -0.55
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Icon {
                name: bridge && bridge.projectPath ? "folderOpen" : "terminal"
                ink: Theme.textMuted
                Layout.preferredWidth: 13
                Layout.preferredHeight: 13
            }
            Text {
                Layout.fillWidth: true
                text: root.detail
                color: Theme.textMuted
                font.family: mode === "codex" && bridge && bridge.projectPath ? Theme.monoFamily : Theme.sansFamily
                font.pixelSize: Theme.caption
                elide: Text.ElideMiddle
            }
        }
    }
}
