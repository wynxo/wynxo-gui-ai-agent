import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Say what you want done.

    The empty-state composer is intentionally compact in Chat and Work. Codex
    expands it into a small project console: the selected folder is always
    visible, Terminal is one click away, and common coding jobs can seed a
    precise agent prompt without turning the home screen into a dashboard.
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

    readonly property string mode: bridge && bridge.desktopEnabled ? "work" : WorkspaceMode.current
    readonly property bool codexMode: root.mode === "codex"
    readonly property bool workMode: root.mode === "work"
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
        radius: root.homeMode && !root.hasAttachments && !root.codexMode ? Math.min(26, height / 2) : 22
        color: Theme.surfaceRaised
        border.width: 1
        border.color: input.activeFocus ? Theme.borderStrong : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.base } }
        Behavior on radius { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: root.shellPadding
            spacing: root.hasAttachments || root.codexMode ? Theme.s2 : 0

            // ----------------------------------------------------- Codex bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: codexProjectRow.implicitHeight + Theme.s2 * 2
                visible: root.codexMode
                radius: 14
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle

                RowLayout {
                    id: codexProjectRow
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s3
                    anchors.rightMargin: Theme.s2
                    spacing: Theme.s2

                    Icon {
                        name: "code"
                        ink: Theme.accent
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: bridge && bridge.projectPath ? bridge.projectName : "No project selected"
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.label
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: bridge && bridge.projectPath
                                ? bridge.projectLabel
                                : "Choose a folder so Codex knows what it may inspect, edit, run, and test."
                            color: Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.micro
                            elide: Text.ElideMiddle
                        }
                    }

                    WButton {
                        text: bridge && bridge.projectPath ? "Change" : "Choose project"
                        iconName: "folderOpen"
                        variant: bridge && bridge.projectPath ? "ghost" : "secondary"
                        compactPadding: true
                        implicitHeight: 30
                        onClicked: if (bridge) bridge.chooseProject()
                    }

                    IconButton {
                        visible: !root.tight
                        iconName: "terminal"
                        tooltip: bridge && bridge.projectPath ? "Open terminal in project" : "Choose a project first"
                        enabled: !!(bridge && bridge.projectPath)
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        iconSize: 14
                        onClicked: if (bridge) bridge.openTerminalHere()
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.codexMode && root.homeMode
                columns: root.width < 560 ? 2 : 4
                columnSpacing: Theme.s2
                rowSpacing: Theme.s2

                Repeater {
                    model: [
                        {
                            label: "Inspect repo", icon: "search",
                            prompt: "Inspect this project before changing anything. Identify the stack, entry points, architecture, important files, and the commands used to build, lint, and test it. Give me a concise codebase map."
                        },
                        {
                            label: "Run tests", icon: "terminal",
                            prompt: "Detect the correct test command for this project, run the relevant test suite, and explain any failures. Do not edit files yet."
                        },
                        {
                            label: "Fix tests", icon: "bug",
                            prompt: "Run the project tests, diagnose the failures, make the smallest correct code changes, rerun the relevant tests, and summarize the files changed."
                        },
                        {
                            label: "Review diff", icon: "branch",
                            prompt: "Inspect git status and the current diff. Review the changes for bugs, regressions, security problems, and unnecessary edits. Do not modify files unless I ask."
                        },
                    ]

                    delegate: WButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.label
                        iconName: modelData.icon
                        variant: "ghost"
                        compactPadding: true
                        implicitHeight: 32
                        enabled: !!(bridge && bridge.projectPath) && !(bridge && bridge.busy)
                        onClicked: root.insert(modelData.prompt)
                        ToolTip.visible: hovered && !enabled
                        ToolTip.text: "Choose a project folder first"
                    }
                }
            }

            // -------------------------------------------------- attachments
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
                    ToolTip.text: "Add files, screenshots, or folders"
                    ToolTip.delay: 650

                    background: Rectangle {
                        radius: Theme.rPill
                        color: addContext.hovered || contextMenu.opened ? Theme.surfaceHover : "transparent"
                        border.width: addContext.visualFocus ? 2 : 0
                        border.color: Theme.accentEdge
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    }
                    contentItem: Item {
                        Icon {
                            anchors.centerIn: parent
                            name: "plus"
                            ink: addContext.hovered ? Theme.textPrimary : Theme.textSecondary
                            width: 15; height: 15
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
                        placeholderText: root.codexMode
                            ? (bridge && bridge.projectPath ? "Describe a code change, bug, or coding task" : "Choose a project, then describe what to build")
                            : root.homeMode
                                ? (root.workMode ? "Describe what to do on your screen" : "Message Wynxo")
                                : (root.workMode ? "Describe what to do on your screen…" : "Ask anything")
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
                        Accessible.name: root.codexMode ? "Coding task for Wynxo" : "Message to Wynxo"
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
