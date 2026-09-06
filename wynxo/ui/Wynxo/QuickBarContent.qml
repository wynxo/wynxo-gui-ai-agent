import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The floating command bar.

    One line of input, three context shortcuts, and a way into the full app.
    Answers stream inline so a quick question never needs the main window.
*/
Item {
    id: root
    signal submitted(string text)
    signal expandRequested()
    signal dismissed()

    property string answer: ""
    property bool answering: false

    function focusInput() { input.forceActiveFocus(); input.selectAll(); }
    function reset() { input.text = ""; answer = ""; }

    implicitHeight: shell.height

    Rectangle {
        id: shell
        width: parent.width
        height: column.implicitHeight + Theme.s3 * 2
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3

                Orb {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    animate: !Theme.reducedMotion
                    active: root.answering
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Ask Wynxo anything…"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.sansFamily
                    font.pixelSize: 19
                    background: Item {}
                    onAccepted: root.send()
                    Keys.onEscapePressed: root.dismissed()
                }

                IconButton {
                    iconName: root.answering ? "stop" : "arrow"
                    tooltip: root.answering ? "Stop" : "Ask"
                    width: 34; height: 34; iconSize: 16
                    tint: root.answering ? Theme.textPrimary : Theme.onAccent
                    activeTint: tint
                    enabled: root.answering || input.text.trim().length > 0
                    onClicked: root.answering ? (bridge && bridge.stop()) : root.send()
                    background: Rectangle {
                        radius: Theme.r2
                        color: root.answering ? Theme.surfaceHover
                             : parent.enabled ? Theme.accent : Theme.surfaceRaised
                    }
                }
            }

            // Streaming answer, capped so the bar never grows into a window.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.answer.length ? Math.min(answerText.implicitHeight + Theme.s4 * 2, 220) : 0
                visible: root.answer.length > 0
                radius: Theme.r2
                color: Theme.surfaceSunken
                clip: true
                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    contentHeight: answerText.implicitHeight
                    clip: true
                    TextEdit {
                        id: answerText
                        width: parent.width
                        text: root.answer
                        readOnly: true; selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        color: Theme.textSecondary
                        selectionColor: Theme.accent
                        font.family: Theme.sansFamily; font.pixelSize: Theme.label
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Chip {
                    text: "Screen"; iconName: "camera"
                    onClicked: bridge && bridge.attachScreenshot()
                }
                Chip {
                    text: "Window"; iconName: "window"
                    onClicked: bridge && bridge.attachWindow()
                }
                Chip {
                    text: "File"; iconName: "file"
                    onClicked: bridge && bridge.attachFile()
                }
                Repeater {
                    model: bridge ? bridge.attachments : []
                    delegate: Chip {
                        required property var modelData
                        text: modelData.title
                        iconName: "paperclip"
                        removable: true
                        interactive: false
                        selected: true
                        onRemoved: bridge && bridge.removeAttachment(modelData.id)
                    }
                }
                Item { Layout.fillWidth: true }
                Chip {
                    text: "Expand"; iconName: "launch"
                    onClicked: root.expandRequested()
                }
            }
        }
    }

    function send() {
        var text = input.text.trim();
        if (!text || root.answering) return;
        root.answer = "";
        root.submitted(text);
        input.text = "";
    }
}
