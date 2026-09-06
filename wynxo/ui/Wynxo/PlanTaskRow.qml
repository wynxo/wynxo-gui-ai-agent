import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    One real agent action rendered as a calm plan step.

    Plan deliberately reads the same action state that powers Activity rather
    than inventing a second checklist. Activity is the audit trail; this row is
    the compact, task-oriented view of that evidence.
*/
Item {
    id: root
    required property var step
    property int number: 1
    property bool last: false

    readonly property string rawState: String(step && step.state || "queued")
    readonly property string stateKey: rawState === "declined" ? "cancelled"
                                      : rawState === "pending" ? "queued"
                                      : rawState
    readonly property bool active: stateKey === "running" || stateKey === "waiting"
    readonly property bool done: stateKey === "done"
    readonly property bool failed: stateKey === "failed"
    readonly property bool skipped: stateKey === "cancelled"
    readonly property color tone: Theme.stateColor(stateKey)
    readonly property string titleText: String(step && (step.summary || step.label) || "Agent step")
    readonly property string stateText: done ? "Completed"
                                           : active ? (stateKey === "waiting" ? "Waiting" : "Running")
                                           : failed ? "Failed"
                                           : skipped ? "Skipped"
                                           : "Pending"
    readonly property string detailText: failed || skipped ? String(step && (step.output || step.detail) || "") : ""

    implicitHeight: content.implicitHeight + Theme.s3

    Accessible.role: Accessible.ListItem
    Accessible.name: titleText + ", " + stateText

    // A quiet timeline line gives the checklist structure without turning the
    // panel into a project-management dashboard.
    Rectangle {
        x: 17
        y: 26
        width: 1
        height: Math.max(0, root.height - 18)
        visible: !root.last
        color: Theme.borderSubtle
    }

    Item {
        id: marker
        x: Theme.s3
        y: Theme.s2
        width: 18
        height: 18

        Rectangle {
            anchors.centerIn: parent
            width: 18; height: 18; radius: 9
            color: root.done ? Theme.surfaceSelected : "transparent"
            border.width: root.done ? 0 : 1
            border.color: root.active ? root.tone : Theme.borderStrong
        }

        Icon {
            anchors.centerIn: parent
            visible: root.done || root.failed || root.skipped
            name: root.done ? "check" : "close"
            ink: root.done ? Theme.textPrimary : root.tone
            width: 10; height: 10
            weight: 1.9
        }

        StatusDot {
            anchors.centerIn: parent
            visible: root.active
            width: 7; height: 7
            tone: root.tone
            pulsing: true
        }

        Text {
            anchors.centerIn: parent
            visible: !root.done && !root.active && !root.failed && !root.skipped
            text: root.number
            color: Theme.textDisabled
            font.family: Theme.monoFamily
            font.pixelSize: Theme.micro
            font.weight: Font.Medium
        }
    }

    ColumnLayout {
        id: content
        x: 45
        y: Theme.s2
        width: parent.width - x - Theme.s3
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2

            Text {
                Layout.fillWidth: true
                text: root.titleText
                color: root.done ? Theme.textSecondary : Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.body
                font.weight: root.active ? Font.Medium : Font.Normal
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                lineHeight: 1.25
            }

            Text {
                text: root.stateText
                color: root.done ? Theme.textDisabled : root.tone
                font.family: Theme.sansFamily
                font.pixelSize: Theme.micro
                font.weight: root.active || root.failed ? Font.Medium : Font.Normal
                Layout.alignment: Qt.AlignTop
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.detailText
            color: root.failed ? Theme.danger : Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.micro
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            lineHeight: 1.3
        }
    }
}
