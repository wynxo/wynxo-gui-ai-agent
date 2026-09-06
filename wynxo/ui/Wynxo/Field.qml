import QtQuick
import QtQuick.Controls

/*! Dense single-line field with a restrained one-pixel focus treatment. */
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
    leftPadding: iconName ? Theme.s3 + 20 : Theme.s3
    rightPadding: Theme.s3
    selectByMouse: true
    Accessible.name: placeholderText

    background: Rectangle {
        radius: Theme.r1
        color: field.activeFocus ? Theme.surfaceRaised : Theme.surface
        border.width: 1
        border.color: field.activeFocus ? Theme.borderStrong : Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
    }

    Icon {
        visible: field.iconName !== ""
        name: field.iconName
        ink: field.activeFocus ? Theme.textSecondary : Theme.textMuted
        width: 13; height: 13
        x: Theme.s3
        anchors.verticalCenter: parent.verticalCenter
    }
}
