import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The project tree.

    One flat, virtualised list; the backend splices children in when a folder
    opens. Indentation and one small mark per kind carry the structure — no
    guide lines, no coloured badges, no second icon family. A file Git reports
    as changed gets a single dot, which is the only decoration in here.
*/
Item {
    id: root
    signal openRequested(string path)
    signal revealRequested(string path)

    readonly property var dock: bridge ? bridge.workspaceDock : null
    readonly property bool searching: dock && dock.fileFilter.trim().length >= 2

    function focusFilter() { filter.forceActiveFocus(); filter.selectAll(); }

    Connections {
        target: root.dock
        function onRevealRow(row) { tree.positionViewAtIndex(row, ListView.Contain); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            title: "Files"
            detail: root.dock ? root.dock.projectName : ""
            detailFont: "mono"

            IconButton {
                width: 28; height: 28; iconSize: 12
                iconName: root.dock && root.dock.showHidden ? "eye" : "hidden"
                tooltip: root.dock && root.dock.showHidden ? "Hide dotfiles" : "Show dotfiles"
                active: !!(root.dock && root.dock.showHidden)
                onClicked: if (root.dock) root.dock.setShowHidden(!root.dock.showHidden)
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                iconName: "retry"
                tooltip: "Refresh"
                onClicked: if (root.dock) root.dock.refreshFiles()
            }
        }

        // --------------------------------------------------------- filter
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.control + Theme.s2 * 2
            visible: !!(root.dock && root.dock.projectPath)

            Field {
                id: filter
                objectName: "fileFilter"
                anchors.fill: parent
                anchors.margins: Theme.s2
                iconName: "search"
                placeholderText: "Find a file"
                font.pixelSize: Theme.caption
                onTextChanged: if (root.dock) root.dock.setFileFilter(text)
                Keys.onEscapePressed: function(event) {
                    if (text.length) { text = ""; event.accepted = true; }
                    else event.accepted = false;
                }
                Keys.onReturnPressed: {
                    if (matches.count > 0 && root.dock)
                        root.openRequested(root.dock.fileMatches[0].path);
                }
            }
        }

        // ------------------------------------------------------ the tree
        ListView {
            id: tree
            objectName: "fileTree"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.searching && !!(root.dock && root.dock.projectPath)
            clip: true
            model: root.dock ? root.dock.fileModel : null
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            cacheBuffer: 600
            topMargin: Theme.s1
            bottomMargin: Theme.s3
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
            }

            delegate: AbstractButton {
                id: node
                required property string name
                required property string path
                required property int depth
                required property bool isDir
                required property bool expanded
                required property string kind
                required property string sizeLabel
                required property bool selected
                required property bool dirty

                width: tree.width
                height: Theme.denseRow
                hoverEnabled: true
                Accessible.role: Accessible.ListItem
                Accessible.name: name + (isDir ? ", folder" : "") + (dirty ? ", changed" : "")
                Accessible.selected: selected

                onClicked: {
                    if (!root.dock) return;
                    if (node.isDir) root.dock.toggleFolder(node.path);
                    else root.openRequested(node.path);
                }

                background: Rectangle {
                    color: node.selected ? Theme.surfaceSelected
                         : node.hovered || nodeMenu.opened ? Theme.surfaceHover : "transparent"
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: node.selected ? parent.height - 8 : 0
                        color: Theme.accent
                    }
                }

                contentItem: Item {
                    Row {
                        id: nodeRow
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.s2 + node.depth * 12
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.s2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.s1

                        Icon {
                            visible: node.isDir
                            width: 11; height: 11
                            anchors.verticalCenter: parent.verticalCenter
                            name: node.expanded ? "chevronDown" : "chevronRight"
                            ink: Theme.textMuted
                            weight: 2.0
                        }
                        Item { visible: !node.isDir; width: 11; height: 11 }

                        Icon {
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            name: node.isDir ? (node.expanded ? "folderOpen" : "folder")
                                             : Theme.kindIcon(node.kind)
                            ink: node.isDir ? Theme.textSecondary
                               : node.selected ? Theme.textPrimary : Theme.textMuted
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth,
                                            nodeRow.width - 11 - 13 - Theme.s1 * 2 - (node.dirty ? 14 : 0))
                            text: node.name
                            color: node.selected ? Theme.textPrimary
                                 : node.isDir ? Theme.textSecondary : Theme.textSecondary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.caption
                            font.weight: node.selected ? Font.Medium : Font.Normal
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            visible: node.dirty
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5; height: 5; radius: 2.5
                            color: Theme.accent
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nodeMenu.open()
                }

                WMenu {
                    id: nodeMenu
                    menuWidth: 214
                    items: [
                        { id: "open", label: node.isDir ? "Expand" : "Open", icon: node.isDir ? "folderOpen" : "file" },
                        { id: "copy", label: "Copy path", icon: "copy" },
                        { id: "reveal", label: "Reveal in file manager", icon: "launch" },
                        { separator: true, hidden: !node.isDir },
                        { id: "terminal", label: "Open terminal here", icon: "terminal", hidden: !node.isDir },
                        { separator: true, hidden: node.isDir },
                        { id: "attach", label: "Attach to the conversation", icon: "paperclip", hidden: node.isDir },
                    ]
                    onPicked: function(id) {
                        if (!bridge) return;
                        if (id === "open") node.clicked();
                        else if (id === "copy") bridge.copyText(node.path);
                        else if (id === "reveal") bridge.revealPath(node.path);
                        else if (id === "terminal" && root.dock) root.dock.runInTerminal("cd " + JSON.stringify(node.path));
                        else if (id === "attach") bridge.attachPath(node.path);
                    }
                }
            }
        }

        // ------------------------------------------------------- matches
        ListView {
            id: matches
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.searching
            clip: true
            model: root.dock ? root.dock.fileMatches : []
            boundsBehavior: Flickable.StopAtBounds
            topMargin: Theme.s1
            bottomMargin: Theme.s3
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
            }

            delegate: AbstractButton {
                id: match
                required property var modelData
                width: matches.width
                height: Theme.rowHeight
                hoverEnabled: true
                Accessible.name: modelData.relative
                onClicked: root.openRequested(modelData.path)

                background: Rectangle {
                    color: match.hovered ? Theme.surfaceHover : "transparent"
                }
                contentItem: RowLayout {
                    anchors.leftMargin: Theme.s3
                    spacing: Theme.s2
                    Icon {
                        Layout.leftMargin: Theme.s3
                        Layout.preferredWidth: 13; Layout.preferredHeight: 13
                        name: Theme.kindIcon(match.modelData.kind)
                        ink: Theme.textMuted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: match.modelData.name
                            color: Theme.textSecondary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: match.modelData.relative
                            color: Theme.textMuted
                            font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                            elide: Text.ElideLeft
                        }
                    }
                    Item { Layout.preferredWidth: Theme.s2 }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }

            EmptyState {
                anchors.fill: parent
                visible: matches.count === 0
                iconName: "search"
                title: "No files match"
                detail: "Try part of a file name."
            }
        }

        // -------------------------------------------------------- no project
        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !(root.dock && root.dock.projectPath)
            iconName: "folder"
            title: "No project open"
            detail: "Choose a folder and Wynxo works inside it — files, terminal, changes."
            actionText: "Open project…"
            onActionInvoked: if (bridge) bridge.chooseProject()
        }
    }
}
