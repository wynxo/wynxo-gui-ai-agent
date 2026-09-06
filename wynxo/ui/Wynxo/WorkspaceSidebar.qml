import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Codex-style project navigator: product, project and threads in one compact
    rail. No oversized product cards and no decorative dashboard chrome.
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
        spacing: Theme.s2
        visible: !root.collapsed

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
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
                iconName: "panelLeft"
                iconSize: 13
                tooltip: "Collapse sidebar"
                shortcut: "Ctrl+B"
                onClicked: root.collapseRequested(true)
            }
        }

        Segmented {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            options: [
                { id: "wynxo", label: "Chat" },
                { id: "wynxi", label: "Code" },
            ]
            current: root.inWynxi ? "wynxi" : "wynxo"
            onSelected: function(value) {
                if (value === "wynxi" && !root.inWynxi) root.newModeTask("codex");
                else if (value === "wynxo" && root.inWynxi) root.newModeTask("chat");
            }
        }

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
            placeholderText: "Search threads"
            font.pixelSize: Theme.caption
            Component.onCompleted: text = bridge ? bridge.searchQuery : ""
            onTextChanged: if (bridge) bridge.setSearch(text)
            Keys.onEscapePressed: function(event) {
                if (text.length) { text = ""; event.accepted = true; }
                else event.accepted = false;
            }
        }

        // ---------------------------------------------------------- project
        SectionLabel {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
            Layout.topMargin: Theme.s1
            text: "Project"
        }

        AbstractButton {
            id: projectButton
            Layout.fillWidth: true
            implicitHeight: 42
            hoverEnabled: true
            Accessible.name: bridge && bridge.projectName
                ? "Project " + bridge.projectName + ". Change project"
                : "Choose a project folder"
            onClicked: projectMenu.opened ? projectMenu.close() : projectMenu.open()

            background: Rectangle {
                radius: Theme.r1
                color: projectButton.hovered || projectMenu.opened ? Theme.surfaceHover : "transparent"
                border.width: projectButton.visualFocus ? 1 : 0
                border.color: Theme.accentEdge
            }

            contentItem: RowLayout {
                spacing: Theme.s2
                Icon {
                    Layout.leftMargin: Theme.s2
                    name: bridge && bridge.projectPath ? "folderOpen" : "folder"
                    ink: bridge && bridge.projectPath ? Theme.textSecondary : Theme.textMuted
                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.projectName ? bridge.projectName : "Open a folder"
                        color: bridge && bridge.projectPath ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.label
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.projectPath ? bridge.projectParentLabel : "Set the workspace for tools"
                        color: Theme.textMuted
                        font.family: bridge && bridge.projectPath ? Theme.monoFamily : Theme.sansFamily
                        font.pixelSize: Theme.micro
                        elide: Text.ElideLeft
                    }
                }
                Icon {
                    Layout.rightMargin: Theme.s2
                    name: "chevron"
                    ink: Theme.textMuted
                    Layout.preferredWidth: 11; Layout.preferredHeight: 11
                }
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }

            WMenu {
                id: projectMenu
                menuWidth: Math.max(250, projectButton.width)
                property var recents: bridge ? bridge.recentProjects : []
                onAboutToShow: recents = bridge ? bridge.recentProjects : []
                items: {
                    var list = [{ id: "choose", label: "Open folder…", icon: "folder" }];
                    var recent = recents;
                    if (recent.length) {
                        list.push({ separator: true });
                        for (var i = 0; i < Math.min(recent.length, 5); i++)
                            list.push({ id: "recent:" + recent[i].path, label: recent[i].name, icon: "clock" });
                    }
                    var has = !!(bridge && bridge.projectPath);
                    list.push({ separator: true, hidden: !has });
                    list.push({ id: "terminal", label: "Open terminal", icon: "terminal", hidden: !has });
                    list.push({ id: "reveal", label: "Reveal in files", icon: "launch", hidden: !has });
                    list.push({ id: "copy", label: "Copy path", icon: "copy", hidden: !has });
                    list.push({ id: "clear", label: "Close project", icon: "close", hidden: !has });
                    return list;
                }
                onPicked: function(id) {
                    if (!bridge) return;
                    if (id === "choose") bridge.chooseProject();
                    else if (id === "terminal") bridge.openTerminalHere();
                    else if (id === "reveal") bridge.revealPath(bridge.projectPath);
                    else if (id === "copy") bridge.copyProjectPath();
                    else if (id === "clear") bridge.clearProject();
                    else if (id.indexOf("recent:") === 0) bridge.openProject(id.substring(7));
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s1
            Layout.topMargin: Theme.s1
            spacing: Theme.s2
            SectionLabel { text: "Threads" }
            Item { Layout.fillWidth: true }
            Text {
                visible: bridge && bridge.taskGroups && bridge.taskGroups.length > 0
                text: bridge ? bridge.taskGroups.length : ""
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
                    leftPadding: Theme.s1
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
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery ? "Search covers titles and messages." : "Start a task above."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderSubtle }

        AbstractButton {
            id: settingsButton
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            hoverEnabled: true
            Accessible.name: "Settings"
            onClicked: root.openSettings()
            background: Rectangle {
                radius: Theme.r1
                color: settingsButton.hovered ? Theme.surfaceHover : "transparent"
                border.width: settingsButton.visualFocus ? 1 : 0
                border.color: Theme.accentEdge
            }
            contentItem: RowLayout {
                spacing: Theme.s2
                Icon {
                    Layout.leftMargin: Theme.s2
                    name: "sliders"; ink: Theme.textMuted
                    Layout.preferredWidth: 13; Layout.preferredHeight: 13
                }
                Text {
                    Layout.fillWidth: true
                    text: "Settings"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                }
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
            iconName: "chat"; tooltip: "Chat"
            active: !root.inWynxi
            onClicked: if (root.inWynxi) root.newModeTask("chat")
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "code"; tooltip: "Code"
            active: root.inWynxi
            onClicked: if (!root.inWynxi) root.newModeTask("codex")
        }
        Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 24; Layout.preferredHeight: 1; color: Theme.borderSubtle }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "plus"; tooltip: "New task"; shortcut: "Ctrl+N"
            onClicked: root.inWynxi ? root.newModeTask("codex") : root.newTask()
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: "search"; tooltip: "Search threads"; shortcut: "Ctrl+K"
            onClicked: { root.collapseRequested(false); root.focusSearch(); }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            iconName: bridge && bridge.projectPath ? "folderOpen" : "folder"
            tooltip: bridge && bridge.projectLabel ? bridge.projectLabel : "Choose project"
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
