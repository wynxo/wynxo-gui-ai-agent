import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The inspector: context, activity, and model — whichever is relevant.

    It is deliberately empty-by-default. When there is nothing to inspect the
    panel says so in one line instead of filling space with decoration.
*/
Item {
    id: root
    signal openModelPicker()
    signal openDesktopSettings()

    // Follow the work: activity while the desktop is being used, context while
    // something is attached, the model otherwise. Choosing a tab pins it.
    property int chosenTab: -1
    readonly property int autoTab: {
        if (!bridge) return 2;
        if (bridge.busy && bridge.activity.length > 0) return 1;
        if (bridge.attachmentCount > 0) return 0;
        if (bridge.activity.length > 0) return 1;
        return 2;
    }
    readonly property int tab: chosenTab >= 0 ? chosenTab : autoTab

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft
        Rectangle { width: 1; height: parent.height; color: Theme.borderSubtle }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s4
        spacing: Theme.s4

        Segmented {
            Layout.fillWidth: true
            options: [
                { id: "context", label: "Context" },
                { id: "activity", label: "Activity" },
                { id: "model", label: "Model" },
            ]
            current: ["context", "activity", "model"][root.tab]
            onSelected: function(value) { root.chosenTab = ["context", "activity", "model"].indexOf(value); }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tab

            // ------------------------------------------------------ CONTEXT
            ColumnLayout {
                spacing: Theme.s4

                SectionLabel { text: "Attached" }
                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    visible: bridge && bridge.attachmentCount > 0
                    Repeater {
                        model: bridge ? bridge.attachments : []
                        delegate: Chip {
                            required property var modelData
                            text: modelData.title
                            iconName: modelData.kind === "image" ? "image"
                                    : modelData.kind === "screenshot" ? "camera"
                                    : modelData.kind === "window" ? "window"
                                    : modelData.kind === "folder" ? "folder"
                                    : modelData.kind === "clipboard" ? "clipboard" : "file"
                            subtitle: modelData.subtitle
                            removable: true
                            interactive: false
                            onRemoved: bridge && bridge.removeAttachment(modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: !bridge || bridge.attachmentCount === 0
                    text: "Nothing attached. Use + in the composer to add a file, folder, screenshot or the clipboard."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }

                // Image previews: exactly what the model will see.
                Repeater {
                    model: bridge ? bridge.attachments : []
                    delegate: Rectangle {
                        required property var modelData
                        visible: !!modelData.image
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 128 : 0
                        radius: Theme.r2
                        color: Theme.surfaceSunken
                        border.width: 1
                        border.color: Theme.borderSubtle
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: modelData.image ? "data:image/png;base64," + modelData.image : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }
                    }
                }

                Divider { Layout.fillWidth: true }
                SectionLabel { text: "Working folder" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.workingDirectoryLabel ? bridge.workingDirectoryLabel : "Not set"
                        color: bridge && bridge.workingDirectory ? Theme.textSecondary : Theme.textMuted
                        font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                        elide: Text.ElideMiddle
                    }
                    IconButton {
                        width: 28; height: 28; iconSize: 14; iconName: "folder"
                        tooltip: "Choose a working folder"
                        onClicked: bridge && bridge.chooseWorkingDirectory()
                    }
                    IconButton {
                        width: 28; height: 28; iconSize: 14; iconName: "launch"
                        tooltip: "Reveal in file manager"
                        enabled: bridge && bridge.workingDirectory !== ""
                        onClicked: bridge && bridge.revealPath(bridge.workingDirectory)
                    }
                    IconButton {
                        width: 28; height: 28; iconSize: 12; iconName: "close"
                        tooltip: "Clear the working folder"
                        visible: bridge && bridge.workingDirectory !== ""
                        onClicked: bridge && bridge.clearWorkingDirectory()
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ----------------------------------------------------- ACTIVITY
            ColumnLayout {
                spacing: Theme.s3
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "Desktop actions"; Layout.fillWidth: true }
                    Text {
                        text: bridge ? String(bridge.activity.length).padStart(2, "0") : "00"
                        color: Theme.textMuted
                        font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                    }
                }
                ListView {
                    id: activityList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.s3
                    model: bridge ? bridge.activity : []
                    onCountChanged: positionViewAtEnd()
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: RowLayout {
                        required property var modelData
                        width: activityList.width
                        spacing: Theme.s3
                        StatusDot {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4
                            tone: Theme.stateColor(modelData.state)
                            pulsing: modelData.state === "running" || modelData.state === "waiting"
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary || modelData.label
                                color: Theme.textSecondary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !!modelData.output
                                text: modelData.output
                                color: modelData.state === "failed" ? Theme.danger : Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        anchors.top: parent.top
                        width: parent.width
                        visible: activityList.count === 0
                        text: bridge && bridge.desktopEnabled
                              ? "No actions yet. Ask Wynxo to do something on your screen."
                              : "Screen control is off, so Wynxo cannot act on your desktop."
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        wrapMode: Text.WordWrap; lineHeight: 1.4
                    }
                }

                Divider { Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    StatusDot { tone: bridge && bridge.desktopEnabled ? Theme.accent : Theme.textMuted }
                    Text {
                        Layout.fillWidth: true
                        text: bridge && bridge.desktopEnabled ? "Screen control on" : "Screen control off"
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                    WButton {
                        text: bridge && bridge.connecting ? "Waiting…"
                            : !(bridge && bridge.desktopAvailable) ? "Unavailable"
                            : bridge && bridge.desktopEnabled ? "Turn off" : "Turn on"
                        variant: bridge && bridge.desktopEnabled ? "secondary" : "primary"
                        compactPadding: true
                        implicitHeight: Theme.controlSmall
                        enabled: bridge && !bridge.connecting && bridge.desktopAvailable
                        onClicked: bridge && bridge.toggleDesktop()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: bridge ? bridge.desktopDetail : ""
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                    wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; lineHeight: 1.35
                }
            }

            // -------------------------------------------------------- MODEL
            ColumnLayout {
                spacing: Theme.s4

                SectionLabel { text: "Selected model" }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: modelColumn.implicitHeight + Theme.s4 * 2
                    radius: Theme.r2
                    color: Theme.surface
                    ColumnLayout {
                        id: modelColumn
                        anchors.fill: parent
                        anchors.margins: Theme.s4
                        spacing: Theme.s2
                        Text {
                            Layout.fillWidth: true
                            text: bridge ? bridge.model : ""
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.label
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: bridge && bridge.modelCapabilitiesLoading
                            text: "Checking what this model can do…"
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.s1
                            visible: !(bridge && bridge.modelCapabilitiesLoading)
                            Repeater {
                                model: bridge && bridge.online
                                       ? ["Chat"].concat(bridge.modelSupportsTools ? ["Tools"] : [])
                                                 .concat(bridge.modelSupportsVision ? ["Vision"] : [])
                                                 .concat(bridge.modelSupportsThinking ? ["Thinking"] : [])
                                       : []
                                delegate: Rectangle {
                                    required property string modelData
                                    width: capText.implicitWidth + Theme.s3
                                    height: 20
                                    radius: Theme.r1
                                    color: Theme.surfaceHover
                                    Text {
                                        id: capText
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.textSecondary
                                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: bridge && bridge.modelContextLabel !== ""
                            text: bridge ? bridge.modelContextLabel : ""
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        }
                        Text {
                            Layout.fillWidth: true
                            text: bridge ? bridge.modelCapabilityHint : ""
                            color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            wrapMode: Text.WordWrap; lineHeight: 1.35
                        }
                        WButton {
                            Layout.fillWidth: true
                            text: "Change model"
                            iconName: "layers"
                            implicitHeight: Theme.controlSmall
                            onClicked: root.openModelPicker()
                        }
                    }
                }

                SectionLabel { text: "Runtime" }
                Segmented {
                    Layout.fillWidth: true
                    options: [
                        { id: "Fast", label: "Fast" },
                        { id: "Balanced", label: "Balanced" },
                        { id: "Deep", label: "Deep" },
                        { id: "Custom", label: "Custom" },
                    ]
                    current: bridge ? bridge.runtimePreset : "Balanced"
                    onSelected: function(value) { if (value !== "Custom") bridge && bridge.applyRuntimePreset(value); }
                }
                Text {
                    Layout.fillWidth: true
                    text: bridge ? bridge.runtimeSummary : ""
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }

                Divider { Layout.fillWidth: true }
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "Last response"; Layout.fillWidth: true }
                    IconButton {
                        width: 24; height: 24; iconSize: 12
                        iconName: metrics.visible ? "up" : "down"
                        tooltip: metrics.visible ? "Hide details" : "Show details"
                        onClicked: metrics.visible = !metrics.visible
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: bridge && bridge.runMetrics.hasData
                          ? bridge.runMetrics.rate.toFixed(1) + " tok/s"
                          : "No generation yet"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.heading
                    font.weight: Font.Medium
                }
                GridLayout {
                    id: metrics
                    Layout.fillWidth: true
                    visible: false
                    columns: 2
                    columnSpacing: Theme.s3
                    rowSpacing: Theme.s2
                    Repeater {
                        model: bridge && bridge.runMetrics.hasData ? [
                            { label: "Output tokens", value: String(bridge.runMetrics.tokens) },
                            { label: "Prompt tokens", value: String(bridge.runMetrics.promptTokens) },
                            { label: "Cached", value: String(bridge.runMetrics.cachedTokens) },
                            { label: "Load", value: bridge.runMetrics.loadSeconds.toFixed(1) + "s" },
                            { label: "Total", value: bridge.runMetrics.totalSeconds.toFixed(1) + "s" },
                        ] : []
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label; color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            }
                            Text {
                                text: modelData.value; color: Theme.textSecondary
                                font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: bridge ? bridge.endpoint : ""
                    color: Theme.textMuted
                    font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                    elide: Text.ElideMiddle
                }
            }
        }
    }

    component SectionLabel: Text {
        color: Theme.textMuted
        font.family: Theme.sansFamily
        font.pixelSize: Theme.micro
        font.letterSpacing: 1.0
        font.capitalization: Font.AllUppercase
    }
}
