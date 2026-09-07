import QtQuick

/*!
    Wynxo's interaction-only glass material.

    Permanent chrome stays fully opaque. Liquid Glass is revealed only when a
    component explicitly enables glassEnabled (hover, press, focus, open menu,
    drag target, etc.). This keeps the workspace calm while preserving tactile
    material feedback for actions.
*/
Rectangle {
    id: surface

    property color tint: Theme.glassTint
    property real fillOpacity: Theme.glassOpacity
    property bool solid: true
    property bool glassEnabled: false
    property bool elevated: false
    property bool active: false
    property bool strongEdge: false
    property bool sheen: true
    property bool outlineVisible: true
    property color edgeColor: active ? Theme.accentEdge
                                     : strongEdge ? Theme.glassEdgeStrong : Theme.borderSubtle

    readonly property real clampedFill: Math.max(0, Math.min(1, fillOpacity))

    antialiasing: true
    color: glassEnabled
           ? Theme.alpha(tint, clampedFill)
           : solid ? tint : Theme.alpha(tint, clampedFill)
    border.width: outlineVisible ? 1 : 0
    border.color: edgeColor

    Behavior on color {
        enabled: !Theme.reducedMotion
        ColorAnimation { duration: Theme.fast }
    }
    Behavior on border.color {
        enabled: !Theme.reducedMotion
        ColorAnimation { duration: Theme.fast }
    }

    // Cheap depth bands fade in only for an interaction/open state.
    Rectangle {
        z: -3
        x: -7; y: 4
        width: surface.width + 14; height: surface.height + 10
        radius: surface.radius + 7
        color: Theme.alpha(Theme.glassShadow, 0.08)
        opacity: surface.glassEnabled && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
    Rectangle {
        z: -2
        x: -4; y: 3
        width: surface.width + 8; height: surface.height + 6
        radius: surface.radius + 4
        color: Theme.alpha(Theme.glassShadow, 0.13)
        opacity: surface.glassEnabled && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
    Rectangle {
        z: -1
        x: -1; y: 2
        width: surface.width + 2; height: surface.height + 2
        radius: surface.radius + 2
        color: Theme.alpha(Theme.glassShadow, 0.20)
        opacity: surface.glassEnabled && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: Math.max(surface.radius * 1.55, Math.round(surface.height * 0.46))
        radius: Math.max(0, surface.radius - 1)
        opacity: surface.glassEnabled && surface.sheen ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: surface.active ? Theme.glassSpecularHot : Theme.glassSpecular }
            GradientStop { position: 0.58; color: Theme.alpha(Theme.textPrimary, 0.022) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, surface.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Theme.glassInner
        opacity: surface.glassEnabled ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Math.max(3, Math.round(surface.radius * 0.46))
        anchors.rightMargin: Math.max(3, Math.round(surface.radius * 0.46))
        height: 1
        color: surface.active ? Theme.glassSpecularHot : Theme.glassSpecular
        opacity: surface.glassEnabled && surface.sheen ? 0.74 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.max(4, Math.round(surface.radius * 0.7))
        anchors.rightMargin: Math.max(4, Math.round(surface.radius * 0.7))
        height: 1
        color: Theme.glassLowlight
        opacity: surface.glassEnabled ? 0.50 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
}
