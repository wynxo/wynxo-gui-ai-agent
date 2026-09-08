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
    signal modeRequested(string mode)

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property bool hasProject: !!(bridge && bridge.projectPath)
    // A task whose mode is still open can be turned into a Work task by
    // picking a starter that needs one. A locked Chat task cannot, so it is
    // not offered openings it would have to refuse.
    readonly property bool modeOpen: !!(bridge && !bridge.taskModeLocked)
    readonly property bool canAct: root.mode !== "chat" || root.modeOpen

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
        if (root.mode !== "codex" && root.canAct)
            list.push({ label: "Read my screen", icon: "eye", needs: "work",
                        prompt: "What is on my screen? Help me with it." });
        if (root.canAct)
            list.push({ label: "Run a command", icon: "bolt", needs: "work",
                        prompt: "Check my disk space and explain what you find." });
        if (root.mode === "chat" && !root.modeOpen)
            list.push({ label: "Review some code", icon: "code",
                        prompt: "Review this code and tell me what you would change:\n\n" });
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
                    // A command or screen opening is a Work opening: choose the
                    // mode with it rather than sending it into a Chat task that
                    // has no way to carry it out.
                    if (modelData.needs && root.modeOpen) root.modeRequested(modelData.needs);
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
