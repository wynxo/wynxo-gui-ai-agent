import QtQuick
import QtQuick.Controls

/*! Small pill: a suggestion, a status, or a removable attachment. */
Control {
    id: chip
    property string text: ""
    property string iconName: ""
    property string subtitle: ""
    property bool removable: false
    property bool interactive: true
    property bool selected: false
    property color tone: Theme.textSecondary
    signal clicked()
    signal removed()

    implicitHeight: Theme.controlSmall
    implicitWidth: layout.implicitWidth + Theme.s3 * 2 + (removable ? Theme.s5 : 0)
    hoverEnabled: true          // Control.hovered drives the attached ToolTip.
    ToolTip.delay: 450
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: subtitle ? text + ", " + subtitle : text

    background: Rectangle {
        radius: Theme.rPill
        color: chip.selected ? Theme.accentMuted
             : mouse.containsMouse && chip.interactive ? Theme.surfaceHover : Theme.surfaceRaised
        border.width: 1
        border.color: chip.selected ? Theme.accentEdge
                    : mouse.containsMouse && chip.interactive ? Theme.borderStrong : Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }

    contentItem: Item {
        Row {
            id: layout
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s2
            Icon {
                visible: chip.iconName !== ""
                name: chip.iconName; ink: chip.selected ? Theme.accent : chip.tone
                width: 14; height: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.text
                color: chip.selected ? Theme.textPrimary : Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
            Text {
                visible: chip.subtitle !== ""
                text: chip.subtitle
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: chip.removable ? Theme.s5 : 0
        hoverEnabled: true
        enabled: chip.interactive
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: chip.clicked()
    }

    IconButton {
        visible: chip.removable
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 22; height: 22; iconSize: 11
        iconName: "close"
        tooltip: "Remove"
        onClicked: chip.removed()
    }
}
