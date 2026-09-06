import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! A four-step welcome, shown once. Never blocks anything for long. */
Popup {
    id: root
    anchors.centerIn: Overlay.overlay
    width: Math.min(520, parent ? parent.width - Theme.s6 : 520)
    height: 268
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    signal finished()
    signal openModelManager()

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
            NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: Theme.slow; easing.type: Theme.easing }
        }
    }

    contentItem: ColumnLayout {
        anchors.margins: Theme.s6
        spacing: Theme.s4
        Accessible.role: Accessible.Dialog
        Accessible.name: "Welcome to Wynxo"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s6
            Layout.bottomMargin: 0
            spacing: Theme.s3
            Mark { Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
            Text {
                Layout.fillWidth: true
                text: ["Wynxo",
                       "Connect Ollama",
                       "Choose a model",
                       "Screen control"][root.step]
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.title
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s6
            Layout.rightMargin: Theme.s6
            text: {
                if (root.step === 0)
                    return "An Ollama-powered AI workbench for Linux. Run inference on this computer or point Wynxo at an Ollama server you control on your LAN, homelab, or trusted remote host. No Wynxo account or API key required.";
                if (root.step === 1)
                    return bridge && bridge.online
                           ? "Connected to " + bridge.endpoint + " · " + bridge.endpointScopeLabel + ". " + bridge.models.length + " model" + (bridge.models.length === 1 ? "" : "s") + " available."
                           : "Wynxo cannot reach the configured Ollama server yet. Check that Ollama is listening there, then retry. You can change the address in Settings — LAN and remote HTTP(S) servers are supported.";
                if (root.step === 2)
                    return bridge && bridge.models.length
                           ? "Wynxo will use " + bridge.model + ". Any chat model works; screen control also needs vision and tool calling."
                           : "No models are installed on that Ollama server yet. Open the model manager to download one — gemma3:4b is a good place to start.";
                return "Wynxo can see your screen and use your mouse and keyboard, but only when you turn it on. Those desktop actions still happen on this computer even if Ollama inference runs on another machine. Escape stops it from the Wynxo window, and your desktop can give it a stop key that works from anywhere.";
            }
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.label
            wrapMode: Text.WordWrap
            lineHeight: 1.55
            verticalAlignment: Text.AlignTop
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s6
            Layout.topMargin: 0
            spacing: Theme.s2

            Row {
                spacing: Theme.s2
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: index === root.step ? 16 : 5
                        height: 5; radius: 2.5
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
                focus: true
                onClicked: {
                    if (root.step === 1 && !(bridge && bridge.online)) { if (bridge) bridge.refreshModels(); return; }
                    if (root.step === 2 && bridge && !bridge.models.length) { root.done(); root.openModelManager(); return; }
                    if (root.step === root.lastStep) root.done();
                    else root.step += 1;
                }
            }
        }
    }

    function done() {
        if (bridge) bridge.completeOnboarding();
        root.finished();
        root.close();
    }
}
