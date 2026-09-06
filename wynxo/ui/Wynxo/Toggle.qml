import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Switch with a label and optional description, sized for comfortable hits.

    It never flips itself: `checked` stays bound to the setting, and a click
    only asks for the new value. If the controller refuses one, the switch
    keeps showing the truth instead of drifting out of sync with it.
*/
AbstractButton {
    id: root
    property string description: ""
    signal switched(bool value)

    hoverEnabled: true
    implicitHeight: Math.max(Theme.control, layout.implicitHeight)
    implicitWidth: 260
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.description: description
    Accessible.checked: checked
    onClicked: root.switched(!root.checked)

    background: Item {}

    contentItem: RowLayout {
        id: layout
        spacing: Theme.s4

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: root.text
                color: Theme.textPrimary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                wrapMode: Text.WordWrap; lineHeight: 1.35
            }
        }

        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: root.checked ? Theme.accent : Theme.surfaceHover
            border.width: 1
            border.color: root.checked ? Theme.accent
                        : root.hovered ? Theme.borderStrong : Theme.borderSubtle
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
            Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

            Rectangle {
                width: 16; height: 16; radius: height / 2
                y: 3
                x: root.checked ? parent.width - width - 3 : 3
                color: root.checked ? Theme.onAccent : Theme.textSecondary
                Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                color: "transparent"
                visible: root.visualFocus
                border.width: 2
                border.color: Theme.accentEdge
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
