import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Approval for a single desktop action.

    Safety state is never hidden: the prompt names the exact action, shows its
    risk, and defaults to declining if it is dismissed or times out.
*/
Popup {
    id: prompt
    anchors.centerIn: Overlay.overlay
    width: Math.min(460, parent ? parent.width - Theme.s7 : 460)
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    visible: bridge ? bridge.permissionPending : false
    property bool showDetails: false
    onVisibleChanged: if (!visible) showDetails = false

    Overlay.modal: Rectangle { color: Theme.scrim }

    background: Rectangle {
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: bridge && bridge.permissionRisk === "sensitive" ? Theme.warning : Theme.borderStrong
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Theme.base; easing.type: Theme.easing }
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.s4

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s6
            Layout.bottomMargin: 0
            spacing: Theme.s3
            Rectangle {
                width: 36; height: 36; radius: Theme.r2
                color: bridge && bridge.permissionRisk === "sensitive" ? Theme.warningMuted : Theme.surfaceHover
                Icon {
                    anchors.centerIn: parent
                    name: bridge && bridge.permissionRisk === "sensitive" ? "warning" : "cursor"
                    ink: bridge && bridge.permissionRisk === "sensitive" ? Theme.warning : Theme.textSecondary
                    width: 19; height: 19
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Allow this action?"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.title - 3
                    font.weight: Font.DemiBold
                }
                Text {
                    text: bridge && bridge.permissionRisk === "sensitive"
                          ? "This can change or send something"
                          : "Wynxo wants to act on your desktop"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s6
            Layout.rightMargin: Theme.s6
            Layout.preferredHeight: summary.implicitHeight + Theme.s4 * 2
            radius: Theme.r2
            color: Theme.surfaceSunken
            border.width: 1
            border.color: Theme.borderSubtle
            Text {
                id: summary
                anchors.fill: parent
                anchors.margins: Theme.s4
                text: bridge ? bridge.permissionSummary : ""
                color: Theme.textPrimary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap; lineHeight: 1.4
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s6
            Layout.rightMargin: Theme.s6
            Layout.preferredHeight: detailsRow.height + (prompt.showDetails ? detailText.height + Theme.s2 : 0)
            visible: bridge && bridge.permissionDetail.length > 0

            Item {
                id: detailsRow
                width: parent.width
                height: 22
                Row {
                    id: detailsLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.s2
                    Icon {
                        name: prompt.showDetails ? "down" : "chevron"
                        ink: Theme.textMuted; width: 12; height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: prompt.showDetails ? "Hide exact arguments" : "Show exact arguments"
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                }
                MouseArea {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: detailsLabel.width + Theme.s2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: prompt.showDetails = !prompt.showDetails
                }
            }
            Text {
                id: detailText
                anchors.top: detailsRow.bottom
                anchors.topMargin: Theme.s2
                width: parent.width
                visible: prompt.showDetails
                text: bridge ? bridge.permissionDetail : ""
                color: Theme.textMuted
                font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 5
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s6
            Layout.topMargin: 0
            spacing: Theme.s2
            WButton {
                text: "Allow all in this task"
                variant: "ghost"
                compactPadding: true
                onClicked: bridge && bridge.allowRestOfTask()
                ToolTip.visible: hovered
                ToolTip.text: "Stop asking until this task finishes"
            }
            Item { Layout.fillWidth: true }
            WButton { text: "Decline"; variant: "secondary"; onClicked: bridge && bridge.resolvePermission(false) }
            WButton { text: "Allow"; variant: "primary"; onClicked: bridge && bridge.resolvePermission(true) }
        }
    }

    // Escape is handled by the window shortcut so it works even when the
    // prompt has not taken focus yet.
}
