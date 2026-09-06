import QtQuick
import QtQuick.Layouts

/*! The new-chat screen. Useful immediately; no marketing copy. */
Item {
    id: root
    signal templateChosen(string prompt)

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.s7 * 2, 640)
        spacing: 0

        Orb {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 62
            Layout.preferredHeight: 62
            Layout.bottomMargin: Theme.s6
            animate: !Theme.reducedMotion
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "How can I help?"
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Math.min(Theme.display, root.width * 0.075)
            font.weight: Font.Medium
            font.letterSpacing: -0.9
            Layout.bottomMargin: Theme.s2
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: bridge && bridge.online
                  ? "Local AI, running on your machine."
                  : "Start Ollama to begin. Everything stays on this computer."
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.label
            Layout.bottomMargin: Theme.s7
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 520 ? 1 : 2
            columnSpacing: Theme.s2
            rowSpacing: Theme.s2

            Repeater {
                model: bridge ? bridge.templates : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: Theme.r2
                    color: area.containsMouse ? Theme.surfaceHover : "transparent"
                    border.width: 1
                    border.color: area.containsMouse ? Theme.borderStrong : Theme.borderSubtle
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s4
                        anchors.rightMargin: Theme.s4
                        spacing: Theme.s3
                        Icon {
                            name: modelData.icon
                            ink: area.containsMouse ? Theme.accent : Theme.textMuted
                            width: 17; height: 17
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on ink { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: modelData.title; color: Theme.textPrimary
                                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                                font.weight: Font.Medium
                            }
                            Text {
                                text: modelData.hint; color: Theme.textMuted
                                font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                            }
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.templateChosen(modelData.prompt)
                    }
                }
            }
        }
    }
}
