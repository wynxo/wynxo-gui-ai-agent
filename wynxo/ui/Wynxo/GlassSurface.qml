import QtQuick

/*!
    Wynxo's cross-platform liquid-glass material.

    Qt on Linux cannot call Apple's private/native macOS Liquid Glass material,
    so this surface recreates the visual cues that matter: translucent tint,
    a brighter incident-light edge, a faint inner reflection, lowlight and
    restrained elevation. It deliberately avoids expensive shader dependencies
    so terminal, file tree and chat scrolling stay responsive on modest GPUs.
*/
Rectangle {
    id: surface

    property color tint: Theme.glassTint
    property real fillOpacity: Theme.glassOpacity
    property bool elevated: false
    property bool active: false
    property bool strongEdge: false
    property bool sheen: true
    property bool outlineVisible: true
    property color edgeColor: active ? Theme.accentEdge
                                     : strongEdge ? Theme.glassEdgeStrong : Theme.glassEdge

    antialiasing: true
    color: Theme.alpha(tint, Math.max(0, Math.min(1, fillOpacity)))
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

    // Three cheap shadow bands read as depth without requiring a blur shader.
    Rectangle {
        visible: surface.elevated
        z: -3
        x: -7; y: 4
        width: surface.width + 14; height: surface.height + 10
        radius: surface.radius + 7
        color: Theme.alpha(Theme.glassShadow, 0.08)
    }
    Rectangle {
        visible: surface.elevated
        z: -2
        x: -4; y: 3
        width: surface.width + 8; height: surface.height + 6
        radius: surface.radius + 4
        color: Theme.alpha(Theme.glassShadow, 0.13)
    }
    Rectangle {
        visible: surface.elevated
        z: -1
        x: -1; y: 2
        width: surface.width + 2; height: surface.height + 2
        radius: surface.radius + 2
        color: Theme.alpha(Theme.glassShadow, 0.20)
    }

    // Broad specular wash: strongest at the top, disappearing into the tint.
    Rectangle {
        visible: surface.sheen
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: Math.max(surface.radius * 1.55, Math.round(surface.height * 0.46))
        radius: Math.max(0, surface.radius - 1)
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: surface.active ? Theme.glassSpecularHot : Theme.glassSpecular
            }
            GradientStop { position: 0.58; color: Theme.alpha(Theme.textPrimary, 0.022) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Inner reflection gives the border a lens-like double edge.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, surface.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Theme.glassInner
    }

    Rectangle {
        visible: surface.sheen
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Math.max(3, Math.round(surface.radius * 0.46))
        anchors.rightMargin: Math.max(3, Math.round(surface.radius * 0.46))
        height: 1
        color: surface.active ? Theme.glassSpecularHot : Theme.glassSpecular
        opacity: 0.74
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.max(4, Math.round(surface.radius * 0.7))
        anchors.rightMargin: Math.max(4, Math.round(surface.radius * 0.7))
        height: 1
        color: Theme.glassLowlight
        opacity: 0.50
    }
}
