import QtQuick

/*!
    Wynxo's interaction-only glass material.

    Permanent chrome stays fully opaque. Liquid Glass is revealed only during
    an interaction/open state. Direct one-off controls also opt in automatically
    when they switch to the shared hover tint, become elevated on hover, or show
    a low-opacity strong-edge drag target.
*/
Rectangle {
    id: surface

    property color tint: Theme.glassTint
    property real fillOpacity: Theme.glassOpacity
    property bool solid: true
    property bool glassEnabled: false
    property bool autoGlass: true
    property bool elevated: false
    property bool active: false
    property bool strongEdge: false
    property bool sheen: true
    property bool outlineVisible: true
    property color edgeColor: active ? Theme.accentEdge
                                     : strongEdge ? Theme.glassEdgeStrong : Theme.borderSubtle

    readonly property real clampedFill: Math.max(0, Math.min(1, fillOpacity))
    readonly property bool autoInteractionGlass: autoGlass && (
        (tint === Theme.glassTintHover && clampedFill > 0)
        || (elevated && clampedFill >= 0.9)
        || (strongEdge && clampedFill > 0 && clampedFill < 0.5)
    )
    readonly property bool materialOn: glassEnabled || autoInteractionGlass
    readonly property bool opaqueIdle: solid && (
        clampedFill >= 0.66
        || (tint === Theme.glassTint && clampedFill >= Theme.glassThinOpacity)
    )

    antialiasing: true
    color: materialOn
           ? Theme.alpha(tint, clampedFill)
           : opaqueIdle ? tint : Theme.alpha(tint, clampedFill)
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

    Rectangle {
        z: -3
        x: -7; y: 4
        width: surface.width + 14; height: surface.height + 10
        radius: surface.radius + 7
        color: Theme.alpha(Theme.glassShadow, 0.08)
        opacity: surface.materialOn && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
    Rectangle {
        z: -2
        x: -4; y: 3
        width: surface.width + 8; height: surface.height + 6
        radius: surface.radius + 4
        color: Theme.alpha(Theme.glassShadow, 0.13)
        opacity: surface.materialOn && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
    Rectangle {
        z: -1
        x: -1; y: 2
        width: surface.width + 2; height: surface.height + 2
        radius: surface.radius + 2
        color: Theme.alpha(Theme.glassShadow, 0.20)
        opacity: surface.materialOn && surface.elevated ? 1 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: Math.max(surface.radius * 1.55, Math.round(surface.height * 0.46))
        radius: Math.max(0, surface.radius - 1)
        opacity: surface.materialOn && surface.sheen ? 1 : 0
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
        opacity: surface.materialOn ? 1 : 0
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
        opacity: surface.materialOn && surface.sheen ? 0.74 : 0
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
        opacity: surface.materialOn ? 0.50 : 0
        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
    }
}
