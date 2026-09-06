import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Product navigation, project context and task history.

    Wynxo and Wynxi are separate workspaces, not tabs inside a web-style
    segmented control. The sidebar keeps that distinction obvious while staying
    compact enough to feel like a native coding tool.
*/
Item {
    id: root
    property bool collapsed: false
    signal newTask()
    signal newModeTask(string mode)
    signal openSettings()
    signal renameRequested(string id, string title)
    signal deleteRequested(string id, string title)
    signal collapseRequested(bool value)

    readonly property bool inWynxi: bridge && bridge.taskMode === "codex"
    function focusSearch() { search.forceActiveFocus(); search.selectAll(); }

    Rectangle { anchors.fill: parent; color: Theme.backgroundSoft }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderSubtle }

    // ------------------------------------------------------------ expanded
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s2
        anchors.topMargin: Theme.s3
        anchors.bottomMargin: Theme.s2
        spacing: Theme.s2
        visible: !root.collapsed

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
            Layout.rightMargin: Theme.s1
            spacing: Theme.s2

            Mark { Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Text {
                Layout.fillWidth: true
                text: "Wynxo"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.heading
                font.weight: Font.DemiBold
            }
            IconButton {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                objectName: "sidebarCollapseButton"
                iconName: "panelLeft"; iconSize: 13
                tooltip: "Collapse sidebar"; shortcut: "Ctrl+B"
                onClicked: root.collapseRequested(true)
            }
        }

        // Product switch. Two quiet rows read much more like Codex/desktop
        // navigation than a large pill control.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            AbstractButton {
                id: wynxoButton
                Layout.fillWidth: true
                implicitHeight: 40
                hoverEnabled: true
                readonly property bool chosen: !root.inWynxi
                Accessible.name: "Wynxo. Chat and Work"
                Accessible.checked: chosen
                onClicked: if (!chosen) root.newModeTask("chat")
                background: Rectangle {
                    radius: Theme.r2
                    color: wynxoButton.chosen ? Theme.surfaceSelected
                         : wynxoButton.hovered ? Theme.surfaceHover : "transparent"
                    border.width: wynxoButton.visualFocus ? 1 : 0
                    border.color: Theme.accentEdge
                }
                contentItem: RowLayout {
                    spacing: Theme.s3
                    Icon {
                        Layout.leftMargin: Theme.s2
                        Layout.preferredWidth: 15; Layout.preferredHeight: 15
                        name: "chat"
                        ink: wynxoButton.chosen ? Theme.textPrimary : Theme.textMuted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Wynxo"
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.label
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "Chat & Work"
                            color: Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.micro
                        }
                    }
                    Icon {
                        Layout.rightMargin: Theme.s2
                        Layout.preferredWidth: 10; Layout.preferredHeight: 10
                        visible: wynxoButton.chosen
                        name: "check"
                        ink: Theme.textMuted
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }

            AbstractButton {
                id: wynxiButton
                Layout.fillWidth: true
                implicitHeight: 40
                hoverEnabled: true
                readonly property bool chosen: root.inWynxi
                Accessible.name: "Wynxi. Coding workspace"
                Accessible.checked: chosen
                onClicked: if (!chosen) root.newModeTask("codex")
                background: Rectangle {
                    radius: Theme.r2
                    color: wynxiButton.chosen ? Theme.surfaceSelected
                         : wynxiButton.hovered ? Theme.surfaceHover : "transparent"
                    border.width: wynxiButton.visualFocus ? 1 : 0
                    border.color: Theme.accentEdge
                }
                contentItem: RowLayout {
                    spacing: Theme.s3
                    Icon {
                        Layout.leftMargin: Theme.s2
                        Layout.preferredWidth: 15; Layout.preferredHeight: 15
                        name: "code"
                        ink: wynxiButton.chosen ? Theme.accent : Theme.textMuted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Wynxi"
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.label
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "Code"
                            color: Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.micro
                        }
                    }
                    Icon {
                        Layout.rightMargin: Theme.s2
                        Layout.preferredWidth: 10; Layout.preferredHeight: 10
                        visible: wynxiButton.chosen
                        name: "check"
                        ink: Theme.textMuted
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }
        }

        Divider { Layout.fillWidth: true; Layout.topMargin: Theme.s1; Layout.bottomMargin: Theme.s1 }

        WButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            text: root.inWynxi ? "New coding task" : "New task"
            iconName: "plus"
            variant: "secondary"
            onClicked: root.inWynxi ? root.newModeTask("codex") : root.newTask()
            ToolTip.visible: hovered
            ToolTip.text: "Ctrl+N"
        }

        Field {
            id: search
            Layout.fillWidth: true
            iconName: "search"
            placeholderText: "Search"
            font.pixelSize: Theme.caption
            Component.onCompleted: text = bridge ? bridge.searchQuery : ""
            onTextChanged: if (bridge) bridge.setSearch(text)
            Keys.onEscapePressed: function(event) {
                if (text.length) { text = ""; event.accepted = true; }
                else event.accepted = false;
            }
        }

        SectionLabel {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
            Layout.topMargin: Theme.s1
            text: "Project"
        }

        AbstractButton {
            id: projectButton
            Layout.fillWidth: true
            implicitHeight: 44
            hoverEnabled: true
            Accessible.name: bridge && bridge.projectName
                ? "Project " + bridge.projectName + ". Change project"
                : "Choose a project folder"
            onClicked: projectMenu.opened ? projectMenu.close() : projectMenu.open()

            background: Rectangle {
                radius: Theme.r2
                color: projectButton.hovered || projectMenu.opened ? Theme.surfaceHover : "transparent"
                border.width: projectButton.visualFocus ? 1 : 0
                border.color: Theme.accentEdge
            }

            contentItem: RowLayout {
                spacing: Theme.s2
                Icon {
                    Layout.leftMargin: Theme.s2
                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                    name: bridge && bridge.projectPath ? "folderOpen" : "folder"
                    ink: bridge && bridge.projectPath ? Theme.textSecondary : Theme.textMuted
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.projectName ? bridge.projectName : "Open project"
                        color: bridge && bridge.projectPath ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.label
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.projectPath ? bridge.projectParentLabel : "Choose a folder"
                        color: Theme.textMuted
                        font.family: bridge && bridge.projectPath ? Theme.monoFamily : Theme.sansFamily
                        font.pixelSize: Theme.micro
                        elide: Text.ElideLeft
                    }
                }
                Icon {
                    Layout.rightMargin: Theme.s2
                    Layout.preferredWidth: 10; Layout.preferredHeight: 10
                    name: "chevron"
                    ink: Theme.textMuted
                }
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }

            WMenu {
                id: projectMenu
                menuWidth: Math.max(240, projectButton.width)
                property var recents: bridge ? bridge.recentProjects : []
                onAboutToShow: recents = bridge ? bridge.recentProjects : []
                items: {
                    var list = [{ id: "choose", label: "Open folder…", icon: "folder" }];
                    if (recents.length) {
                        list.push({ separator: true });
                        for (var i = 0; i < Math.min(recents.length, 5); i++)
                            list.push({ id: "recent:" + recents[i].path,
                                        label: recents[i].name, icon: "clock" });
                    }
                    var has = !!(bridge && bridge.projectPath);
                    list.push({ separator: true, hidden: !has });
                    list.push({ id: "reveal", label: "Reveal in file manager", icon: "launch", hidden: !has });
                    list.push({ id: "terminal", label: "Open terminal here", icon: "terminal", hidden: !has });
                    list.push({ id: "copy", label: "Copy path", icon: "copy", hidden: !has });
                    list.push({ id: "clear", label: "Close project", icon: "close", hidden: !has });
                    return list;
                }
                onPicked: function(id) {
                    if (!bridge) return;
                    if (id === "choose") bridge.chooseProject();
                    else if (id === "reveal") bridge.revealPath(bridge.projectPath);
                    else if (id === "terminal") bridge.openTerminalHere();
                    else if (id === "copy") bridge.copyProjectPath();
                    else if (id === "clear") bridge.clearProject();
                    else if (id.indexOf("recent:") === 0) bridge.openProject(id.substring(7));
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
            Layout.rightMargin: Theme.s1
            Layout.topMargin: Theme.s1
            SectionLabel { text: "Threads" }
            Item { Layout.fillWidth: true }
            Text {
                text: bridge && bridge.taskGroups ? String(bridge.taskGroups.reduce(function(total, group) { return total + group.items.length; }, 0)) : ""
                color: Theme.textMuted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.micro
            }
        }

        ListView {
            id: groups
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.s2
            model: bridge ? bridge.taskGroups : []
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderSubtle }
            }

            delegate: Column {
                required property var modelData
                width: groups.width
                spacing: 1

                SectionLabel {
                    width: parent.width
                    text: modelData.title
                    leftPadding: Theme.s2
                    topPadding: Theme.s1
                    bottomPadding: Theme.s1
                }

                Repeater {
                    model: modelData.items
                    delegate: TaskRow {
                        required property var modelData
                        width: groups.width
                        entry: modelData
                        onRenameRequested: root.renameRequested(entry.id, entry.title)
                        onDeleteRequested: root.deleteRequested(entry.id, entry.title)
                    }
                }
            }

            Column {
                anchors.top: parent.top
                anchors.topMargin: Theme.s3
                x: Theme.s2
                width: parent.width - Theme.s4
                spacing: Theme.s2
                visible: groups.count === 0
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery ? "No matching threads" : "No threads yet"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery ? "Try a different search." : "New tasks are saved here automatically."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.35
                }
            }
        }

        Divider { Layout.fillWidth: true }

        AbstractButton {
            id: settingsButton
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            hoverEnabled: true
            Accessible.name: "Settings"
            onClicked: root.openSettings()
            background: Rectangle {
                radius: Theme.r2
                color: settingsButton.hovered ? Theme.surfaceHover : "transparent"
                border.width: settingsButton.visualFocus ? 1 : 0
                border.color: Theme.accentEdge
            }
            contentItem: RowLayout {
                spacing: Theme.s3
                Icon {
                    Layout.leftMargin: Theme.s2
                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                    name: "sliders"; ink: Theme.textMuted
                }
                Text {
                    text: "Settings"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
                Item { Layout.fillWidth: true }
                KeyHint { Layout.rightMargin: Theme.s1; keys: "Ctrl+," }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
        }
    }

    // ---------------------------------------------------------- collapsed
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s2
        anchors.topMargin: Theme.s3
        spacing: Theme.s2
        visible: root.collapsed

        Mark { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
        Item { Layout.preferredHeight: Theme.s1 }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "chat"; tooltip: "Wynxo · Chat & Work"
            active: !root.inWynxi
            onClicked: if (root.inWynxi) root.newModeTask("chat")
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "code"; tooltip: "Wynxi · Code"
            active: root.inWynxi
            onClicked: if (!root.inWynxi) root.newModeTask("codex")
        }

        Divider { Layout.fillWidth: true; Layout.topMargin: Theme.s1; Layout.bottomMargin: Theme.s1 }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "plus"
            tooltip: root.inWynxi ? "New coding task" : "New task"
            shortcut: "Ctrl+N"
            onClicked: root.inWynxi ? root.newModeTask("codex") : root.newTask()
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "search"; tooltip: "Search"; shortcut: "Ctrl+K"
            onClicked: { root.collapseRequested(false); Qt.callLater(root.focusSearch); }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: bridge && bridge.projectPath ? "folderOpen" : "folder"
            tooltip: bridge && bridge.projectLabel ? "Project · " + bridge.projectLabel : "Open project"
            onClicked: root.collapseRequested(false)
        }

        Item { Layout.fillHeight: true }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "sliders"; tooltip: "Settings"; shortcut: "Ctrl+,"
            onClicked: root.openSettings()
        }
    }
}
