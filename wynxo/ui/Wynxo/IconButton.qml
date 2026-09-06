import QtQuick
import QtQuick.Controls

/*! Square icon-only control with an accessible label and a quiet hover state. */
Button {
    id: control
    property string iconName: "plus"
    property color tint: Theme.textSecondary
    property color activeTint: Theme.textPrimary
    property bool active: false
    property real iconSize: Math.round(width * 0.48)
    property string tooltip: ""

    implicitWidth: Theme.control
    implicitHeight: Theme.control
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35
    Accessible.name: tooltip || iconName

    ToolTip.visible: hovered && tooltip.length > 0
    ToolTip.text: tooltip
    ToolTip.delay: 420

    contentItem: Icon {
        name: control.iconName
        ink: control.active || control.hovered ? control.activeTint : control.tint
        width: control.iconSize; height: control.iconSize
        anchors.centerIn: parent
        Behavior on ink { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }

    background: Rectangle {
        radius: Theme.r2
        color: control.down ? Theme.surfaceSelected
             : control.hovered ? Theme.surfaceHover
             : control.active ? Theme.surfaceRaised : "transparent"
        border.width: control.visualFocus ? 2 : 0
        border.color: Theme.accentEdge
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }
}
