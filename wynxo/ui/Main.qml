import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1440; height: 920
    minimumWidth: 880; minimumHeight: 650
    visible: true
    title: bridge && bridge.taskTitle + " — Wynxo"
    color: bridge && bridge.solidBackground ? "#0d100f" : "#121615"
    font.family: "Lato"
    font.pixelSize: 14
    property bool inspectorOpen: true
    property bool closing: false
    property string searchText: ""
    property color accent: bridge && bridge.accentColor ? bridge.accentColor : "#b9dfc6"
    property color muted: "#858f89"
    property color bright: "#e7ece8"
    property var themeNames: ["Obsidian", "Violet", "Ice", "Amber", "Rose"]
    property var themeColors: ({ "Obsidian": "#b9dfc6", "Violet": "#c7b6ff", "Ice": "#9fd5ff", "Amber": "#f0c27b", "Rose": "#f2a7be" })

    onClosing: function(close) {
        if (bridge && !bridge.canClose()) { close.accepted = false; closing = true; closeTimer.start(); }
    }
    Timer { id: closeTimer; interval: 150; repeat: true; onTriggered: { if(bridge && bridge.canClose()){ stop(); window.close(); } } }
    Shortcut { sequence: "Ctrl+N"; onActivated: bridge && bridge.newTask() }
    Shortcut { sequence: "Ctrl+,"; onActivated: settings.open() }
    Shortcut { sequence: "Ctrl+K"; onActivated: taskSearch.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+Shift+P"; onActivated: commandPalette.open() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: bridge && bridge.stop() }
    Shortcut { sequence: "Escape"; onActivated: { if(bridge && bridge.busy) bridge && bridge.stop(); } }
    Connections {
        target: bridge
        function onToast(text) { toastLabel.text = text; toastBox.visible = true; toastTimer.restart(); }
        function onFocusComposer() { composer.forceActiveFocus(); }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Quiet navigation rail with persistent local conversations.
        Rectangle {
            Layout.preferredWidth: 224
            Layout.fillHeight: true
            color: "#111413"
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#282e2a" }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 55
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Rectangle {
                            width: 31; height: 31; radius: 10; color: accent
                            Text { anchors.centerIn: parent; text: "w"; font.family: "Lato"; font.pixelSize: 27; font.weight: Font.Black; color: "#172c20"; anchors.verticalCenterOffset: -2 }
                        }
                        Text { text: "wynxo"; color: bright; font.pixelSize: 23; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter; font.letterSpacing: -.6 }
                        Text { text: "DESKTOP"; color: "#77897c"; font.pixelSize: 8; font.letterSpacing: 1.7; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 3 }
                    }
                }
                ActionButton { Layout.fillWidth: true; text: "New task"; iconName: "plus"; primary: true; enabled: bridge && !bridge.busy; onClicked: bridge && bridge.newTask(); ToolTip.visible: hovered; ToolTip.text: "New task · Ctrl+N" }
                TextField {
                    id: taskSearch
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    placeholderText: "Search tasks"; placeholderTextColor: "#768079"; color: bright
                    leftPadding: 31; font.pixelSize: 12
                    background: Rectangle { color: taskSearch.activeFocus ? "#1c221e" : "transparent"; radius: 7; border.color: taskSearch.activeFocus ? "#435c4b" : "transparent" }
                    Icon { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; name: "search"; ink: "#768079" }
                    onTextChanged: window.searchText = text.toLowerCase()
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#252b27" }
                Text { text: "YOUR TASKS"; font.pixelSize: 10; font.letterSpacing: 1.6; color: "#737e76"; Layout.topMargin: 14; Layout.leftMargin: 7 }
                ListView {
                    id: taskList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: bridge && bridge.tasks
                    delegate: Rectangle {
                        id: taskDelegate
                        required property var modelData
                        width: taskList.width
                        property bool matches: !window.searchText || modelData.title.toLowerCase().indexOf(window.searchText) !== -1
                        height: matches ? 43 : 0; visible: matches
                        radius: 8
                        color: modelData.id === (bridge && bridge.taskId) ? "#252e27" : taskMouse.containsMouse ? "#1a201c" : "transparent"
                        Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "chat"; width: 16; height: 16; ink: modelData.id === (bridge && bridge.taskId) ? accent : "#727f76" }
                        Text { x: 35; anchors.verticalCenter: parent.verticalCenter; width: parent.width-62; text: modelData.title; elide: Text.ElideRight; color: modelData.id === (bridge && bridge.taskId) ? "#dce8de" : "#9ea9a1"; font.pixelSize: 12 }
                        MouseArea { id: taskMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bridge && bridge.openTask(taskDelegate.modelData.id) }
                        ActionButton { visible: taskMouse.containsMouse || hovered; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 30; iconName: "trash"; quiet: true; onClicked: { deleteDialog.taskToDelete = taskDelegate.modelData.id; deleteDialog.open(); } }
                    }
                    Text { visible: taskList.count === 0; width: parent.width-14; x: 7; y: 8; text: "A fresh start.\nYour tasks will live here."; color: "#69756d"; font.pixelSize: 12; lineHeight: 1.5 }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 92
                    radius: 11; color: "#19221b"; border.color: "#2d3c30"
                    Column { anchors.fill: parent; anchors.margins: 13; spacing: 8
                        Row { spacing: 7; Icon { name: "shield"; ink: "#a0c4aa"; width: 15; height: 15 } Text { text: "Local by design"; color: "#c0d5c5"; font.pixelSize: 12; font.weight: Font.DemiBold } }
                        Text { width: parent.width; text: "Your models. Your machine.\nYour conversations stay here."; color: "#8ca591"; font.pixelSize: 11; lineHeight: 1.35 }
                    }
                }
                ActionButton { Layout.fillWidth: true; iconName: "sliders"; text: "Settings"; quiet: true; onClicked: settings.open() }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#252b27" }
                RowLayout { Layout.fillWidth: true; Layout.topMargin: 5; spacing: 10
                    Rectangle { width: 30; height: 30; radius: 15; color: "#29342c"; Text { anchors.centerIn: parent; text: "W"; font.pixelSize: 12; font.weight: Font.Bold; color: "#bbd4c2" } }
                    Column { spacing: 4; Text { text: "Personal workspace"; color: "#c3cdc6"; font.pixelSize: 11 } Text { text: "On this device"; color: "#737f77"; font.pixelSize: 10 } }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 74
                color: "#141816"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#282e2a" }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 29; anchors.rightMargin: 24; spacing: 12
                    Icon { name: "folder"; width: 17; height: 17; ink: "#839188" }
                    Text { text: "Workspace"; color: "#8d9991"; font.pixelSize: 12; visible: window.width > 1050 }
                    Text { text: "/"; color: "#4d5b51"; visible: window.width > 1050 }
                    Text { text: bridge && bridge.taskTitle; color: "#dce4df"; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onDoubleClicked: renameDialog.open(); ToolTip.visible: containsMouse; ToolTip.text: "Rename task" } }
                        Rectangle {
                        Layout.preferredWidth: ollamaLabel.implicitWidth+31; height: 29; radius: 15; color: bridge && bridge.online ? "#1c2b21" : "#30281f"; border.color: bridge && bridge.online ? "#304836" : "#584732"
                        Row { anchors.centerIn: parent; spacing: 6
                            Rectangle { width: 5; height: 5; radius: 3; color: bridge && bridge.online ? accent : bridge && (bridge.connecting || bridge.pulling) ? "#d9b679" : "#b78963"; anchors.verticalCenter: parent.verticalCenter }
                            Text { id: ollamaLabel; text: bridge && bridge.connecting ? "Connecting…" : bridge && bridge.pulling ? "Downloading…" : bridge && bridge.online ? "Ollama connected" : "Ollama offline"; font.pixelSize: 10; color: bridge && bridge.online ? "#b7d1be" : "#d3b787" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bridge && bridge.refreshModels() }
                    }
                    ActionButton { iconName: "download"; quiet: true; width: 33; height: 33; visible: bridge && bridge.hasMessages; onClicked: bridge && bridge.exportTask(); ToolTip.visible: hovered; ToolTip.text: "Export conversation" }
                    ActionButton { iconName: "bolt"; quiet: true; width: 33; height: 33; onClicked: commandPalette.open(); ToolTip.visible: hovered; ToolTip.text: "Command palette · Ctrl+Shift+P" }
                    ActionButton { iconName: "panel"; quiet: true; width: 33; height: 33; onClicked: window.inspectorOpen = !window.inspectorOpen; ToolTip.visible: hovered; ToolTip.text: "Toggle workspace panel" }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 30; anchors.topMargin: 12; anchors.bottomMargin: 18; spacing: 14
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            ColumnLayout {
                                visible: bridge && !bridge.hasMessages
                                anchors.centerIn: parent; width: Math.min(parent.width, 720); spacing: 0
                                Orb { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 104; Layout.preferredHeight: 104; animate: !(bridge && bridge.reducedMotion); Layout.bottomMargin: 20 }
                                Text { Layout.alignment: Qt.AlignHCenter; text: "YOUR LOCAL COPILOT"; color: "#98b6a0"; font.pixelSize: 10; font.letterSpacing: 3; Layout.bottomMargin: 19 }
                                Text { Layout.fillWidth: true; text: "Big ideas. Less busywork."; color: "#e5ece7"; font.pixelSize: parent.width < 580 ? 32 : 39; font.weight: Font.Medium; font.letterSpacing: -1.2; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; Layout.bottomMargin: 14 }
                                Text { Layout.fillWidth: true; text: "Think it through. Make it happen.\nAn extra pair of hands, right on your desktop."; color: "#8e9c92"; font.pixelSize: 14; lineHeight: 1.5; horizontalAlignment: Text.AlignHCenter; Layout.bottomMargin: 37 }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Repeater {
                                        model: [
                                            {icon: "paint", title: "Make something", description: "Turn an idea into a first draft", prompt: "Open a drawing app and draw a simple mountain landscape. Inspect the screen first and work step by step."},
                                            {icon: "cursor", title: "Take the wheel", description: "Get a hand with desktop tasks", prompt: "Look at my desktop and tell me what apps are open. Ask what I want to work on next."},
                                            {icon: "code", title: "Think it through", description: "Code, plan, and solve together", prompt: "Help me plan a small Python project. Ask what I want to build, then help me break it into practical steps."}
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true; Layout.preferredHeight: 123
                                            radius: 12; color: cardMouse.containsMouse ? "#222e25" : "#1b221d"; border.color: cardMouse.containsMouse ? "#4d6c56" : "#303d32"
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                            Column { anchors.fill: parent; anchors.margins: 15; spacing: 11
                                                Icon { name: modelData.icon; ink: "#a6c6af"; width: 19; height: 19 }
                                                Text { width: parent.width; text: modelData.title; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#d6e1d8"; elide: Text.ElideRight }
                                                Text { width: parent.width; text: modelData.description; font.pixelSize: 10; color: "#85998b"; wrapMode: Text.WordWrap; lineHeight: 1.3 }
                                            }
                                            MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { composer.text = modelData.prompt; composer.forceActiveFocus(); } }
                                        }
                                    }
                                }
                            }

                            ListView {
                                id: chatList
                                visible: bridge && bridge.hasMessages
                                anchors.fill: parent; anchors.topMargin: 14
                                clip: true; spacing: 27
                                model: bridge && bridge.messageModel
                                property bool followTail: true
                                onMovementStarted: followTail = false
                                onMovementEnded: followTail = atYEnd
                                onContentHeightChanged: { if(followTail) positionViewAtEnd(); }
                                onCountChanged: { followTail = true; positionViewAtEnd(); }
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                delegate: ColumnLayout {
                                    id: messageDelegate
                                    required property string speaker
                                    required property string body
                                    required property string thought
                                    width: chatList.width-12
                                    spacing: 10
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 9
                                        Rectangle { width: 25; height: 25; radius: speaker === "user" ? 13 : 8; color: speaker === "user" ? "#343e36" : accent; Text { anchors.centerIn: parent; text: speaker === "user" ? "Y" : "w"; font.pixelSize: speaker === "user" ? 11 : 22; font.weight: Font.Bold; color: speaker === "user" ? "#c7d3ca" : "#1a3222"; anchors.verticalCenterOffset: speaker === "user" ? 0 : -2 } }
                                        Text { text: speaker === "user" ? "You" : "Wynxo"; color: "#d9e3dc"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        Text { visible: speaker === "assistant"; text: "LOCAL"; color: "#6d8f77"; font.pixelSize: 8; font.letterSpacing: 1 }
                                        Item { Layout.fillWidth: true }
                                        ActionButton { iconName: "copy"; quiet: true; width: 27; height: 25; onClicked: bridge && bridge.copyText(messageDelegate.body); ToolTip.visible: hovered; ToolTip.text: "Copy message" }
                                    }
                                    ColumnLayout {
                                        visible: thought.length > 0; Layout.fillWidth: true; Layout.leftMargin: 34
                                        property bool expanded: false
                                        ActionButton { text: parent.expanded ? "Hide reasoning" : "Show reasoning"; iconName: "bolt"; quiet: true; height: 28; foreground: "#8daa96"; onClicked: parent.expanded = !parent.expanded }
                                        TextArea { visible: parent.expanded; Layout.fillWidth: true; text: thought; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: "#8f9d94"; font.pixelSize: 12; background: Rectangle { radius: 8; color: "#191f1b" } padding: 12 }
                                    }
                                    TextArea {
                                        Layout.fillWidth: true; Layout.leftMargin: 34
                                        visible: body.length > 0
                                        text: body
                                        textFormat: speaker === "assistant" ? TextEdit.MarkdownText : TextEdit.PlainText
                                        readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                                        color: "#c9d4cd"; selectedTextColor: "#17251b"; selectionColor: accent
                                        font.pixelSize: 14; font.family: "Lato"; padding: 0
                                        background: Item {}
                                        onLinkActivated: function(link) { if(/^https?:\/\//.test(link)) { linkDialog.link = link; linkDialog.open(); } }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: bridge && bridge.error.length > 0
                            Layout.fillWidth: true; Layout.preferredHeight: Math.min(116, errorText.implicitHeight+26)
                            color: "#2c271e"; radius: 9; border.color: "#514531"
                            Text { id: errorText; anchors.fill: parent; anchors.margins: 13; anchors.rightMargin: 42; text: bridge && bridge.error; color: "#d5bd92"; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 5; elide: Text.ElideRight }
                            ActionButton { anchors.right: parent.right; anchors.top: parent.top; width: 32; height: 32; iconName: "close"; quiet: true; onClicked: bridge && bridge.clearError() }
                        }

                        RowLayout {
                            visible: bridge && bridge.busy
                            Layout.fillWidth: true; spacing: 8
                            Rectangle { width: 6; height: 6; radius: 3; color: accent; SequentialAnimation on opacity { running: bridge && bridge.busy && !bridge.reducedMotion; loops: Animation.Infinite; NumberAnimation { to: .3; duration: 650 } NumberAnimation { to: 1; duration: 650 } } }
                            Text { text: bridge && bridge.status; color: "#a7beae"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: "Esc to stop"; color: "#74897c"; font.pixelSize: 10 }
                        }

                        Rectangle {
                            visible: bridge && bridge.thinkingActive
                            Layout.fillWidth: true; Layout.preferredHeight: 76
                            radius: 10; color: bridge && bridge.solidBackground ? "#151a17" : "#1a211c"; border.color: "#33463a"
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 11; spacing: 5
                                RowLayout { Layout.fillWidth: true
                                    Text { text: "LIVE THINKING"; color: accent; font.pixelSize: 9; font.letterSpacing: 1.5; font.weight: Font.DemiBold }
                                    Item { Layout.fillWidth: true }
                                    Text { text: bridge && bridge.thinking ? "model reasoning" : "response planning"; color: "#71877a"; font.pixelSize: 9 }
                                }
                                Text { Layout.fillWidth: true; text: bridge && bridge.thinkingText; color: "#9caf9f"; font.pixelSize: 11; maximumLineCount: 3; elide: Text.ElideRight; wrapMode: Text.WordWrap; lineHeight: 1.2 }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(250, Math.max(148, composer.contentHeight+78 + (bridge && !bridge.hasMessages ? 34 : 0)))
                            radius: 15; color: "#202923"
                            border.width: 1; border.color: composer.activeFocus ? "#6d8e74" : "#405346"
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 14; spacing: 9
                                Flow {
                                    Layout.fillWidth: true; Layout.preferredHeight: visible ? 28 : 0
                                    visible: bridge && !bridge.busy
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            {label: "Open Paint", prompt: "Open Paint and wait for it to be ready. Inspect the desktop before acting."},
                                            {label: "Draw something", prompt: "Open a drawing app and draw a simple mountain landscape. Inspect the screen first and work step by step."},
                                            {label: "Inspect desktop", prompt: "Inspect my desktop and summarize what is open. Ask before changing anything."},
                                            {label: "Plan a project", prompt: "Help me plan a small project. Ask one useful question, then turn the answer into clear next steps."}
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: suggestionLabel.implicitWidth + 24; height: 27; radius: 14
                                            color: suggestionMouse.containsMouse ? "#334638" : "#29352d"; border.color: suggestionMouse.containsMouse ? accent : "#3b4c40"
                                            Text { id: suggestionLabel; anchors.centerIn: parent; text: modelData.label; color: "#b9d0be"; font.pixelSize: 10 }
                                            MouseArea { id: suggestionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { composer.text = modelData.prompt; composer.forceActiveFocus(); } }
                                        }
                                    }
                                }
                                ScrollView {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    TextArea {
                                        id: composer
                                        objectName: "composer"
                                        placeholderText: bridge && bridge.desktopEnabled ? "What should we do on your desktop?" : "Ask anything, or give your copilot a task…"
                                        placeholderTextColor: "#8a9e90"; color: "#e1ebe4"
                                        selectionColor: accent; selectedTextColor: "#15241a"
                                        wrapMode: TextEdit.Wrap; font.pixelSize: 14; padding: 5
                                        background: Item {}
                                        enabled: !window.closing
                                        Keys.onReturnPressed: function(event) {
                                            if (!(event.modifiers & Qt.ShiftModifier)) { window.sendPrompt(); event.accepted = true; }
                                            else event.accepted = false;
                                        }
                                        Keys.onEnterPressed: function(event) {
                                            if (!(event.modifiers & Qt.ShiftModifier)) { window.sendPrompt(); event.accepted = true; }
                                            else event.accepted = false;
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    ActionButton { iconName: bridge && bridge.desktopEnabled ? "cursor" : "chat"; text: bridge && bridge.desktopEnabled ? "Desktop" : "Chat"; height: 29; quiet: true; foreground: "#bad0c0"; onClicked: window.inspectorOpen = true; ToolTip.visible: hovered; ToolTip.text: "Enable desktop control in the workspace panel" }
                                    Rectangle { width: 1; height: 14; color: "#425448" }
                                    ComboBox {
                                        id: modelPicker
                                        objectName: "modelPicker"
                                        Layout.preferredWidth: Math.min(230, composer.width * .44); Layout.preferredHeight: 30
                                        model: bridge && bridge.models.length ? bridge && bridge.models : [bridge && bridge.model]
                                        currentIndex: Math.max(0, model.indexOf(bridge && bridge.model))
                                        enabled: bridge && !bridge.busy && !bridge.pulling
                                        font.pixelSize: 11
                                        contentItem: Text { text: modelPicker.displayText; color: "#a9bfb0"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle; leftPadding: 7; rightPadding: 21; font: modelPicker.font }
                                        indicator: Icon { name: "down"; width: 15; height: 15; x: modelPicker.width-18; y: 8; ink: "#8da996" }
                                        background: Rectangle { color: modelPicker.hovered ? "#2b3930" : "transparent"; radius: 6 }
                                        popup: Popup { y: modelPicker.height+3; width: Math.max(280, modelPicker.width); padding: 5; background: Rectangle { radius: 9; color: "#26312a"; border.color: "#465a4b" } contentItem: ListView { implicitHeight: Math.min(240, contentHeight); model: modelPicker.popup.visible ? modelPicker.delegateModel : null; clip: true; currentIndex: modelPicker.highlightedIndex } }
                                        delegate: ItemDelegate { required property var modelData; width: modelPicker.popup.width-10; height: 38; text: modelData; highlighted: modelPicker.highlightedIndex === index; contentItem: Text { text: modelData; color: "#d6e2da"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle } background: Rectangle { radius: 5; color: parent.highlighted ? "#3b5041" : "transparent" } }
                                        onActivated: bridge && bridge.setModel(currentText)
                                    }
                                    Rectangle {
                                        visible: bridge && bridge.online && composer.width > 650
                                        Layout.preferredWidth: Math.min(178, capabilityLabel.implicitWidth + 18)
                                        Layout.preferredHeight: 27
                                        radius: 14
                                        color: bridge && bridge.modelCapabilitiesLoading ? "#2a302c" : bridge && bridge.modelSupportsTools ? "#22382a" : "#302e25"
                                        border.color: bridge && bridge.modelCapabilitiesLoading ? "#424b45" : bridge && bridge.modelSupportsTools ? "#3d6147" : "#57513c"
                                        Text { id: capabilityLabel; anchors.centerIn: parent; text: bridge && bridge.modelCapabilitySummary; color: bridge && bridge.modelSupportsTools ? "#a9cdb4" : "#b5ad8c"; font.pixelSize: 9; elide: Text.ElideRight; width: Math.min(160, implicitWidth); horizontalAlignment: Text.AlignHCenter }
                                        MouseArea { id: capabilityMouse; anchors.fill: parent; hoverEnabled: true }
                                        ToolTip.visible: capabilityMouse.containsMouse
                                        ToolTip.text: bridge && bridge.modelCapabilityHint
                                    }
                                    Item { Layout.fillWidth: true }
                                    ActionButton { objectName: "sendButton"; iconName: bridge && bridge.busy ? "stop" : "arrow"; primary: true; width: 36; height: 34; enabled: (bridge && bridge.busy) || (composer.text.trim().length > 0 && bridge && bridge.online && !bridge.connecting); onClicked: bridge && bridge.busy ? bridge.stop() : window.sendPrompt(); ToolTip.visible: hovered; ToolTip.text: bridge && bridge.busy ? "Stop task · Esc" : "Send · Enter" }
                                }
                            }
                        }
                        RowLayout { Layout.fillWidth: true
                            Text { text: "Runs on your machine. Powered by Ollama."; color: "#66786b"; font.pixelSize: 10; Layout.fillWidth: true }
                            Text { text: "Shift + Enter for a new line"; color: "#66786b"; font.pixelSize: 10; visible: parent.width > 500 }
                        }
                    }
                }

                Rectangle {
                    visible: window.inspectorOpen && window.width >= 1120
                    Layout.preferredWidth: 280; Layout.fillHeight: true
                    color: "#151b17"
                    Rectangle { width: 1; height: parent.height; color: "#2a352c" }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 21; anchors.topMargin: 25; spacing: 18
                        RowLayout { Layout.fillWidth: true; Text { text: "Your workspace"; color: "#d7e1da"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true } Icon { name: "sun"; ink: "#718c79"; width: 17; height: 17 } }
                        Text { text: "A little context. A lot of capability."; color: "#7e9685"; font.pixelSize: 10 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 150
                            radius: 12; color: "#202d23"; border.color: "#344a39"
                            // Abstract desktop map, not a simulated screenshot.
                            Rectangle { anchors.centerIn: parent; width: 155; height: 88; radius: 6; color: "#1a241d"; border.color: "#52745a"; rotation: -5
                                Rectangle { x: 0; y: 0; width: parent.width; height: 14; radius: 6; color: "#344b3b" }
                                Row { x: 7; y: 5; spacing: 3; Repeater { model: 3; Rectangle { width: 3; height: 3; radius: 2; color: "#91b09a" } } }
                                Rectangle { x: 9; y: 24; width: 33; height: 52; radius: 3; color: "#2b3c30" }
                                Rectangle { x: 50; y: 24; width: 94; height: 6; radius: 3; color: "#405c47" }
                                Rectangle { x: 50; y: 36; width: 66; height: 4; radius: 2; color: "#314838" }
                                Rectangle { x: 50; y: 47; width: 93; height: 29; radius: 3; color: "#24372a"; border.color: "#37513e" }
                            }
                            Rectangle { x: 146; y: 82; width: 39; height: 39; radius: 13; rotation: 8; color: accent; Icon { anchors.centerIn: parent; name: "cursor"; ink: "#274332"; width: 23; height: 23 } }
                            Rectangle { x: 41; y: 28; width: 6; height: 6; radius: 3; color: "#a9cdb4" }
                        }
                        RowLayout { Layout.fillWidth: true; Text { text: "Desktop control"; color: "#cddad1"; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.fillWidth: true } Rectangle { width: 6; height: 6; radius: 3; color: bridge && bridge.desktopEnabled ? accent : "#6b7e70" } Text { text: bridge && bridge.desktopEnabled ? "Enabled" : "Off"; color: bridge && bridge.desktopEnabled ? accent : "#809787"; font.pixelSize: 10 } }
                        Text { Layout.fillWidth: true; text: bridge && bridge.desktopEnabled ? "Wynxo can see your screen and use your mouse and keyboard for your tasks." : "Let Wynxo see your screen, open apps, and use your mouse and keyboard."; color: "#819b89"; font.pixelSize: 11; wrapMode: Text.WordWrap; lineHeight: 1.4 }
                        ActionButton { Layout.fillWidth: true; iconName: bridge && bridge.desktopEnabled ? "shield" : "cursor"; text: bridge && bridge.connecting ? "Waiting for permission…" : bridge && bridge.desktopEnabled ? "Disable desktop control" : "Enable desktop control"; enabled: bridge && !bridge.connecting; onClicked: bridge && bridge.toggleDesktop(); height: 37; foreground: "#c4d9cb" }
                        Text { Layout.fillWidth: true; text: bridge && bridge.desktopDetail; color: "#687f70"; font.pixelSize: 10; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight; lineHeight: 1.3 }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: capabilityDetail.implicitHeight + 44
                            radius: 9
                            color: "#19231c"
                            border.color: bridge && bridge.modelSupportsTools ? "#34513d" : "#403f32"
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 11; spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "SELECTED MODEL"; color: "#78917f"; font.pixelSize: 8; font.letterSpacing: 1.3; Layout.fillWidth: true }
                                    Text { text: bridge && bridge.modelCapabilitySummary; color: bridge && bridge.modelSupportsTools ? "#9fc4a9" : "#afa883"; font.pixelSize: 9; elide: Text.ElideRight; Layout.maximumWidth: 145 }
                                }
                                Text { id: capabilityDetail; Layout.fillWidth: true; text: bridge && bridge.modelCapabilityHint; color: "#7f9787"; font.pixelSize: 10; wrapMode: Text.WordWrap; lineHeight: 1.3; maximumLineCount: 4; elide: Text.ElideRight }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#2b382e" }
                        RowLayout { Text { text: "ACTIVITY"; color: "#8da693"; font.pixelSize: 9; font.letterSpacing: 1.8 } Item { Layout.fillWidth: true } Text { text: bridge && bridge.activity.length.toString().padStart(2, "0"); color: "#6f8a78"; font.pixelSize: 10 } }
                        ListView {
                            id: activityList
                            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 50
                            model: bridge && bridge.activity; clip: true; spacing: 13
                            onCountChanged: positionViewAtEnd()
                            delegate: RowLayout {
                                required property var modelData
                                width: activityList.width; spacing: 10
                                Icon { name: modelData.state === "done" ? "check" : modelData.state === "failed" ? "close" : "bolt"; ink: modelData.state === "failed" ? "#caa281" : "#9abfa5"; width: 14; height: 14; Layout.alignment: Qt.AlignTop }
                                ColumnLayout { Layout.fillWidth: true; spacing: 5; Text { text: modelData.name; color: "#b9d0c1"; font.pixelSize: 11; font.capitalization: Font.Capitalize } Text { Layout.fillWidth: true; text: modelData.detail; color: "#738d7c"; font.pixelSize: 10; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight } }
                            }
                            Column { visible: activityList.count === 0; width: parent.width; spacing: 8; Text { text: "Nothing in motion. Yet."; color: "#92aa9a"; font.pixelSize: 11 } Text { text: "Desktop actions will appear here\nas your copilot works."; color: "#6e8776"; font.pixelSize: 10; lineHeight: 1.4 } }
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#2b382e" }
                        RowLayout { Layout.fillWidth: true; Text { text: "CONNECTION"; color: "#728b7a"; font.pixelSize: 9; font.letterSpacing: 1.4 } Item { Layout.fillWidth: true } Text { text: bridge && bridge.tokenRate; color: "#93b69f"; font.pixelSize: 10 } }
                        Text { text: bridge && bridge.endpoint; Layout.fillWidth: true; color: "#8da996"; font.family: "monospace"; font.pixelSize: 10; elide: Text.ElideRight }
                        Text { text: "Native Linux  /  " + (bridge && bridge.desktopBackend); color: "#5d7968"; font.pixelSize: 9; Layout.bottomMargin: 4 }
                    }
                }
            }
        }
    }

    function sendPrompt() {
        if((bridge && bridge.busy) || !(bridge && bridge.online) || (bridge && bridge.connecting) || !composer.text.trim()) return;
        bridge && bridge.send(composer.text);
        composer.text = "";
        chatList.followTail = true;
    }

    Dialog {
        id: settings
        anchors.centerIn: parent
        width: 560; height: Math.min(window.height-60, 675)
        modal: true; title: "Settings"
        padding: 26
        background: Rectangle { radius: 16; color: "#1c2520"; border.color: "#455b4b" }
        header: Item { height: 68; Text { x: 26; y: 27; text: "Make yourself at home"; color: bright; font.pixelSize: 21; font.weight: Font.DemiBold } ActionButton { anchors.right: parent.right; anchors.rightMargin: 15; y: 18; iconName: "close"; quiet: true; width: 35; height: 35; onClicked: settings.close() } }
        onOpened: {
            endpointField.text = bridge && bridge.endpoint;
            thinkCheck.checked = bridge && bridge.thinking;
            motionCheck.checked = bridge && bridge.reducedMotion;
            themePicker.currentIndex = Math.max(0, window.themeNames.indexOf(bridge && bridge.theme));
            accentField.text = bridge && bridge.accentColor;
            solidCheck.checked = bridge && bridge.solidBackground;
        }
        contentItem: ScrollView {
            clip: true
            ColumnLayout {
                width: settings.availableWidth; spacing: 16
                Text { text: "OLLAMA"; color: "#8fae99"; font.pixelSize: 10; font.letterSpacing: 2 }
                Text { text: "Local server address"; color: "#cbdacf"; font.pixelSize: 12 }
                TextField { id: endpointField; Layout.fillWidth: true; height: 43; color: bright; font.family: "monospace"; font.pixelSize: 12; padding: 12; background: Rectangle { radius: 8; color: "#141d17"; border.color: "#415647" } }
                Text { Layout.fillWidth: true; text: "Connects directly to Ollama on this computer. No account or API key needed."; color: "#849e8d"; font.pixelSize: 11; wrapMode: Text.WordWrap }
                RowLayout { Layout.fillWidth: true; ActionButton { text: "Reconnect"; iconName: "bolt"; onClicked: bridge && bridge.refreshModels() } Item { Layout.fillWidth: true } Text { text: bridge && bridge.online ? bridge && bridge.models.length + " models installed" : "Not connected"; color: "#92b09c"; font.pixelSize: 11 } }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#34473a" }
                Text { text: "Download a model"; color: "#cbdacf"; font.pixelSize: 12 }
                RowLayout { Layout.fillWidth: true; spacing: 8
                    TextField { id: pullField; text: "qwen3.8:27b"; Layout.fillWidth: true; height: 40; color: bright; font.pixelSize: 12; padding: 10; background: Rectangle { radius: 8; color: "#141d17"; border.color: "#415647" } enabled: bridge && !bridge.pulling }
                    ActionButton { text: bridge && bridge.pulling ? "Stop" : "Download"; iconName: bridge && bridge.pulling ? "stop" : "download"; enabled: bridge && bridge.online && !bridge.busy; onClicked: bridge && bridge.pulling ? bridge.cancelPull() : bridge.pullModel(pullField.text) }
                }
                Text { Layout.fillWidth: true; text: bridge && bridge.pullProgress || "Downloads from Ollama’s registry. Large models need substantial memory and disk space."; color: "#849e8d"; font.pixelSize: 11; wrapMode: Text.WordWrap }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#34473a" }
                Text { text: "APPEARANCE"; color: "#8fae99"; font.pixelSize: 10; font.letterSpacing: 2 }
                Text { text: "Make Wynxo yours"; color: "#cbdacf"; font.pixelSize: 12 }
                ComboBox {
                    id: themePicker
                    Layout.fillWidth: true; Layout.preferredHeight: 41
                    model: window.themeNames
                    font.pixelSize: 12
                    contentItem: Text { text: themePicker.displayText; color: bright; verticalAlignment: Text.AlignVCenter; leftPadding: 11; font: themePicker.font }
                    indicator: Icon { name: "down"; width: 15; height: 15; x: themePicker.width-22; y: 12; ink: "#8da996" }
                    background: Rectangle { radius: 8; color: "#141d17"; border.color: themePicker.activeFocus ? accent : "#415647" }
                    onActivated: accentField.text = window.themeColors[currentText]
                    delegate: ItemDelegate { required property var modelData; width: themePicker.popup.width-10; height: 38; contentItem: Row { spacing: 9; Rectangle { width: 13; height: 13; radius: 7; color: window.themeColors[modelData]; anchors.verticalCenter: parent.verticalCenter } Text { text: modelData; color: "#d6e2da"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter } } background: Rectangle { radius: 5; color: parent.highlighted ? "#3b5041" : "transparent" } }
                    popup: Popup { y: themePicker.height+3; width: Math.max(250, themePicker.width); padding: 5; background: Rectangle { radius: 9; color: "#26312a"; border.color: "#465a4b" } contentItem: ListView { implicitHeight: Math.min(220, contentHeight); model: themePicker.popup.visible ? themePicker.delegateModel : null; clip: true; currentIndex: themePicker.highlightedIndex } }
                }
                RowLayout { Layout.fillWidth: true; spacing: 9
                    Text { text: "Accent"; color: "#a7bcae"; font.pixelSize: 11 }
                    TextField { id: accentField; Layout.fillWidth: true; height: 38; placeholderText: "#b9dfc6"; color: bright; font.family: "monospace"; font.pixelSize: 11; padding: 10; background: Rectangle { radius: 8; color: "#141d17"; border.color: "#415647" } }
                    Rectangle { width: 30; height: 30; radius: 15; color: accentField.text; border.color: "#718b79"; border.width: 1 }
                }
                CheckBox { id: solidCheck; text: "Use a solid dark canvas"; palette.windowText: "#c3d4c9"; palette.buttonText: "#c3d4c9"; font.pixelSize: 12 }
                Text { Layout.fillWidth: true; text: "Themes set the accent system. Enter any opaque hex color for a custom primary color."; color: "#849e8d"; font.pixelSize: 11; wrapMode: Text.WordWrap }
                Rectangle { Layout.fillWidth: true; height: 1; color: "#34473a" }
                CheckBox { id: thinkCheck; text: "Let the model think before responding"; palette.windowText: "#c3d4c9"; palette.buttonText: "#c3d4c9"; font.pixelSize: 12 }
                CheckBox { id: motionCheck; text: "Reduce animations"; palette.windowText: "#c3d4c9"; palette.buttonText: "#c3d4c9"; font.pixelSize: 12 }
                // Desktop access remains available on smaller windows.
                ActionButton { Layout.fillWidth: true; text: bridge && bridge.desktopEnabled ? "Disable desktop control" : "Enable desktop control"; iconName: "desktop"; enabled: bridge && !bridge.connecting; onClicked: bridge && bridge.toggleDesktop() }
                Text { Layout.fillWidth: true; text: "Desktop mode can click, type, and change things in your apps. Enable it for a task you want done. Esc stops the agent while this window is focused."; color: "#849e8d"; font.pixelSize: 11; wrapMode: Text.WordWrap; lineHeight: 1.4 }
                ActionButton { Layout.fillWidth: true; text: "Save settings"; primary: true; onClicked: { if (bridge && bridge.saveSettings(endpointField.text, thinkCheck.checked, motionCheck.checked, themePicker.currentText, accentField.text, solidCheck.checked)) settings.close(); } }
                Text { text: "WYNXO  0.2.0   ·   LOCAL DESKTOP COPILOT"; font.pixelSize: 8; font.letterSpacing: 1.5; color: "#718e7c"; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    Dialog {
        id: commandPalette
        anchors.centerIn: parent
        width: Math.min(540, window.width - 40); height: 440
        modal: true; title: "Command palette"; padding: 18
        property int matchingCount: 7
        function updateMatchCount() {
            var query = commandSearch.text.toLowerCase();
            var count = 0;
            for (var i = 0; i < commandList.model.length; i++) {
                var item = commandList.model[i];
                if (!query || (item.label + " " + item.detail).toLowerCase().indexOf(query) !== -1) count++;
            }
            matchingCount = count;
        }
        background: Rectangle { radius: 15; color: "#18201b"; border.color: "#455b4b" }
        header: Item { height: 43
            Text { x: 2; y: 10; text: "Command palette"; color: bright; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { anchors.right: parent.right; y: 13; text: "Esc to close"; color: "#718579"; font.pixelSize: 10 }
        }
        onOpened: { commandSearch.text = ""; commandPalette.updateMatchCount(); commandSearch.forceActiveFocus(); }
        contentItem: ColumnLayout {
            spacing: 10
            TextField {
                id: commandSearch
                Layout.fillWidth: true; Layout.preferredHeight: 40
                placeholderText: "Search actions…"; placeholderTextColor: "#7f9586"; color: bright; font.pixelSize: 12; padding: 11
                leftPadding: 34
                background: Rectangle { radius: 8; color: "#111713"; border.color: commandSearch.activeFocus ? accent : "#3a4d40" }
                Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; width: 15; height: 15; ink: "#7f9586" }
                Keys.onEscapePressed: commandPalette.close()
                onTextChanged: commandPalette.updateMatchCount()
            }
            ListView {
                id: commandList
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                model: [
                    {label: "New task", detail: "Start a fresh conversation", shortcut: "Ctrl+N", icon: "plus", action: "new"},
                    {label: "Focus composer", detail: "Jump to the prompt box", shortcut: "", icon: "chat", action: "focus"},
                    {label: "Toggle workspace panel", detail: "Show or hide desktop activity", shortcut: "", icon: "panel", action: "panel"},
                    {label: "Enable desktop control", detail: "Grant or revoke Wayland/X11 input access", shortcut: "", icon: "cursor", action: "desktop"},
                    {label: "Reconnect Ollama", detail: "Refresh local models", shortcut: "", icon: "bolt", action: "refresh"},
                    {label: "Open settings", detail: "Models, thinking, themes, and appearance", shortcut: "Ctrl+,", icon: "sliders", action: "settings"},
                    {label: "Stop current task", detail: "Cancel generation and desktop actions", shortcut: "Esc", icon: "stop", action: "stop"}
                ]
                delegate: ItemDelegate {
                    id: commandDelegate
                    required property var modelData
                    property bool matches: !commandSearch.text || (modelData.label + " " + modelData.detail).toLowerCase().indexOf(commandSearch.text.toLowerCase()) !== -1
                    width: commandList.width; height: matches ? 49 : 0; visible: matches; hoverEnabled: true
                    contentItem: RowLayout { spacing: 11
                        Icon { name: commandDelegate.modelData.icon; ink: commandDelegate.hovered ? accent : "#9ab6a1"; width: 17; height: 17 }
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: commandDelegate.modelData.label; color: "#d6e2da"; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { text: commandDelegate.modelData.detail; color: "#7f9586"; font.pixelSize: 10; elide: Text.ElideRight }
                        }
                        Text { text: commandDelegate.modelData.shortcut; color: "#718579"; font.pixelSize: 10 }
                    }
                    background: Rectangle { radius: 8; color: commandDelegate.hovered ? "#2b3c31" : "transparent" }
                    onClicked: { window.runCommand(commandDelegate.modelData.action); commandPalette.close(); }
                }
                Text { visible: commandPalette.matchingCount === 0; text: "No matching command"; color: "#7f9586"; anchors.centerIn: parent; font.pixelSize: 12 }
            }
        }
    }

    Dialog {
        id: renameDialog
        anchors.centerIn: parent
        width: 430; modal: true; title: "Rename task"; padding: 20
        background: Rectangle { radius: 14; color: "#1c2520"; border.color: "#455b4b" }
        onOpened: { renameField.text = bridge && bridge.taskTitle; renameField.selectAll(); renameField.forceActiveFocus(); }
        contentItem: ColumnLayout {
            spacing: 12
            Text { text: "Give this task a name you will recognize later."; color: "#9caf9f"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            TextField { id: renameField; Layout.fillWidth: true; height: 42; color: bright; font.pixelSize: 13; padding: 11; onAccepted: { bridge && bridge.renameTask(text); renameDialog.close(); } background: Rectangle { radius: 8; color: "#141d17"; border.color: renameField.activeFocus ? accent : "#415647" } }
        }
        footer: RowLayout { spacing: 8; Item { Layout.fillWidth: true } ActionButton { text: "Cancel"; quiet: true; onClicked: renameDialog.close() } ActionButton { text: "Save name"; primary: true; enabled: renameField.text.trim().length > 0; onClicked: { bridge && bridge.renameTask(renameField.text); renameDialog.close(); } } }
    }

    Dialog { id: deleteDialog; property string taskToDelete: ""; anchors.centerIn: parent; modal: true; title: "Delete this task?"; standardButtons: Dialog.Yes | Dialog.Cancel; onAccepted: bridge && bridge.deleteTask(taskToDelete); Label { text: "This removes its saved conversation from this computer."; color: "#c6d5ca" } background: Rectangle { radius: 12; color: "#28352c"; border.color: "#526d59" } }
    Dialog { id: linkDialog; property string link: ""; anchors.centerIn: parent; modal: true; width: 480; title: "Open link in your browser?"; standardButtons: Dialog.Open | Dialog.Cancel; onAccepted: Qt.openUrlExternally(link); Label { width: 430; text: linkDialog.link; wrapMode: Text.WrapAnywhere; color: "#c6d5ca" } background: Rectangle { radius: 12; color: "#28352c"; border.color: "#526d59" } }
    Rectangle { id: toastBox; visible: false; z: 200; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; anchors.horizontalCenter: parent.horizontalCenter; width: toastLabel.implicitWidth+38; height: 42; radius: 10; color: "#c4e2cd"; Text { id: toastLabel; anchors.centerIn: parent; color: "#1d3827"; font.pixelSize: 12 } }
    Timer { id: toastTimer; interval: 2600; onTriggered: toastBox.visible = false }

    function runCommand(action) {
        if (action === "new") bridge && bridge.newTask();
        else if (action === "focus") composer.forceActiveFocus();
        else if (action === "panel") window.inspectorOpen = !window.inspectorOpen;
        else if (action === "desktop") bridge && bridge.toggleDesktop();
        else if (action === "refresh") bridge && bridge.refreshModels();
        else if (action === "settings") settings.open();
        else if (action === "stop") bridge && bridge.stop();
    }
}