import QtQuick
import QtQuick.Controls

/*! Square icon-only control with an accessible label and a quiet hover state. */
Button {
    id: control
    property string iconName: "plus"
    property color tint: Theme.textSecondary
    property color activeTint: Theme.textPrimary
    property bool active: false
    property real iconSize: Math.round(width * 0.46)
    // Small icons need a heavier stroke to keep the same optical weight.
    property real iconWeight: iconSize <= 13 ? 2.0 : 1.6
    property string tooltip: ""
    property string shortcut: ""

    implicitWidth: Theme.control
    implicitHeight: Theme.control
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35
    Accessible.name: tooltip || iconName

    ToolTip.visible: hovered && enabled && tooltip.length > 0
    ToolTip.text: shortcut ? tooltip + " · " + shortcut : tooltip
    ToolTip.delay: 500

    contentItem: Item {
        Icon {
            name: control.iconName
            ink: control.active || control.hovered ? control.activeTint : control.tint
            weight: control.iconWeight
            width: control.iconSize; height: control.iconSize
            anchors.centerIn: parent
            Behavior on ink { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        }
    }

    background: Rectangle {
        radius: Theme.r2
        color: control.down ? Theme.surfaceSelected
             : control.hovered ? Theme.surfaceHover
             : control.active ? Theme.surfaceRaised : "transparent"
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            visible: control.visualFocus
            border.width: 2
            border.color: Theme.accentEdge
        }
    }
}
