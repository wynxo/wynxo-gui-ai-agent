import QtQuick
import QtQuick.Controls

/*! Compact text button. Variants: primary, secondary, ghost, danger. */
Button {
    id: control
    property string variant: "secondary"
    property string iconName: ""
    property bool compactPadding: false

    readonly property bool isPrimary: variant === "primary"
    readonly property bool isGhost: variant === "ghost"
    readonly property bool isDanger: variant === "danger"
    readonly property color ink: isPrimary ? Theme.onAccent
                               : isDanger ? Theme.danger
                               : isGhost ? (hovered ? Theme.textPrimary : Theme.textSecondary)
                               : Theme.textPrimary

    implicitHeight: Theme.control
    implicitWidth: row.implicitWidth + (compactPadding ? Theme.s3 : Theme.s4) * 2
    hoverEnabled: true
    opacity: enabled ? 1 : 0.42
    scale: down ? 0.985 : hovered ? 1.01 : 1
    font.family: Theme.sansFamily
    font.pixelSize: Theme.label
    font.weight: Font.Medium
    Accessible.name: text || iconName

    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: Theme.fast; easing.type: Theme.easing }
    }

    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: control.text && control.iconName ? Theme.s2 : 0
            Icon {
                visible: control.iconName !== ""
                name: control.iconName
                ink: control.ink
                width: 14; height: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: !!control.text
                text: control.text
                color: control.ink
                font: control.font
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: GlassSurface {
        radius: Theme.r2
        tint: control.isPrimary
              ? (control.down ? Qt.darker(Theme.accent, 1.08)
                 : control.hovered ? Theme.accentHover : Theme.accent)
              : control.isDanger ? Theme.danger
              : control.down ? Theme.glassTintStrong
              : control.hovered ? Theme.glassTintHover : Theme.glassTint
        fillOpacity: control.isPrimary ? (control.down ? 0.98 : control.hovered ? 0.94 : 0.90)
                   : control.isDanger ? (control.hovered ? 0.17 : 0.10)
                   : control.isGhost ? (control.hovered || control.down ? 0.48 : 0.0)
                   : control.down ? 0.80
                   : control.hovered ? 0.68 : Theme.glassThinOpacity
        outlineVisible: !control.isGhost || control.hovered || control.visualFocus
        strongEdge: control.isPrimary || control.hovered
        active: control.visualFocus
        elevated: control.isPrimary && control.hovered
        sheen: !control.isGhost || control.hovered
        edgeColor: control.visualFocus ? Theme.accentEdge
                 : control.isDanger ? Theme.alpha(Theme.danger, 0.34)
                 : control.isPrimary ? Theme.alpha(Theme.textPrimary, 0.15)
                 : control.hovered ? Theme.glassEdgeStrong : Theme.glassEdge
    }
}
