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
    property bool latest: false
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
            height: 16
            StatusDot {
                visible: root.streaming
                width: 6; height: 6
                tone: Theme.accent
                pulsing: root.streaming
                anchors.verticalCenter: parent.verticalCenter
            }
            SectionLabel {
                text: "Wynxo"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ----------------------------------------------------- reasoning
        Item {
            width: parent.width
            visible: root.thought.length > 0
            height: visible ? thoughtHeader.height + (root.thoughtOpen ? thoughtBody.height + Theme.s2 : 0) : 0

            AbstractButton {
                id: thoughtHeader
                width: Math.min(thoughtRow.implicitWidth + Theme.s2 * 2, parent.width)
                height: 24
                hoverEnabled: true
                Accessible.name: thoughtLabel.text
                onClicked: root.thoughtOpen = !root.thoughtOpen
                background: Rectangle {
                    radius: Theme.r1
                    color: thoughtHeader.hovered ? Theme.surfaceHover : "transparent"
                    border.width: thoughtHeader.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                }
                contentItem: Row {
                    id: thoughtRow
                    spacing: Theme.s2
                    leftPadding: Theme.s2
                    Icon {
                        name: root.thoughtOpen ? "down" : "chevron"
                        ink: thoughtHeader.hovered ? Theme.textSecondary : Theme.textMuted
                        width: 12; height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: thoughtLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: !root.thinkDone ? "Thinking…"
                            : root.thinkSeconds > 0 ? "Thought for " + root.thinkSeconds.toFixed(1) + "s"
                            : "Reasoning"
                        color: thoughtHeader.hovered ? Theme.textSecondary : Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
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
                    selectedTextColor: Theme.onAccent
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
            height: 28
            opacity: hover.hovered && !root.streaming ? 1 : 0
            visible: opacity > 0 && root.body.length > 0
            Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
            IconButton {
                width: 28; height: 28; iconSize: 14; iconName: "copy"; tooltip: "Copy response"
                onClicked: if (bridge) bridge.copyText(root.body)
            }
            IconButton {
                width: 28; height: 28; iconSize: 14; iconName: "retry"; tooltip: "Regenerate"; shortcut: "Ctrl+R"
                enabled: bridge && bridge.canRegenerate
                onClicked: if (bridge) bridge.regenerate()
            }
            IconButton {
                width: 28; height: 28; iconSize: 14; iconName: "branch"; tooltip: "Branch a new task from here"
                onClicked: root.branched()
            }
            // How the newest answer was produced. Never a permanent readout:
            // it appears with the actions for the turn it describes.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Theme.s2
                visible: root.latest && bridge && bridge.runMetrics.hasData
                text: bridge ? bridge.runMetrics.rate.toFixed(1) + " tok/s · "
                             + bridge.runMetrics.tokens + " out · "
                             + bridge.runMetrics.totalSeconds.toFixed(1) + "s" : ""
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
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
