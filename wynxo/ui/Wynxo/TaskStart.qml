import QtQuick
import QtQuick.Layouts

// The empty conversation stays focused on one thing: the next message.
Item {
    id: root
    signal starterChosen(string prompt)
    Accessible.role: Accessible.StaticText
    Accessible.name: "Where should we begin?"

    Text {
        anchors.centerIn: parent
        width: parent.width
        text: "Where should we begin?"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: Theme.textPrimary
        font.family: Theme.sansFamily
        font.pixelSize: root.width < 600 ? 25 : 28
        font.weight: Font.Medium
        font.letterSpacing: -0.45
    }
}
