import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The command centre.

    Progressive disclosure: attachments appear only when they exist, the
    context menu lives behind "+", and secondary readouts stay in tooltips.
*/
Item {
    id: root
    signal submitted(string text)
    signal openModelPicker()
    signal openDesktopSettings()

    property alias text: input.text
    property int maxHeight: 260

    implicitHeight: shell.height

    function focusInput() { input.forceActiveFocus(); }
    function insert(prompt) { input.text = prompt; input.cursorPosition = input.length; input.forceActiveFocus(); }

    Rectangle {
        id: shell
        width: parent.width
        height: content.implicitHeight + Theme.s3 * 2
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: input.activeFocus ? Theme.accentEdge : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.base } }
        Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s2

            // -------------------------------------------------- attachments
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s1
                visible: bridge && bridge.attachmentCount > 0
                spacing: Theme.s2
                Repeater {
                    model: bridge ? bridge.attachments : []
                    delegate: Chip {
                        required property var modelData
                        text: modelData.title
                        subtitle: modelData.subtitle
                        iconName: modelData.kind === "image" ? "image"
                                : modelData.kind === "screenshot" ? "camera"
                                : modelData.kind === "window" ? "window"
                                : modelData.kind === "folder" ? "folder"
                                : modelData.kind === "clipboard" ? "clipboard" : "file"
                        removable: true
                        interactive: false
                        onRemoved: bridge && bridge.removeAttachment(modelData.id)
                    }
                }
            }

            // -------------------------------------------------------- input
            ScrollView {
                Layout.fillWidth: true
                Layout.minimumHeight: 44
                Layout.preferredHeight: Math.min(root.maxHeight, Math.max(44, input.implicitHeight + 8))
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: input
                    objectName: "composer"
                    placeholderText: bridge && bridge.desktopEnabled
                                     ? "Describe what to do on your screen…"
                                     : "Ask Wynxo anything…"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    wrapMode: TextEdit.Wrap
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.body + 1
                    leftPadding: Theme.s3
                    rightPadding: Theme.s3
                    topPadding: Theme.s2
                    bottomPadding: Theme.s2
                    background: Item {}

                    Keys.onReturnPressed: function(event) {
                        if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return; }
                        root.send(); event.accepted = true;
                    }
                    Keys.onEnterPressed: function(event) {
                        if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return; }
                        root.send(); event.accepted = true;
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)
                                && (event.modifiers & Qt.ShiftModifier)) {
                            bridge && bridge.pasteImage();
                            event.accepted = true;
                        }
                    }
                }
            }

            // ------------------------------------------------------ toolbar
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s1

                IconButton {
                    iconName: "plus"
                    tooltip: "Add context"
                    width: Theme.control; height: Theme.control
                    active: contextMenu.opened
                    onClicked: contextMenu.opened ? contextMenu.close() : contextMenu.open()
                }

                WMenu {
                    id: contextMenu
                    y: -implicitHeight - Theme.s2
                    menuWidth: 250
                    items: [
                        { id: "file", label: "File…", icon: "file" },
                        { id: "folder", label: "Folder…", icon: "folder" },
                        { id: "clipboard", label: "Clipboard", icon: "clipboard" },
                        { separator: true },
                        { id: "screen", label: "Capture screen", icon: "camera" },
                        { id: "window", label: "Capture active window", icon: "window" },
                    ]
                    onPicked: function(id) {
                        if (!bridge) return;
                        if (id === "file") bridge.attachFile();
                        else if (id === "folder") bridge.attachFolder();
                        else if (id === "clipboard") bridge.attachClipboard();
                        else if (id === "screen") bridge.attachScreenshot();
                        else if (id === "window") bridge.attachWindow();
                    }
                }

                Chip {
                    text: bridge ? bridge.model : "No model"
                    iconName: "layers"
                    onClicked: root.openModelPicker()
                    Layout.maximumWidth: Math.max(120, root.width * 0.24)
                    ToolTip.visible: hovered
                    ToolTip.text: bridge ? bridge.modelCapabilitySummary : ""
                }

                Chip {
                    visible: root.width > 620
                    text: bridge ? bridge.runtimePreset : "Balanced"
                    iconName: "bolt"
                    onClicked: runtimeMenu.opened ? runtimeMenu.close() : runtimeMenu.open()
                    ToolTip.visible: hovered
                    ToolTip.text: bridge ? bridge.runtimeSummary : ""

                    WMenu {
                        id: runtimeMenu
                        y: -implicitHeight - Theme.s2
                        menuWidth: 250
                        items: [
                            { id: "Fast", label: "Fast", icon: "bolt", shortcut: "8K" },
                            { id: "Balanced", label: "Balanced", icon: "spark", shortcut: "16K" },
                            { id: "Deep", label: "Deep", icon: "brain", shortcut: "32K" },
                        ]
                        onPicked: function(id) { bridge && bridge.applyRuntimePreset(id); }
                    }
                }

                Item {
                    // Context meter: quiet until it starts to matter.
                    visible: root.width > 760 && bridge && bridge.contextUsed > 0
                    Layout.leftMargin: Theme.s2
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: Theme.controlSmall
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: 62
                        Text {
                            text: bridge ? Math.round(bridge.contextFraction * 100) + "% context" : ""
                            color: bridge && bridge.contextFraction > 0.9 ? Theme.warning : Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        }
                        Meter { width: 62; value: bridge ? bridge.contextFraction : 0 }
                    }
                    HoverHandler { id: meterHover }
                    ToolTip.visible: meterHover.hovered
                    ToolTip.text: bridge ? bridge.contextSummary : ""
                }

                Item { Layout.fillWidth: true }

                Chip {
                    visible: bridge && bridge.desktopEnabled && root.width > 560
                    text: root.width > 780 ? "Screen control" : "Screen"
                    iconName: "cursor"
                    selected: true
                    onClicked: root.openDesktopSettings()
                    ToolTip.visible: hovered
                    ToolTip.text: bridge ? "Permission mode: " + bridge.permissionModeLabel : ""
                }

                Item { Layout.preferredWidth: Theme.s1 }

                IconButton {
                    id: sendButton
                    objectName: "sendButton"
                    iconName: bridge && bridge.busy ? "stop" : "arrow"
                    Layout.preferredWidth: Theme.control + 6
                    Layout.preferredHeight: Theme.control
                    iconSize: 17
                    tint: bridge && bridge.busy ? Theme.textPrimary : Theme.onAccent
                    activeTint: tint
                    tooltip: bridge && bridge.busy ? "Stop · Esc" : "Send · Enter"
                    enabled: (bridge && bridge.busy) || root.canSend
                    onClicked: bridge && bridge.busy ? bridge.stop() : root.send()
                    background: Rectangle {
                        radius: Theme.r2
                        color: bridge && bridge.busy ? Theme.surfaceHover
                             : sendButton.enabled ? (sendButton.hovered ? Theme.accentHover : Theme.accent)
                             : Theme.surfaceRaised
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    }
                }
            }
        }
    }

    readonly property bool canSend: input.text.trim().length > 0 && bridge && bridge.online && !bridge.connecting

    function send() {
        if (!canSend || (bridge && bridge.busy)) return;
        root.submitted(input.text);
        input.text = "";
    }

    // Drag and drop straight into the composer.
    DropArea {
        anchors.fill: parent
        onEntered: function(drag) { if (drag.hasUrls) drag.accept(); }
        onDropped: function(drop) {
            if (!bridge || !drop.hasUrls) return;
            for (var i = 0; i < drop.urls.length; i++)
                bridge.attachPath(drop.urls[i].toString());
            drop.accept();
        }
        Rectangle {
            anchors.fill: parent
            visible: parent.containsDrag
            radius: Theme.r4
            color: Theme.accentMuted
            border.width: 1
            border.color: Theme.accentEdge
            Text {
                anchors.centerIn: parent
                text: "Drop files to attach"
                color: Theme.textPrimary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
            }
        }
    }
}
