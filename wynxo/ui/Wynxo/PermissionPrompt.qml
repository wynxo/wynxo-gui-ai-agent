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
    width: Math.min(440, parent ? parent.width - Theme.s7 : 440)
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.NoAutoClose
    visible: bridge ? bridge.permissionPending : false
    property bool showDetails: false
    onVisibleChanged: if (!visible) showDetails = false
    readonly property bool sensitive: bridge && bridge.permissionRisk === "sensitive"

    Overlay.modal: Rectangle { color: Theme.scrim }

    background: Rectangle {
        radius: Theme.r4
        color: Theme.surface
        border.width: 1
        border.color: prompt.sensitive ? Theme.warning : Theme.borderStrong
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base }
            NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: Theme.base; easing.type: Theme.easing }
        }
    }

    contentItem: ColumnLayout {
        spacing: Theme.s4
        Accessible.role: Accessible.Dialog
        Accessible.name: "Allow this action? " + (bridge ? bridge.permissionSummary : "")

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s5
            Layout.bottomMargin: 0
            spacing: Theme.s3
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignTop
                radius: Theme.r2
                color: prompt.sensitive ? Theme.warningMuted : Theme.surfaceHover
                Icon {
                    anchors.centerIn: parent
                    name: prompt.sensitive ? "warning" : "cursor"
                    ink: prompt.sensitive ? Theme.warning : Theme.textSecondary
                    width: 17; height: 17
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: "Allow this action?"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.title - 2
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: prompt.sensitive
                          ? "This can change or send something"
                          : "Wynxo wants to act on your desktop"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s5
            Layout.rightMargin: Theme.s5
            Layout.preferredHeight: summary.implicitHeight + Theme.s3 * 2
            radius: Theme.r2
            color: Theme.surfaceSunken
            border.width: 1
            border.color: Theme.borderSubtle
            Text {
                id: summary
                anchors.fill: parent
                anchors.margins: Theme.s3
                text: bridge ? bridge.permissionSummary : ""
                color: Theme.textPrimary
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
                wrapMode: Text.WordWrap; lineHeight: 1.45
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s5
            Layout.rightMargin: Theme.s5
            spacing: Theme.s2
            visible: bridge && bridge.permissionDetail.length > 0

            AbstractButton {
                id: detailsToggle
                Layout.preferredHeight: 24
                Layout.preferredWidth: detailsRow.implicitWidth + Theme.s2 * 2
                hoverEnabled: true
                Accessible.name: detailsLabel.text
                onClicked: prompt.showDetails = !prompt.showDetails
                background: Rectangle {
                    radius: Theme.r1
                    color: detailsToggle.hovered ? Theme.surfaceHover : "transparent"
                    border.width: detailsToggle.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                }
                contentItem: Row {
                    id: detailsRow
                    spacing: Theme.s2
                    leftPadding: Theme.s2
                    Icon {
                        name: prompt.showDetails ? "down" : "chevron"
                        ink: Theme.textMuted; width: 11; height: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: detailsLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: prompt.showDetails ? "Hide exact arguments" : "Show exact arguments"
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                visible: prompt.showDetails
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                TextArea {
                    text: bridge ? bridge.permissionDetail : ""
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    color: Theme.textSecondary
                    font.family: Theme.monoFamily; font.pixelSize: Theme.caption
                    wrapMode: TextEdit.WrapAnywhere
                    background: Item {}
                    Accessible.name: "Exact action arguments"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s5
            Layout.topMargin: 0
            spacing: Theme.s2
            WButton {
                text: "Allow all in this task"
                variant: "ghost"
                compactPadding: true
                onClicked: if (bridge) bridge.allowRestOfTask()
                ToolTip.visible: hovered
                ToolTip.text: "Stop asking until this task finishes"
            }
            Item { Layout.fillWidth: true }
            WButton {
                text: "Decline"
                variant: "secondary"
                onClicked: if (bridge) bridge.resolvePermission(false)
                ToolTip.visible: hovered
                ToolTip.text: "Decline · Esc"
            }
            WButton {
                text: "Allow"
                variant: "primary"
                focus: true
                onClicked: if (bridge) bridge.resolvePermission(true)
            }
        }
    }

    // Escape is handled by the window shortcut so it works even when the
    // prompt has not taken focus yet.
}
