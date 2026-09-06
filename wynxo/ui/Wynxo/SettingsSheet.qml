import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Five sections, each answering one question.

    Anything with a home in the interface itself is not repeated here: models
    are chosen in the composer, the project is chosen in the sidebar, and
    shortcuts are a reference sheet rather than a settings page.
*/
Sheet {
    id: sheet
    title: "Settings"
    width: Math.min(820, parent ? parent.width - Theme.s6 : 820)
    height: Math.min(620, parent ? parent.height - Theme.s6 : 620)
    signal openModelManager()

    readonly property int generalPage: 0
    readonly property int modelPage: 1
    readonly property int agentPage: 2
    readonly property int appearancePage: 3
    readonly property int advancedPage: 4

    property int page: 0
    readonly property var pages: [
        { label: "General", icon: "sliders" },
        { label: "Model & runtime", icon: "layers" },
        { label: "Agent", icon: "cursor" },
        { label: "Appearance", icon: "sun" },
        { label: "Advanced", icon: "shield" },
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
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 186
            Layout.fillHeight: true
            color: Theme.backgroundSoft
            bottomLeftRadius: Theme.r4
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderSubtle }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.s2
                spacing: 1
                Repeater {
                    model: sheet.pages
                    delegate: AbstractButton {
                        id: pageButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.rowHeight
                        hoverEnabled: true
                        Accessible.name: modelData.label
                        Accessible.checked: sheet.page === index
                        onClicked: sheet.page = index

                        background: Rectangle {
                            radius: Theme.r2
                            color: sheet.page === index ? Theme.surfaceSelected
                                 : pageButton.hovered ? Theme.surfaceHover : "transparent"
                            border.width: pageButton.visualFocus ? 2 : 0
                            border.color: Theme.accentEdge
                            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                        }
                        contentItem: Row {
                            leftPadding: Theme.s3
                            spacing: Theme.s3
                            Icon {
                                name: modelData.icon
                                ink: sheet.page === index ? Theme.accent : Theme.textMuted
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                color: sheet.page === index ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Item {
                width: sheet.width - 186
                readonly property Item current: stack.children[sheet.page] || null
                implicitHeight: (current ? current.implicitHeight : 0) + Theme.s5 + Theme.s7

                StackLayout {
                    id: stack
                    width: parent.width - Theme.s6 * 2
                    x: Theme.s6
                    y: Theme.s5
                    currentIndex: sheet.page

                    // ------------------------------------------------ GENERAL
                    Column {
                        spacing: Theme.s6
                        Group {
                            title: "Ollama server"
                            description: "Connect to Ollama on this computer, another machine on your LAN, or a server you trust. Wynxo never follows server redirects."
                            Row {
                                width: parent.width
                                spacing: Theme.s2
                                Field {
                                    id: endpointField
                                    width: parent.width - saveEndpoint.width - Theme.s2
                                    mono: true
                                    placeholderText: "http://192.168.1.50:11434"
                                    Accessible.name: "Ollama server URL"
                                    onAccepted: if (bridge) bridge.setEndpoint(text)
                                }
                                WButton {
                                    id: saveEndpoint
                                    text: "Save and reconnect"
                                    variant: "primary"
                                    enabled: bridge && !bridge.busy
                                    onClicked: if (bridge) bridge.setEndpoint(endpointField.text)
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: Theme.s2
                                StatusDot {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tone: bridge && bridge.online ? Theme.success : Theme.danger
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: bridge && bridge.online
                                          ? bridge.models.length + " model" + (bridge.models.length === 1 ? "" : "s") + " available"
                                          : "Not connected"
                                    color: bridge && bridge.online ? Theme.textSecondary : Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                }
                                Rectangle {
                                    visible: !!bridge
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: scopeLabel.implicitWidth + Theme.s2 * 2
                                    implicitHeight: 22
                                    radius: Theme.r1
                                    color: Theme.surfaceRaised
                                    border.width: 1
                                    border.color: Theme.borderSubtle
                                    Text {
                                        id: scopeLabel
                                        anchors.centerIn: parent
                                        text: bridge ? bridge.endpointScopeLabel : "Server"
                                        color: Theme.textSecondary
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                    }
                                }
                                Item { width: Theme.s1; height: 1 }
                                WButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Reconnect"; iconName: "retry"; variant: "ghost"
                                    compactPadding: true
                                    implicitHeight: Theme.controlSmall
                                    onClicked: if (bridge) bridge.refreshModels()
                                }
                            }
                            Text {
                                width: parent.width
                                text: bridge ? bridge.endpointPrivacyHint : ""
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                            Rectangle {
                                width: parent.width
                                visible: bridge && bridge.endpointScope === "remote"
                                         && String(bridge.endpoint).indexOf("http://") === 0
                                implicitHeight: insecureText.implicitHeight + Theme.s3 * 2
                                radius: Theme.r2
                                color: Theme.warningMuted
                                border.width: 1
                                border.color: Theme.alpha(Theme.warning, 0.35)
                                Text {
                                    id: insecureText
                                    anchors.fill: parent
                                    anchors.margins: Theme.s3
                                    text: "This remote server uses plain HTTP. Prefer HTTPS, Tailscale/WireGuard, or another trusted private tunnel before sending screenshots or sensitive files."
                                    color: Theme.textSecondary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                    wrapMode: Text.WordWrap; lineHeight: 1.45
                                }
                            }
                        }
                        Group {
                            title: "Behaviour"
                            Toggle {
                                width: parent.width
                                text: "Desktop notifications"
                                description: "Tell me when a long task finishes and Wynxo is not focused."
                                checked: bridge ? bridge.notificationsEnabled : true
                                onSwitched: function(value) { if (bridge) bridge.setFlag("notifications", value); }
                            }
                            Toggle {
                                width: parent.width
                                text: "System tray icon"
                                description: "Keep Wynxo reachable from the tray. Takes effect on restart."
                                checked: bridge ? bridge.trayEnabled : false
                                onSwitched: function(value) { if (bridge) bridge.setFlag("tray", value); }
                            }
                        }
                    }

                    // ----------------------------------------- MODEL & RUNTIME
                    Column {
                        spacing: Theme.s6
                        Group {
                            title: "Default model"
                            description: "The model a new task starts with. Switching for one task is quicker from the composer."
                            Row {
                                spacing: Theme.s3
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: bridge ? bridge.model : ""
                                    color: Theme.textPrimary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                    font.weight: Font.Medium
                                }
                                WButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Manage models"
                                    iconName: "layers"
                                    onClicked: { sheet.close(); sheet.openModelManager(); }
                                }
                            }
                            Text {
                                width: parent.width
                                text: bridge ? bridge.modelCapabilityHint : ""
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                        }
                        Group {
                            title: "Speed"
                            description: bridge ? bridge.runtimeHint : ""
                            Segmented {
                                width: Math.min(parent.width, 400)
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
                            Toggle {
                                width: parent.width
                                text: "Let the model think before answering"
                                description: "Uses the model's reasoning mode where Ollama reports support for it."
                                checked: bridge ? bridge.thinking : false
                                onSwitched: function(value) { if (bridge) bridge.setFlag("think", value); }
                            }
                        }
                        Disclosure {
                            width: parent.width
                            title: "Advanced generation options"
                            hint: "Ollama options. Saving these switches the preset to Custom."
                            Grid {
                                id: advancedGrid
                                width: parent.width
                                columns: width > 460 ? 2 : 1
                                columnSpacing: Theme.s3
                                rowSpacing: Theme.s3
                                property real cellWidth: columns === 2 ? (width - columnSpacing) / 2 : width

                                Column {
                                    width: advancedGrid.cellWidth
                                    spacing: Theme.s2
                                    FieldLabel { text: "Context tokens" }
                                    Field { id: ctxField; width: parent.width; inputMethodHints: Qt.ImhDigitsOnly }
                                }
                                Column {
                                    width: advancedGrid.cellWidth
                                    spacing: Theme.s2
                                    FieldLabel { text: "Temperature" }
                                    Field { id: tempField; width: parent.width }
                                }
                                Column {
                                    width: advancedGrid.cellWidth
                                    spacing: Theme.s2
                                    FieldLabel { text: "Keep model loaded" }
                                    Field { id: keepField; width: parent.width; placeholderText: "5m" }
                                }
                                Column {
                                    width: advancedGrid.cellWidth
                                    spacing: Theme.s2
                                    FieldLabel { text: "Desktop action budget" }
                                    Field { id: stepsField; width: parent.width; inputMethodHints: Qt.ImhDigitsOnly }
                                }
                            }
                            WButton {
                                text: "Save runtime settings"
                                variant: "primary"
                                enabled: bridge && !bridge.busy
                                onClicked: if (bridge) bridge.saveRuntimeSettings(ctxField.text, tempField.text,
                                                                                 keepField.text, stepsField.text)
                            }
                        }
                    }

                    // -------------------------------------------------- AGENT
                    Column {
                        spacing: Theme.s6
                        Group {
                            title: "Local copilot"
                            description: "Ask Wynxo to open apps, run commands, inspect files or help with code. Tools execute on this computer even when Ollama inference runs on another server. Commands run in your workspace folder, or your home folder when none is selected."
                        }
                        Group {
                            title: "Screen control"
                            description: "Wynxo can see your screen and use your mouse and keyboard. It starts off every time Wynxo opens."
                            Row {
                                spacing: Theme.s3
                                WButton {
                                    text: !(bridge && bridge.desktopAvailable) ? "Unavailable here"
                                        : bridge && bridge.desktopEnabled ? "Turn off screen control"
                                        : "Turn on screen control"
                                    iconName: "cursor"
                                    variant: bridge && bridge.desktopEnabled ? "secondary" : "primary"
                                    enabled: bridge && !bridge.connecting && bridge.desktopAvailable
                                    onClicked: if (bridge) bridge.toggleDesktop()
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.s2
                                    StatusDot {
                                        anchors.verticalCenter: parent.verticalCenter
                                        tone: bridge && bridge.desktopEnabled ? Theme.accent : Theme.textMuted
                                        pulsing: bridge && bridge.desktopEnabled && bridge.busy
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: bridge && bridge.desktopEnabled ? "On" : "Off"
                                        color: Theme.textSecondary
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                    }
                                }
                            }
                            Text {
                                width: parent.width
                                text: bridge ? bridge.desktopBackend + " — " + bridge.desktopDetail : ""
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                            Row {
                                width: parent.width
                                spacing: Theme.s2
                                visible: bridge && bridge.desktopRemembered
                                Icon { name: "check"; ink: Theme.success; width: 13; height: 13
                                       anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Your desktop remembered this permission, so it did not ask again."
                                    color: Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                }
                            }
                        }

                        Group {
                            title: "Stopping a run"
                            description: "Escape stops generation and desktop actions whenever Wynxo has focus. While a model is driving another window, Wynxo does not — so it also asks your desktop for a shortcut that works from anywhere."
                            Row {
                                spacing: Theme.s2
                                visible: !!(bridge && bridge.desktopStopShortcut)
                                Icon { name: "keyboard"; ink: Theme.textMuted; width: 14; height: 14
                                       anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Stop from anywhere"
                                    color: Theme.textSecondary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                }
                                KeyHint {
                                    anchors.verticalCenter: parent.verticalCenter
                                    keys: bridge ? bridge.desktopStopShortcut : ""
                                }
                            }
                            Text {
                                width: parent.width
                                visible: !!(bridge && bridge.desktopStopDetail) && !(bridge && bridge.desktopStopShortcut)
                                text: bridge ? bridge.desktopStopDetail : ""
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                            Text {
                                width: parent.width
                                visible: !(bridge && bridge.desktopEnabled)
                                text: "Turn screen control on to see which key your desktop assigned."
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                        }
                        Group {
                            title: "Permission"
                            description: "How much Wynxo may do on your desktop without asking first."
                            Repeater {
                                model: bridge ? bridge.permissionModes : []
                                delegate: AbstractButton {
                                    id: mode
                                    required property var modelData
                                    readonly property bool current: bridge && bridge.permissionMode === modelData.id
                                    width: parent.width
                                    implicitHeight: 54
                                    hoverEnabled: true
                                    Accessible.name: modelData.label
                                    Accessible.description: modelData.detail
                                    Accessible.checked: current
                                    onClicked: if (bridge) bridge.setPermissionMode(modelData.id)

                                    background: Rectangle {
                                        radius: Theme.r2
                                        color: mode.current ? Theme.surfaceSelected
                                             : mode.hovered ? Theme.surfaceHover : "transparent"
                                        border.width: mode.current || mode.visualFocus ? 1 : 0
                                        border.color: Theme.accentEdge
                                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                                    }
                                    contentItem: Row {
                                        leftPadding: Theme.s4
                                        spacing: Theme.s3
                                        Icon {
                                            name: mode.current ? "check" : "shield"
                                            ink: mode.current ? Theme.accent : Theme.textMuted
                                            width: 16; height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2
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
                                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                                }
                            }
                            Text {
                                width: parent.width
                                text: "Reading the screen and moving the pointer never prompt — they change nothing. Every run also has an action budget, set under Model & runtime."
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.45
                            }
                        }
                    }

                    // --------------------------------------------- APPEARANCE
                    Column {
                        spacing: Theme.s6
                        Group {
                            title: "Accent"
                            description: "One restrained highlight colour, used sparingly across the app."
                            Flow {
                                width: parent.width
                                spacing: Theme.s2
                                Repeater {
                                    model: bridge ? bridge.themes : []
                                    delegate: AbstractButton {
                                        id: swatch
                                        required property var modelData
                                        readonly property bool current: bridge && bridge.theme === modelData.name
                                        width: 96; height: 52
                                        hoverEnabled: true
                                        Accessible.name: modelData.name
                                        Accessible.checked: current
                                        onClicked: { if (bridge) bridge.setTheme(modelData.name); accentField.text = modelData.color; }
                                        background: Rectangle {
                                            radius: Theme.r2
                                            color: swatch.hovered ? Theme.surfaceHover : Theme.surface
                                            border.width: 1
                                            border.color: swatch.current || swatch.visualFocus ? Theme.accentEdge : Theme.borderSubtle
                                            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                                        }
                                        contentItem: Column {
                                            spacing: Theme.s2
                                            topPadding: Theme.s2
                                            Rectangle {
                                                width: 22; height: 22; radius: 11
                                                color: modelData.color
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                Icon {
                                                    anchors.centerIn: parent
                                                    visible: swatch.current
                                                    name: "check"; ink: Theme.textInverse
                                                    width: 13; height: 13
                                                }
                                            }
                                            Text {
                                                text: modelData.name
                                                color: swatch.current ? Theme.textPrimary : Theme.textSecondary
                                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                            Row {
                                spacing: Theme.s2
                                width: parent.width
                                Field {
                                    id: accentField
                                    width: Math.min(200, parent.width - 100)
                                    mono: true
                                    placeholderText: "#e9e3d6"
                                    onAccepted: if (bridge) bridge.setAccent(text)
                                }
                                WButton { text: "Apply"; onClicked: if (bridge) bridge.setAccent(accentField.text) }
                            }
                        }
                        Group {
                            title: "Density and motion"
                            Segmented {
                                width: 240
                                options: [{ id: "Comfortable", label: "Comfortable" }, { id: "Compact", label: "Compact" }]
                                current: bridge ? bridge.density : "Comfortable"
                                onSelected: function(value) { if (bridge) bridge.setDensity(value); }
                            }
                            Toggle {
                                width: parent.width
                                text: "Reduce motion"
                                description: "Turn off transitions and looping animations."
                                checked: bridge ? bridge.reducedMotion : false
                                onSwitched: function(value) { if (bridge) bridge.setFlag("reduced_motion", value); }
                            }
                            Toggle {
                                width: parent.width
                                text: "Use the system font"
                                description: "Match your desktop's interface font instead of the bundled Inter."
                                checked: bridge ? bridge.systemFont : false
                                onSwitched: function(value) { if (bridge) bridge.setFlag("system_font", value); }
                            }
                            Toggle {
                                width: parent.width
                                text: "Solid dark canvas"
                                description: "A flat background instead of the layered one."
                                checked: bridge ? bridge.solidBackground : true
                                onSwitched: function(value) { if (bridge) bridge.setFlag("solid_background", value); }
                            }
                        }
                    }

                    // ----------------------------------------------- ADVANCED
                    Column {
                        spacing: Theme.s6
                        Group {
                            title: "Privacy & data path"
                            description: bridge ? bridge.endpointPrivacyHint : ""
                            Repeater {
                                model: [
                                    { icon: "layers", line: "Inference is sent only to the Ollama server URL you configure above." },
                                    { icon: "chat", line: "Task history stays in Wynxo's private SQLite database on this computer." },
                                    { icon: "camera", line: "Screenshots are not written to chat history, but a model request can send them to your configured Ollama server." },
                                    { icon: "lock", line: "Wynxo has no account, API key requirement, telemetry service, or hosted backend of its own." },
                                    { icon: "shield", line: "Server redirects and environment proxy settings are refused by the Ollama transport." },
                                ]
                                delegate: RowLayout {
                                    required property var modelData
                                    width: parent.width
                                    spacing: Theme.s3
                                    Icon { name: modelData.icon; ink: Theme.textMuted; width: 14; height: 14; Layout.alignment: Qt.AlignTop }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.line; color: Theme.textSecondary
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                        wrapMode: Text.WordWrap; lineHeight: 1.45
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
                                    onClicked: if (bridge) bridge.revealPath(bridge.dataLocation.replace(/\/[^/]*$/, ""))
                                }
                                WButton {
                                    text: "Replay the welcome"
                                    iconName: "retry"
                                    variant: "ghost"
                                    onClicked: { if (bridge) bridge.resetOnboarding(); sheet.close(); }
                                }
                            }
                        }
                        Group {
                            title: "Global quick bar"
                            description: "Linux gives applications no system-wide hotkey. Bind your desktop's custom shortcut to this command and the quick bar will open from anywhere."
                            Rectangle {
                                width: parent.width; height: 38; radius: Theme.r2
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
                                    width: 30; height: 30; iconSize: 14
                                    iconName: "copy"; tooltip: "Copy command"
                                    onClicked: if (bridge) bridge.copyText("wynxo --quick")
                                }
                            }
                        }
                        Group {
                            title: "About"
                            Text {
                                width: parent.width
                                text: "Wynxo " + (bridge ? bridge.appVersion : "") + " — an Ollama-powered copilot for the Linux desktop. "
                                      + "Inference can run locally or on a server you choose. Desktop backend: " + (bridge ? bridge.desktopBackend : "") + ".\n\n"
                                      + "Interface type is Inter; code is set in JetBrains Mono, both under the SIL Open Font "
                                      + "License. Wynxo is an independent project and is not affiliated with Ollama or any AI vendor."
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                wrapMode: Text.WordWrap; lineHeight: 1.5
                            }
                        }
                    }
                }
            }
        }
    }

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
            wrapMode: Text.WordWrap; lineHeight: 1.5
            bottomPadding: Theme.s1
        }
        Column {
            id: holder
            width: parent.width
            spacing: Theme.s3
        }
    }

    component Disclosure: Column {
        id: disclosure
        property string title: ""
        property string hint: ""
        property bool expanded: false
        default property alias disclosureBody: inner.data
        width: parent ? parent.width : 400
        spacing: Theme.s3

        AbstractButton {
            id: toggle
            width: parent.width
            implicitHeight: Theme.control
            hoverEnabled: true
            Accessible.name: disclosure.title
            onClicked: disclosure.expanded = !disclosure.expanded
            background: Rectangle {
                radius: Theme.r2
                color: toggle.hovered ? Theme.surfaceHover : "transparent"
                border.width: toggle.visualFocus ? 2 : 0
                border.color: Theme.accentEdge
            }
            contentItem: Row {
                spacing: Theme.s2
                Icon {
                    name: disclosure.expanded ? "down" : "chevron"
                    ink: Theme.textSecondary; width: 13; height: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: disclosure.title
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.heading
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
        }
        Text {
            width: parent.width
            visible: disclosure.expanded && disclosure.hint !== ""
            text: disclosure.hint
            color: Theme.textMuted
            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            wrapMode: Text.WordWrap; lineHeight: 1.5
        }
        Column {
            id: inner
            width: parent.width
            spacing: Theme.s3
            visible: disclosure.expanded
            height: visible ? implicitHeight : 0
        }
    }

    component FieldLabel: Text {
        color: Theme.textSecondary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.caption
    }
}