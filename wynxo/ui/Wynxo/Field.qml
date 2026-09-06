import QtQuick
import QtQuick.Controls

/*! Single-line text field with an optional leading icon and a quiet focus ring. */
TextField {
    id: field
    property string iconName: ""
    property bool mono: false
    implicitHeight: Theme.control
    color: Theme.textPrimary
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.accent
    selectedTextColor: Theme.onAccent
    font.family: mono ? Theme.monoFamily : Theme.sansFamily
    font.pixelSize: Theme.label
    leftPadding: iconName ? Theme.s3 + 21 : Theme.s3
    rightPadding: Theme.s3
    selectByMouse: true
    Accessible.name: placeholderText

    background: Rectangle {
        radius: Theme.r2
        color: Theme.surface
        border.width: 1
        border.color: field.activeFocus ? Theme.accentEdge : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }

    Icon {
        visible: field.iconName !== ""
        name: field.iconName
        ink: field.activeFocus ? Theme.textSecondary : Theme.textMuted
        width: 14; height: 14
        x: Theme.s3
        anchors.verticalCenter: parent.verticalCenter
        Behavior on ink { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }
}
