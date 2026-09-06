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
*/
Item {
    id: root
    property bool panelOpen: false
    property int panelWidth: 380
    readonly property alias resizing: resizer.dragging
    signal widthChangeRequested(int value)

    readonly property var dock: bridge ? bridge.workspaceDock : null
    readonly property string tab: dock ? dock.tab : "files"

    implicitWidth: Theme.railWidth + (panelOpen ? panelWidth + 5 : 0)

    function focusPanel() {
        if (tab === "browser" && browserLoader.item) browserLoader.item.focusAddress();
        else if (tab === "terminal" && terminalLoader.item) terminalLoader.item.focusInput();
        else if (tab === "files" && filesLoader.item) filesLoader.item.focusFilter();
    }

    function openFile(path) {
        if (!dock || !path) return;
        dock.openFile(path);
        dock.revealFile(path);
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

            // Files keeps the tree and the open file in one column.
            SplitView {
                id: filesSplit
                anchors.fill: parent
                visible: root.tab === "files"
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
                    active: root.tab === "files"
                    sourceComponent: FileExplorer {
                        onOpenRequested: function(path) { root.openFile(path); }
                    }
                }
                Loader {
                    id: viewerLoader
                    SplitView.fillHeight: true
                    SplitView.minimumHeight: 120
                    active: root.tab === "files"
                    sourceComponent: FileViewer {
                        onClosed: if (root.dock) root.dock.closeFile()
                    }
                }
            }

            Loader {
                id: terminalLoader
                anchors.fill: parent
                visible: root.tab === "terminal"
                // Kept alive once opened: a shell that restarts because you
                // looked at the diff is not a shell.
                active: visible || item !== null
                sourceComponent: TerminalPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: root.tab === "changes"
                active: visible
                sourceComponent: ChangesPanel {
                    onOpenRequested: function(path) {
                        if (!path || !root.dock) return;
                        root.dock.setTab("files");
                        root.openFile(path);
                    }
                    onRevertRequested: function(path, name) { revertSheet.ask(path, name); }
                }
            }

            Loader {
                anchors.fill: parent
                visible: root.tab === "context"
                active: visible
                sourceComponent: ContextPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: root.tab === "activity"
                active: visible
                sourceComponent: ActivityPanel {}
            }

            Loader {
                id: browserLoader
                anchors.fill: parent
                visible: root.tab === "browser"
                // A loaded page should survive a look at the terminal.
                active: visible || item !== null
                sourceComponent: BrowserPanel {}
            }

            Loader {
                anchors.fill: parent
                visible: root.tab === "preview"
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
            onPicked: function(id) { if (root.dock) root.dock.openTab(id); }
            onToggleDock: if (root.dock) root.dock.toggle()
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
