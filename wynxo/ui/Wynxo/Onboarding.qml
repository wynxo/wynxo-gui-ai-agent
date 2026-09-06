import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! A four-step welcome, shown once. Never blocks anything for long. */
Popup {
    id: root
    anchors.centerIn: Overlay.overlay
    width: Math.min(560, parent ? parent.width - Theme.s6 : 560)
    height: 404
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    signal finished()
    signal openModelPicker()

    property int step: 0
    readonly property int lastStep: 3

    Overlay.modal: Rectangle { color: Theme.scrim }
    background: Rectangle {
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.slow }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.slow; easing.type: Theme.easing }
        }
    }

    contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s7
            spacing: Theme.s5

            Orb {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 72; Layout.preferredHeight: 72
                animate: !Theme.reducedMotion
                active: root.step === 1 && bridge && bridge.connectionState === "connecting"
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: ["Welcome to Wynxo",
                       "Looking for Ollama",
                       "Choose a model",
                       "Screen control"][root.step]
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.title + 5
                font.weight: Font.Medium
                font.letterSpacing: -0.5
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (root.step === 0)
                        return "Your local desktop copilot. It runs on your machine through Ollama — no account, no API key, nothing sent to a cloud service.";
                    if (root.step === 1)
                        return bridge && bridge.online
                               ? "Connected. " + bridge.models.length + " local model" + (bridge.models.length === 1 ? "" : "s") + " found at " + bridge.endpoint + "."
                               : "Wynxo cannot reach Ollama yet. Start it with “ollama serve”, then try again. You can also change the address in Settings.";
                    if (root.step === 2)
                        return bridge && bridge.models.length
                               ? "Wynxo will use " + bridge.model + ". Any chat model works; screen control also needs vision and tool calling."
                               : "No models are installed yet. Open the model manager to download one — gemma3:4b is a good place to start.";
                    return "Wynxo can see your screen and use your mouse and keyboard, but only when you turn it on. It starts off every session, and Escape stops everything instantly.";
                }
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.label
                wrapMode: Text.WordWrap
                lineHeight: 1.5
                verticalAlignment: Text.AlignTop
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2

                Row {
                    spacing: Theme.s2
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: index === root.step ? 18 : 6
                            height: 6; radius: 3
                            color: index === root.step ? Theme.accent : Theme.borderStrong
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.base; easing.type: Theme.easing } }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                WButton {
                    text: "Skip"
                    variant: "ghost"
                    visible: root.step < root.lastStep
                    onClicked: root.done()
                }
                WButton {
                    text: root.step === 1 && !(bridge && bridge.online) ? "Retry"
                        : root.step === 2 && bridge && !bridge.models.length ? "Open model manager"
                        : root.step === root.lastStep ? "Start using Wynxo" : "Continue"
                    variant: "primary"
                    onClicked: {
                        if (root.step === 1 && !(bridge && bridge.online)) { bridge && bridge.refreshModels(); return; }
                        if (root.step === 2 && bridge && !bridge.models.length) { root.done(); root.openModelPicker(); return; }
                        if (root.step === root.lastStep) root.done();
                        else root.step += 1;
                    }
                }
            }
        }
    }

    function done() {
        bridge && bridge.completeOnboarding();
        root.finished();
        root.close();
    }
}
