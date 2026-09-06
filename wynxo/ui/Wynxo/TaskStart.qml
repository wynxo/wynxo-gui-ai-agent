import QtQuick
import QtQuick.Layouts

/*!
    Quiet empty state sized to the shell's compact home slot. Project context
    lives in the command box and sidebar, so this area stays deliberately terse.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property string headline: mode === "work" ? "What should Wynxo do?"
                                      : mode === "codex" ? "What do you want to build?"
                                      : "What do you want to work on?"

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 640)
        spacing: Theme.s1

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: Theme.s2
            Mark {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
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
                implicitHeight: 20
                radius: Theme.r1
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle
                Text {
                    id: modeLabel
                    anchors.centerIn: parent
                    text: mode === "codex" ? "Code" : "Work"
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.micro
                }
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: root.headline
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 620 ? 24 : 27
            font.weight: Font.Medium
            font.letterSpacing: -0.5
        }
    }
}
