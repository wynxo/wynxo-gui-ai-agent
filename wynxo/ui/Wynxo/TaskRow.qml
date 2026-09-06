import QtQuick
import QtQuick.Controls

/*!
    One task in the sidebar.

    Row actions stay hidden until hover or focus so the list reads as a list.
    The text lane is a fixed width whether or not they are showing, so nothing
    reflows under the pointer.
*/
AbstractButton {
    id: row
    property var entry: ({})
    readonly property bool current: bridge && entry.id === bridge.taskId
    signal renameRequested()
    signal deleteRequested()

    height: Theme.rowHeight
    hoverEnabled: true
    Accessible.role: Accessible.ListItem
    Accessible.name: (entry.title || "") + (entry.pinned ? ", pinned" : "")
    Accessible.description: entry.preview || ""
    Accessible.selected: current
    onClicked: if (bridge) bridge.openTask(entry.id)

    background: Rectangle {
        radius: Theme.r2
        color: row.current ? Theme.surfaceSelected
             : row.hovered || actionsShowing ? Theme.surfaceHover : "transparent"
        border.width: row.visualFocus ? 2 : 0
        border.color: Theme.accentEdge
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        // Selection marker: shape as well as colour.
        Rectangle {
            x: 0; anchors.verticalCenter: parent.verticalCenter
            width: 2; height: row.current ? 14 : 0
            radius: 1
            color: Theme.accent
            Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.base; easing.type: Theme.easing } }
        }
    }

    readonly property bool actionsShowing: moreMenu.opened

    contentItem: Item {
        Icon {
            id: glyph
            x: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            name: row.entry.pinned ? "pin" : "chat"
            ink: row.current ? Theme.accent : Theme.textMuted
            width: 13; height: 13
        }
        Text {
            anchors.left: glyph.right
            anchors.leftMargin: Theme.s2 + 2
            anchors.right: parent.right
            // The lane never changes width, so hovering does not shift text.
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.title || ""
            elide: Text.ElideRight
            color: row.current ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.caption
            font.weight: row.current ? Font.Medium : Font.Normal
        }
    }

    IconButton {
        id: more
        anchors.right: parent.right
        anchors.rightMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; iconSize: 13
        iconName: "moreVertical"
        tooltip: "Task actions"
        opacity: row.hovered || row.visualFocus || moreMenu.opened ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
        onClicked: moreMenu.opened ? moreMenu.close() : moreMenu.open()

        WMenu {
            id: moreMenu
            anchorX: -menuWidth + more.width
            menuWidth: 190
            items: [
                { id: "rename", label: "Rename", icon: "edit" },
                { id: "pin", label: row.entry.pinned ? "Unpin" : "Pin", icon: "pin" },
                { id: "duplicate", label: "Duplicate", icon: "duplicate" },
                { separator: true },
                { id: "delete", label: "Delete", icon: "trash", danger: true },
            ]
            onPicked: function(id) {
                if (!bridge) return;
                if (id === "rename") row.renameRequested();
                else if (id === "pin") bridge.togglePin(row.entry.id);
                else if (id === "duplicate") bridge.duplicateTaskById(row.entry.id);
                else if (id === "delete") row.deleteRequested();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 28
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: moreMenu.open()
    }
}
