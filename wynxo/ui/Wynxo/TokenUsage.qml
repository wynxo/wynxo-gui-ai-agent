import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Token accounting lives beside the composer because it describes the work
    happening *through* that composer. The idle control is deliberately quiet;
    live generation makes the numbers move, and opening it reveals persisted
    local usage without turning the main workspace into a dashboard.
*/
Item {
    id: root
    objectName: "tokenUsage"
    property bool compact: false
    implicitWidth: usageButton.implicitWidth
    implicitHeight: 30
    readonly property bool hasLiveRun: !!(bridge && (bridge.busy || bridge.liveOutputTokens > 0 || bridge.liveTokenRate > 0))

    function showUsage() { usagePopover.open(); }

    function formatCount(value) {
        var count = Math.max(0, Math.round(Number(value) || 0));
        if (count >= 1000000000) return (count / 1000000000).toFixed(count >= 10000000000 ? 1 : 2) + "B";
        if (count >= 1000000) return (count / 1000000).toFixed(count >= 10000000 ? 1 : 2) + "M";
        if (count >= 1000) return (count / 1000).toFixed(count >= 10000 ? 1 : 2) + "K";
        return count.toString();
    }

    function bucket(name) {
        if (!bridge || !bridge.tokenUsage) return ({ tokens: 0, outputTokens: 0, promptTokens: 0, runs: 0, averageRate: 0 });
        var value = bridge.tokenUsage[name];
        return value || ({ tokens: 0, outputTokens: 0, promptTokens: 0, runs: 0, averageRate: 0 });
    }

    AbstractButton {
        id: usageButton
        height: 30
        readonly property real desiredWidth: Math.max(root.compact ? 46 : 64,
                                                      liveRow.implicitWidth + Theme.s3 * 2)
        implicitWidth: desiredWidth
        hoverEnabled: true
        Accessible.role: Accessible.Button
        Accessible.name: "Token usage"
        Accessible.description: bridge && bridge.liveOutputTokens > 0
            ? Math.round(displayedTokens) + " generated tokens at " + displayedRate.toFixed(1) + " tokens per second"
            : root.bucket("today").tokens > 0
                ? root.bucket("today").tokens + " tokens used today; open usage statistics"
                : "Open token usage statistics"
        onClicked: usagePopover.opened ? usagePopover.close() : usagePopover.open()

        // `Usage` can become `45 tokens · 2.5 tokens/s` in one stream event.
        // Move the neighboring model/send controls instead of snapping them.
        Behavior on implicitWidth {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.base; easing.type: Theme.easing }
        }

        background: GlassSurface {
            radius: Theme.r2
            tint: usagePopover.opened ? Theme.glassTintStrong : Theme.glassTintHover
            fillOpacity: usagePopover.opened ? 0.42
                         : usageButton.down ? 0.46
                         : usageButton.hovered ? 0.32 : 0.0
            outlineVisible: usagePopover.opened || usageButton.hovered || usageButton.visualFocus
            strongEdge: usagePopover.opened || usageButton.hovered
            active: usageButton.visualFocus
            sheen: usagePopover.opened || usageButton.hovered
            edgeColor: usageButton.visualFocus ? Theme.accentEdge : Theme.glassEdge
        }

        property real displayedTokens: bridge ? bridge.liveOutputTokens : 0
        property real displayedRate: bridge ? bridge.liveTokenRate : 0
        property real displayedToday: Number(root.bucket("today").tokens || 0)
        Behavior on displayedTokens {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.base; easing.type: Theme.easing }
        }
        Behavior on displayedRate {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.slow; easing.type: Theme.easing }
        }
        Behavior on displayedToday {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.slow; easing.type: Theme.easing }
        }

        contentItem: Row {
            id: liveRow
            anchors.centerIn: parent
            spacing: Theme.s2

            Row {
                spacing: 5
                Icon {
                    name: "bolt"
                    ink: bridge && bridge.busy ? Theme.accent : Theme.textMuted
                    width: 12; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: usageButton.displayedTokens > 0
                        ? root.formatCount(usageButton.displayedTokens) + (root.compact ? "" : " tokens")
                        : usageButton.displayedToday > 0
                            ? root.formatCount(usageButton.displayedToday) + (root.compact ? "" : " today")
                            : "Usage"
                    color: bridge && bridge.busy ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.caption
                    font.weight: bridge && bridge.busy ? Font.DemiBold : Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                visible: usageButton.displayedRate > 0 && !root.compact
                width: 1; height: 12
                color: Theme.borderSubtle
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: usageButton.displayedRate > 0 && !root.compact
                text: usageButton.displayedRate.toFixed(1) + " tokens/s"
                color: bridge && bridge.busy ? Theme.textSecondary : Theme.textMuted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.caption
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        ToolTip.visible: hovered && !usagePopover.opened
        ToolTip.delay: 550
        ToolTip.text: "Token usage · click for today, week, month and all time"

        Popover {
            id: usagePopover
            width: 352
            height: 324
            preferredEdge: "above"
            anchorX: usageButton.width - width
            title: "Token usage"
            onAboutToShow: if (bridge) bridge.refreshTokenUsage()

            Item {
                anchors.fill: parent

                ColumnLayout {
                    id: usageContent
                    anchors.fill: parent
                    spacing: Theme.s3

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: currentRow.implicitHeight + Theme.s3 * 2
                        radius: Theme.r2
                        color: Theme.surfaceSunken
                        border.width: 1
                        border.color: Theme.borderSubtle

                        RowLayout {
                            id: currentRow
                            anchors.fill: parent
                            anchors.margins: Theme.s3
                            spacing: Theme.s3
                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: bridge && bridge.busy ? "CURRENT RUN"
                                        : root.hasLiveRun ? "LATEST RUN" : "USAGE TODAY"
                                    color: Theme.textMuted
                                    font.family: Theme.sansFamily
                                    font.pixelSize: Theme.micro
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    property real animatedValue: root.hasLiveRun
                                        ? (bridge ? bridge.liveOutputTokens : 0)
                                        : Number(root.bucket("today").tokens || 0)
                                    Behavior on animatedValue {
                                        enabled: !Theme.reducedMotion
                                        NumberAnimation { duration: Theme.base; easing.type: Theme.easing }
                                    }
                                    text: root.hasLiveRun
                                        ? root.formatCount(animatedValue) + " generated"
                                        : root.formatCount(animatedValue) + " total"
                                    color: Theme.textPrimary
                                    font.family: Theme.monoFamily
                                    font.pixelSize: Theme.heading
                                    font.weight: Font.DemiBold
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                property real animatedRate: bridge ? bridge.liveTokenRate : 0
                                Behavior on animatedRate {
                                    enabled: !Theme.reducedMotion
                                    NumberAnimation { duration: Theme.slow; easing.type: Theme.easing }
                                }
                                text: root.hasLiveRun
                                    ? (animatedRate > 0 ? animatedRate.toFixed(1) + " tokens/s" : "— tokens/s")
                                    : root.bucket("today").runs + " run"
                                      + (root.bucket("today").runs === 1 ? "" : "s")
                                color: bridge && bridge.busy ? Theme.accent : Theme.textSecondary
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.label
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Theme.s2
                        rowSpacing: Theme.s2

                        Repeater {
                            model: [
                                { key: "today", label: "TODAY" },
                                { key: "week", label: "THIS WEEK" },
                                { key: "month", label: "THIS MONTH" },
                                { key: "allTime", label: "ALL TIME" }
                            ]
                            delegate: Rectangle {
                                id: stat
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 76
                                radius: Theme.r2
                                color: statHover.hovered ? Theme.surfaceHover : Theme.surface
                                border.width: 1
                                border.color: statHover.hovered ? Theme.borderStrong : Theme.borderSubtle
                                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                                HoverHandler { id: statHover }

                                property var bucketData: root.bucket(modelData.key)
                                property real targetTotal: Number(bucketData.tokens || 0)
                                property real displayedTotal: targetTotal

                                function revealTotal() {
                                    totalReveal.stop();
                                    if (Theme.reducedMotion) {
                                        displayedTotal = targetTotal;
                                        return;
                                    }
                                    displayedTotal = 0;
                                    totalReveal.start();
                                }

                                onTargetTotalChanged: {
                                    if (usagePopover.opened) revealTotal();
                                    else displayedTotal = targetTotal;
                                }

                                Connections {
                                    target: usagePopover
                                    function onOpened() { stat.revealTotal(); }
                                }

                                SequentialAnimation {
                                    id: totalReveal
                                    PauseAnimation { duration: stat.index * 45 }
                                    NumberAnimation {
                                        target: stat
                                        property: "displayedTotal"
                                        from: 0
                                        to: stat.targetTotal
                                        duration: Theme.slow
                                        easing.type: Theme.easing
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Theme.s3
                                    spacing: 3
                                    Text {
                                        text: stat.modelData.label
                                        color: Theme.textMuted
                                        font.family: Theme.sansFamily
                                        font.pixelSize: Theme.micro
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: root.formatCount(stat.displayedTotal)
                                        color: Theme.textPrimary
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.heading
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: root.formatCount(stat.bucketData.outputTokens || 0) + " out · "
                                              + root.formatCount(stat.bucketData.promptTokens || 0) + " in"
                                        color: Theme.textMuted
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.micro
                                    }
                                }

                                ToolTip.visible: statHover.hovered
                                ToolTip.text: (stat.bucketData.runs || 0) + " model run" + ((stat.bucketData.runs || 0) === 1 ? "" : "s")
                                              + (stat.bucketData.averageRate > 0 ? " · avg " + Number(stat.bucketData.averageRate).toFixed(1) + " tokens/s" : "")
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Period totals are exact Ollama prompt + output tokens. Live output is estimated until the model reports final metrics."
                        color: Theme.textMuted
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.micro
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                }
            }
        }
    }
}