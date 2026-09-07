import QtQuick
import QtQuick.Controls

/*! Square icon-only control with an accessible label and a quiet glass hover state. */
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
    scale: down ? 0.95 : hovered ? 1.025 : 1
    Accessible.name: tooltip || iconName

    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.fast; easing.type: Theme.easing }
    }

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

    background: GlassSurface {
        radius: Theme.r2
        tint: control.active ? Theme.accent
             : control.down ? Theme.glassTintStrong
             : control.hovered ? Theme.glassTintHover : Theme.glassTint
        fillOpacity: control.down ? 0.74
                   : control.hovered ? 0.58
                   : control.active ? 0.14 : 0.0
        outlineVisible: control.hovered || control.active || control.visualFocus
        strongEdge: control.hovered || control.active
        active: control.visualFocus
        sheen: control.hovered || control.active
        edgeColor: control.visualFocus ? Theme.accentEdge
                 : control.active ? Theme.accentEdge
                 : control.hovered ? Theme.glassEdgeStrong : Theme.glassEdge
    }
}
