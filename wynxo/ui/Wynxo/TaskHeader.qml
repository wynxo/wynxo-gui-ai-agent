import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A task chooses its surface once.

    New Wynxo tasks expose a small Chat / Work choice at the left edge of the
    header. The moment one is chosen (or the first Chat message is sent), the
    choice disappears and becomes part of that task. Wynxi is entered from the
    product switch in the sidebar and is always a coding task.
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

    implicitHeight: Theme.compact ? 46 : 52

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
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s2
        anchors.rightMargin: Theme.s2
        spacing: Theme.s1

        IconButton {
            objectName: "headerSidebarToggle"
            visible: root.sidebarCollapsed && !root.drawerOpen
            iconName: root.sidebarCollapsed ? "panel" : "panelLeft"
            tooltip: root.sidebarCollapsed ? "Show sidebar" : "Hide sidebar"
            shortcut: "Ctrl+B"
            onClicked: root.toggleSidebar()
        }

        // The only mode chooser. It lives on one side instead of floating in
        // the centre, and vanishes permanently for this task after selection.
        Segmented {
            id: modeSwitch
            visible: root.canChooseMode
            Layout.preferredWidth: 184
            Layout.preferredHeight: 34
            Layout.leftMargin: root.sidebarCollapsed ? Theme.s1 : Theme.s2
            options: [
                { id: "chat", label: "Chat", detail: "Conversation and local tools" },
                { id: "work", label: "Work", detail: "Desktop control with Ollama" },
            ]
            current: root.resolvedMode
            onSelected: function(value) { root.requestMode(value); }
        }

        // -------------------------------------------------- the breadcrumb
        RowLayout {
            visible: !root.homeMode
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            spacing: Theme.s2

            AbstractButton {
                id: titleButton
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(180, root.width * 0.48)
                implicitHeight: Theme.controlSmall
                implicitWidth: titleText.implicitWidth + Theme.s2 * 2
                hoverEnabled: true
                enabled: !!(bridge && bridge.taskId)
                Accessible.name: "Rename this task"
                onClicked: root.renameRequested()
                ToolTip.visible: hovered && enabled
                ToolTip.text: "Rename"
                ToolTip.delay: 700

                background: Rectangle {
                    radius: Theme.r2
                    color: titleButton.hovered && titleButton.enabled ? Theme.surfaceHover : "transparent"
                    border.width: titleButton.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                }
                contentItem: Text {
                    id: titleText
                    text: bridge && bridge.hasMessages ? bridge.taskTitle : (bridge ? bridge.productName : "Wynxo")
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.heading
                    font.weight: Font.Medium
                    font.letterSpacing: -0.1
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

        Item { visible: root.homeMode; Layout.fillWidth: true }

        // ------------------------------------------------------- run state
        Rectangle {
            visible: !root.homeMode && bridge && bridge.busy
            Layout.preferredWidth: runRow.implicitWidth + Theme.s3 * 2
            Layout.preferredHeight: Theme.controlSmall
            Layout.maximumWidth: Math.max(120, root.width * 0.38)
            radius: Theme.r2
            color: Theme.surfaceRaised
            border.width: 1
            border.color: Theme.borderSubtle
            clip: true

            RowLayout {
                id: runRow
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s2
                spacing: Theme.s2
                StatusDot {
                    tone: bridge && bridge.permissionPending ? Theme.warning : Theme.accent
                    pulsing: true
                }
                Text {
                    Layout.fillWidth: true
                    text: !bridge ? ""
                        : bridge.permissionPending ? "Waiting for you"
                        : root.resolvedMode === "codex" ? "Coding"
                        : root.resolvedMode === "work" ? "Working on your screen" : "Running"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    elide: Text.ElideRight
                }
                Text {
                    visible: bridge && bridge.tokenRate !== "—" && root.width > 1080
                    text: bridge ? bridge.tokenRate : ""
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
                Divider { vertical: true; Layout.preferredHeight: 14 }
                AbstractButton {
                    implicitWidth: stopLabel.implicitWidth + Theme.s2
                    implicitHeight: 22
                    hoverEnabled: true
                    Accessible.name: "Stop"
                    onClicked: if (bridge) bridge.stop()
                    ToolTip.visible: hovered
                    ToolTip.text: "Stop everything · Esc"
                    background: Rectangle {
                        radius: Theme.r1
                        color: parent.hovered ? Theme.dangerMuted : "transparent"
                    }
                    contentItem: Text {
                        id: stopLabel
                        text: "Stop"
                        color: Theme.danger
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        Chip {
            visible: !root.homeMode && bridge && root.resolvedMode === "work"
                     && bridge.desktopEnabled && !bridge.busy && root.width > 720
            text: "Screen control"
            iconName: "cursor"
            selected: true
            onClicked: root.openAgentSettings()
            ToolTip.visible: hovered
            ToolTip.text: bridge ? "Permission mode: " + bridge.permissionModeLabel + " — click to change" : ""
        }

        // ------------------------------------------------------ connection
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
            tooltip: "More actions"
            active: overflow.opened
            onClicked: overflow.opened ? overflow.close() : overflow.open()

            WMenu {
                id: overflow
                anchorX: -menuWidth + parent.width
                menuWidth: 270
                items: [
                    { id: "palette", label: "Command palette", icon: "command", shortcut: "Ctrl+Shift+P" },
                    { id: "shortcuts", label: "Keyboard shortcuts", icon: "keyboard" },
                    { separator: true },
                    { id: "rename", label: "Rename task", icon: "edit", disabled: !(bridge && bridge.taskId) },
                    { id: "pin", label: bridge && bridge.taskPinned ? "Unpin task" : "Pin task", icon: "pin", disabled: !(bridge && bridge.taskId) },
                    { id: "duplicate", label: "Duplicate task", icon: "duplicate", shortcut: "Ctrl+D", disabled: !(bridge && bridge.taskId) },
                    { id: "export", label: "Export to Markdown", icon: "download", disabled: !(bridge && bridge.hasMessages) },
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
