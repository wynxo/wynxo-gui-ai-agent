import QtQuick
import QtQuick.Layouts

/*!
    The fresh-task headline.

    One question, sized to the reading measure, sitting directly above the
    composer — the shell places them together so they read as one block rather
    than as a title marooned above an empty page. The openings live in
    TaskStarters, below the composer, where they do not compete with the thing
    you came here to type.
*/
Item {
    id: root

    readonly property string mode: bridge ? bridge.taskMode : "chat"
    readonly property bool hasProject: !!(bridge && bridge.projectPath)
    readonly property string headline: mode === "work" ? "What should I do?"
                                      : mode === "codex" ? "What are we building?"
                                      : "What are we working on?"
    readonly property string detail: mode === "chat"
        ? "Answers and explanations. Chat runs no commands and changes nothing on this computer."
        : mode === "codex" && !hasProject
            ? "Open a project and Wynxi can read it, edit it, run it and test it."
            : mode === "work" && !(bridge && bridge.desktopEnabled)
                ? "Screen control is requested when Work starts; commands run without it."
                : hasProject
                    ? "Working in " + (bridge ? bridge.projectLabel : "")
                    : ""

    implicitHeight: column.implicitHeight

    Accessible.role: Accessible.StaticText
    Accessible.name: root.headline + (root.detail ? ". " + root.detail : "")

    ColumnLayout {
        id: column
        width: parent.width
        spacing: Theme.s2

        Text {
            Layout.fillWidth: true
            text: root.headline
            elide: Text.ElideRight
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: root.width < 560 ? 23 : 27
            font.weight: Font.Medium
            font.letterSpacing: -0.5
        }

        Text {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            color: Theme.textMuted
            font.family: root.hasProject && root.detail.indexOf("Working in") === 0
                         ? Theme.monoFamily : Theme.sansFamily
            font.pixelSize: Theme.caption
            elide: Text.ElideMiddle
        }
    }
}
