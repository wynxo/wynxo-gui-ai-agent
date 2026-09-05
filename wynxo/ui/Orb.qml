import QtQuick
import QtQuick.Window

Item {
    id: orb
    property bool animate: true
    property bool active: false
    property color accentColor: Window.window && Window.window.accent ? Window.window.accent : "#b9dfc6"
    implicitWidth: 110
    implicitHeight: 110
    Rectangle { anchors.centerIn: parent; width: parent.width * .96; height: width; radius: width/2; color: "#14251e"; opacity: .65 }
    Rectangle { anchors.centerIn: parent; width: parent.width * .78; height: width; radius: width/2; color: "transparent"; border.color: Qt.darker(orb.accentColor, 1.7); border.width: 1 }
    Item {
        anchors.fill: parent
        RotationAnimator on rotation { from: 0; to: 360; duration: orb.active ? 7000 : 40000; loops: Animation.Infinite; running: orb.animate }
        Repeater {
            model: 3
            Rectangle { required property int index; anchors.centerIn: parent; width: parent.width * .47; height: width; radius: width*.25; color: "transparent"; rotation: index * 60 + 15; border.width: 1.2; border.color: index === 0 ? Qt.lighter(orb.accentColor, 1.18) : index === 1 ? orb.accentColor : Qt.darker(orb.accentColor, 1.35) }
        }
        Rectangle { x: parent.width*.8; y: parent.height*.24; width: 5; height: 5; radius: 3; color: "#cee9d6" }
    }
    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Qt.lighter(orb.accentColor, 1.15) }
}
