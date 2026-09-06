import QtQuick
import QtQuick.Controls

/*! A styled dropdown. Items: {id, label, icon, shortcut, detail, danger, disabled}. */
Popup {
    id: menu
    property var items: []
    property int itemHeight: 34
    property int menuWidth: 232
    signal picked(string id)

    padding: Theme.s1
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent | Popup.CloseOnPressOutside
    width: menuWidth
    implicitHeight: listHeight + Theme.s1 * 2
    readonly property int listHeight: {
        var total = 0;
        for (var i = 0; i < items.length; i++) {
            if (items[i].hidden) continue;
            total += items[i].separator ? 9 : itemHeight;
        }
        return total;
    }

    background: Rectangle {
        radius: Theme.r3
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.borderStrong
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.fast; easing.type: Theme.easing }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast } }

    contentItem: Column {
        spacing: 0
        Repeater {
            model: menu.items
            delegate: Loader {
                required property var modelData
                width: menu.width - Theme.s1 * 2
                active: !modelData.hidden
                sourceComponent: modelData.separator ? separatorItem : entryItem
                onLoaded: if (!modelData.separator) item.entry = modelData
            }
        }
    }

    Component {
        id: separatorItem
        Item {
            height: 9
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.s3; height: 1
                color: Theme.borderSubtle
            }
        }
    }

    Component {
        id: entryItem
        Rectangle {
            property var entry: ({})
            height: menu.itemHeight
            radius: Theme.r1
            color: area.containsMouse && !entry.disabled ? Theme.surfaceHover : "transparent"
            opacity: entry.disabled ? 0.4 : 1
            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s3
                spacing: Theme.s3
                Icon {
                    visible: !!entry.icon
                    name: entry.icon || "chat"
                    ink: entry.danger ? Theme.danger : Theme.textSecondary
                    width: 15; height: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: entry.label || ""
                    color: entry.danger ? Theme.danger : Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: Theme.s3
                anchors.verticalCenter: parent.verticalCenter
                text: entry.shortcut || ""
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: !entry.disabled
                cursorShape: Qt.PointingHandCursor
                onClicked: { menu.picked(entry.id); menu.close(); }
            }
        }
    }
}
