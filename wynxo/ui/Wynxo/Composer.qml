import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The command box is the centre of the product. It behaves like a coding-agent
    prompt rather than a chat bubble: roomy text area, context above, controls
    below, and no decorative quick-action dashboard.
*/
Item {
    id: root
    signal submitted(string text)
    signal openModelManager()

    property alias text: input.text
    property int maxHeight: 220
    implicitHeight: shell.height

    function focusInput() { input.forceActiveFocus(); }
    function showModelPicker() { modelButton.showPicker(); }
    function insert(prompt) {
        input.text = prompt;
        input.cursorPosition = input.length;
        input.forceActiveFocus();
    }

    Connections {
        target: bridge
        function onDraftChanged() { input.text = bridge.draftText; }
    }
    Component.onCompleted: if (bridge) input.text = bridge.draftText

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property bool codexMode: root.mode === "codex"
    readonly property bool workMode: root.mode === "work"
    readonly property bool homeMode: bridge && !bridge.hasMessages
    readonly property bool hasAttachments: bridge && bridge.attachmentCount > 0
    readonly property bool tight: root.width < 520
    readonly property bool canSend: input.text.trim().length > 0 && bridge && bridge.online && !bridge.connecting

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
        border.color: input.activeFocus ? Theme.borderStrong : Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s2

            // -------------------------------------------------- attachments
            Flow {
                Layout.fillWidth: true
                visible: root.hasAttachments
                spacing: Theme.s2

                Repeater {
                    model: bridge ? bridge.attachments : []
                    delegate: Item {
                        id: attachment
                        required property var modelData
                        readonly property bool isImage: !!modelData.image
                        width: isImage ? 72 : Math.min(fileChip.implicitWidth, root.width - Theme.s5)
                        height: isImage ? 72 : fileChip.implicitHeight

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
                            visible: attachment.isImage
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
                            width: 18; height: 18
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            hoverEnabled: true
                            Accessible.name: "Remove " + modelData.title
                            onClicked: if (bridge) bridge.removeAttachment(modelData.id)
                            background: Rectangle {
                                radius: 9
                                color: removeImage.hovered ? Theme.textPrimary : Theme.alpha(Theme.background, 0.92)
                                border.width: 1
                                border.color: Theme.borderStrong
                            }
                            contentItem: Text {
                                text: "×"
                                color: removeImage.hovered ? Theme.textInverse : Theme.textPrimary
                                font.family: Theme.sansFamily
                                font.pixelSize: 13
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

            // ------------------------------------------------------- prompt
            ScrollView {
                Layout.fillWidth: true
                Layout.minimumHeight: root.homeMode ? 66 : 48
                Layout.preferredHeight: Math.min(root.maxHeight,
                    Math.max(root.homeMode ? 66 : 48, input.implicitHeight + Theme.s2))
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    id: input
                    objectName: "composer"
                    onTextChanged: if (bridge) bridge.setDraft(text)
                    placeholderText: root.codexMode
                        ? (bridge && bridge.projectPath
                            ? "Ask Wynxi to build, fix, explain, run, or review…"
                            : "Open a project, then describe the coding task…")
                        : root.workMode
                            ? "Describe what you want done on the desktop…"
                            : "Ask Wynxo anything…"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    wrapMode: TextEdit.Wrap
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.body
                    leftPadding: 1
                    rightPadding: 1
                    topPadding: Theme.s1
                    bottomPadding: Theme.s1
                    background: Item {}
                    Accessible.role: Accessible.EditableText
                    Accessible.name: root.codexMode ? "Coding task for Wynxi" : "Message to Wynxo"
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

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderSubtle }

            // ------------------------------------------------------ toolbar
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s1

                IconButton {
                    id: addContext
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    iconSize: 14
                    iconName: "plus"
                    tooltip: "Add context"
                    active: contextMenu.opened
                    onClicked: contextMenu.opened ? contextMenu.close() : contextMenu.open()

                    WMenu {
                        id: contextMenu
                        preferredEdge: "above"
                        menuWidth: 260
                        property string windowTitle: ""
                        onAboutToShow: windowTitle = bridge ? bridge.activeWindowTitle() : ""
                        items: [
                            { id: "file", label: "File…", icon: "file" },
                            { id: "folder", label: "Folder…", icon: "folder" },
                            { id: "clipboard", label: "Clipboard", icon: "clipboard" },
                            { separator: true },
                            { id: "screen", label: "Screenshot", icon: "camera" },
                            { id: "region", label: "Screen region…", icon: "crop" },
                            { id: "window", label: contextMenu.windowTitle
                                ? "Window: " + contextMenu.windowTitle.substring(0, 22)
                                : "Active window", icon: "window" },
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

                AbstractButton {
                    id: projectChip
                    visible: root.codexMode
                    Layout.preferredHeight: 28
                    Layout.maximumWidth: Math.max(150, root.width * 0.34)
                    implicitWidth: projectRow.implicitWidth + Theme.s3 * 2
                    hoverEnabled: true
                    Accessible.name: bridge && bridge.projectPath ? "Project " + bridge.projectName : "Open project"
                    onClicked: if (bridge) bridge.chooseProject()
                    background: Rectangle {
                        radius: Theme.r1
                        color: projectChip.hovered ? Theme.surfaceHover : "transparent"
                        border.width: 1
                        border.color: Theme.borderSubtle
                    }
                    contentItem: Row {
                        id: projectRow
                        anchors.centerIn: parent
                        spacing: Theme.s2
                        Icon {
                            name: bridge && bridge.projectPath ? "folderOpen" : "folder"
                            ink: bridge && bridge.projectPath ? Theme.textSecondary : Theme.textMuted
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: bridge && bridge.projectPath ? bridge.projectName : "Open project"
                            color: bridge && bridge.projectPath ? Theme.textSecondary : Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.micro
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                }

                IconButton {
                    visible: root.codexMode && !root.tight
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    iconName: "terminal"
                    iconSize: 13
                    tooltip: bridge && bridge.projectPath ? "Open terminal in project" : "Open a project first"
                    enabled: !!(bridge && bridge.projectPath)
                    onClicked: if (bridge) bridge.openTerminalHere()
                }

                Chip {
                    visible: root.workMode && !root.tight
                    text: bridge && bridge.desktopEnabled ? "Screen on" : "Work"
                    iconName: "cursor"
                    selected: bridge && bridge.desktopEnabled
                }

                Row {
                    visible: bridge && bridge.contextFraction > 0.75 && !root.tight
                    spacing: Theme.s2
                    Text {
                        text: bridge ? Math.round(bridge.contextFraction * 100) + "% ctx" : ""
                        color: bridge && bridge.contextFraction > 0.9 ? Theme.warning : Theme.textMuted
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.micro
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Meter {
                        width: 38
                        value: bridge ? bridge.contextFraction : 0
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    HoverHandler { id: meterHover }
                    ToolTip.visible: meterHover.hovered
                    ToolTip.text: bridge ? bridge.contextSummary + ". Start a new task to clear it." : ""
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.width > 620 && !(bridge && bridge.busy)
                    text: "Shift+Enter newline"
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.micro
                }

                ModelPicker {
                    id: modelButton
                    compact: root.tight
                    onOpenModelManager: root.openModelManager()
                }

                IconButton {
                    id: sendButton
                    objectName: "sendButton"
                    iconName: bridge && bridge.busy ? "stop" : "arrow"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    iconSize: 14
                    tint: bridge && bridge.busy ? Theme.textPrimary
                        : sendButton.enabled ? Theme.onAccent : Theme.textMuted
                    activeTint: tint
                    tooltip: bridge && bridge.busy ? "Stop" : "Send"
                    shortcut: bridge && bridge.busy ? "Esc" : "Enter"
                    enabled: (bridge && bridge.busy) || root.canSend
                    onClicked: bridge && bridge.busy ? bridge.stop() : root.send()
                    background: Rectangle {
                        radius: Theme.r1
                        color: bridge && bridge.busy ? Theme.surfaceHover
                             : sendButton.enabled ? (sendButton.hovered ? Theme.accentHover : Theme.accent)
                             : Theme.surfaceRaised
                        border.width: sendButton.enabled || (bridge && bridge.busy) ? 0 : 1
                        border.color: Theme.borderSubtle
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: parent.radius + 2
                            color: "transparent"
                            visible: sendButton.visualFocus
                            border.width: 1
                            border.color: Theme.accentEdge
                        }
                    }
                }
            }
        }
    }

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
                text: "Drop files to add context"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.label
            }
        }
    }
}
