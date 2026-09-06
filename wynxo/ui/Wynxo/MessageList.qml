import QtQuick
import QtQuick.Controls

/*! The conversation. One column, one comfortable reading measure. */
ListView {
    id: list
    property bool following: true
    signal linkClicked(string link)

    clip: true
    spacing: Theme.s7
    topMargin: Theme.s6
    bottomMargin: Theme.s6
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 800

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4; radius: 2
            color: parent.pressed ? Theme.borderStrong : Theme.borderSubtle
        }
    }

    onMovementStarted: following = false
    onMovementEnded: following = atYEnd
    onContentHeightChanged: if (following) positionViewAtEnd()
    onCountChanged: { following = true; positionViewAtEnd(); }

    function jumpToEnd() { following = true; positionViewAtEnd(); }

    delegate: Item {
        id: rowItem
        required property int index
        required property string kind
        required property string body
        required property string thought
        required property var blocks
        required property string tail
        required property string tailKind
        required property string tailLanguage
        required property string tailLabel
        required property var steps
        required property bool streaming
        required property real thinkSeconds
        required property bool thinkDone

        width: list.width
        height: loader.implicitHeight

        Loader {
            id: loader
            // Leave the scrollbar its own lane rather than running text under it.
            width: Math.min(parent.width - Theme.s4, Theme.readingWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: kind === "user" ? userTurn : kind === "activity" ? activityTurn : assistantTurn
        }

        Component {
            id: userTurn
            UserMessage {
                body: rowItem.body
                row: rowItem.index
                onEdited: function(text) { bridge && bridge.editMessage(rowItem.index, text); }
            }
        }
        Component {
            id: assistantTurn
            AssistantMessage {
                body: rowItem.body
                thought: rowItem.thought
                blocks: rowItem.blocks
                tail: rowItem.tail
                tailKind: rowItem.tailKind
                tailLanguage: rowItem.tailLanguage
                tailLabel: rowItem.tailLabel
                streaming: rowItem.streaming
                thinkSeconds: rowItem.thinkSeconds
                thinkDone: rowItem.thinkDone
                row: rowItem.index
                onLinkClicked: function(link) { list.linkClicked(link); }
                onBranched: bridge && bridge.branchFrom(rowItem.index)
            }
        }
        Component {
            id: activityTurn
            ToolActivity {
                steps: rowItem.steps
                live: bridge && bridge.busy && rowItem.index === list.count - 1
            }
        }
    }

    add: Transition {
        enabled: !Theme.reducedMotion
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base; easing.type: Theme.easing }
            NumberAnimation { property: "y"; from: 12; duration: Theme.base; easing.type: Theme.easing }
        }
    }
}
