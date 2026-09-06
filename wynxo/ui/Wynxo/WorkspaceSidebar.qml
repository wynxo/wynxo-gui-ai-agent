import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Where you are, and what you have been doing.

    The project comes first because it frames everything below it: a task list
    without a place is just a chat history. Collapsed, the sidebar keeps the
    four things worth a click — new task, search, project, settings.
*/
Item {
    id: root
    property bool collapsed: false
    signal newTask()
    signal openSettings()
    signal renameRequested(string id, string title)
    signal deleteRequested(string id, string title)
    signal collapseRequested(bool value)

    function focusSearch() { search.forceActiveFocus(); search.selectAll(); }

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft

    }

    // ------------------------------------------------------------ expanded
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s3
        anchors.topMargin: Theme.s4
        spacing: Theme.s3
        visible: !root.collapsed

        // Wordmark. Small, once, and never animated.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.bottomMargin: Theme.s1
            spacing: Theme.s2
            Mark { Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Text {
                Layout.fillWidth: true
                text: "Wynxo"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.heading
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
                elide: Text.ElideRight
            }
            IconButton {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                iconSize: 14
                objectName: "sidebarCollapseButton"
                iconName: "panelLeft"; tooltip: "Collapse sidebar"; shortcut: "Ctrl+B"
                onClicked: root.collapseRequested(true)
            }
        }

        // ------------------------------------------------------ new + find
        WButton {
            Layout.fillWidth: true
            Layout.topMargin: Theme.s1
            text: "New chat"
            iconName: "edit"
            variant: "ghost"
            onClicked: root.newTask()
            ToolTip.visible: hovered
            ToolTip.text: "New task · Ctrl+N"
        }

        Field {
            id: search
            Layout.fillWidth: true
            iconName: "search"
            placeholderText: "Search chats"
            font.pixelSize: Theme.caption
            // The docked sidebar and the drawer are separate instances; both
            // start from whatever query is already active.
            Component.onCompleted: text = bridge ? bridge.searchQuery : ""
            onTextChanged: if (bridge) bridge.setSearch(text)
            Keys.onEscapePressed: function(event) {
                if (text.length) { text = ""; event.accepted = true; }
                else event.accepted = false;
            }
        }

        // ---------------------------------------------------------- project
        SectionLabel { Layout.fillWidth: true; Layout.leftMargin: Theme.s2; text: "Workspace" }

        Rectangle {
            id: projectCard
            Layout.fillWidth: true
            Layout.preferredHeight: projectColumn.implicitHeight + Theme.s2 * 2
            radius: Theme.r2
            color: projectButton.hovered || projectMenu.opened ? Theme.surfaceHover : "transparent"
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

            Column {
                id: projectColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.s2
                anchors.rightMargin: Theme.s2
                spacing: 2
                Row {
                    width: parent.width
                    spacing: Theme.s2
                    Icon {
                        name: bridge && bridge.projectPath ? "folderOpen" : "folder"
                        ink: bridge && bridge.projectPath ? Theme.textSecondary : Theme.textMuted
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: parent.width - 14 - Theme.s2 - 14
                        text: bridge && bridge.projectName ? bridge.projectName : "No project folder"
                        color: bridge && bridge.projectPath ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.label
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Icon {
                        name: "down"; ink: Theme.textMuted; width: 12; height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    width: parent.width
                    leftPadding: 14 + Theme.s2
                    text: bridge && bridge.projectPath ? bridge.projectParentLabel
                                                       : "Choose one to give tasks a place"
                    color: Theme.textMuted
                    font.family: bridge && bridge.projectPath ? Theme.monoFamily : Theme.sansFamily
                    font.pixelSize: Theme.micro
                    elide: Text.ElideLeft
                }
            }

            AbstractButton {
                id: projectButton
                anchors.fill: parent
                hoverEnabled: true
                Accessible.name: bridge && bridge.projectName
                                 ? "Project " + bridge.projectName + ". Change project"
                                 : "Choose a project folder"
                onClicked: projectMenu.opened ? projectMenu.close() : projectMenu.open()
                background: Rectangle {
                    radius: Theme.r2; color: "transparent"
                    border.width: projectButton.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }

                WMenu {
                    id: projectMenu
                    menuWidth: Math.max(240, projectCard.width)
                    property var recents: bridge ? bridge.recentProjects : []
                    onAboutToShow: recents = bridge ? bridge.recentProjects : []
                    items: {
                        var list = [{ id: "choose", label: "Open folder…", icon: "folder" }];
                        var recent = recents;
                        if (recent.length) {
                            list.push({ separator: true });
                            for (var i = 0; i < Math.min(recent.length, 5); i++)
                                list.push({ id: "recent:" + recent[i].path,
                                            label: recent[i].name, icon: "clock" });
                        }
                        var has = !!(bridge && bridge.projectPath);
                        list.push({ separator: true, hidden: !has });
                        list.push({ id: "reveal", label: "Reveal in file manager", icon: "launch", hidden: !has });
                        list.push({ id: "terminal", label: "Open a terminal here", icon: "terminal", hidden: !has });
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
        }

        // ----------------------------------------------------------- tasks
        ListView {
            id: groups
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.s1
            clip: true
            spacing: Theme.s3
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

            // Empty and no-result states.
            Column {
                anchors.top: parent.top
                anchors.topMargin: Theme.s4
                x: Theme.s2
                width: parent.width - Theme.s4
                spacing: Theme.s2
                visible: groups.count === 0
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery ? "Nothing matches" : "Your chats appear here"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery
                          ? "Search covers titles and message text."
                          : "Start one and it is saved here, on this computer."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }
            }
        }

        Divider { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            AbstractButton {
                id: settingsButton
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.rowHeight
                hoverEnabled: true
                Accessible.name: "Settings"
                onClicked: root.openSettings()
                background: Rectangle {
                    radius: Theme.r2
                    color: settingsButton.hovered ? Theme.surfaceHover : "transparent"
                    border.width: settingsButton.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                }
                contentItem: Row {
                    leftPadding: Theme.s2
                    spacing: Theme.s3
                    Icon {
                        name: "sliders"; ink: Theme.textMuted; width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Settings"
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }
            KeyHint { keys: "Ctrl+," }
        }
    }

    // ---------------------------------------------------------- collapsed
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s2
        anchors.topMargin: Theme.s4
        spacing: Theme.s2
        visible: root.collapsed

        Mark { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
        Item { Layout.preferredHeight: Theme.s2 }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "plus"; tooltip: "New task"; shortcut: "Ctrl+N"
            onClicked: root.newTask()
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "search"; tooltip: "Search tasks"; shortcut: "Ctrl+K"
            onClicked: { root.collapseRequested(false); root.focusSearch(); }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: bridge && bridge.projectPath ? "folderOpen" : "folder"
            tooltip: bridge && bridge.projectLabel ? "Project · " + bridge.projectLabel : "Choose a project folder"
            onClicked: { root.collapseRequested(false); }
        }

        Item { Layout.fillHeight: true }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "sliders"; tooltip: "Settings"; shortcut: "Ctrl+,"
            onClicked: root.openSettings()
        }

    }
}
