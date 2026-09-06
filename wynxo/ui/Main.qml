import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Wynxo

/*!
    The application shell.

    Two regions: where you are, and what you are doing. The sidebar is docked
    and resizable above 900px and a drawer below it. A new task deliberately
    stays sparse: one centered prompt and one composer. Conversation-only
    controls appear after the first message instead of crowding the home screen.
*/
ApplicationWindow {
    id: window
    width: 1400; height: 900
    minimumWidth: 560; minimumHeight: 520
    visible: true
    title: (bridge ? bridge.taskTitle : "Wynxo") + " — Wynxo"
    color: bridge && bridge.solidBackground ? Theme.background : Theme.backgroundSoft

    // ------------------------------------------------------------ layout
    readonly property bool roomForSidebar: width >= 900
    onRoomForSidebarChanged: if (roomForSidebar && sidebarDrawer) sidebarDrawer.close()
    readonly property bool sidebarCollapsed: bridge ? bridge.sidebarCollapsed : false
    readonly property bool sidebarDocked: roomForSidebar
    readonly property bool homeMode: bridge && !bridge.hasMessages
    property int sidebarUserWidth: 248
    readonly property int sidebarWidth: sidebarCollapsed ? 52
        : Math.max(200, Math.min(sidebarUserWidth, Math.round(width * 0.3)))

    property bool closing: false

    // ------------------------------------------------------------- setup
    Binding { target: Theme; property: "bridge"; value: bridge }

    Component.onCompleted: {
        Theme.systemSans = window.font.family;
        if (bridge) window.sidebarUserWidth = bridge.sidebarWidth;
        window.pushPalettes();
        if (bridge && !bridge.onboarded) onboarding.open();
    }

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
        function onChanged() {
            if (bridge && !bridge.onboarded && !onboarding.opened && window.previewOverlay === "")
                onboarding.open();
        }
        function onToast(text) { toast.show(text); }
        function onFocusComposer() { composer.focusInput(); }
        function onScrollToEnd() { taskView.jumpToEnd(); }
        function onQuickBarRequested() { window.openQuickBar(); }
    }

    // -------------------------------------------------------- shortcuts
    Shortcut { sequences: ["Ctrl+N"]; onActivated: if (bridge) bridge.newTask() }
    Shortcut { sequences: ["Ctrl+,"]; onActivated: settings.show(settings.generalPage) }
    Shortcut { sequences: ["Ctrl+K"]; onActivated: window.focusSearch() }
    Shortcut { sequences: ["Ctrl+M"]; onActivated: models.open() }
    Shortcut { sequences: ["Ctrl+B"]; onActivated: window.toggleSidebar() }
    Shortcut { sequences: ["Ctrl+Shift+P"]; onActivated: palette.open() }
    Shortcut { sequences: ["Ctrl+Space"]; onActivated: window.openQuickBar() }
    Shortcut { sequences: ["Ctrl+Shift+S"]; onActivated: if (bridge) bridge.stop() }
    Shortcut { sequences: ["Ctrl+R"]; onActivated: if (bridge) bridge.regenerate() }
    Shortcut { sequences: ["Ctrl+D"]; onActivated: if (bridge) bridge.duplicateTask() }
    Shortcut { sequences: ["Ctrl+Shift+V"]; onActivated: if (bridge) bridge.pasteImage() }
    Shortcut { sequences: ["Alt+Up"]; onActivated: if (bridge) bridge.openAdjacentTask(-1) }
    Shortcut { sequences: ["Alt+Down"]; onActivated: if (bridge) bridge.openAdjacentTask(1) }
    Shortcut {
        sequences: ["Escape"]
        onActivated: {
            if (bridge && bridge.permissionPending) bridge.resolvePermission(false);
            else if (bridge && bridge.busy) bridge.stop();
        }
    }

    // ---------------------------------------------------------- the shell
    RowLayout {
        anchors.fill: parent
        spacing: 0

        WorkspaceSidebar {
            id: sidebar
            Layout.preferredWidth: window.sidebarWidth
            Layout.fillHeight: true
            visible: window.sidebarDocked
            collapsed: window.sidebarCollapsed
            onCollapseRequested: function(value) { if (bridge) bridge.setSidebarCollapsed(value); }
            onNewTask: if (bridge) bridge.newTask()
            onOpenSettings: settings.show(settings.generalPage)
            onRenameRequested: function(id, title) { renameSheet.ask(id, title); }
            onDeleteRequested: function(id, title) { deleteSheet.ask(id, title); }
            Behavior on Layout.preferredWidth {
                enabled: !Theme.reducedMotion && !resizer.dragging
                NumberAnimation { duration: Theme.base; easing.type: Theme.easing }
            }
        }

        Item {
            id: resizer
            property bool dragging: drag.active
            visible: window.sidebarDocked && !window.sidebarCollapsed
            Layout.preferredWidth: visible ? 5 : 0
            Layout.fillHeight: true
            z: 2
            Rectangle {
                anchors.centerIn: parent
                width: 1; height: parent.height
                color: resizer.dragging || hover.hovered ? Theme.borderStrong : "transparent"
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
            }
            HoverHandler { id: hover; cursorShape: Qt.SizeHorCursor }
            DragHandler {
                id: drag
                target: null
                yAxis.enabled: false
                cursorShape: Qt.SizeHorCursor
                property real startWidth: 0
                onActiveChanged: {
                    if (active) startWidth = window.sidebarUserWidth;
                    else if (bridge) bridge.setSidebarWidth(window.sidebarUserWidth);
                }
                onTranslationChanged: if (active)
                    window.sidebarUserWidth = Math.max(200, Math.min(400, startWidth + translation.x))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TaskHeader {
                Layout.fillWidth: true
                sidebarCollapsed: !window.sidebarDocked || window.sidebarCollapsed
                drawerOpen: sidebarDrawer.opened
                onToggleSidebar: window.toggleSidebar()
                onRenameRequested: if (bridge && bridge.taskId) renameSheet.ask(bridge.taskId, bridge.taskTitle)
                onOpenSettings: settings.show(settings.generalPage)
                onOpenAgentSettings: settings.show(settings.agentPage)
                onOpenCommandPalette: palette.open()
                onOpenShortcuts: shortcuts.open()
                onClearRequested: clearSheet.open()
                onModeRequested: function(mode) {
                    if (!bridge || bridge.connecting) return;
                    var wantsWork = mode === "work";
                    if (wantsWork !== bridge.desktopEnabled) bridge.toggleDesktop();
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.gutter
                Layout.rightMargin: Theme.gutter
                Layout.bottomMargin: Theme.s4
                spacing: window.homeMode ? Theme.s2 : Theme.s3

                // Equal flexible space above and below keeps the empty-state
                // prompt/composer cluster optically centered like ChatGPT's
                // desktop home screen.
                Item { Layout.fillHeight: true; visible: window.homeMode }

                TaskView {
                    id: taskView
                    objectName: "conversationViewport"
                    Layout.fillWidth: true
                    Layout.fillHeight: bridge && bridge.hasMessages
                    Layout.preferredHeight: window.homeMode ? 64 : -1
                    onLinkClicked: function(link) { linkSheet.ask(link); }
                    onStarterChosen: function(prompt) { composer.insert(prompt); }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Theme.readingWidth
                    Layout.alignment: Qt.AlignHCenter
                    visible: bridge && bridge.capabilityWarning.length > 0
                    Layout.preferredHeight: visible ? warningText.implicitHeight + Theme.s3 * 2 : 0
                    radius: Theme.r2
                    color: Theme.warningMuted
                    border.width: 1
                    border.color: Theme.alpha(Theme.warning, 0.3)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: bridge ? bridge.capabilityWarning : ""
                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.s3
                        spacing: Theme.s3
                        Icon { name: "info"; ink: Theme.warning; width: 14; height: 14 }
                        Text {
                            id: warningText
                            width: parent.width - 14 - Theme.s3
                            text: bridge ? bridge.capabilityWarning : ""
                            color: Theme.textSecondary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap; lineHeight: 1.45
                        }
                    }
                }

                ErrorBanner {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Theme.readingWidth
                    Layout.alignment: Qt.AlignHCenter
                    onActionInvoked: function(action) { window.runCommand(action); }
                }

                Composer {
                    id: composer
                    objectName: "mainComposer"
                    Layout.fillWidth: true
                    Layout.maximumWidth: Theme.readingWidth
                    Layout.alignment: Qt.AlignHCenter
                    onSubmitted: function(text) { if (bridge) bridge.send(text); }
                    onOpenModelManager: models.open()
                }

                // Home suggestions were deliberately removed. The first screen
                // now asks for one thing only: the user's instruction.
                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Theme.readingWidth
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    visible: bridge && bridge.hasMessages
                    text: bridge && bridge.projectPath ? "Working in " + bridge.projectName
                          : "Local AI · Commands, apps, and everyday questions"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    elide: Text.ElideMiddle
                }

                Item { Layout.fillHeight: true; visible: window.homeMode }
            }
        }
    }

    // --------------------------------------------------------- the drawer
    Drawer {
        id: sidebarDrawer
        edge: Qt.LeftEdge
        width: Math.min(300, window.width - 48)
        height: window.height
        dragMargin: 0
        background: Rectangle { color: Theme.backgroundSoft }
        property bool focusSearchWhenOpen: false
        onOpened: if (focusSearchWhenOpen) { focusSearchWhenOpen = false; drawerSidebar.focusSearch(); }
        onClosed: focusSearchWhenOpen = false
        WorkspaceSidebar {
            id: drawerSidebar
            anchors.fill: parent
            onNewTask: { if (bridge) bridge.newTask(); sidebarDrawer.close(); }
            onOpenSettings: { sidebarDrawer.close(); settings.show(settings.generalPage); }
            onRenameRequested: function(id, title) { sidebarDrawer.close(); renameSheet.ask(id, title); }
            onDeleteRequested: function(id, title) { sidebarDrawer.close(); deleteSheet.ask(id, title); }
            onCollapseRequested: sidebarDrawer.close()
        }
    }

    // --------------------------------------------------------- overlays
    ModelManager { id: models }
    SettingsSheet { id: settings; onOpenModelManager: models.open() }
    ShortcutsSheet { id: shortcuts }
    CommandPalette { id: palette; onInvoked: function(action) { window.runCommand(action); } }
    PermissionPrompt { id: permission }
    Onboarding { id: onboarding; onOpenModelManager: models.open() }
    Toast { id: toast }
    RegionSelector { id: regionSelector }

    ConfirmSheet {
        id: renameSheet
        title: "Rename task"
        withInput: true
        confirmText: "Save"
        property string targetId: ""
        function ask(id, title) { targetId = id; inputText = title; show(); }
        onConfirmed: if (bridge) bridge.renameTaskById(targetId, inputText)
    }

    ConfirmSheet {
        id: deleteSheet
        title: "Delete this task?"
        confirmText: "Delete"
        confirmVariant: "danger"
        property string targetId: ""
        function ask(id, title) {
            targetId = id;
            message = "“" + title + "” and its messages will be removed from this computer.";
            show();
        }
        onConfirmed: if (bridge) bridge.deleteTask(targetId)
    }

    ConfirmSheet {
        id: clearSheet
        title: "Clear this task?"
        message: "The task stays in your list, but every message is removed from local history."
        confirmText: "Clear"
        confirmVariant: "danger"
        onConfirmed: if (bridge) bridge.clearTask()
    }

    ConfirmSheet {
        id: linkSheet
        title: "Open this link?"
        message: "This opens in your default browser, outside Wynxo."
        confirmText: "Open"
        property string link: ""
        function ask(url) { link = url; detail = url; show(); }
        onConfirmed: Qt.openUrlExternally(link)
    }

    // -------------------------------------------------------- quick bar
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

    // Preview hook: --snapshot drives the real UI into a named state so README
    // screenshots come from this renderer, not from a mock-up.
    property string previewOverlay: ""
    function closeOverlays() {
        settings.close(); models.close(); palette.close(); shortcuts.close();
        onboarding.close(); quickBar.close();
        renameSheet.close(); deleteSheet.close(); clearSheet.close(); linkSheet.close();
    }
    onPreviewOverlayChanged: {
        closeOverlays();
        if (previewOverlay === "welcome") onboarding.open();
        else if (previewOverlay === "settings") settings.show(settings.generalPage);
        else if (previewOverlay === "modelSettings") settings.show(settings.modelPage);
        else if (previewOverlay === "agentSettings") settings.show(settings.agentPage);
        else if (previewOverlay === "appearanceSettings") settings.show(settings.appearancePage);
        else if (previewOverlay === "advancedSettings") settings.show(settings.advancedPage);
        else if (previewOverlay === "models") models.open();
        else if (previewOverlay === "modelPicker") composer.showModelPicker();
        else if (previewOverlay === "palette") palette.open();
        else if (previewOverlay === "shortcuts") shortcuts.open();
        else if (previewOverlay === "rename" && bridge) renameSheet.ask(bridge.taskId, bridge.taskTitle);
        else if (previewOverlay === "quickbar") window.openQuickBar();
    }

    // ---------------------------------------------------------- commands
    function toggleSidebar() {
        if (!window.sidebarDocked) {
            if (sidebarDrawer.opened) sidebarDrawer.close();
            else sidebarDrawer.open();
            return;
        }
        if (bridge) bridge.setSidebarCollapsed(!bridge.sidebarCollapsed);
    }

    function focusSearch() {
        if (!window.sidebarDocked) {
            if (sidebarDrawer.opened) drawerSidebar.focusSearch();
            else { sidebarDrawer.focusSearchWhenOpen = true; sidebarDrawer.open(); }
            return;
        }
        if (bridge) bridge.setSidebarCollapsed(false);
        sidebar.focusSearch();
    }

    function runCommand(action) {
        if (!bridge) return;
        switch (action) {
        case "new": bridge.newTask(); break;
        case "search": window.focusSearch(); break;
        case "models": models.open(); break;
        case "settings": settings.show(settings.generalPage); break;
        case "shortcuts": shortcuts.open(); break;
        case "sidebar": window.toggleSidebar(); break;
        case "quickbar": window.openQuickBar(); break;
        case "screenshot": bridge.attachScreenshot(); break;
        case "window": bridge.attachWindow(); break;
        case "region": bridge.attachRegion(); break;
        case "file": bridge.attachFile(); break;
        case "folder": bridge.attachFolder(); break;
        case "clipboard": bridge.attachClipboard(); break;
        case "project": bridge.chooseProject(); break;
        case "reveal": bridge.revealPath(bridge.projectPath); break;
        case "copypath": bridge.copyProjectPath(); break;
        case "terminal": bridge.openTerminalHere(); break;
        case "desktop": bridge.toggleDesktop(); break;
        case "permission": settings.show(settings.agentPage); break;
        case "runtime": settings.show(settings.modelPage); break;
        case "regenerate": bridge.regenerate(); break;
        case "stop": bridge.stop(); break;
        case "export": bridge.exportTask(); break;
        case "duplicate": bridge.duplicateTask(); break;
        case "pin": if (bridge.taskId) bridge.togglePin(bridge.taskId); break;
        case "clear": if (bridge.taskId) clearSheet.open(); break;
        case "reconnect": case "retry": bridge.refreshModels(); break;
        case "previous": bridge.openAdjacentTask(-1); break;
        case "next": bridge.openAdjacentTask(1); break;
        }
    }
}
