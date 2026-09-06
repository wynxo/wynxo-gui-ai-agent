import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Wynxo

/*!
    The application shell.

    Three regions — navigation, conversation, inspector — where only the
    conversation is ever mandatory. Below 1180px the inspector becomes a
    drawer; below 820px the sidebar does too, so the app stays usable all the
    way down to its minimum size.
*/
ApplicationWindow {
    id: window
    width: 1440; height: 920
    minimumWidth: 560; minimumHeight: 520
    visible: true
    title: (bridge ? bridge.taskTitle : "Wynxo") + " — Wynxo"
    color: bridge && bridge.solidBackground ? Theme.background : Theme.backgroundSoft

    // ------------------------------------------------------------ layout
    readonly property bool wide: width >= 1180
    readonly property bool medium: width >= 820
    property bool sidebarCollapsed: false
    property bool inspectorOpen: true
    property bool closing: false
    readonly property bool sidebarDocked: medium && !sidebarCollapsed
    readonly property bool inspectorDocked: wide && inspectorOpen

    // ------------------------------------------------------------- setup
    // A binding rather than an assignment, so the theme keeps following the
    // bridge — including when a preview run swaps it out underneath us.
    Binding { target: Theme; property: "bridge"; value: bridge }

    Component.onCompleted: {
        Theme.systemSans = window.font.family;
        window.pushPalettes();
        if (bridge && !bridge.onboarded) onboarding.open();
    }

    // Markdown and code are rendered in Python, so the renderers need the same
    // palette the rest of the interface uses — including after an accent change.
    function pushPalettes() {
        if (!Theme.bridge) return;
        Theme.bridge.setCodePalette(Theme.codePalette);
        Theme.bridge.setHtmlPalette({
            "text": Theme.textPrimary, "muted": Theme.textSecondary,
            "faint": Theme.textMuted, "accent": Theme.accent,
            "codeBackground": Theme.surfaceSunken, "border": Theme.borderStrong,
            "rule": Theme.borderSubtle
        });
    }

    Connections {
        target: Theme
        function onAccentChanged() { window.pushPalettes(); }
        function onBridgeChanged() { window.pushPalettes(); }
    }

    onActiveChanged: if (bridge) bridge.setWindowActive(active)

    onClosing: function(close) {
        if (bridge && !bridge.canClose()) { close.accepted = false; closing = true; closeTimer.start(); }
    }
    Timer { id: closeTimer; interval: 150; repeat: true; onTriggered: { if (bridge && bridge.canClose()) { stop(); window.close(); } } }

    Connections {
        target: bridge
        // A first run — or "replay the welcome tour" — opens onboarding.
        function onChanged() {
            if (bridge && !bridge.onboarded && !onboarding.opened && window.previewOverlay === "")
                onboarding.open();
        }
        function onToast(text) { toast.show(text); }
        function onFocusComposer() { composer.focusInput(); }
        function onScrollToEnd() { chat.jumpToEnd(); }
        function onQuickBarRequested() { window.openQuickBar(); }
    }

    // -------------------------------------------------------- shortcuts
    Shortcut { sequences: ["Ctrl+N"]; onActivated: bridge && bridge.newTask() }
    Shortcut { sequences: ["Ctrl+,"]; onActivated: settings.show(0) }
    Shortcut { sequences: ["Ctrl+K"]; onActivated: window.focusSearch() }
    Shortcut { sequences: ["Ctrl+M"]; onActivated: models.open() }
    Shortcut { sequences: ["Ctrl+B"]; onActivated: window.sidebarCollapsed = !window.sidebarCollapsed }
    Shortcut { sequences: ["Ctrl+I"]; onActivated: window.inspectorOpen = !window.inspectorOpen }
    Shortcut { sequences: ["Ctrl+Shift+P"]; onActivated: palette.open() }
    Shortcut { sequences: ["Ctrl+Space"]; onActivated: window.openQuickBar() }
    Shortcut { sequences: ["Ctrl+Shift+S"]; onActivated: bridge && bridge.stop() }
    Shortcut { sequences: ["Ctrl+R"]; onActivated: bridge && bridge.regenerate() }
    Shortcut { sequences: ["Ctrl+D"]; onActivated: bridge && bridge.duplicateTask() }
    Shortcut { sequences: ["Ctrl+Shift+V"]; onActivated: bridge && bridge.pasteImage() }
    Shortcut { sequences: ["Alt+Up"]; onActivated: bridge && bridge.openAdjacentTask(-1) }
    Shortcut { sequences: ["Alt+Down"]; onActivated: bridge && bridge.openAdjacentTask(1) }
    Shortcut {
        sequences: ["Escape"]
        // Escape is the emergency stop: it always reaches the running task.
        onActivated: {
            if (bridge && bridge.permissionPending) bridge.resolvePermission(false);
            else if (bridge && bridge.busy) bridge.stop();
        }
    }

    // ---------------------------------------------------------- the shell
    RowLayout {
        anchors.fill: parent
        spacing: 0

        AppSidebar {
            id: sidebar
            Layout.preferredWidth: window.sidebarCollapsed ? 60 : 264
            Layout.fillHeight: true
            visible: window.medium
            collapsed: window.sidebarCollapsed
            onCollapsedChanged: window.sidebarCollapsed = collapsed
            onNewChat: bridge && bridge.newTask()
            onOpenSettings: settings.show(0)
            onRenameRequested: function(id, title) { renameSheet.show(id, title); }
            onDeleteRequested: function(id, title) { deleteSheet.show(id, title); }
            Behavior on Layout.preferredWidth {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.base; easing.type: Theme.easing }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TopBar {
                id: topBar
                Layout.fillWidth: true
                sidebarCollapsed: window.sidebarCollapsed || !window.medium
                inspectorOpen: window.inspectorOpen
                onToggleSidebar: {
                    if (!window.medium) sidebarDrawer.open();
                    else window.sidebarCollapsed = !window.sidebarCollapsed;
                }
                onToggleInspector: {
                    if (!window.wide) inspectorDrawer.open();
                    else window.inspectorOpen = !window.inspectorOpen;
                }
                onRenameRequested: if (bridge && bridge.taskId) renameSheet.show(bridge.taskId, bridge.taskTitle)
                onOpenModelPicker: models.open()
                onOpenSettings: settings.show(0)
                onOpenCommandPalette: palette.open()
                onOpenDesktopSettings: settings.show(4)
                onClearRequested: clearSheet.open()
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ------------------------------------------- conversation
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.gutter
                        anchors.rightMargin: Theme.gutter
                        anchors.bottomMargin: Theme.s4
                        spacing: Theme.s3

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            EmptyState {
                                anchors.fill: parent
                                visible: bridge && !bridge.hasMessages
                                onTemplateChosen: function(prompt) { composer.insert(prompt); }
                            }

                            MessageList {
                                id: chat
                                anchors.fill: parent
                                visible: bridge && bridge.hasMessages
                                model: bridge ? bridge.messageModel : null
                                onLinkClicked: function(link) { linkSheet.show(link); }
                            }
                        }

                        // A model limit the user should know before sending.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Theme.readingWidth
                            Layout.alignment: Qt.AlignHCenter
                            visible: bridge && bridge.capabilityWarning.length > 0
                            Layout.preferredHeight: visible ? warningText.implicitHeight + Theme.s3 * 2 : 0
                            radius: Theme.r2
                            color: Theme.warningMuted
                            border.width: 1
                            border.color: Theme.alpha(Theme.warning, 0.35)
                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.s3
                                spacing: Theme.s3
                                Icon { name: "info"; ink: Theme.warning; width: 15; height: 15 }
                                Text {
                                    id: warningText
                                    width: parent.width - 30
                                    text: bridge ? bridge.capabilityWarning : ""
                                    color: Theme.textSecondary
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                    wrapMode: Text.WordWrap; lineHeight: 1.4
                                }
                            }
                        }

                        ErrorBanner {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Theme.readingWidth
                            Layout.alignment: Qt.AlignHCenter
                            onActionInvoked: function(action) { window.runCommand(action); }
                        }

                        // Live status while the model works.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Theme.readingWidth
                            Layout.alignment: Qt.AlignHCenter
                            visible: bridge && bridge.busy
                            spacing: Theme.s2
                            StatusDot { tone: Theme.accent; pulsing: true }
                            Text {
                                Layout.fillWidth: true
                                text: bridge ? bridge.status : ""
                                color: Theme.textSecondary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                elide: Text.ElideRight
                            }
                            Text {
                                text: bridge && bridge.tokenRate !== "—" ? bridge.tokenRate : ""
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            }
                            Text {
                                text: "Esc to stop"
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            }
                        }

                        Composer {
                            id: composer
                            Layout.fillWidth: true
                            Layout.maximumWidth: Theme.readingWidth
                            Layout.alignment: Qt.AlignHCenter
                            onSubmitted: function(text) { bridge && bridge.send(text); }
                            onOpenModelPicker: models.open()
                            onOpenDesktopSettings: settings.show(4)
                        }

                        Text {
                            Layout.maximumWidth: Theme.readingWidth
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            horizontalAlignment: Text.AlignHCenter
                            visible: window.height > 600
                            text: "Runs locally with Ollama · Enter to send · Shift+Enter for a new line"
                            color: Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.micro
                            elide: Text.ElideRight
                        }
                    }
                }

                // ---------------------------------------------- inspector
                ContextPanel {
                    id: inspector
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    visible: window.inspectorDocked
                    onOpenModelPicker: models.open()
                    onOpenDesktopSettings: settings.show(4)
                }
            }
        }
    }

    // ------------------------------------------------------- drawers
    Drawer {
        id: sidebarDrawer
        edge: Qt.LeftEdge
        width: 280
        height: window.height
        dragMargin: 0
        background: Rectangle { color: Theme.backgroundSoft }
        AppSidebar {
            anchors.fill: parent
            onNewChat: { bridge && bridge.newTask(); sidebarDrawer.close(); }
            onOpenSettings: { sidebarDrawer.close(); settings.show(0); }
            onRenameRequested: function(id, title) { sidebarDrawer.close(); renameSheet.show(id, title); }
            onDeleteRequested: function(id, title) { sidebarDrawer.close(); deleteSheet.show(id, title); }
        }
    }

    Drawer {
        id: inspectorDrawer
        edge: Qt.RightEdge
        width: Math.min(320, window.width - 40)
        height: window.height
        dragMargin: 0
        background: Rectangle { color: Theme.backgroundSoft }
        ContextPanel {
            anchors.fill: parent
            onOpenModelPicker: { inspectorDrawer.close(); models.open(); }
            onOpenDesktopSettings: { inspectorDrawer.close(); settings.show(4); }
        }
    }

    // --------------------------------------------------------- overlays
    ModelPicker { id: models }
    SettingsSheet { id: settings; onOpenModelPicker: models.open() }
    CommandPalette { id: palette; onInvoked: function(action) { window.runCommand(action); } }
    PermissionPrompt { id: permission }
    Onboarding { id: onboarding; onOpenModelPicker: models.open() }
    Toast { id: toast }
    RegionSelector { id: regionSelector }

    Sheet {
        id: renameSheet
        title: "Rename chat"
        width: 440
        height: 210
        property string targetId: ""
        function show(id, title) { targetId = id; renameField.text = title; open(); renameField.selectAll(); renameField.forceActiveFocus(); }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            anchors.topMargin: 0
            spacing: Theme.s4
            Field {
                id: renameField
                Layout.fillWidth: true
                implicitHeight: 44
                onAccepted: renameSheet.commit()
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                WButton { text: "Cancel"; variant: "ghost"; onClicked: renameSheet.close() }
                WButton {
                    text: "Save"; variant: "primary"
                    enabled: renameField.text.trim().length > 0
                    onClicked: renameSheet.commit()
                }
            }
        }
        function commit() {
            if (bridge && renameField.text.trim()) bridge.renameTaskById(targetId, renameField.text);
            close();
        }
    }

    Sheet {
        id: deleteSheet
        title: "Delete this chat?"
        width: 440
        height: 210
        property string targetId: ""
        property string targetTitle: ""
        function show(id, title) { targetId = id; targetTitle = title; open(); }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            anchors.topMargin: 0
            spacing: Theme.s4
            Text {
                Layout.fillWidth: true
                text: "“" + deleteSheet.targetTitle + "” and its messages will be removed from this computer."
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap; lineHeight: 1.4
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                WButton { text: "Cancel"; variant: "ghost"; onClicked: deleteSheet.close() }
                WButton {
                    text: "Delete"; variant: "danger"
                    onClicked: { bridge && bridge.deleteTask(deleteSheet.targetId); deleteSheet.close(); }
                }
            }
        }
    }

    Sheet {
        id: clearSheet
        title: "Clear this conversation?"
        width: 440
        height: 210
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            anchors.topMargin: 0
            spacing: Theme.s4
            Text {
                Layout.fillWidth: true
                text: "The chat stays in your list, but every message is removed from local history."
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap; lineHeight: 1.4
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                WButton { text: "Cancel"; variant: "ghost"; onClicked: clearSheet.close() }
                WButton { text: "Clear"; variant: "danger"; onClicked: { bridge && bridge.clearTask(); clearSheet.close(); } }
            }
        }
    }

    Sheet {
        id: linkSheet
        title: "Open this link?"
        width: 520
        height: 230
        property string link: ""
        function show(url) { link = url; open(); }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            anchors.topMargin: 0
            spacing: Theme.s4
            Text {
                Layout.fillWidth: true
                text: "This opens in your default browser, outside Wynxo."
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            }
            Text {
                Layout.fillWidth: true
                text: linkSheet.link
                color: Theme.textSecondary
                font.family: Theme.monoFamily; font.pixelSize: Theme.caption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                WButton { text: "Cancel"; variant: "ghost"; onClicked: linkSheet.close() }
                WButton {
                    text: "Open"; variant: "primary"
                    onClicked: { Qt.openUrlExternally(linkSheet.link); linkSheet.close(); }
                }
            }
        }
    }

    // -------------------------------------------------------- quick bar
    // Exposed so --snapshot can grab the floating window on its own.
    property var quickBarWindow: quickBar

    Window {
        id: quickBar
        objectName: "quickBar"
        width: 620
        height: quickContent.implicitHeight
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Dialog
        color: "transparent"
        title: "Wynxo quick bar"

        QuickBarContent {
            id: quickContent
            width: parent.width
            onSubmitted: function(text) {
                window.show();
                window.raise();
                if (bridge) bridge.send(text);
                quickBar.close();
            }
            onExpandRequested: { quickBar.close(); window.show(); window.raise(); window.requestActivate(); }
            onDismissed: quickBar.close()
        }
    }

    function openQuickBar() {
        var screenWidth = Screen.width > 0 ? Screen.width : window.width;
        var screenHeight = Screen.height > 0 ? Screen.height : window.height;
        quickBar.x = Math.round((screenWidth - quickBar.width) / 2);
        quickBar.y = Math.round(screenHeight * 0.26);
        quickBar.show();
        quickBar.raise();
        quickBar.requestActivate();
        quickContent.focusInput();
    }

    // Preview hook: --snapshot drives the real UI into a named state so the
    // README screenshots come from this renderer, not from a mock-up.
    property string previewOverlay: ""
    function closeOverlays() {
        settings.close(); models.close(); palette.close();
        onboarding.close(); quickBar.close();
        renameSheet.close(); deleteSheet.close(); clearSheet.close(); linkSheet.close();
    }
    onPreviewOverlayChanged: {
        closeOverlays();
        if (previewOverlay === "welcome") onboarding.open();
        else if (previewOverlay === "settings") settings.show(0);
        else if (previewOverlay === "desktopSettings") settings.show(4);
        else if (previewOverlay === "models") models.open();
        else if (previewOverlay === "palette") palette.open();
        else if (previewOverlay === "quickbar") window.openQuickBar();
    }

    // ---------------------------------------------------------- commands
    function focusSearch() {
        if (!window.medium) { sidebarDrawer.open(); return; }
        window.sidebarCollapsed = false;
        sidebar.focusSearch();
    }

    function runCommand(action) {
        if (!bridge) return;
        switch (action) {
        case "new": bridge.newTask(); break;
        case "search": window.focusSearch(); break;
        case "models": models.open(); break;
        case "settings": settings.show(0); break;
        case "sidebar": window.sidebarCollapsed = !window.sidebarCollapsed; break;
        case "inspector":
            if (window.wide) window.inspectorOpen = !window.inspectorOpen;
            else inspectorDrawer.open();
            break;
        case "quickbar": window.openQuickBar(); break;
        case "screenshot": bridge.attachScreenshot(); break;
        case "window": bridge.attachWindow(); break;
        case "region": bridge.attachRegion(); break;
        case "file": bridge.attachFile(); break;
        case "folder": bridge.attachFolder(); break;
        case "desktop": bridge.toggleDesktop(); break;
        case "permission": settings.show(4); break;
        case "runtime": settings.show(3); break;
        case "regenerate": bridge.regenerate(); break;
        case "stop": bridge.stop(); break;
        case "export": bridge.exportTask(); break;
        case "duplicate": bridge.duplicateTask(); break;
        case "pin": if (bridge.taskId) bridge.togglePin(bridge.taskId); break;
        case "clear": if (bridge.taskId) clearSheet.open(); break;
        case "reconnect": case "retry": bridge.refreshModels(); break;
        case "terminal": bridge.openTerminalHere(); break;
        case "previous": bridge.openAdjacentTask(-1); break;
        case "next": bridge.openAdjacentTask(1); break;
        }
    }
}
