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
    font.family: Theme.sansFamily
    font.pixelSize: Theme.label
    font.weight: Font.Medium
    Accessible.name: text || iconName

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

    background: Rectangle {
        radius: Theme.r1
        color: control.isPrimary ? (control.down ? Qt.darker(Theme.accent, 1.08)
                                                 : control.hovered ? Theme.accentHover : Theme.accent)
             : control.isGhost ? (control.down ? Theme.surfaceSelected
                                 : control.hovered ? Theme.surfaceHover : "transparent")
             : (control.down ? Theme.surfaceSelected
               : control.hovered ? Theme.surfaceHover : Theme.surface)
        border.width: control.isPrimary || control.isGhost ? 0 : 1
        border.color: control.isDanger ? Theme.alpha(Theme.danger, 0.35) : Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"
            visible: control.visualFocus
            border.width: 1
            border.color: Theme.accentEdge
        }
    }
}
