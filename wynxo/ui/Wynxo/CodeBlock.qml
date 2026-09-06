import QtQuick
import QtQuick.Controls

/*!
    A fenced code block.

    While a block is still streaming it renders as plain monospace; once it
    closes, Python hands back pre-highlighted rich text. That keeps token
    updates cheap and avoids re-tokenising a growing string on every frame.
*/
Rectangle {
    id: root
    property string code: ""
    property string language: ""
    property string label: "Text"
    property bool streaming: false
    property bool runnable: false

    color: Theme.surfaceSunken
    radius: Theme.r2
    border.width: 1
    border.color: Theme.borderSubtle
    implicitHeight: header.height + body.implicitHeight + Theme.s3 * 2
    clip: true

    Item {
        id: header
        width: parent.width
        height: 34
        Text {
            anchors.left: parent.left; anchors.leftMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.textMuted
            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
            font.letterSpacing: 0.8
            font.capitalization: Font.AllUppercase
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: Theme.s1
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            opacity: root.streaming ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
            IconButton {
                width: 28; height: 28; iconSize: 14
                iconName: "terminal"; tooltip: "Copy and open a terminal"
                visible: root.runnable
                onClicked: bridge && bridge.copyAndOpenTerminal(root.code)
            }
            IconButton {
                width: 28; height: 28; iconSize: 14
                iconName: "save"; tooltip: "Save snippet…"
                onClicked: bridge && bridge.saveCode(root.code, root.language)
            }
            IconButton {
                width: 28; height: 28; iconSize: 14
                iconName: "copy"; tooltip: "Copy code"
                onClicked: bridge && bridge.copyText(root.code)
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: 1
            color: Theme.borderSubtle
        }
    }

    Flickable {
        id: body
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.s3
        anchors.topMargin: Theme.s3
        implicitHeight: Math.min(codeText.implicitHeight, 520)
        height: implicitHeight
        contentWidth: codeText.implicitWidth
        contentHeight: codeText.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        TextEdit {
            id: codeText
            readOnly: true
            selectByMouse: true
            textFormat: root.streaming ? TextEdit.PlainText : TextEdit.RichText
            // `revision` exists only so a palette change re-runs this binding.
            property int revision: 0
            text: codeText.render(revision)
            function render(revision) {
                if (root.streaming || !bridge) return root.code;
                return bridge.highlight(root.code, root.language);
            }
            Connections {
                target: bridge
                function onPaletteChanged() { codeText.revision++; }
            }
            color: Theme.codePalette.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Theme.monoFamily
            font.pixelSize: Theme.caption + 1
            // Highlighted output already carries hard line breaks.
            wrapMode: TextEdit.NoWrap
        }
    }
}
