import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Conversation navigation.

    Collapses to an icon rail; grouped by date with pinned chats first. Row
    actions stay hidden until hover so the list reads as a list, not a toolbar.
*/
Item {
    id: root
    property bool collapsed: false
    signal newChat()
    signal openSettings()
    signal openModels()
    signal openCommands()
    signal renameRequested(string id, string title)
    signal deleteRequested(string id, string title)

    function focusSearch() { search.forceActiveFocus(); search.selectAll(); }

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft
        Rectangle {
            anchors.top: parent.top; width: parent.width; height: 180
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.07) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderSubtle }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s3
        anchors.topMargin: Theme.s4
        spacing: Theme.s3

        // ---------------------------------------------------------- brand
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.s2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s3
                Orb { width: 22; height: 22; animate: !Theme.reducedMotion; active: bridge && bridge.busy; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    visible: !root.collapsed
                    text: "Wynxo"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.heading + 2
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ------------------------------------------------------ new + find
        WButton {
            Layout.fillWidth: true
            visible: !root.collapsed
            text: "New chat"
            iconName: "plus"
            variant: "primary"
            onClicked: root.newChat()
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.collapsed
            iconName: "plus"; tooltip: "New chat · Ctrl+N"
            onClicked: root.newChat()
        }

        Field {
            id: search
            Layout.fillWidth: true
            visible: !root.collapsed
            iconName: "search"
            placeholderText: "Search chats"
            font.pixelSize: Theme.caption
            // The docked sidebar and the drawer are separate instances; both
            // start from whatever query is already active.
            Component.onCompleted: text = bridge ? bridge.searchQuery : ""
            onTextChanged: bridge && bridge.setSearch(text)
            Connections {
                target: bridge
                function onTasksChanged() {
                    if (search.text !== bridge.searchQuery) search.text = bridge.searchQuery;
                }
            }
            Keys.onEscapePressed: { text = ""; }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.collapsed
            iconName: "search"; tooltip: "Search chats · Ctrl+K"
            onClicked: { root.collapsed = false; root.focusSearch(); }
        }

        Segmented {
            Layout.fillWidth: true
            visible: !root.collapsed
            options: [{id: "all", label: "Chats"}, {id: "pinned", label: "Pinned"}, {id: "archived", label: "Archive"}]
            current: bridge ? bridge.chatFilter : "all"
            onSelected: function(value) { bridge && bridge.setChatFilter(value); }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.collapsed
            Text {
                Layout.fillWidth: true
                text: "YOUR WORKSPACE"
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                font.letterSpacing: 1.2
            }
            Text {
                text: bridge ? bridge.visibleChatCount : "0"
                color: Theme.textSecondary
                font.family: Theme.monoFamily; font.pixelSize: Theme.micro
            }
        }

        // ----------------------------------------------------------- list
        ListView {
            id: groups
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.collapsed
            clip: true
            spacing: Theme.s3
            model: bridge ? bridge.taskGroups : []
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderSubtle }
            }

            delegate: Column {
                required property var modelData
                width: groups.width
                spacing: 2

                Text {
                    text: modelData.title
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.micro
                    font.letterSpacing: 0.9
                    font.capitalization: Font.AllUppercase
                    leftPadding: Theme.s3
                    bottomPadding: Theme.s1
                }

                Repeater {
                    model: modelData.items
                    delegate: Rectangle {
                        id: chatRow
                        required property var modelData
                        width: groups.width
                        height: Theme.compact ? Theme.rowHeight : 62
                        radius: Theme.r2
                        property bool current: bridge && modelData.id === bridge.taskId
                        readonly property bool hovered: rowHover.hovered || activeFocus || moreMenu.opened
                        HoverHandler { id: rowHover }
                        color: current ? Theme.surfaceSelected
                             : chatRow.hovered ? Theme.surfaceHover : "transparent"
                        border.width: chatRow.activeFocus ? 2 : 0
                        border.color: Theme.accentEdge
                        activeFocusOnTab: true
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

                        Rectangle {
                            // Selection marker: shape as well as colour.
                            x: 0; anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: chatRow.current ? 16 : 0
                            radius: 1
                            color: Theme.accent
                            Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.base; easing.type: Theme.easing } }
                        }

                        Icon {
                            x: Theme.s3
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.pinned ? "pin" : "chat"
                            ink: chatRow.current ? Theme.accent : Theme.textMuted
                            width: 14; height: 14
                        }
                        Text {
                            x: Theme.s3 + 22
                            y: Theme.compact ? (parent.height - height) / 2 : 12
                            width: parent.width - (Theme.s3 + 22) - (chatRow.hovered ? 62 : Theme.s3)
                            text: modelData.title
                            elide: Text.ElideRight
                            color: chatRow.current ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.caption + 0.5
                            font.weight: chatRow.current ? Font.Medium : Font.Normal
                        }

                        Text {
                            visible: !Theme.compact
                            x: Theme.s3 + 22; y: 34
                            width: parent.width - x - Theme.s3
                            text: modelData.preview || "Empty conversation"
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            opacity: chatRow.hovered || moreMenu.opened ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
                            IconButton {
                                width: 26; height: 26; iconSize: 13
                                iconName: "pin"
                                tooltip: modelData.pinned ? "Unpin" : "Pin"
                                active: modelData.pinned
                                activeTint: Theme.accent
                                onClicked: bridge && bridge.togglePin(chatRow.modelData.id)
                            }
                            IconButton {
                                width: 26; height: 26; iconSize: 13
                                iconName: "moreVertical"; tooltip: "More"
                                onClicked: moreMenu.opened ? moreMenu.close() : moreMenu.open()
                                WMenu {
                                    id: moreMenu
                                    x: -menuWidth + parent.width
                                    y: parent.height + 4
                                    menuWidth: 200
                                    items: [
                                        { id: "rename", label: "Rename", icon: "edit" },
                                        { id: "pin", label: chatRow.modelData.pinned ? "Unpin" : "Pin", icon: "pin" },
                                        { id: "duplicate", label: "Duplicate", icon: "duplicate" },
                                        { id: "archive", label: chatRow.modelData.archived ? "Restore chat" : "Archive chat", icon: "folder" },
                                        { separator: true },
                                        { id: "delete", label: "Delete", icon: "trash", danger: true },
                                    ]
                                    onPicked: function(id) {
                                        if (!bridge) return;
                                        if (id === "rename") root.renameRequested(chatRow.modelData.id, chatRow.modelData.title);
                                        else if (id === "pin") bridge.togglePin(chatRow.modelData.id);
                                        else if (id === "duplicate") bridge.duplicateTaskById(chatRow.modelData.id);
                                        else if (id === "archive") bridge.toggleArchive(chatRow.modelData.id);
                                        else if (id === "delete") root.deleteRequested(chatRow.modelData.id, chatRow.modelData.title);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            anchors.rightMargin: chatRow.hovered ? 56 : 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) moreMenu.open();
                                else bridge && bridge.openTask(chatRow.modelData.id);
                            }
                        }
                        Keys.onReturnPressed: bridge && bridge.openTask(chatRow.modelData.id)
                        Keys.onMenuPressed: moreMenu.open()
                        Keys.onSpacePressed: bridge && bridge.openTask(chatRow.modelData.id)
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData.title + (modelData.pinned ? ", pinned" : "")
                        Accessible.description: modelData.preview || ""
                        Accessible.selected: chatRow.current
                    }
                }
            }

            // Empty and no-result states
            Column {
                anchors.top: parent.top
                anchors.topMargin: Theme.s5
                width: parent.width - Theme.s5
                x: Theme.s3
                spacing: Theme.s2
                visible: groups.count === 0
                Text {
                    text: bridge && bridge.searchQuery ? "No chats match"
                          : bridge && bridge.chatFilter === "archived" ? "Archive is empty"
                          : bridge && bridge.chatFilter === "pinned" ? "No pinned chats" : "No chats yet"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery
                          ? "Try a different word."
                          : bridge && bridge.chatFilter === "archived" ? "Archived chats stay saved. Restore them whenever you need."
                          : bridge && bridge.chatFilter === "pinned" ? "Pin a chat from its menu to keep it close."
                          : "Start one and it will be saved here, on this computer."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }
            }
        }

        Item { visible: root.collapsed; Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 126
            visible: !root.collapsed
            radius: Theme.r3
            color: Theme.surface
            border.color: Theme.borderSubtle
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Theme.s3; spacing: Theme.s2
                RowLayout {
                    Layout.fillWidth: true
                    Rectangle { width: 6; height: 6; radius: 3; color: bridge && bridge.online ? Theme.success : Theme.warning }
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.online ? "Ollama connected" : "Ollama offline"
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                    IconButton { width: 24; height: 24; iconSize: 13; iconName: "retry"; tooltip: "Refresh models"; onClicked: bridge && bridge.refreshModels() }
                }
                WButton {
                    Layout.fillWidth: true
                    text: bridge ? bridge.modelShortName : "Choose model"
                    iconName: "layers"; variant: "secondary"
                    onClicked: root.openModels()
                }
                Text {
                    Layout.fillWidth: true
                    text: bridge ? bridge.runtimePreset + " · " + Math.round(bridge.contextFraction * 100) + "% context" : "Local workspace"
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
            }
        }
        WButton {
            Layout.fillWidth: true
            visible: !root.collapsed
            text: "Command palette"; iconName: "search"; variant: "ghost"
            onClicked: root.openCommands()
        }
        Divider { Layout.fillWidth: true }

        // --------------------------------------------------------- footer
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            IconButton {
                iconName: "sliders"; tooltip: "Settings · Ctrl+,"
                onClicked: root.openSettings()
            }
            Text {
                visible: !root.collapsed
                Layout.fillWidth: true
                text: "Settings"
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettings() }
            }
            IconButton {
                visible: !root.collapsed
                iconName: "panelLeft"; tooltip: "Collapse sidebar · Ctrl+B"
                onClicked: root.collapsed = true
            }
        }
        IconButton {
            visible: root.collapsed
            Layout.alignment: Qt.AlignHCenter
            iconName: "panel"; tooltip: "Expand sidebar · Ctrl+B"
            onClicked: root.collapsed = false
        }
    }
}
