import QtQuick
import QtQuick.Controls

/*!
    The inline activity timeline: what Wynxo actually did on the desktop.

    Each row carries an icon, a plain-language summary, its state and duration.
    Failures and declined actions stay visible rather than being swallowed.
*/
Item {
    id: root
    property var steps: []
    property bool live: false

    implicitHeight: card.height

    Rectangle {
        id: card
        width: parent.width
        height: column.implicitHeight + Theme.s4 * 2
        radius: Theme.r3
        color: Theme.surface
        border.width: 1
        border.color: root.live ? Theme.accentEdge : Theme.borderSubtle
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.base } }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3

            Row {
                spacing: Theme.s2
                Icon { name: "cursor"; ink: Theme.textMuted; width: 13; height: 13; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: root.live ? "Working on your desktop" : "Desktop activity"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                    font.letterSpacing: 1.1; font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.totalLabel
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                }
            }

            Repeater {
                model: root.steps
                delegate: Item {
                    id: step
                    required property var modelData
                    required property int index
                    width: column.width
                    height: stepColumn.implicitHeight + Theme.s2
                    property bool expanded: false
                    property bool last: index === root.steps.length - 1
                    property color tone: Theme.stateColor(modelData.state)

                    // Timeline rail
                    Rectangle {
                        x: 7; y: 18
                        width: 1
                        height: step.last ? 0 : step.height - 12
                        color: Theme.borderSubtle
                        visible: !step.last
                    }

                    StatusDot {
                        x: 3; y: 5
                        width: 9; height: 9
                        tone: step.tone
                        pulsing: modelData.state === "running" || modelData.state === "waiting"
                    }

                    Column {
                        id: stepColumn
                        x: 26
                        width: parent.width - 26
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: Theme.s2
                            Icon {
                                name: modelData.icon || "bolt"
                                ink: modelData.state === "done" ? Theme.textSecondary : step.tone
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.summary || modelData.label
                                color: Theme.textPrimary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                width: Math.min(implicitWidth, stepColumn.width - 130)
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: modelData.state === "waiting"
                                text: "waiting for you"
                                color: Theme.warning
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: modelData.state === "declined"
                                text: "declined"
                                color: Theme.warning
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                visible: modelData.ms > 0
                                text: modelData.ms >= 1000 ? (modelData.ms / 1000).toFixed(1) + "s" : modelData.ms + "ms"
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: modelData.output || ""
                            color: modelData.state === "failed" ? Theme.danger : Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            wrapMode: Text.WordWrap
                            maximumLineCount: step.expanded ? 20 : 2
                            elide: Text.ElideRight
                            lineHeight: 1.35
                        }

                        Text {
                            width: parent.width
                            visible: step.expanded && !!modelData.detail
                            text: modelData.detail || ""
                            color: Theme.textMuted
                            font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 6
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: modelData.detail ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (modelData.detail) step.expanded = !step.expanded
                    }
                }
            }
        }
    }

    readonly property string totalLabel: {
        var total = 0;
        var complete = true;
        for (var i = 0; i < steps.length; i++) {
            total += steps[i].ms || 0;
            if (steps[i].state === "running" || steps[i].state === "waiting") complete = false;
        }
        if (!complete || total < 100) return "";
        return "· " + (total / 1000).toFixed(1) + "s";
    }
}
