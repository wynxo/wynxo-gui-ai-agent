import QtQuick
import QtQuick.Controls

/*! Text button. Variants: "primary", "secondary" (default), "ghost", "danger". */
Button {
    id: control
    property string variant: "secondary"
    property string iconName: ""
    property bool compactPadding: false
    property color tint: variant === "danger" ? Theme.danger : Theme.textPrimary

    readonly property bool isPrimary: variant === "primary"
    readonly property bool isGhost: variant === "ghost"
    readonly property color ink: isPrimary ? Theme.onAccent
                                           : (variant === "danger" ? Theme.danger
                                           : (isGhost ? Theme.textSecondary : Theme.textPrimary))

    implicitHeight: Theme.control
    implicitWidth: row.implicitWidth + (compactPadding ? Theme.s4 : Theme.s5) * 2
    hoverEnabled: true
    opacity: enabled ? 1 : 0.38
    font.family: Theme.sansFamily
    font.pixelSize: Theme.label
    font.weight: isPrimary ? Font.DemiBold : Font.Medium
    Accessible.name: text || iconName

    contentItem: Row {
        id: row
        spacing: control.text && control.iconName ? Theme.s2 : 0
        anchors.centerIn: parent
        Icon {
            visible: control.iconName !== ""
            name: control.iconName
            ink: control.hovered && control.isGhost ? Theme.textPrimary : control.ink
            width: 17; height: 17
            anchors.verticalCenter: parent.verticalCenter
            Behavior on ink { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        }
        Text {
            visible: !!control.text
            text: control.text
            color: control.hovered && control.isGhost ? Theme.textPrimary : control.ink
            font: control.font
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        }
    }

    background: Rectangle {
        radius: Theme.r2
        color: control.isPrimary ? (control.down ? Qt.darker(Theme.accent, 1.08)
                                                 : control.hovered ? Theme.accentHover : Theme.accent)
             : control.isGhost ? (control.hovered ? Theme.surfaceHover : "transparent")
             : (control.hovered ? Theme.surfaceHover : Theme.surfaceRaised)
        border.width: control.isPrimary || control.isGhost ? 0 : 1
        border.color: Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            visible: control.visualFocus
            border.width: 2; border.color: Theme.accentEdge
        }
    }
}
