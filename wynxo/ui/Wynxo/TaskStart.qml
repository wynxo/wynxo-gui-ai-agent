import QtQuick
import QtQuick.Layouts

/*!
    The fresh-task headline.

    Keep the first screen calm: one mode cue, one useful question, one short
    explanation. The composer remains the visual centre of gravity.
*/
Item {
    id: root

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property bool hasProject: !!(bridge && bridge.projectPath)
    readonly property string modeLabel: mode === "work" ? "WORK"
                                      : mode === "codex" ? "WYNXI"
                                      : "CHAT"
    readonly property string headline: mode === "work" ? "What should I handle?"
                                      : mode === "codex" ? "What should we build?"
                                      : "What do you want to figure out?"
    readonly property string detail: mode === "chat"
        ? "Conversation only — no shell, workspace tools, or desktop control."
        : mode === "codex" && !hasProject
            ? "Open a project to read, edit, run, and test code in its workspace."
            : mode === "work"
                ? (bridge && bridge.desktopEnabled
                    ? "Commands are available. Screen control is on and used only when the task needs visual context."
                    : "Commands are available. Screen control is optional and stays off until you enable it.")
                : hasProject
                    ? "Working in " + (bridge ? bridge.projectLabel : "")
                    : ""

    implicitHeight: column.implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: root.modeLabel + ". " + root.headline + (root.detail ? ". " + root.detail : "")

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.s2

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2

            Rectangle {
                width: 5
                height: 5
                radius: 3
                color: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.modeLabel
                color: Theme.textMuted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.micro
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: root.headline
            elide: Text.ElideRight
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 560 ? 23 : 27
            font.weight: Font.Medium
            font.letterSpacing: -0.45
        }

        Text {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textMuted
            font.family: root.hasProject && root.detail.indexOf("Working in") === 0
                         ? Theme.monoFamily : Theme.sansFamily
            font.pixelSize: Theme.caption
            lineHeight: 1.35
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
}
