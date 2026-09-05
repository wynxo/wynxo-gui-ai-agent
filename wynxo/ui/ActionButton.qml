import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: button
    property string iconName: ""
    property bool primary: false
    property bool quiet: false
    property color accentColor: Window.window && Window.window.accent ? Window.window.accent : "#b9dfc6"
    property color foreground: primary ? ((accentColor.r * .299 + accentColor.g * .587 + accentColor.b * .114) > .55 ? "#142119" : "#f2f7f3") : "#c8cecb"
    implicitHeight: 40
    implicitWidth: label.implicitWidth + (iconName ? 38 : 0) + 28
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    font.family: "Lato"
    font.pixelSize: 13
    Accessible.name: text || iconName
    contentItem: Item {
        Icon { visible: button.iconName !== ""; name: button.iconName; ink: button.foreground; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; x: button.text ? 1 : (parent.width-width)/2 }
        Text { id: label; visible: !!button.text; text: button.text; color: button.foreground; font: button.font; anchors.verticalCenter: parent.verticalCenter; x: button.iconName ? 29 : (parent.width-width)/2 }
    }
    background: Rectangle {
        radius: 9
        color: button.primary ? (button.hovered ? Qt.lighter(button.accentColor, 1.12) : button.accentColor) : (button.hovered ? "#282d2c" : button.quiet ? "transparent" : "#202524")
        border.width: button.quiet || button.primary ? 0 : 1
        border.color: button.activeFocus ? button.accentColor : "#333a37"
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
