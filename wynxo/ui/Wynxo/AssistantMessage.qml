import QtQuick
import QtQuick.Controls

/*!
    Wynxo's turn: conversational typography, not a bubble.

    Reasoning collapses into a single line once it is finished, so a thinking
    model does not bury the answer it produced.
*/
Item {
    id: root
    property string body: ""
    property string thought: ""
    property var blocks: []
    property string tail: ""
    property string tailKind: "markdown"
    property string tailLanguage: ""
    property string tailLabel: ""
    property bool streaming: false
    property real thinkSeconds: 0
    property bool thinkDone: false
    property int row: -1
    signal linkClicked(string link)
    signal branched()

    implicitHeight: column.implicitHeight
    property bool thoughtOpen: false
    Accessible.role: Accessible.StaticText
    Accessible.name: (root.streaming ? "Wynxo is replying: " : "Wynxo said: ") + root.body

    Column {
        id: column
        width: parent.width
        spacing: Theme.s3

        // ------------------------------------------------------- byline
        Row {
            spacing: Theme.s2
            height: 20
            Orb {
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                animate: root.streaming && !Theme.reducedMotion
                active: root.streaming
            }
            Text {
                text: "Wynxo"
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ----------------------------------------------------- reasoning
        Item {
            width: parent.width
            visible: root.thought.length > 0
            height: thoughtHeader.height + (root.thoughtOpen ? thoughtBody.height + Theme.s2 : 0)

            Item {
                id: thoughtHeader
                width: parent.width
                height: 26
                Row {
                    id: thoughtRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.s2
                    Icon {
                        name: root.thoughtOpen ? "down" : "chevron"
                        ink: thoughtHover.hovered ? Theme.textSecondary : Theme.textMuted
                        width: 13; height: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Icon {
                        name: "brain"
                        ink: thoughtHover.hovered ? Theme.textSecondary : Theme.textMuted
                        width: 13; height: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: !root.thinkDone ? "Thinking…"
                            : root.thinkSeconds > 0 ? "Thought for " + root.thinkSeconds.toFixed(1) + "s"
                            : "Reasoning"
                        color: thoughtHover.hovered ? Theme.textSecondary : Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                }
                MouseArea {
                    id: thoughtHover
                    property bool hovered: containsMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: thoughtRow.width + Theme.s2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.thoughtOpen = !root.thoughtOpen
                }
            }

            Rectangle {
                id: thoughtBody
                anchors.top: thoughtHeader.bottom
                anchors.topMargin: Theme.s2
                width: parent.width
                height: root.thoughtOpen ? thoughtText.implicitHeight + Theme.s4 * 2 : 0
                visible: root.thoughtOpen
                radius: Theme.r2
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle
                TextEdit {
                    id: thoughtText
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    text: root.thought
                    readOnly: true; selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.textMuted
                    selectionColor: Theme.accent
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
            }
        }

        // -------------------------------------------------------- content
        Repeater {
            model: root.blocks
            delegate: Loader {
                required property var modelData
                width: column.width
                sourceComponent: modelData.kind === "code" ? codeBlock : proseBlock
                onLoaded: {
                    item.blockText = modelData.text;
                    if (modelData.kind === "code") {
                        item.blockLanguage = modelData.language;
                        item.blockLabel = modelData.label;
                        item.blockRunnable = modelData.runnable;
                    }
                }
            }
        }

        // The block still receiving tokens; rendered without highlighting.
        Loader {
            width: column.width
            active: root.tail.length > 0
            sourceComponent: root.tailKind === "code" ? codeBlock : proseBlock
            onLoaded: {
                item.blockText = Qt.binding(function() { return root.tail; });
                item.blockStreaming = Qt.binding(function() { return root.streaming; });
                if (root.tailKind === "code") {
                    item.blockLanguage = Qt.binding(function() { return root.tailLanguage; });
                    item.blockLabel = Qt.binding(function() { return root.tailLabel; });
                }
            }
        }

        // -------------------------------------------------------- actions
        Row {
            spacing: 0
            height: 30
            opacity: hover.hovered && !root.streaming ? 1 : 0
            visible: opacity > 0 && root.body.length > 0
            Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
            IconButton {
                width: 30; height: 30; iconSize: 15; iconName: "copy"; tooltip: "Copy response"
                onClicked: bridge && bridge.copyText(root.body)
            }
            IconButton {
                width: 30; height: 30; iconSize: 15; iconName: "retry"; tooltip: "Regenerate"
                enabled: bridge && bridge.canRegenerate
                onClicked: bridge && bridge.regenerate()
            }
            IconButton {
                width: 30; height: 30; iconSize: 15; iconName: "branch"; tooltip: "Branch a new chat from here"
                onClicked: root.branched()
            }
        }
    }

    HoverHandler { id: hover }

    Component {
        id: proseBlock
        Markdown {
            property string blockText: ""
            property string blockLanguage: ""
            property string blockLabel: ""
            property bool blockStreaming: false
            property bool blockRunnable: false
            source: blockText
            streaming: blockStreaming
            onLinkClicked: function(link) { root.linkClicked(link); }
        }
    }
    Component {
        id: codeBlock
        CodeBlock {
            property string blockText: ""
            property string blockLanguage: ""
            property string blockLabel: "Text"
            property bool blockStreaming: false
            property bool blockRunnable: false
            code: blockText
            language: blockLanguage
            label: blockLabel
            streaming: blockStreaming
            runnable: blockRunnable
        }
    }
}
