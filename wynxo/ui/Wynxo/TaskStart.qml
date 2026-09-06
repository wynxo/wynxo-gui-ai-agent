import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A new task, oriented around work rather than a greeting.

    It answers the two questions you actually have when you open a tool: where
    am I working, and what was I doing last. The starters are prompts, not
    features — they fill the composer and leave.
*/
Item {
    id: root
    signal starterChosen(string prompt)

    readonly property var recent: {
        var groups = bridge ? bridge.taskGroups : [];
        var out = [];
        for (var g = 0; g < groups.length && out.length < 4; g++)
            for (var i = 0; i < groups[g].items.length && out.length < 4; i++)
                out.push(groups[g].items[i]);
        return out;
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight + Theme.s7 * 2
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            width: Math.min(parent.width - Theme.s5 * 2, Theme.readingWidth)
            x: Math.max(Theme.s5, (parent.width - width) / 2)
            y: Math.max(Theme.s6, (root.height - implicitHeight) / 2.6)
            spacing: Theme.s5

            Text {
                Layout.fillWidth: true
                text: "Start a task"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.display
                font.weight: Font.DemiBold
                font.letterSpacing: -0.6
            }

            // ---------------------------------------------------- the place
            Row {
                Layout.fillWidth: true
                spacing: Theme.s2
                SectionLabel {
                    text: "Working in"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(bridge && bridge.projectPath)
                    text: bridge ? bridge.projectLabel : ""
                    color: Theme.textSecondary
                    font.family: Theme.monoFamily; font.pixelSize: Theme.caption
                    width: Math.min(implicitWidth, body.width - 220)
                    elide: Text.ElideLeft
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !(bridge && bridge.projectPath)
                    text: "no folder chosen"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                }
                WButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bridge && bridge.projectPath ? "Change" : "Choose a folder"
                    iconName: bridge && bridge.projectPath ? "" : "folder"
                    variant: "ghost"
                    compactPadding: true
                    implicitHeight: Theme.controlSmall
                    onClicked: if (bridge) bridge.chooseProject()
                }
            }

            Divider { Layout.fillWidth: true }

            // ------------------------------------------------ recent tasks
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                visible: root.recent.length > 0

                SectionLabel { Layout.fillWidth: true; text: "Pick up where you left off" }

                Repeater {
                    model: root.recent
                    delegate: AbstractButton {
                        id: recentRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Theme.rowHeight
                        hoverEnabled: true
                        Accessible.name: modelData.title
                        onClicked: if (bridge) bridge.openTask(modelData.id)

                        background: Rectangle {
                            radius: Theme.r2
                            color: recentRow.hovered ? Theme.surfaceHover : "transparent"
                            border.width: recentRow.visualFocus ? 2 : 0
                            border.color: Theme.accentEdge
                            Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                        }
                        contentItem: RowLayout {
                            spacing: Theme.s3
                            Icon {
                                Layout.leftMargin: Theme.s2
                                name: modelData.pinned ? "pin" : "chat"
                                ink: recentRow.hovered ? Theme.textSecondary : Theme.textMuted
                                Layout.preferredWidth: 13; Layout.preferredHeight: 13
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: Theme.textPrimary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.rightMargin: Theme.s3
                                Layout.maximumWidth: body.width * 0.4
                                // A title derived from the first message says
                                // the same thing twice; show only new detail.
                                visible: text !== "" && body.width > 480
                                text: {
                                    var line = (modelData.preview || "").replace(/^You:\s*/, "");
                                    return line === modelData.title ? "" : line;
                                }
                                color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }

            // ---------------------------------------------------- starters
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s1
                spacing: Theme.s2

                SectionLabel { Layout.fillWidth: true; text: "Or start from" }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    Repeater {
                        model: bridge ? bridge.starters : []
                        delegate: Chip {
                            required property var modelData
                            text: modelData.title
                            iconName: modelData.icon
                            implicitHeight: Theme.control
                            onClicked: root.starterChosen(modelData.prompt)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s2
                text: bridge && bridge.online
                      ? "Runs on this computer through Ollama. Enter sends, Shift+Enter starts a line."
                      : "Ollama is not running. Start it with “ollama serve”, then reconnect."
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                wrapMode: Text.WordWrap
            }
        }
    }
}
