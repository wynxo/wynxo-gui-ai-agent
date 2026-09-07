import QtQuick
import QtQuick.Controls

/*! Dense single-line field with a liquid-glass focus treatment. */
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

    background: GlassSurface {
        radius: Theme.r2
        tint: field.activeFocus ? Theme.glassTintStrong : Theme.glassTint
        fillOpacity: field.activeFocus ? 0.72 : Theme.glassThinOpacity
        active: field.activeFocus
        strongEdge: field.activeFocus
        edgeColor: field.activeFocus ? Theme.accentEdge : Theme.glassEdge
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
