import QtQuick

/*!
    The Wynxo mark.

    Two open arcs around a solid core, drawn on canvas so it stays crisp from
    18px in a byline to 72px on the welcome screen. It rotates slowly at rest
    and speeds up while the model is working, which is the only motion the
    interface uses to signal activity at a glance.
*/
Item {
    id: orb
    property bool animate: true
    property bool active: false
    property color tone: Theme.accent
    implicitWidth: 64
    implicitHeight: 64

    Canvas {
        id: rings
        anchors.fill: parent
        antialiasing: true
        rotation: spin.angle
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const s = Math.min(width, height);
            c.scale(s / 64, s / 64);
            c.lineCap = "round";
            const tone = orb.tone;

            // Outer ring: a near-complete circle with one deliberate gap.
            c.strokeStyle = Qt.rgba(tone.r, tone.g, tone.b, 0.9);
            c.lineWidth = 2.2;
            c.beginPath();
            c.arc(32, 32, 26, -Math.PI * 0.62, Math.PI * 1.24);
            c.stroke();

            // Inner ring, offset the other way to give the mark a direction.
            c.strokeStyle = Qt.rgba(tone.r, tone.g, tone.b, 0.42);
            c.lineWidth = 1.8;
            c.beginPath();
            c.arc(32, 32, 17.5, Math.PI * 0.35, Math.PI * 1.72);
            c.stroke();

            // Travelling node on the outer ring.
            c.fillStyle = tone;
            c.beginPath();
            c.arc(32 + 26 * Math.cos(-Math.PI * 0.62), 32 + 26 * Math.sin(-Math.PI * 0.62), 3, 0, Math.PI * 2);
            c.fill();
        }
        onRotationChanged: {}
    }

    // The solid core stays still so the mark reads as one object, not a spinner.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.16
        height: width
        radius: width / 2
        color: orb.tone
    }

    QtObject {
        id: spin
        property real angle: 0
    }

    NumberAnimation {
        target: spin
        property: "angle"
        from: 0; to: 360
        duration: orb.active ? 3400 : 24000
        loops: Animation.Infinite
        running: orb.animate
    }

    onToneChanged: rings.requestPaint()
}
