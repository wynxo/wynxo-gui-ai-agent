import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! Almost nothing: what you are in, what it runs on, and one overflow menu. */
Item {
    id: root
    property bool sidebarCollapsed: false
    property bool inspectorOpen: true
    signal toggleSidebar()
    signal toggleInspector()
    signal renameRequested()
    signal openModelPicker()
    signal openSettings()
    signal openCommandPalette()
    signal openDesktopSettings()
    signal clearRequested()

    implicitHeight: Theme.compact ? 52 : 60

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.borderSubtle }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        spacing: Theme.s2

        IconButton {
            iconName: root.sidebarCollapsed ? "panel" : "panelLeft"
            tooltip: "Toggle sidebar · Ctrl+B"
            onClicked: root.toggleSidebar()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: bridge ? bridge.taskTitle : "Wynxo"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.heading
                font.weight: Font.Medium
                elide: Text.ElideRight
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onDoubleClicked: root.renameRequested()
                    hoverEnabled: true
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Double-click to rename"
                    ToolTip.delay: 700
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== "" && !Theme.compact
                text: bridge && bridge.busy ? bridge.status
                    : bridge && bridge.desktopEnabled ? "Screen control · " + bridge.permissionModeLabel : ""
                color: bridge && bridge.desktopEnabled && !bridge.busy ? Theme.accent : Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.micro
                elide: Text.ElideRight
            }
        }

        // ------------------------------------------------ screen control
        Item {
            visible: bridge && bridge.desktopEnabled
            Layout.preferredWidth: controlRow.implicitWidth + Theme.s4
            Layout.preferredHeight: Theme.controlSmall
            Rectangle {
                anchors.fill: parent
                radius: Theme.rPill
                color: Theme.accentMuted
                border.width: 1
                border.color: Theme.accentEdge
            }
            Row {
                id: controlRow
                anchors.centerIn: parent
                spacing: Theme.s2
                StatusDot { tone: Theme.accent; pulsing: bridge && bridge.busy; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Screen control active"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.openDesktopSettings()
                ToolTip.visible: containsMouse
                ToolTip.text: "Permission mode: " + (bridge ? bridge.permissionModeLabel : "") + " — click to change"
            }
        }

        WButton {
            visible: bridge && bridge.busy
            text: "Stop"
            iconName: "stop"
            variant: "danger"
            compactPadding: true
            onClicked: bridge && bridge.stop()
            ToolTip.visible: hovered
            ToolTip.text: "Stop everything · Esc"
        }

        // ------------------------------------------------- ollama status
        Item {
            Layout.preferredWidth: statusRow.implicitWidth + Theme.s4
            Layout.preferredHeight: Theme.controlSmall
            Rectangle {
                anchors.fill: parent
                radius: Theme.rPill
                color: statusMouse.containsMouse ? Theme.surfaceHover : "transparent"
                border.width: 1
                border.color: Theme.borderSubtle
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
            }
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: Theme.s2
                StatusDot {
                    anchors.verticalCenter: parent.verticalCenter
                    tone: {
                        var state = bridge ? bridge.connectionState : "offline";
                        if (state === "connected") return Theme.success;
                        if (state === "connecting" || state === "downloading") return Theme.warning;
                        return Theme.danger;
                    }
                    pulsing: bridge && (bridge.connectionState === "connecting" || bridge.connectionState === "downloading")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bridge ? bridge.connectionLabel : "Ollama"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
            }
            MouseArea {
                id: statusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bridge && bridge.refreshModels()
                ToolTip.visible: containsMouse
                ToolTip.text: bridge ? bridge.endpoint + " — click to reconnect" : ""
            }
        }

        // -------------------------------------------------- model chip
        Chip {
            visible: root.width > 700
            text: bridge ? bridge.model : "No model"
            iconName: "layers"
            Layout.maximumWidth: 210
            onClicked: root.openModelPicker()
            ToolTip.visible: hovered
            ToolTip.text: bridge ? bridge.modelCapabilitySummary : ""
        }

        IconButton {
            iconName: "more"
            tooltip: "More actions"
            active: overflow.opened
            onClicked: overflow.opened ? overflow.close() : overflow.open()

            WMenu {
                id: overflow
                x: -menuWidth + parent.width
                y: parent.height + Theme.s2
                menuWidth: 268
                items: [
                    { id: "palette", label: "Command palette", icon: "spark", shortcut: "Ctrl+Shift+P" },
                    { id: "rename", label: "Rename chat", icon: "edit", disabled: !(bridge && bridge.taskId) },
                    { id: "pin", label: bridge && bridge.taskPinned ? "Unpin chat" : "Pin chat", icon: "pin", disabled: !(bridge && bridge.taskId) },
                    { id: "duplicate", label: "Duplicate chat", icon: "duplicate", shortcut: "Ctrl+D", disabled: !(bridge && bridge.taskId) },
                    { id: "export", label: "Export to Markdown", icon: "download", disabled: !(bridge && bridge.hasMessages) },
                    { separator: true },
                    { id: "regenerate", label: "Regenerate", icon: "retry", shortcut: "Ctrl+R", disabled: !(bridge && bridge.canRegenerate) },
                    { id: "clear", label: "Clear messages", icon: "trash", disabled: !(bridge && bridge.hasMessages) },
                    { separator: true },
                    { id: "inspector", label: root.inspectorOpen ? "Hide inspector" : "Show inspector", icon: "panel", shortcut: "Ctrl+I" },
                    { id: "settings", label: "Settings", icon: "sliders", shortcut: "Ctrl+," },
                ]
                onPicked: function(id) {
                    if (id === "palette") root.openCommandPalette();
                    else if (id === "rename") root.renameRequested();
                    else if (id === "inspector") root.toggleInspector();
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

        IconButton {
            visible: root.width > 640
            iconName: "panel"
            tooltip: "Toggle inspector · Ctrl+I"
            active: root.inspectorOpen
            onClicked: root.toggleInspector()
        }
    }
}
