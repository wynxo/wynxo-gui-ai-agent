import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! Settings, organised by what you are trying to change rather than by module. */
Sheet {
    id: sheet
    title: "Settings"
    width: Math.min(860, parent ? parent.width - Theme.s6 : 860)
    height: Math.min(660, parent ? parent.height - Theme.s6 : 660)
    signal openModelPicker()

    property int page: 0
    property var pages: [
        { label: "General", icon: "sliders" },
        { label: "Appearance", icon: "sun" },
        { label: "Models", icon: "layers" },
        { label: "AI runtime", icon: "bolt" },
        { label: "Screen control", icon: "cursor" },
        { label: "Privacy", icon: "shield" },
        { label: "Keyboard", icon: "keyboard" },
        { label: "About", icon: "info" },
    ]

    function show(index) { page = index; open(); }

    onOpened: {
        endpointField.text = bridge ? bridge.endpoint : "";
        accentField.text = bridge ? bridge.accentColor : "";
        ctxField.text = bridge ? bridge.numCtx : "";
        tempField.text = bridge ? bridge.temperature : "";
        keepField.text = bridge ? bridge.keepAlive : "";
        stepsField.text = bridge ? bridge.maxSteps : "";
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 0
        spacing: 0

        // ------------------------------------------------------ page rail
        Rectangle {
            Layout.preferredWidth: 196
            Layout.fillHeight: true
            color: Theme.backgroundSoft
            bottomLeftRadius: Theme.r4
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderSubtle }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.s3
                spacing: 1
                Repeater {
                    model: sheet.pages
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.rowHeight
                        radius: Theme.r2
                        color: sheet.page === index ? Theme.surfaceSelected
                             : pageMouse.containsMouse ? Theme.surfaceHover : "transparent"
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.s3
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.s3
                            Icon {
                                name: modelData.icon
                                ink: sheet.page === index ? Theme.accent : Theme.textMuted
                                width: 15; height: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                color: sheet.page === index ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: pageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sheet.page = index
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s3
                    Layout.bottomMargin: Theme.s2
                    text: "Wynxo " + (bridge ? bridge.appVersion : "")
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
            }
        }

        // ---------------------------------------------------------- pages
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            StackLayout {
                width: sheet.width - 196 - Theme.s6 * 2
                x: Theme.s6
                y: Theme.s5
                currentIndex: sheet.page

                // ------------------------------------------------- GENERAL
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Connection"
                        description: "Wynxo talks to Ollama on this computer. No account, no API key, no cloud."
                        Field {
                            id: endpointField
                            width: parent.width
                            mono: true
                            placeholderText: "http://127.0.0.1:11434"
                        }
                        Row {
                            spacing: Theme.s2
                            WButton {
                                text: "Save and reconnect"
                                variant: "primary"
                                onClicked: bridge && bridge.setEndpoint(endpointField.text)
                            }
                            WButton { text: "Reconnect"; iconName: "retry"; onClicked: bridge && bridge.refreshModels() }
                        }
                        Text {
                            width: parent.width
                            text: bridge && bridge.online
                                  ? bridge.models.length + " local models available"
                                  : "Not connected"
                            color: bridge && bridge.online ? Theme.success : Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        }
                    }
                    Group {
                        title: "Behaviour"
                        Toggle {
                            width: parent.width
                            text: "Let the model think before answering"
                            description: "Uses the model's reasoning mode where Ollama reports support for it."
                            checked: bridge ? bridge.thinking : false
                            onToggled: function(value) { bridge && bridge.setFlag("think", value); }
                        }
                        Toggle {
                            width: parent.width
                            text: "Desktop notifications"
                            description: "Tell me when a long task finishes and Wynxo is not focused."
                            checked: bridge ? bridge.notificationsEnabled : true
                            onToggled: function(value) { bridge && bridge.setFlag("notifications", value); }
                        }
                        Toggle {
                            width: parent.width
                            text: "System tray icon"
                            description: "Keep Wynxo reachable from the tray. Takes effect on restart."
                            checked: bridge ? bridge.trayEnabled : false
                            onToggled: function(value) { bridge && bridge.setFlag("tray", value); }
                        }
                    }
                }

                // ---------------------------------------------- APPEARANCE
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Accent"
                        description: "One restrained highlight colour, used sparingly across the app."
                        Flow {
                            width: parent.width
                            spacing: Theme.s2
                            Repeater {
                                model: bridge ? bridge.themes : []
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 108; height: 56
                                    radius: Theme.r2
                                    color: swatchMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: bridge && bridge.theme === modelData.name ? Theme.accentEdge : Theme.borderSubtle
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: Theme.s2
                                        Rectangle {
                                            width: 26; height: 26; radius: 13
                                            color: modelData.color
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            text: modelData.name
                                            color: Theme.textSecondary
                                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: swatchMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { bridge && bridge.setTheme(modelData.name); accentField.text = modelData.color; }
                                    }
                                }
                            }
                        }
                        Row {
                            spacing: Theme.s2
                            width: parent.width
                            Field {
                                id: accentField
                                width: parent.width - 130
                                mono: true
                                placeholderText: "#e9e3d6"
                            }
                            WButton { text: "Apply"; onClicked: bridge && bridge.setAccent(accentField.text) }
                        }
                    }
                    Group {
                        title: "Layout"
                        Segmented {
                            width: 260
                            options: [{ id: "Comfortable", label: "Comfortable" }, { id: "Compact", label: "Compact" }]
                            current: bridge ? bridge.density : "Comfortable"
                            onSelected: function(value) { bridge && bridge.setDensity(value); }
                        }
                        Toggle {
                            width: parent.width
                            text: "Use the system font"
                            description: "Match your desktop's interface font instead of the bundled Inter."
                            checked: bridge ? bridge.systemFont : false
                            onToggled: function(value) { bridge && bridge.setFlag("system_font", value); }
                        }
                        Toggle {
                            width: parent.width
                            text: "Reduce motion"
                            description: "Turn off transitions and looping animations."
                            checked: bridge ? bridge.reducedMotion : false
                            onToggled: function(value) { bridge && bridge.setFlag("reduced_motion", value); }
                        }
                        Toggle {
                            width: parent.width
                            text: "Solid dark canvas"
                            description: "A flat background instead of the layered one."
                            checked: bridge ? bridge.solidBackground : true
                            onToggled: function(value) { bridge && bridge.setFlag("solid_background", value); }
                        }
                    }
                }

                // -------------------------------------------------- MODELS
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Model manager"
                        description: "Browse, favourite, download and delete the models installed with Ollama."
                        Text {
                            width: parent.width
                            text: bridge ? "Default model: " + bridge.model : ""
                            color: Theme.textSecondary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.label
                        }
                        Text {
                            width: parent.width
                            text: bridge ? bridge.modelCapabilityHint : ""
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap; lineHeight: 1.4
                        }
                        WButton {
                            text: "Open model manager"
                            iconName: "layers"
                            variant: "primary"
                            onClicked: { sheet.close(); sheet.openModelPicker(); }
                        }
                    }
                    Group {
                        title: "What each capability unlocks"
                        Repeater {
                            model: [
                                { name: "Chat", detail: "Streamed answers, saved locally." },
                                { name: "Tools", detail: "Discover and launch installed applications." },
                                { name: "Vision", detail: "Read screenshots and images you attach." },
                                { name: "Vision + tools", detail: "Full screen control: click, type, scroll, drag." },
                                { name: "Thinking", detail: "Show the model's reasoning before its answer." },
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                width: parent.width
                                spacing: Theme.s3
                                Rectangle {
                                    Layout.preferredWidth: 104; Layout.preferredHeight: 22
                                    radius: Theme.r1; color: Theme.surfaceHover
                                    Text {
                                        anchors.centerIn: parent; text: modelData.name
                                        color: Theme.textSecondary
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.detail; color: Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------- RUNTIME
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Preset"
                        description: bridge ? bridge.runtimeHint : ""
                        Segmented {
                            width: 380
                            options: [
                                { id: "Fast", label: "Fast", detail: "Low latency" },
                                { id: "Balanced", label: "Balanced", detail: "Everyday default" },
                                { id: "Deep", label: "Deep", detail: "More context and reasoning" },
                                { id: "Custom", label: "Custom", detail: "Your own values" },
                            ]
                            current: bridge ? bridge.runtimePreset : "Balanced"
                            onSelected: function(value) {
                                if (value === "Custom" || !bridge) return;
                                bridge.applyRuntimePreset(value);
                                ctxField.text = bridge.numCtx; tempField.text = bridge.temperature;
                                keepField.text = bridge.keepAlive; stepsField.text = bridge.maxSteps;
                            }
                        }
                    }
                    Group {
                        title: "Advanced"
                        description: "Ollama generation options. Saving these switches the preset to Custom."
                        Grid {
                            id: advancedGrid
                            width: parent.width
                            columns: 2
                            columnSpacing: Theme.s3
                            rowSpacing: Theme.s3
                            property real cellWidth: (width - columnSpacing) / 2

                            Column {
                                width: advancedGrid.cellWidth
                                spacing: Theme.s2
                                Text { text: "Context tokens"; color: Theme.textSecondary; font.family: Theme.sansFamily; font.pixelSize: Theme.caption }
                                Field { id: ctxField; width: parent.width; inputMethodHints: Qt.ImhDigitsOnly }
                            }
                            Column {
                                width: advancedGrid.cellWidth
                                spacing: Theme.s2
                                Text { text: "Temperature"; color: Theme.textSecondary; font.family: Theme.sansFamily; font.pixelSize: Theme.caption }
                                Field { id: tempField; width: parent.width }
                            }
                            Column {
                                width: advancedGrid.cellWidth
                                spacing: Theme.s2
                                Text { text: "Keep model loaded"; color: Theme.textSecondary; font.family: Theme.sansFamily; font.pixelSize: Theme.caption }
                                Field { id: keepField; width: parent.width; placeholderText: "5m" }
                            }
                            Column {
                                width: advancedGrid.cellWidth
                                spacing: Theme.s2
                                Text { text: "Desktop action budget"; color: Theme.textSecondary; font.family: Theme.sansFamily; font.pixelSize: Theme.caption }
                                Field { id: stepsField; width: parent.width; inputMethodHints: Qt.ImhDigitsOnly }
                            }
                        }
                        WButton {
                            text: "Save runtime settings"
                            variant: "primary"
                            enabled: bridge && !bridge.busy
                            onClicked: bridge && bridge.saveRuntimeSettings(ctxField.text, tempField.text, keepField.text, stepsField.text)
                        }
                    }
                }

                // ------------------------------------------ SCREEN CONTROL
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Permission mode"
                        description: "How much Wynxo may do on your desktop without asking first."
                        Repeater {
                            model: bridge ? bridge.permissionModes : []
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 60
                                radius: Theme.r2
                                color: bridge && bridge.permissionMode === modelData.id ? Theme.surfaceSelected
                                     : modeMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                                border.width: 1
                                border.color: bridge && bridge.permissionMode === modelData.id ? Theme.accentEdge : Theme.borderSubtle
                                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.s4
                                    spacing: Theme.s3
                                    Icon {
                                        name: bridge && bridge.permissionMode === modelData.id ? "check" : "shield"
                                        ink: bridge && bridge.permissionMode === modelData.id ? Theme.accent : Theme.textMuted
                                        width: 17; height: 17
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3
                                        Text {
                                            text: modelData.label; color: Theme.textPrimary
                                            font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                            font.weight: Font.Medium
                                        }
                                        Text {
                                            text: modelData.detail; color: Theme.textMuted
                                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                        }
                                    }
                                }
                                MouseArea {
                                    id: modeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bridge && bridge.setPermissionMode(modelData.id)
                                }
                            }
                        }
                    }
                    Group {
                        title: "Session"
                        Row {
                            spacing: Theme.s2
                            StatusDot { tone: bridge && bridge.desktopEnabled ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: bridge && bridge.desktopEnabled ? "Screen control is on" : "Screen control is off"
                                color: Theme.textSecondary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        WButton {
                            text: bridge && bridge.desktopEnabled ? "Turn off screen control" : "Turn on screen control"
                            iconName: "cursor"
                            variant: bridge && bridge.desktopEnabled ? "secondary" : "primary"
                            enabled: bridge && !bridge.connecting
                            onClicked: bridge && bridge.toggleDesktop()
                        }
                        Text {
                            width: parent.width
                            text: (bridge ? bridge.desktopBackend + " — " + bridge.desktopDetail : "")
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap; lineHeight: 1.4
                        }
                        Text {
                            width: parent.width
                            text: "Screen control starts off every time Wynxo opens. Escape stops any running task immediately."
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap; lineHeight: 1.4
                        }
                    }
                }

                // ------------------------------------------------- PRIVACY
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "What stays on this computer"
                        Repeater {
                            model: [
                                { icon: "layers", line: "Inference runs through your local Ollama server." },
                                { icon: "chat", line: "Conversations are stored in a private SQLite file." },
                                { icon: "camera", line: "Screenshots are sent to your local model and never saved to history." },
                                { icon: "lock", line: "No account, no API key, no telemetry, no hosted backend." },
                                { icon: "shield", line: "Only loopback Ollama addresses are accepted; redirects are refused." },
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                width: parent.width
                                spacing: Theme.s3
                                Icon { name: modelData.icon; ink: Theme.textMuted; width: 15; height: 15; Layout.alignment: Qt.AlignTop }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.line; color: Theme.textSecondary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                    wrapMode: Text.WordWrap; lineHeight: 1.4
                                }
                            }
                        }
                    }
                    Group {
                        title: "Local data"
                        Text {
                            width: parent.width
                            text: bridge ? bridge.dataLocation : ""
                            color: Theme.textSecondary
                            font.family: Theme.monoFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WrapAnywhere
                        }
                        Row {
                            spacing: Theme.s2
                            WButton {
                                text: "Open data folder"
                                iconName: "folder"
                                onClicked: bridge && bridge.revealPath(bridge.dataLocation.replace(/\/[^/]*$/, ""))
                            }
                            WButton {
                                text: "Replay the welcome tour"
                                iconName: "spark"
                                variant: "ghost"
                                onClicked: { bridge && bridge.resetOnboarding(); sheet.close(); }
                            }
                        }
                    }
                }

                // ------------------------------------------------ KEYBOARD
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Shortcuts"
                        description: "Window shortcuts, active while Wynxo has keyboard focus."
                        Repeater {
                            model: [
                                { keys: "Enter", label: "Send message" },
                                { keys: "Shift + Enter", label: "New line" },
                                { keys: "Escape", label: "Stop generation and desktop actions" },
                                { keys: "Ctrl + N", label: "New chat" },
                                { keys: "Ctrl + K", label: "Search chats" },
                                { keys: "Ctrl + Shift + P", label: "Command palette" },
                                { keys: "Ctrl + Space", label: "Quick bar" },
                                { keys: "Ctrl + M", label: "Model manager" },
                                { keys: "Ctrl + B", label: "Toggle sidebar" },
                                { keys: "Ctrl + I", label: "Toggle inspector" },
                                { keys: "Ctrl + R", label: "Regenerate" },
                                { keys: "Ctrl + D", label: "Duplicate chat" },
                                { keys: "Ctrl + Shift + V", label: "Paste an image as context" },
                                { keys: "Ctrl + ,", label: "Settings" },
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                width: parent.width
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label; color: Theme.textSecondary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                }
                                Rectangle {
                                    width: keyLabel.implicitWidth + Theme.s3; height: 22; radius: Theme.r1
                                    color: Theme.surfaceSunken
                                    border.width: 1; border.color: Theme.borderSubtle
                                    Text {
                                        id: keyLabel
                                        anchors.centerIn: parent
                                        text: modelData.keys; color: Theme.textMuted
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                    }
                                }
                            }
                        }
                    }
                    Group {
                        title: "Global quick bar"
                        description: "Linux does not offer applications a system-wide hotkey. Bind your desktop's custom shortcut to the command below and Ctrl+Space will reach Wynxo from anywhere."
                        Rectangle {
                            width: parent.width; height: 40; radius: Theme.r2
                            color: Theme.surfaceSunken
                            border.width: 1; border.color: Theme.borderSubtle
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: Theme.s3
                                anchors.verticalCenter: parent.verticalCenter
                                text: "wynxo --quick"
                                color: Theme.textSecondary
                                font.family: Theme.monoFamily; font.pixelSize: Theme.caption
                            }
                            IconButton {
                                anchors.right: parent.right; anchors.rightMargin: Theme.s1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30; height: 30; iconSize: 15
                                iconName: "copy"; tooltip: "Copy command"
                                onClicked: bridge && bridge.copyText("wynxo --quick")
                            }
                        }
                    }
                }

                // --------------------------------------------------- ABOUT
                Column {
                    spacing: Theme.s5
                    Group {
                        title: "Wynxo"
                        description: "A local desktop copilot for Linux, powered entirely by Ollama."
                        Row {
                            spacing: Theme.s4
                            Orb { width: 56; height: 56; animate: !Theme.reducedMotion }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: "Version " + (bridge ? bridge.appVersion : "")
                                    color: Theme.textPrimary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                }
                                Text {
                                    text: "Local by design · no cloud AI, no API keys"
                                    color: Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                }
                                Text {
                                    text: bridge ? "Desktop backend: " + bridge.desktopBackend : ""
                                    color: Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                }
                            }
                        }
                    }
                    Group {
                        title: "Credits"
                        Text {
                            width: parent.width
                            text: "Interface type is Inter; code is set in JetBrains Mono. Both are used under the SIL Open Font License. Wynxo is an independent project and is not affiliated with Ollama or any AI vendor."
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap; lineHeight: 1.5
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ helpers
    component Group: Column {
        property string title: ""
        property string description: ""
        default property alias groupBody: holder.data
        width: parent ? parent.width : 400
        spacing: Theme.s3
        Text {
            text: parent.title
            color: Theme.textPrimary
            font.family: Theme.sansFamily; font.pixelSize: Theme.heading
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            visible: parent.description !== ""
            text: parent.description
            color: Theme.textMuted
            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            wrapMode: Text.WordWrap; lineHeight: 1.45
        }
        Column {
            id: holder
            width: parent.width
            spacing: Theme.s3
        }
    }

}
