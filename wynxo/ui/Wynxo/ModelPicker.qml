import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! Choosing a model is a real decision, so it gets a real screen. */
Sheet {
    id: sheet
    title: "Models"
    subtitle: "Installed locally with Ollama"
    width: Math.min(700, parent ? parent.width - Theme.s7 : 700)
    height: Math.min(600, parent ? parent.height - Theme.s7 : 600)

    property string query: ""
    onOpened: { query = ""; filter.text = ""; bridge && bridge.refreshModels(); filter.forceActiveFocus(); }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s6
        anchors.topMargin: 0
        spacing: Theme.s4

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Field {
                id: filter
                Layout.fillWidth: true
                iconName: "search"
                placeholderText: "Search installed models"
                onTextChanged: sheet.query = text.toLowerCase()
            }
            IconButton {
                iconName: "retry"; tooltip: "Refresh from Ollama"
                onClicked: bridge && bridge.refreshModels()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.s1
            model: bridge ? bridge.modelCatalog : []
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: entry
                required property var modelData
                property bool matches: !sheet.query || modelData.name.toLowerCase().indexOf(sheet.query) !== -1
                width: list.width
                height: matches ? 62 : 0
                visible: matches
                radius: Theme.r2
                color: modelData.selected ? Theme.surfaceSelected
                     : rowMouse.containsMouse ? Theme.surfaceHover : "transparent"
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    anchors.rightMargin: Theme.s2
                    spacing: Theme.s3

                    Icon {
                        name: modelData.selected ? "check" : "layers"
                        ink: modelData.selected ? Theme.accent : Theme.textMuted
                        width: 17; height: 17
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.s2
                            Text {
                                text: modelData.name
                                color: Theme.textPrimary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                font.weight: modelData.selected ? Font.DemiBold : Font.Medium
                                Layout.maximumWidth: 300
                                elide: Text.ElideMiddle
                            }
                            Rectangle {
                                visible: modelData.loaded
                                width: loadedText.implicitWidth + Theme.s2; height: 17; radius: Theme.r1
                                color: Theme.successMuted
                                Text {
                                    id: loadedText
                                    anchors.centerIn: parent; text: "in memory"
                                    color: Theme.success
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                }
                            }
                            Rectangle {
                                visible: modelData.recent && !modelData.selected
                                width: recentText.implicitWidth + Theme.s2; height: 17; radius: Theme.r1
                                color: Theme.surfaceHover
                                Text {
                                    id: recentText
                                    anchors.centerIn: parent; text: "recent"
                                    color: Theme.textMuted
                                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [modelData.parameters, modelData.quantization, modelData.sizeLabel,
                                   modelData.selected && bridge ? bridge.modelContextLabel : "",
                                   modelData.selected && bridge ? bridge.modelCapabilitySummary : ""]
                                  .filter(function(p) { return !!p; }).join(" · ")
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        spacing: 0
                        opacity: rowMouse.containsMouse || modelData.favorite || modelData.selected ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
                        IconButton {
                            width: 30; height: 30; iconSize: 15
                            iconName: modelData.favorite ? "starFilled" : "star"
                            tooltip: modelData.favorite ? "Remove favourite" : "Mark as favourite"
                            activeTint: Theme.accent
                            active: modelData.favorite
                            onClicked: bridge && bridge.toggleFavoriteModel(entry.modelData.name)
                        }
                        IconButton {
                            width: 30; height: 30; iconSize: 15
                            iconName: "trash"; tooltip: "Delete from disk"
                            enabled: !modelData.selected
                            onClicked: { sheet.pendingDelete = entry.modelData.name; confirmDelete.open(); }
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    anchors.rightMargin: 64
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { bridge && bridge.setModel(entry.modelData.name); sheet.close(); }
                }
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.s7
                spacing: Theme.s2
                visible: list.count === 0
                Text {
                    text: bridge && bridge.online ? "No models installed" : "Ollama is not connected"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.label
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    width: parent.width
                    text: bridge && bridge.online
                          ? "Download one below — for example gemma3:4b for chat, or a vision model such as qwen2.5vl:7b for screen control."
                          : "Start Ollama with “ollama serve”, then refresh."
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }
            }
        }

        Divider { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Text {
                text: "Download a model"
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Field {
                    id: pullField
                    Layout.fillWidth: true
                    placeholderText: "Ollama model tag, e.g. gemma3:4b"
                    mono: true
                    enabled: bridge && !bridge.pulling
                    onAccepted: if (bridge && !bridge.pulling) bridge.pullModel(text)
                }
                WButton {
                    text: bridge && bridge.pulling ? "Stop" : "Download"
                    iconName: bridge && bridge.pulling ? "stop" : "download"
                    variant: bridge && bridge.pulling ? "secondary" : "primary"
                    enabled: bridge && bridge.online && !bridge.busy && (bridge.pulling || pullField.text.trim().length > 0)
                    onClicked: bridge && bridge.pulling ? bridge.cancelPull() : bridge.pullModel(pullField.text)
                }
            }
            Meter {
                Layout.fillWidth: true
                visible: bridge && bridge.pulling
                value: bridge ? bridge.pullPercent : 0
            }
            Text {
                Layout.fillWidth: true
                text: bridge && bridge.pullProgress
                      ? bridge.pullProgress
                      : "Downloads come straight from Ollama's registry to this computer."
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                elide: Text.ElideRight
            }
        }
    }

    property string pendingDelete: ""

    Sheet {
        id: confirmDelete
        title: "Delete this model?"
        width: 420
        height: 190
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            anchors.topMargin: 0
            spacing: Theme.s4
            Text {
                Layout.fillWidth: true
                text: sheet.pendingDelete + " will be removed from disk. You can download it again later."
                color: Theme.textSecondary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap; lineHeight: 1.4
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                WButton { text: "Cancel"; variant: "ghost"; onClicked: confirmDelete.close() }
                WButton {
                    text: "Delete"; variant: "danger"
                    onClicked: { bridge && bridge.deleteModel(sheet.pendingDelete); confirmDelete.close(); }
                }
            }
        }
    }
}
