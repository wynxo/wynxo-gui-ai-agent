import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Say what you want done.

    The empty-state composer is intentionally compact: one rounded row with
    add-context, input, model and send. It grows only when text wraps or context
    is attached. Image context becomes a real thumbnail instead of a text chip,
    making the expanded state read like a modern desktop chat composer.
*/
Item {
    id: root
    signal submitted(string text)
    signal openModelManager()

    property alias text: input.text
    property int maxHeight: 240

    implicitHeight: shell.height

    function focusInput() { input.forceActiveFocus(); }
    function showModelPicker() { modelButton.showPicker(); }

    // What you typed belongs to the task you typed it in, so switching tasks
    // parks it rather than throwing it away.
    Connections {
        target: bridge
        function onDraftChanged() { input.text = bridge.draftText; }
    }
    Component.onCompleted: if (bridge) input.text = bridge.draftText
    function insert(prompt) {
        input.text = prompt;
        input.cursorPosition = input.length;
        input.forceActiveFocus();
    }

    readonly property bool canSend: input.text.trim().length > 0 && bridge && bridge.online && !bridge.connecting
    readonly property bool tight: root.width < 520
    readonly property bool homeMode: bridge && !bridge.hasMessages
    readonly property bool hasAttachments: bridge && bridge.attachmentCount > 0
    readonly property int shellPadding: root.homeMode ? 6 : Theme.s3

    function send() {
        if (!canSend || (bridge && bridge.busy)) return;
        root.submitted(input.text);
        input.text = "";
    }

    Rectangle {
        id: shell
        width: parent.width
        height: content.implicitHeight + root.shellPadding * 2
        radius: root.homeMode && !root.hasAttachments ? Math.min(26, height / 2) : 22
        color: Theme.surfaceRaised
        border.width: 1
        border.color: input.activeFocus ? Theme.borderStrong : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.base } }
        Behavior on radius { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: root.shellPadding
            spacing: root.hasAttachments ? Theme.s2 : 0

            // -------------------------------------------------- attachments
            // Files stay concise; images get a proper visual preview like the
            // desktop ChatGPT composer rather than a filename-only chip.
            Flow {
                Layout.fillWidth: true
                Layout.bottomMargin: root.hasAttachments ? Theme.s1 : 0
                visible: root.hasAttachments
                spacing: Theme.s2

                Repeater {
                    model: bridge ? bridge.attachments : []

                    delegate: Item {
                        id: attachment
                        required property var modelData
                        readonly property bool isImage: !!modelData.image
                        width: isImage ? 82 : Math.min(fileChip.implicitWidth, root.width - Theme.s4)
                        height: isImage ? 82 : fileChip.implicitHeight

                        Chip {
                            id: fileChip
                            visible: !attachment.isImage
                            width: parent.width
                            text: modelData.title
                            subtitle: modelData.subtitle
                            iconName: ContextKinds.icon(modelData.kind)
                            removable: true
                            onRemoved: if (bridge) bridge.removeAttachment(modelData.id)
                        }

                        Rectangle {
                            id: thumbnail
                            visible: attachment.isImage
                            anchors.fill: parent
                            radius: 11
                            color: Theme.surfaceSunken
                            border.width: 1
                            border.color: Theme.borderSubtle
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: attachment.isImage ? "data:image/png;base64," + modelData.image : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: preview.open()
                            }
                        }

                        AbstractButton {
                            id: removeImage
                            visible: attachment.isImage
                            z: 4
                            width: 20; height: 20
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            hoverEnabled: true
                            Accessible.name: "Remove " + modelData.title
                            onClicked: if (bridge) bridge.removeAttachment(modelData.id)
                            background: Rectangle {
                                radius: 10
                                color: removeImage.hovered ? Theme.textPrimary : Theme.alpha(Theme.backgroundSoft, 0.90)
                                border.width: 1
                                border.color: Theme.alpha(Theme.textPrimary, 0.18)
                            }
                            contentItem: Text {
                                text: "×"
                                color: removeImage.hovered ? Theme.textInverse : Theme.textPrimary
                                font.family: Theme.sansFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                        }

                        Popover {
                            id: preview
                            width: 320
                            height: 238
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
                                    source: attachment.isImage ? "data:image/png;base64," + modelData.image : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ composer row
            RowLayout {
                id: composerRow
                Layout.fillWidth: true
                spacing: Theme.s1

                AbstractButton {
                    id: addContext
                    Layout.preferredWidth: root.homeMode ? 32 : Theme.control
                    Layout.preferredHeight: root.homeMode ? 32 : Theme.control
                    hoverEnabled: true
                    Accessible.name: "Add context"
                    onClicked: contextMenu.opened ? contextMenu.close() : contextMenu.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Add context"
                    ToolTip.delay: 650

                    background: Rectangle {
                        radius: Theme.rPill
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
                            width: 15; height: 15
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            visible: !root.homeMode && !root.tight
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

                // -------------------------------------------------------- input
                ScrollView {
                    Layout.fillWidth: true
                    Layout.minimumHeight: root.homeMode ? 34 : 40
                    Layout.preferredHeight: Math.min(root.maxHeight,
                                                     Math.max(root.homeMode ? 34 : 42,
                                                              input.implicitHeight + 2))
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        id: input
                        objectName: "composer"
                        onTextChanged: if (bridge) bridge.setDraft(text)
                        placeholderText: root.homeMode
                            ? (bridge && bridge.desktopEnabled ? "Describe what to do on your screen" : "Message Wynxo")
                            : (bridge && bridge.desktopEnabled ? "Describe what to do on your screen…" : "Ask anything")
                        placeholderTextColor: Theme.textMuted
                        color: Theme.textPrimary
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        wrapMode: TextEdit.Wrap
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.body
                        leftPadding: Theme.s1
                        rightPadding: Theme.s1
                        topPadding: root.homeMode ? 7 : Theme.s2
                        bottomPadding: root.homeMode ? 7 : Theme.s2
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

                // Quiet until the context window actually starts to fill.
                Row {
                    visible: bridge && bridge.contextFraction > 0.75 && !root.tight && !root.homeMode
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
                    compact: root.homeMode || root.width < 460
                    onOpenModelManager: root.openModelManager()
                }

                IconButton {
                    id: sendButton
                    objectName: "sendButton"
                    iconName: bridge && bridge.busy ? "stop" : "arrow"
                    Layout.preferredWidth: root.homeMode ? 32 : Theme.control
                    Layout.preferredHeight: root.homeMode ? 32 : Theme.control
                    iconSize: 15
                    tint: bridge && bridge.busy ? Theme.textPrimary
                        : sendButton.enabled ? Theme.onAccent : Theme.textMuted
                    activeTint: tint
                    tooltip: bridge && bridge.busy ? "Stop" : "Send"
                    shortcut: bridge && bridge.busy ? "Esc" : "Enter"
                    enabled: (bridge && bridge.busy) || root.canSend
                    onClicked: bridge && bridge.busy ? bridge.stop() : root.send()
                    background: Rectangle {
                        radius: Theme.rPill
                        color: bridge && bridge.busy ? Theme.surfaceHover
                             : sendButton.enabled ? (sendButton.hovered ? Theme.accentHover : Theme.accent)
                             : Theme.surfaceHover
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
            radius: shell.radius
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
