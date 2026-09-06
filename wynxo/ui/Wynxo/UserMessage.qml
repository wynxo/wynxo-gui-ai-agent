import QtQuick
import QtQuick.Controls

/*! A user turn is a task prompt: full-width, left aligned, compact and editable. */
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
        width: parent.width
        height: root.editing ? editColumn.implicitHeight + Theme.s3 * 2
                             : Math.max(42, text.implicitHeight + Theme.s3 * 2)
        radius: Theme.r2
        color: Theme.surface
        border.width: 1
        border.color: root.editing ? Theme.accentEdge : Theme.borderSubtle

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            radius: 1
            color: Theme.accent
            opacity: 0.75
        }

        Row {
            visible: !root.editing
            anchors.left: parent.left
            anchors.leftMargin: Theme.s3
            anchors.top: parent.top
            anchors.topMargin: Theme.s3
            spacing: Theme.s2
            Text {
                text: ">"
                color: Theme.accent
                font.family: Theme.monoFamily
                font.pixelSize: Theme.body
                font.weight: Font.DemiBold
            }
        }

        TextEdit {
            id: text
            visible: !root.editing
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.s3
            anchors.leftMargin: Theme.s3 + 18
            // Keep the compact edit/copy controls out of the text lane even
            // for a very long prompt. They remain keyboard-reachable without
            // requiring pointer hover.
            anchors.rightMargin: 68
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
                    text: "Run again"; variant: "primary"; compactPadding: true
                    enabled: editor.text.trim().length > 0
                    onClicked: { root.editing = false; root.edited(editor.text); }
                }
            }
        }

        Row {
            objectName: "messageActions"
            anchors.right: parent.right
            anchors.rightMargin: Theme.s2
            anchors.top: parent.top
            anchors.topMargin: Theme.s2
            spacing: 0
            opacity: root.editing ? 0 : (hover.hovered ? 1 : 0.58)
            visible: !root.editing
            Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
            IconButton {
                width: 26; height: 26; iconSize: 12; iconName: "edit"; tooltip: "Edit and run again"
                onClicked: { editor.text = root.body; root.editing = true; editor.forceActiveFocus(); }
            }
            IconButton {
                width: 26; height: 26; iconSize: 12; iconName: "copy"; tooltip: "Copy"
                onClicked: if (bridge) bridge.copyText(root.body)
            }
        }
    }

    HoverHandler { id: hover }
}
