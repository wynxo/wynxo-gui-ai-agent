import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Where you are, what is happening, and which kind of assistant you want.

    Chat is the quiet conversational surface, Work owns visual desktop control,
    and Codex is the project-first coding surface. The selector stays centered
    on the home screen and remains available in wide active conversations; on
    narrow windows the same three modes live in the overflow menu.
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
    readonly property string resolvedMode: bridge && bridge.desktopEnabled ? "work" : WorkspaceMode.current

    function requestMode(value) {
        if (value !== "chat" && value !== "work" && value !== "codex") return;
        if (!bridge || bridge.connecting || bridge.busy) return;
        if (value === root.resolvedMode) {
            // A failed/denied Work connection leaves the tab selected so the
            // user can see what they asked for; clicking it again must retry.
            if (value !== "work" || bridge.desktopEnabled) return;
        }
        WorkspaceMode.current = value;
        root.modeRequested(value);
    }

    Shortcut { sequences: ["Ctrl+1"]; onActivated: root.requestMode("chat") }
    Shortcut { sequences: ["Ctrl+2"]; onActivated: root.requestMode("work") }
    Shortcut { sequences: ["Ctrl+3"]; onActivated: root.requestMode("codex") }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // Independent from the row below so left/right status controls never knock
    // the mode switch off the geometric center of the workspace.
    Segmented {
        id: modeSwitch
        visible: root.homeMode || root.width >= 960
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: root.homeMode ? Math.min(300, Math.max(220, root.width - 150)) : 292
        height: 36
        z: 4
        options: [
            { id: "chat", label: "Chat", detail: "Conversation and local non-visual tools" },
            { id: "work", label: "Work", detail: "Visual desktop control with Ollama" },
            { id: "codex", label: "Codex", detail: "Project-aware coding, commands, edits and tests" },
        ]
        current: root.resolvedMode
        onSelected: function(value) { root.requestMode(value); }
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

        // -------------------------------------------------- the breadcrumb
        RowLayout {
            visible: !root.homeMode
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            spacing: Theme.s2

            AbstractButton {
                id: titleButton
                Layout.fillWidth: true
                Layout.maximumWidth: Math.min(implicitWidth,
                    modeSwitch.visible ? Math.max(120, root.width * 0.23) : Math.max(180, root.width * 0.48))
                implicitHeight: Theme.controlSmall
                implicitWidth: titleText.implicitWidth + Theme.s2 * 2
                hoverEnabled: true
                enabled: !!(bridge && bridge.taskId)
                opacity: 1
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
                    text: bridge && bridge.hasMessages ? bridge.taskTitle : "Wynxo"
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
            Layout.maximumWidth: Math.max(120, root.width * (modeSwitch.visible ? 0.26 : 0.38))
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
                        : bridge.desktopEnabled ? "Working on your screen" : "Running"
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
            visible: !root.homeMode && bridge && bridge.desktopEnabled && !bridge.busy
                     && root.width > 720 && !modeSwitch.visible
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
                    { id: "modeChat", label: "Chat mode", icon: "chat", shortcut: "Ctrl+1", disabled: root.resolvedMode === "chat" },
                    { id: "modeWork", label: "Work mode", icon: "desktop", shortcut: "Ctrl+2", disabled: root.resolvedMode === "work" && bridge && bridge.desktopEnabled },
                    { id: "modeCodex", label: "Codex mode", icon: "code", shortcut: "Ctrl+3", disabled: root.resolvedMode === "codex" },
                    { separator: true },
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
                    if (id === "modeChat") root.requestMode("chat");
                    else if (id === "modeWork") root.requestMode("work");
                    else if (id === "modeCodex") root.requestMode("codex");
                    else if (id === "palette") root.openCommandPalette();
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
