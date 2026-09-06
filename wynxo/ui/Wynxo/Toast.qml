import QtQuick

/*! Transient confirmation. Bottom-centred, never blocking. */
Item {
    id: root
    property string message: ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.s7
    width: card.width
    height: card.height
    opacity: 0
    visible: opacity > 0
    z: 900

    function show(text) {
        root.message = text;
        root.opacity = 1;
        timer.restart();
    }

    Rectangle {
        id: card
        width: label.implicitWidth + Theme.s6 * 2
        height: 40
        radius: Theme.rPill
        color: Theme.surfaceSelected
        border.width: 1
        border.color: Theme.borderStrong
        Text {
            id: label
            anchors.centerIn: parent
            text: root.message
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.caption
        }
    }

    transform: Translate { y: root.opacity > 0 ? 0 : 10 }
    Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.base; easing.type: Theme.easing } }
    Timer { id: timer; interval: 2600; onTriggered: root.opacity = 0 }
}
