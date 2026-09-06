import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The right-hand workspace: the tools, beside the conversation.

    The rail is always there; the panel opens beside it. Only the visible panel
    is instantiated, and each one keeps its state once it has been opened, so
    switching tabs is instant and a terminal does not restart because you
    looked at the files.

    Files and the file viewer share the column: the tree above, the open file
    below, because opening a file from a tree that then disappears is a worse
    tree.

    Plan is the agent-authored execution outline for genuine multi-step work.
    It can reveal itself once when the agent publishes a plan, but after the
    user chooses any workspace surface for this task the dock never moves itself
    again. That preference resets when the conversation changes.
*/
Item {
    id: root
    property bool panelOpen: false
    property int panelWidth: 380
    property bool planSelected: false
    property bool userSelectedWorkspaceTab: false
    property string observedTaskId: bridge ? bridge.taskId : ""
    readonly property alias resizing: resizer.dragging
    signal widthChangeRequested(int value)

    readonly property var dock: bridge ? bridge.workspaceDock : null
    readonly property string tab: dock ? dock.tab : "files"

    implicitWidth: Theme.railWidth + (panelOpen ? panelWidth + 5 : 0)

    function focusPanel() {
        if (planSelected) return;
        if (tab === "browser" && browserLoader.item) browserLoader.item.focusAddress();
        else if (tab === "terminal" && terminalLoader.item) terminalLoader.item.focusInput();
        else if (tab === "files" && filesLoader.item) filesLoader.item.focusFilter();
    }

    function openFile(path) {
        if (!dock || !path) return;
        planSelected = false;
        dock.openFile(path);
        dock.revealFile(path);
    }

    function pickWorkspaceTab(id) {
        userSelectedWorkspaceTab = true;
        if (!dock) return;
        if (planSelected) {
            // openTab would close the dock when id is already the backend tab.
            // Leaving Plan therefore sets the tab directly and keeps the dock up.
            planSelected = false;
            dock.setTab(id);
            if (!dock.visible) dock.setVisible(true);
            return;
        }
        dock.openTab(id);
    }

    function pickPlan() {
        userSelectedWorkspaceTab = true;
        if (!dock) return;
        if (planSelected && dock.visible) {
            dock.setVisible(false);
            return;
        }
        planSelected = true;
        // A deliberate Plan click counts as choosing the workspace. Pin the
        // underlying backend tab too so later suggestions cannot steal it.
        dock.setTab(dock.tab);
        if (!dock.visible) dock.setVisible(true);
    }

    Connections {
        target: bridge

        function onChanged() {
            if (!bridge) return;
            var taskId = bridge.taskId || "";
            if (taskId !== root.observedTaskId) {
                root.observedTaskId = taskId;
                root.userSelectedWorkspaceTab = false;
                root.planSelected = false;
            }
        }

        function onPlanChanged() {
            if (!bridge || !root.dock || root.userSelectedWorkspaceTab)
                return;
            var steps = bridge.planSteps || [];
            // update_plan requires at least two steps. Publishing one therefore
            // means the agent has explicitly decided this is multi-step work.
            // Every WorkspaceDock instance selects Plan locally; the backend
            // visibility flag is shared by the desktop dock and compact drawer,
            // so using it as a selection guard could leave the visible instance
            // stuck on Files when the hidden instance handled the signal first.
            if (steps.length >= 2) {
                root.planSelected = true;
                if (!root.dock.visible) root.dock.setVisible(true);
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------- the handle
        Item {
            id: resizer
            property bool dragging: drag.active
            visible: root.panelOpen
            Layout.preferredWidth: visible ? 5 : 0
            Layout.fillHeight: true
            z: 3

            Rectangle {
                anchors.centerIn: parent
                width: 1; height: parent.height
                color: resizer.dragging || edge.hovered ? Theme.borderStrong : Theme.borderSubtle
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
            }
            HoverHandler { id: edge; cursorShape: Qt.SizeHorCursor }
            DragHandler {
                id: drag
                target: null
                yAxis.enabled: false
                cursorShape: Qt.SizeHorCursor
                property real startWidth: 0
                onActiveChanged: {
                    if (active) startWidth = root.panelWidth;
                    else if (root.dock) root.dock.setWidth(root.panelWidth);
                }
                onTranslationChanged: {
                    if (!active || !root.dock) return;
                    root.widthChangeRequested(Math.max(root.dock.minimumWidth,
                        Math.min(root.dock.maximumWidth, startWidth - translation.x)));
                }
            }
        }

        // -------------------------------------------------------- the panel
        Item {
            id: panel
            Layout.preferredWidth: root.panelOpen ? root.panelWidth : 0
            Layout.fillHeight: true
            visible: root.panelOpen
            clip: true

            Rectangle { anchors.fill: parent; color: Theme.background }

            Loader {
                id: planLoader
                anchors.fill: parent
                visible: root.planSelected
                active: visible
                sourceComponent: PlanPanel {}
            }

            // Files keeps the tree and the open file in one column.
            SplitView {
                id: filesSplit
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "files"
                orientation: Qt.Vertical
                handle: Rectangle {
                    implicitHeight: 5
                    color: "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: 1
                        color: SplitHandle.pressed || SplitHandle.hovered
                               ? Theme.borderStrong : Theme.borderSubtle
                    }
                }

                Loader {
                    id: filesLoader
                    SplitView.preferredHeight: Math.round(root.height * 0.42)
                    SplitView.minimumHeight: 120
                    active: !root.planSelected && root.tab === "files"
                    sourceComponent: FileExplorer {
                        onOpenRequested: function(path) { root.openFile(path); }
                    }
                }
                Loader {
                    id: viewerLoader
                    SplitView.fillHeight: true
                    SplitView.minimumHeight: 120
                    active: !root.planSelected && root.tab === "files"
                    sourceComponent: FileViewer {
                        onClosed: if (root.dock) root.dock.closeFile()
                    }
                }
            }

            Loader {
                id: terminalLoader
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "terminal"
                // Kept alive once opened: a shell that restarts because you
                // looked at the diff is not a shell.
                active: visible || item !== null
                sourceComponent: TerminalPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "changes"
                active: visible
                sourceComponent: ChangesPanel {
                    onOpenRequested: function(path) {
                        if (!path || !root.dock) return;
                        root.planSelected = false;
                        root.dock.setTab("files");
                        root.openFile(path);
                    }
                    onRevertRequested: function(path, name) { revertSheet.ask(path, name); }
                }
            }

            Loader {
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "context"
                active: visible
                sourceComponent: ContextPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "activity"
                active: visible
                sourceComponent: ActivityPanel {}
            }

            Loader {
                id: browserLoader
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "browser"
                // A loaded page should survive a look at the terminal.
                active: visible || item !== null
                sourceComponent: BrowserPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: !root.planSelected && root.tab === "preview"
                active: visible
                sourceComponent: PreviewPanel {}
            }
        }

        // --------------------------------------------------------- the rail
        DockTabBar {
            Layout.preferredWidth: Theme.railWidth
            Layout.fillHeight: true
            current: root.tab
            panelOpen: root.panelOpen
            planSelected: root.planSelected
            onPicked: function(id) { root.pickWorkspaceTab(id); }
            onPickedPlan: root.pickPlan()
            onToggleDock: {
                root.userSelectedWorkspaceTab = true;
                if (root.dock) root.dock.toggle();
            }
        }
    }

    ConfirmSheet {
        id: revertSheet
        title: "Discard these changes?"
        confirmText: "Discard"
        confirmVariant: "danger"
        property string targetPath: ""
        function ask(path, name) {
            targetPath = path;
            message = "Every uncommitted change in “" + name + "” will be thrown away. This cannot be undone.";
            detail = path;
            show();
        }
        onConfirmed: if (root.dock) root.dock.revertChange(targetPath)
    }
}
