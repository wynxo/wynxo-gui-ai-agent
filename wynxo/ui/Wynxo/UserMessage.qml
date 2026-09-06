import QtQuick
import QtQuick.Controls

/*! The user's turn: a quiet card, right-aligned, editable in place. */
Item {
    id: root
    property string body: ""
    property int row: -1
    signal edited(string text)

    implicitHeight: card.height
    property bool editing: false

    Rectangle {
        id: card
        anchors.right: parent.right
        width: root.editing ? parent.width : Math.min(parent.width * 0.82, text.implicitWidth + Theme.s5 * 2)
        height: (root.editing ? editor.implicitHeight + Theme.s4 * 2 + 44 : text.implicitHeight + Theme.s4 * 2)
        radius: Theme.r3
        color: Theme.surfaceRaised
        border.width: root.editing ? 1 : 0
        border.color: Theme.accentEdge
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        TextEdit {
            id: text
            visible: !root.editing
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.s4
            anchors.leftMargin: Theme.s5
            anchors.rightMargin: Theme.s5
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
            visible: root.editing
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3
            TextArea {
                id: editor
                width: parent.width
                wrapMode: TextEdit.Wrap
                color: Theme.textPrimary
                selectionColor: Theme.accent
                font.family: Theme.sansFamily
                font.pixelSize: Theme.body
                padding: 0
                background: Item {}
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

    Row {
        anchors.right: card.left
        anchors.rightMargin: Theme.s2
        anchors.top: card.top
        anchors.topMargin: Theme.s1
        spacing: 0
        opacity: hover.hovered && !root.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
        IconButton {
            width: 28; height: 28; iconSize: 14; iconName: "edit"; tooltip: "Edit and resend"
            onClicked: { editor.text = root.body; root.editing = true; editor.forceActiveFocus(); }
        }
        IconButton {
            width: 28; height: 28; iconSize: 14; iconName: "copy"; tooltip: "Copy"
            onClicked: bridge && bridge.copyText(root.body)
        }
    }

    HoverHandler { id: hover }
}
