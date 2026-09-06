import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Ways into a task, sitting under the composer.

    Compact text actions, not cards. Each one either fills the composer with a
    prompt or opens the tool it names — nothing here is decorative, and nothing
    is offered that this machine cannot do.
*/
Item {
    id: root
    signal starterChosen(string prompt)
    signal commandInvoked(string action)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property bool hasProject: !!(bridge && bridge.projectPath)

    implicitHeight: flow.implicitHeight

    readonly property var actions: {
        var list = [];
        if (!root.hasProject)
            list.push({ label: "Open project", icon: "folder", command: "project" });
        else
            list.push({ label: "Browse files", icon: "folderOpen", command: "files" });
        list.push({ label: "Terminal", icon: "terminal", command: "terminal-panel" });
        if (root.hasProject)
            list.push({ label: "Explain this project", icon: "code",
                        prompt: "Inspect this project and explain how it is put together." });
        if (root.mode !== "codex")
            list.push({ label: "Read my screen", icon: "eye",
                        prompt: "What is on my screen? Help me with it." });
        list.push({ label: "Run a command", icon: "bolt",
                    prompt: "Check my disk space and explain what you find." });
        if (bridge && bridge.workspaceDock && bridge.workspaceDock.browserAvailable)
            list.push({ label: "Browser", icon: "globe", command: "browser" });
        return list;
    }

    Flow {
        id: flow
        width: parent.width
        spacing: Theme.s1

        Repeater {
            model: root.actions
            delegate: AbstractButton {
                id: starter
                required property var modelData
                implicitHeight: 28
                implicitWidth: starterRow.implicitWidth + Theme.s3 * 2
                hoverEnabled: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                onClicked: {
                    if (modelData.command) root.commandInvoked(modelData.command);
                    else root.starterChosen(modelData.prompt);
                }
                background: Rectangle {
                    radius: Theme.r2
                    color: starter.down ? Theme.surfacePressed
                         : starter.hovered ? Theme.surfaceHover : "transparent"
                    border.width: starter.visualFocus ? 1 : 0
                    border.color: Theme.accentEdge
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                }
                contentItem: Row {
                    id: starterRow
                    anchors.centerIn: parent
                    spacing: Theme.s2
                    Icon {
                        name: starter.modelData.icon
                        ink: starter.hovered ? Theme.textSecondary : Theme.textDisabled
                        width: 13; height: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: starter.modelData.label
                        color: starter.hovered ? Theme.textPrimary : Theme.textMuted
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
