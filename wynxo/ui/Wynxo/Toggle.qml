import QtQuick
import QtQuick.Controls

/*! Switch with a label and optional description, sized for comfortable hits. */
Item {
    id: root
    property string text: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool value)

    implicitHeight: Math.max(Theme.control, column.implicitHeight)
    implicitWidth: 260

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: knob.left
        anchors.rightMargin: Theme.s4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
            width: parent.width
            text: root.text; color: Theme.textPrimary
            font.family: Theme.sansFamily; font.pixelSize: Theme.label
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: root.description !== ""
            text: root.description; color: Theme.textMuted
            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            wrapMode: Text.WordWrap; lineHeight: 1.3
        }
    }

    Rectangle {
        id: knob
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 23; radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHover
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.borderStrong
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        Rectangle {
            width: 17; height: 17; radius: height / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.onAccent : Theme.textSecondary
            Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked); }
    }
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.checked: root.checked
}
