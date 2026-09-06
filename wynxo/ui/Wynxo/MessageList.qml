import QtQuick
import QtQuick.Controls

/*!
    The task: one column, one comfortable reading measure.

    Auto-scroll follows the newest output only while you are already at the
    bottom. Scroll up and it stops, immediately and for good, until you come
    back down or ask to jump — reading earlier output is never interrupted.
*/
ListView {
    id: list
    property bool following: true
    signal linkClicked(string link)

    clip: true
    spacing: Theme.s6
    topMargin: Theme.s5
    bottomMargin: Theme.s5
    boundsBehavior: Flickable.StopAtBounds
    cacheBuffer: 1200
    reuseItems: true

    readonly property bool atBottom: atYEnd || contentHeight + topMargin + bottomMargin <= height

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: 4; radius: 2
            color: parent.pressed ? Theme.borderStrong : Theme.borderSubtle
        }
    }

    onMovementStarted: following = false
    onMovementEnded: following = atBottom
    onContentHeightChanged: if (following) positionViewAtEnd()
    onCountChanged: if (following) Qt.callLater(positionViewAtEnd)

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
                onEdited: function(text) { if (bridge) bridge.editMessage(rowItem.index, text); }
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
                latest: rowItem.index === list.count - 1
                row: rowItem.index
                onLinkClicked: function(link) { list.linkClicked(link); }
                onBranched: if (bridge) bridge.branchFrom(rowItem.index)
            }
        }
        Component {
            id: activityTurn
            RunActivity {
                steps: rowItem.steps
                live: bridge && bridge.busy && rowItem.index === list.count - 1
            }
        }
    }

    add: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base; easing.type: Theme.easing }
    }
}
