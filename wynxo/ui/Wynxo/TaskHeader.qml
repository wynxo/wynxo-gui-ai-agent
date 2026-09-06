import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A quiet desktop-workspace title bar.

    The task context stays on the left and transient run/connection controls stay
    on the right. Chat / Work is a one-time choice for a fresh Wynxo task; once
    selected it disappears instead of becoming permanent navigation chrome.
*/
Item {
    id: root
    property bool sidebarCollapsed: false
    property bool drawerOpen: false
    signal toggleSidebar()
    signal renameRequested()
    signal openSettings()
    signal openCommandPalette()
    signal openAgentSettings()
    signal openShortcuts()
    signal clearRequested()
    signal modeRequested(string mode)

    implicitHeight: 46

    readonly property bool homeMode: bridge && !bridge.hasMessages
    readonly property bool needsAttention: bridge && !bridge.online
    readonly property bool connecting: bridge && bridge.connectionState === "connecting"
    readonly property string resolvedMode: bridge ? bridge.taskMode : "chat"
    readonly property bool canChooseMode: root.homeMode && bridge
        && !bridge.taskModeLocked && bridge.taskMode !== "codex"

    function requestMode(value) {
        if ((value !== "chat" && value !== "work") || !root.canChooseMode) return;
        if (!bridge || bridge.connecting || bridge.busy) return;
        root.modeRequested(value);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.borderSubtle
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s2
        anchors.rightMargin: Theme.s2
        spacing: Theme.s1

        IconButton {
            objectName: "headerSidebarToggle"
            visible: root.sidebarCollapsed && !root.drawerOpen
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            iconSize: 14
            iconName: "panel"
            tooltip: "Show sidebar"
            shortcut: "Ctrl+B"
            onClicked: root.toggleSidebar()
        }

        // ---------------------------------------------------- task context
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.sidebarCollapsed && !root.drawerOpen ? Theme.s1 : Theme.s2
            spacing: Theme.s2

            Text {
                text: bridge && bridge.taskMode === "codex" ? "Wynxi" : "Wynxo"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.label
                font.weight: Font.DemiBold
            }

            Text {
                visible: bridge && bridge.projectName
                text: "/"
                color: Theme.borderStrong
                font.family: Theme.sansFamily
                font.pixelSize: Theme.caption
            }

            Text {
                visible: bridge && bridge.projectName
                text: bridge ? bridge.projectName : ""
                color: Theme.textMuted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.caption
                elide: Text.ElideMiddle
                Layout.maximumWidth: Math.max(110, root.width * 0.22)
            }

            Text {
                visible: !root.homeMode && bridge && bridge.taskId
                text: "/"
                color: Theme.borderStrong
                font.family: Theme.sansFamily
                font.pixelSize: Theme.caption
            }

            AbstractButton {
                id: titleButton
                visible: !root.homeMode
                enabled: !!(bridge && bridge.taskId)
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(160, root.width * 0.42)
                implicitHeight: 28
                hoverEnabled: true
                Accessible.name: "Rename this task"
                onClicked: root.renameRequested()
                background: Rectangle {
                    radius: Theme.r1
                    color: titleButton.hovered && titleButton.enabled ? Theme.surfaceHover : "transparent"
                    border.width: titleButton.visualFocus ? 1 : 0
                    border.color: Theme.accentEdge
                }
                contentItem: Text {
                    text: bridge ? bridge.taskTitle : ""
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.label
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: titleButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }

            Item { Layout.fillWidth: true }
        }

        // -------------------------------------------- one-time Chat / Work
        Row {
            id: modeChoice
            visible: root.canChooseMode
            spacing: 2

            Repeater {
                model: [
                    { id: "chat", label: "Chat", icon: "chat" },
                    { id: "work", label: "Work", icon: "cursor" },
                ]
                delegate: AbstractButton {
                    id: choice
                    required property var modelData
                    width: choiceRow.implicitWidth + Theme.s3 * 2
                    height: 30
                    hoverEnabled: true
                    readonly property bool chosen: root.resolvedMode === modelData.id
                    Accessible.name: modelData.label
                    Accessible.checked: chosen
                    onClicked: root.requestMode(modelData.id)
                    background: Rectangle {
                        radius: Theme.r2
                        color: choice.hovered ? Theme.surfaceHover
                             : choice.chosen ? Theme.surfaceSelected : "transparent"
                        border.width: choice.chosen || choice.visualFocus ? 1 : 0
                        border.color: choice.visualFocus ? Theme.accentEdge : Theme.borderSubtle
                    }
                    contentItem: Row {
                        id: choiceRow
                        anchors.centerIn: parent
                        spacing: Theme.s2
                        Icon {
                            name: choice.modelData.icon
                            ink: choice.chosen ? Theme.textPrimary : Theme.textMuted
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: choice.modelData.label
                            color: choice.chosen ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.caption
                            font.weight: choice.chosen ? Font.Medium : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        // ------------------------------------------------------- run state
        Rectangle {
            visible: bridge && bridge.busy
            Layout.preferredWidth: runRow.implicitWidth + Theme.s3 * 2
            Layout.preferredHeight: 28
            Layout.maximumWidth: Math.max(110, root.width * 0.30)
            radius: Theme.r2
            color: Theme.surface
            border.width: 1
            border.color: Theme.borderSubtle

            RowLayout {
                id: runRow
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s2
                spacing: Theme.s2
                StatusDot {
                    tone: bridge && bridge.permissionPending ? Theme.warning : Theme.accent
                    pulsing: true
                    width: 7; height: 7
                }
                Text {
                    text: !bridge ? ""
                        : bridge.permissionPending ? "Waiting"
                        : root.resolvedMode === "codex" ? "Running"
                        : root.resolvedMode === "work" ? "Working" : "Generating"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                    elide: Text.ElideRight
                }
                Text {
                    visible: bridge && bridge.tokenRate !== "—" && root.width > 1080
                    text: bridge ? bridge.tokenRate : ""
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.micro
                }
                AbstractButton {
                    implicitWidth: 34
                    implicitHeight: 21
                    hoverEnabled: true
                    Accessible.name: "Stop"
                    onClicked: if (bridge) bridge.stop()
                    background: Rectangle {
                        radius: Theme.r1
                        color: parent.hovered ? Theme.dangerMuted : "transparent"
                    }
                    contentItem: Text {
                        text: "Stop"
                        color: Theme.danger
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.micro
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Chip {
            visible: !root.homeMode && bridge && root.resolvedMode === "work"
                     && bridge.desktopEnabled && !bridge.busy && root.width > 760
            text: "Screen"
            iconName: "cursor"
            selected: true
            onClicked: root.openAgentSettings()
            ToolTip.visible: hovered
            ToolTip.text: bridge ? "Permission mode: " + bridge.permissionModeLabel : ""
        }

        Chip {
            visible: root.needsAttention || root.connecting
            text: root.connecting ? "Connecting" : "Ollama offline"
            iconName: root.connecting ? "clock" : "warning"
            tone: root.connecting ? Theme.textMuted : Theme.danger
            onClicked: if (bridge) bridge.refreshModels()
            ToolTip.visible: hovered
            ToolTip.text: bridge ? bridge.endpoint + " — click to reconnect" : ""
        }

        IconButton {
            visible: !root.homeMode
            iconName: "more"
            tooltip: "Task actions"
            active: overflow.opened
            onClicked: overflow.opened ? overflow.close() : overflow.open()

            WMenu {
                id: overflow
                anchorX: -menuWidth + parent.width
                menuWidth: 250
                items: [
                    { id: "palette", label: "Command palette", icon: "command", shortcut: "Ctrl+Shift+P" },
                    { id: "shortcuts", label: "Keyboard shortcuts", icon: "keyboard" },
                    { separator: true },
                    { id: "rename", label: "Rename task", icon: "edit", disabled: !(bridge && bridge.taskId) },
                    { id: "pin", label: bridge && bridge.taskPinned ? "Unpin task" : "Pin task", icon: "pin", disabled: !(bridge && bridge.taskId) },
                    { id: "duplicate", label: "Duplicate task", icon: "duplicate", shortcut: "Ctrl+D", disabled: !(bridge && bridge.taskId) },
                    { id: "export", label: "Export Markdown", icon: "download", disabled: !(bridge && bridge.hasMessages) },
                    { separator: true },
                    { id: "regenerate", label: "Regenerate", icon: "retry", shortcut: "Ctrl+R", disabled: !(bridge && bridge.canRegenerate) },
                    { id: "clear", label: "Clear messages", icon: "trash", disabled: !(bridge && bridge.hasMessages) },
                    { separator: true },
                    { id: "settings", label: "Settings", icon: "sliders", shortcut: "Ctrl+," },
                ]
                onPicked: function(id) {
                    if (id === "palette") root.openCommandPalette();
                    else if (id === "shortcuts") root.openShortcuts();
                    else if (id === "rename") root.renameRequested();
                    else if (id === "settings") root.openSettings();
                    else if (!bridge) return;
                    else if (id === "pin") bridge.togglePin(bridge.taskId);
                    else if (id === "duplicate") bridge.duplicateTask();
                    else if (id === "export") bridge.exportTask();
                    else if (id === "regenerate") bridge.regenerate();
                    else if (id === "clear") root.clearRequested();
                }
            }
        }
    }
}
