import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Say what you want done.

    The field is the component; everything else is one row of small controls
    under it. Attachments appear above the field only when they exist, the
    context sources live behind "+", and how the model runs lives behind the
    model button — so nothing here occupies space for a state you are not in.
*/
Item {
    id: root
    signal submitted(string text)
    signal openModelManager()

    property alias text: input.text
    property int maxHeight: 240

    implicitHeight: shell.height

    function focusInput() { input.forceActiveFocus(); }
    // Opened from here by the preview runner, so the picker can be captured
    // the same way every other surface is.
    function showModelPicker() { modelButton.showPicker(); }
    function insert(prompt) {
        input.text = prompt;
        input.cursorPosition = input.length;
        input.forceActiveFocus();
    }

    readonly property bool canSend: input.text.trim().length > 0 && bridge && bridge.online && !bridge.connecting
    readonly property bool tight: root.width < 520

    function send() {
        if (!canSend || (bridge && bridge.busy)) return;
        root.submitted(input.text);
        input.text = "";
    }

    Rectangle {
        id: shell
        width: parent.width
        height: content.implicitHeight + Theme.s3 * 2
        radius: Theme.r3
        color: Theme.surface
        border.width: 1
        border.color: input.activeFocus ? Theme.accentEdge : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.base } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s2

            // -------------------------------------------------- attachments
            // The one canonical view of what the model will be given.
            Flow {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.s1
                visible: bridge && bridge.attachmentCount > 0
                spacing: Theme.s2
                Repeater {
                    model: bridge ? bridge.attachments : []
                    delegate: Chip {
                        required property var modelData
                        text: modelData.title
                        subtitle: modelData.subtitle
                        iconName: ContextKinds.icon(modelData.kind)
                        removable: true
                        interactive: !!modelData.image
                        width: Math.min(implicitWidth, root.width - Theme.s3 * 2)
                        onClicked: if (modelData.image) preview.open()
                        onRemoved: if (bridge) bridge.removeAttachment(modelData.id)
                        ToolTip.visible: hovered && !!modelData.image
                        ToolTip.text: "Preview"

                        Popover {
                            id: preview
                            width: 300
                            height: 220
                            preferredEdge: "above"
                            title: modelData.subtitle || modelData.title
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r2
                                color: Theme.surfaceSunken
                                border.width: 1
                                border.color: Theme.borderSubtle
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: modelData.image ? "data:image/png;base64," + modelData.image : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------- input
            ScrollView {
                Layout.fillWidth: true
                Layout.minimumHeight: 46
                Layout.preferredHeight: Math.min(root.maxHeight, Math.max(46, input.implicitHeight + 6))
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: input
                    objectName: "composer"
                    placeholderText: bridge && bridge.desktopEnabled
                                     ? "Describe what to do on your screen…"
                                     : "Ask Wynxo to inspect, change, build or explain…"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    wrapMode: TextEdit.Wrap
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.body + 1
                    leftPadding: Theme.s2
                    rightPadding: Theme.s2
                    topPadding: Theme.s2
                    bottomPadding: Theme.s2
                    background: Item {}
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Message to Wynxo"
                    Accessible.description: placeholderText

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
                            if (bridge) bridge.pasteImage();
                            event.accepted = true;
                        }
                    }
                }
            }

            // ------------------------------------------------------ toolbar
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                AbstractButton {
                    id: addContext
                    implicitHeight: Theme.controlSmall
                    implicitWidth: addRow.implicitWidth + Theme.s2 * 2
                    hoverEnabled: true
                    Accessible.name: "Add context"
                    onClicked: contextMenu.opened ? contextMenu.close() : contextMenu.open()
                    ToolTip.visible: hovered && root.tight
                    ToolTip.text: "Add context"

                    background: Rectangle {
                        radius: Theme.r2
                        color: addContext.hovered || contextMenu.opened ? Theme.surfaceHover : "transparent"
                        border.width: addContext.visualFocus ? 2 : 0
                        border.color: Theme.accentEdge
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    }
                    contentItem: Row {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: Theme.s2
                        Icon {
                            name: "plus"
                            ink: addContext.hovered ? Theme.textPrimary : Theme.textSecondary
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: !root.tight
                            text: "Context"
                            color: addContext.hovered ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }

                    WMenu {
                        id: contextMenu
                        preferredEdge: "above"
                        menuWidth: 262
                        // Naming the focused window makes it obvious what will
                        // be captured; X11 reports it, Wayland does not.
                        property string windowTitle: ""
                        onAboutToShow: windowTitle = bridge ? bridge.activeWindowTitle() : ""
                        items: [
                            { id: "file", label: "File…", icon: "file" },
                            { id: "folder", label: "Folder…", icon: "folder" },
                            { id: "clipboard", label: "Clipboard", icon: "clipboard" },
                            { separator: true },
                            { id: "screen", label: "Screenshot", icon: "camera" },
                            { id: "region", label: "Screen region…", icon: "crop" },
                            { id: "window",
                              label: contextMenu.windowTitle
                                     ? "Window: " + contextMenu.windowTitle.substring(0, 22)
                                     : "Active window",
                              icon: "window" },
                            { separator: true, hidden: !(bridge && bridge.attachmentCount > 1) },
                            { id: "clear", label: "Remove all context", icon: "close",
                              hidden: !(bridge && bridge.attachmentCount > 1) },
                        ]
                        onPicked: function(id) {
                            if (!bridge) return;
                            if (id === "file") bridge.attachFile();
                            else if (id === "folder") bridge.attachFolder();
                            else if (id === "clipboard") bridge.attachClipboard();
                            else if (id === "screen") bridge.attachScreenshot();
                            else if (id === "region") bridge.attachRegion();
                            else if (id === "window") bridge.attachWindow();
                            else if (id === "clear") bridge.clearAttachments();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Quiet until the window actually starts to fill up.
                Row {
                    visible: bridge && bridge.contextFraction > 0.75 && !root.tight
                    spacing: Theme.s2
                    Text {
                        text: bridge ? Math.round(bridge.contextFraction * 100) + "% context" : ""
                        color: bridge && bridge.contextFraction > 0.9 ? Theme.warning : Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Meter {
                        width: 44
                        value: bridge ? bridge.contextFraction : 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    HoverHandler { id: meterHover }
                    ToolTip.visible: meterHover.hovered
                    ToolTip.text: bridge ? bridge.contextSummary + ". Start a new task to clear it." : ""
                }

                ModelPicker {
                    id: modelButton
                    compact: root.width < 460
                    onOpenModelManager: root.openModelManager()
                }

                IconButton {
                    id: sendButton
                    objectName: "sendButton"
                    iconName: bridge && bridge.busy ? "stop" : "arrow"
                    Layout.preferredWidth: Theme.control
                    Layout.preferredHeight: Theme.controlSmall
                    iconSize: 15
                    tint: bridge && bridge.busy ? Theme.textPrimary
                        : sendButton.enabled ? Theme.onAccent : Theme.textMuted
                    activeTint: tint
                    tooltip: bridge && bridge.busy ? "Stop" : "Send"
                    shortcut: bridge && bridge.busy ? "Esc" : "Enter"
                    enabled: (bridge && bridge.busy) || root.canSend
                    onClicked: bridge && bridge.busy ? bridge.stop() : root.send()
                    background: Rectangle {
                        radius: Theme.r2
                        color: bridge && bridge.busy ? Theme.surfaceHover
                             : sendButton.enabled ? (sendButton.hovered ? Theme.accentHover : Theme.accent)
                             : Theme.surfaceRaised
                        border.width: sendButton.enabled || (bridge && bridge.busy) ? 0 : 1
                        border.color: Theme.borderSubtle
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius; color: "transparent"
                            visible: sendButton.visualFocus
                            border.width: 2; border.color: Theme.accentEdge
                        }
                    }
                }
            }
        }
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
            radius: Theme.r3
            color: Theme.accentMuted
            border.width: 1
            border.color: Theme.accentEdge
            Text {
                anchors.centerIn: parent
                text: "Drop to attach"
                color: Theme.textPrimary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
            }
        }
    }
}
