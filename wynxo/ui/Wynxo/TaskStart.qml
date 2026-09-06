import QtQuick
import QtQuick.Layouts

// The empty conversation stays focused on one thing: the next message.
Item {
    id: root
    signal starterChosen(string prompt)
    Accessible.role: Accessible.StaticText
    Accessible.name: "What can I help with?"
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.s4
        Text {
            Layout.fillWidth: true
            text: "What can I help with?"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 600 ? 28 : 36
            font.weight: Font.Medium
            font.letterSpacing: -1
        }
        Text {
            Layout.fillWidth: true
            text: "Your ideas. Your computer. A little help from Wynxo."
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.body
        }
    }
}
