import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A task-oriented view of the agent's real execution steps.

    The model is the persisted conversation model. Reopening a task therefore
    reconstructs this checklist from stored tool evidence instead of showing an
    empty, session-only plan. Activity remains the detailed audit log.
*/
Item {
    id: root
    readonly property var messageModel: bridge ? bridge.messageModel : null

    function hasPersistedSteps() {
        if (!messageModel || messageModel.rowCount === undefined)
            return bridge && bridge.activity && bridge.activity.length > 0;
        // QAbstractListModel does not expose arbitrary role reads conveniently
        // from JS. The ListView itself determines visibility per activity row;
        // this fallback keeps the empty state sensible for a fresh task.
        return bridge && (bridge.hasMessages || bridge.busy);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            title: "Plan"
            detail: bridge && bridge.busy ? bridge.status
                  : bridge && bridge.taskId ? "Agent execution steps" : ""

            StatusDot {
                visible: bridge && bridge.busy
                width: 8; height: 8
                tone: Theme.accent
                pulsing: true
            }
        }

        ListView {
            id: list
            objectName: "planRows"
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.messageModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            topMargin: Theme.s2
            bottomMargin: Theme.s4
            cacheBuffer: 500
            spacing: 0

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
            }

            delegate: Item {
                id: group
                required property int index
                required property string kind
                required property var steps

                width: list.width
                visible: kind === "activity" && steps && steps.length > 0
                height: visible ? stepColumn.implicitHeight + Theme.s2 : 0

                Column {
                    id: stepColumn
                    x: Theme.s1
                    width: parent.width - Theme.s2

                    Repeater {
                        model: group.visible ? group.steps : []
                        delegate: PlanTaskRow {
                            required property var modelData
                            required property int index
                            width: stepColumn.width
                            step: modelData
                            number: index + 1
                            last: index === group.steps.length - 1
                        }
                    }
                }
            }
        }

        // This copy is deliberately modest: Plan is useful once the agent has
        // real actions to show, not a pretend checklist generated from prose.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            visible: bridge && !bridge.hasMessages && !bridge.busy

            Row {
                anchors.centerIn: parent
                spacing: Theme.s2
                Icon { name: "clipboard"; ink: Theme.textDisabled; width: 13; height: 13 }
                Text {
                    text: "Multi-step agent work appears here as it runs."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                }
            }
        }
    }
}
