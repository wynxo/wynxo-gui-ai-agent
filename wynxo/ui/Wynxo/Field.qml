import QtQuick
import QtQuick.Controls

/*! Dense single-line field. Solid at rest; focus reveals the glass treatment. */
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
        solid: true
        glassEnabled: field.activeFocus
        tint: field.activeFocus ? Theme.glassTintStrong : Theme.surfaceSunken
        fillOpacity: field.activeFocus ? 0.72 : 1.0
        active: field.activeFocus
        strongEdge: field.activeFocus
        sheen: field.activeFocus
        edgeColor: field.activeFocus ? Theme.accentEdge : Theme.borderSubtle
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
