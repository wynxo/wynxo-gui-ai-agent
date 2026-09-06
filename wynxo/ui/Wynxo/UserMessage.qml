import QtQuick
import QtQuick.Controls

/*! What you asked for: a quiet card, right-aligned, editable in place. */
Item {
    id: root
    property string body: ""
    property int row: -1
    signal edited(string text)

    implicitHeight: card.height
    property bool editing: false
    Accessible.role: Accessible.StaticText
    Accessible.name: "You said: " + root.body

    Rectangle {
        id: card
        anchors.right: parent.right
        width: root.editing ? parent.width
                            : Math.min(Math.max(0, parent.width - 68), text.implicitWidth + Theme.s4 * 2)
        height: root.editing ? editColumn.implicitHeight + Theme.s3 * 2
                             : text.implicitHeight + Theme.s3 * 2
        radius: Theme.r3
        color: Theme.surfaceRaised
        border.width: 1
        border.color: root.editing ? Theme.accentEdge : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        TextEdit {
            id: text
            visible: !root.editing
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.s3
            anchors.leftMargin: Theme.s4
            anchors.rightMargin: Theme.s4
            text: root.body
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            color: Theme.textPrimary
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Theme.sansFamily
            font.pixelSize: Theme.body
        }

        Column {
            id: editColumn
            visible: root.editing
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.s3
            spacing: Theme.s3
            TextArea {
                id: editor
                width: parent.width
                wrapMode: TextEdit.Wrap
                color: Theme.textPrimary
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.family: Theme.sansFamily
                font.pixelSize: Theme.body
                padding: 0
                background: Item {}
                Accessible.name: "Edit your message"
                Keys.onEscapePressed: root.editing = false
            }
            Row {
                spacing: Theme.s2
                anchors.right: parent.right
                WButton { text: "Cancel"; variant: "ghost"; compactPadding: true; onClicked: root.editing = false }
                WButton {
                    text: "Send again"; variant: "primary"; compactPadding: true
                    enabled: editor.text.trim().length > 0
                    onClicked: { root.editing = false; root.edited(editor.text); }
                }
            }
        }
    }

    // Reserve room for actions even for long messages in narrow windows.
    // Keep them reachable by keyboard without requiring pointer hover.
    Row {
        objectName: "messageActions"
        anchors.right: card.left
        anchors.rightMargin: Theme.s2
        anchors.top: card.top
        spacing: 0
        opacity: !root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
        IconButton {
            width: 28; height: 28; iconSize: 13; iconName: "edit"; tooltip: "Edit and resend"
            onClicked: { editor.text = root.body; root.editing = true; editor.forceActiveFocus(); }
        }
        IconButton {
            width: 28; height: 28; iconSize: 13; iconName: "copy"; tooltip: "Copy"
            onClicked: if (bridge) bridge.copyText(root.body)
        }
    }

}
