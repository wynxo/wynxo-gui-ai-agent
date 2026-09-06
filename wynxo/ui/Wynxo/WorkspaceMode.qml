pragma Singleton
import QtQuick

/*!
    Lightweight UI mode state for the shell.

    Chat stays conversational, Work owns visual desktop control, and Codex
    turns the empty task into a project-first coding workspace. Work mode is
    still backed by the controller's desktop connection; this singleton only
    remembers which non-visual surface the user selected.
*/
QtObject {
    property string current: "chat"

    function label(mode) {
        if (mode === "work") return "Work";
        if (mode === "codex") return "Codex";
        return "Chat";
    }
}
