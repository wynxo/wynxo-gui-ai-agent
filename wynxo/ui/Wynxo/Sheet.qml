import QtQuick
import QtQuick.Controls
import QtQuick.Window

/*!
    Centred modal surface: one radius, one border, one entrance animation.

    Closing restores focus to whatever had it before the sheet opened, so a
    dialog never leaves the keyboard stranded.
*/
Popup {
    id: sheet
    property string title: ""
    property string subtitle: ""
    default property alias body: holder.data
    // Published so a sheet that hugs its content can size itself without
    // re-deriving the header height from the title and subtitle.
    readonly property int headerHeight: title ? (subtitle ? 68 : 56) : 0

    anchors.centerIn: Overlay.overlay
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Qt restores focus to whatever had it before a popup opened, but only
    // while that item still exists; remembering it here also covers a sheet
    // that opens another one on top of itself.
    property var returnFocusTo: null
    onAboutToShow: {
        var host = contentItem ? contentItem.Window.window : null;
        returnFocusTo = host ? host.activeFocusItem : null;
    }
    onClosed: {
        if (returnFocusTo && returnFocusTo.forceActiveFocus)
            returnFocusTo.forceActiveFocus();
        returnFocusTo = null;
    }

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
            NumberAnimation { property: "scale"; from: 0.99; to: 1; duration: Theme.base; easing.type: Theme.easing }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast }
    }

    contentItem: Item {
        implicitWidth: holder.implicitWidth
        implicitHeight: header.height + holder.implicitHeight
        Accessible.role: Accessible.Dialog
        Accessible.name: sheet.title

        Item {
            id: header
            width: parent.width
            height: sheet.headerHeight
            visible: height > 0
            Column {
                anchors.left: parent.left; anchors.leftMargin: Theme.s5
                anchors.right: closeButton.left; anchors.rightMargin: Theme.s3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: sheet.title; color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.title
                    font.weight: Font.DemiBold; font.letterSpacing: -0.3
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: sheet.subtitle !== ""
                    text: sheet.subtitle; color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    elide: Text.ElideRight
                }
            }
            IconButton {
                id: closeButton
                anchors.right: parent.right; anchors.rightMargin: Theme.s3
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"; tooltip: "Close"; shortcut: "Esc"
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
