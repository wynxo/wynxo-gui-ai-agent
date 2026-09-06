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
    signal renameRequested(string id, string title)
    signal deleteRequested(string id, string title)

    function focusSearch() { search.forceActiveFocus(); search.selectAll(); }

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft
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
            variant: "secondary"
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
            onTextChanged: bridge && bridge.setSearch(text)
            Keys.onEscapePressed: { text = ""; }
        }
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.collapsed
            iconName: "search"; tooltip: "Search chats · Ctrl+K"
            onClicked: { root.collapsed = false; root.focusSearch(); }
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
                        height: Theme.rowHeight
                        radius: Theme.r2
                        property bool current: bridge && modelData.id === bridge.taskId
                        color: current ? Theme.surfaceSelected
                             : rowMouse.containsMouse ? Theme.surfaceHover : "transparent"
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
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (Theme.s3 + 22) - (rowMouse.containsMouse ? 62 : Theme.s3)
                            text: modelData.title
                            elide: Text.ElideRight
                            color: chatRow.current ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.caption + 0.5
                            font.weight: chatRow.current ? Font.Medium : Font.Normal
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            opacity: rowMouse.containsMouse || moreMenu.opened ? 1 : 0
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
                                        { separator: true },
                                        { id: "delete", label: "Delete", icon: "trash", danger: true },
                                    ]
                                    onPicked: function(id) {
                                        if (!bridge) return;
                                        if (id === "rename") root.renameRequested(chatRow.modelData.id, chatRow.modelData.title);
                                        else if (id === "pin") bridge.togglePin(chatRow.modelData.id);
                                        else if (id === "duplicate") bridge.duplicateTaskById(chatRow.modelData.id);
                                        else if (id === "delete") root.deleteRequested(chatRow.modelData.id, chatRow.modelData.title);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            anchors.rightMargin: 56
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) moreMenu.open();
                                else bridge && bridge.openTask(chatRow.modelData.id);
                            }
                        }
                        Keys.onReturnPressed: bridge && bridge.openTask(chatRow.modelData.id)
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
                    text: bridge && bridge.searchQuery ? "No chats match" : "No chats yet"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.searchQuery
                          ? "Try a different word."
                          : "Start one and it will be saved here, on this computer."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }
            }
        }

        Item { visible: root.collapsed; Layout.fillHeight: true }

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
