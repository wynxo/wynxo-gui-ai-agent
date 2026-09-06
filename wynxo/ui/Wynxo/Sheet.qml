import QtQuick
import QtQuick.Controls

/*! Centred modal surface: one radius, one border, one entrance animation. */
Popup {
    id: sheet
    property string title: ""
    property string subtitle: ""
    default property alias body: holder.data

    anchors.centerIn: Overlay.overlay
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Theme.scrim }

    background: Rectangle {
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base; easing.type: Theme.easing }
            NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: Theme.base; easing.type: Theme.easing }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast }
    }

    contentItem: Item {
        implicitWidth: holder.implicitWidth
        implicitHeight: header.height + holder.implicitHeight

        Item {
            id: header
            width: parent.width
            height: sheet.title ? (sheet.subtitle ? 74 : 60) : 0
            visible: height > 0
            Column {
                anchors.left: parent.left; anchors.leftMargin: Theme.s6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: sheet.title; color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.title
                    font.weight: Font.DemiBold; font.letterSpacing: -0.3
                }
                Text {
                    visible: sheet.subtitle !== ""
                    text: sheet.subtitle; color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
            }
            IconButton {
                anchors.right: parent.right; anchors.rightMargin: Theme.s4
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"; tooltip: "Close"
                onClicked: sheet.close()
            }
        }

        Item {
            id: holder
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }
}
