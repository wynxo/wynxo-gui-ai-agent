import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*! Everything Wynxo can do, one keystroke away. */
Sheet {
    id: palette
    width: Math.min(580, parent ? parent.width - Theme.s7 : 580)
    height: Math.min(460, parent ? parent.height - Theme.s7 : 460)
    signal invoked(string action)

    property var commands: [
        { id: "new", label: "New chat", detail: "Start a fresh conversation", icon: "plus", shortcut: "Ctrl+N" },
        { id: "search", label: "Search chats", detail: "Filter your saved conversations", icon: "search", shortcut: "Ctrl+K" },
        { id: "next", label: "Next chat", detail: "Move down your conversation list", icon: "down", shortcut: "Alt+Down" },
        { id: "previous", label: "Previous chat", detail: "Move up your conversation list", icon: "up", shortcut: "Alt+Up" },
        { id: "models", label: "Switch model", detail: "Open the model manager", icon: "layers", shortcut: "Ctrl+M" },
        { id: "settings", label: "Open settings", detail: "Appearance, runtime, privacy", icon: "sliders", shortcut: "Ctrl+," },
        { id: "sidebar", label: "Toggle sidebar", detail: "Show or hide conversations", icon: "panelLeft", shortcut: "Ctrl+B" },
        { id: "inspector", label: "Toggle inspector", detail: "Context, activity and model", icon: "panel", shortcut: "Ctrl+I" },
        { id: "quickbar", label: "Open quick bar", detail: "Floating command bar", icon: "spark", shortcut: "Ctrl+Space" },
        { id: "screenshot", label: "Capture screen", detail: "Attach a screenshot to this message", icon: "camera", shortcut: "" },
        { id: "window", label: "Capture active window", detail: "Attach the focused window", icon: "window", shortcut: "" },
        { id: "region", label: "Capture a region", detail: "Drag a rectangle on your screen", icon: "grid", shortcut: "" },
        { id: "file", label: "Attach a file", detail: "Add local text or an image", icon: "file", shortcut: "" },
        { id: "folder", label: "Attach a folder", detail: "Share a directory listing", icon: "folder", shortcut: "" },
        { id: "desktop", label: "Toggle screen control", detail: "Grant or revoke desktop access", icon: "cursor", shortcut: "" },
        { id: "permission", label: "Change permission mode", detail: "Ask, safe auto, or auto", icon: "shield", shortcut: "" },
        { id: "runtime", label: "Change runtime preset", detail: "Fast, balanced or deep", icon: "bolt", shortcut: "" },
        { id: "regenerate", label: "Regenerate response", detail: "Run the last prompt again", icon: "retry", shortcut: "Ctrl+R" },
        { id: "stop", label: "Stop", detail: "Cancel generation and desktop actions", icon: "stop", shortcut: "Esc" },
        { id: "export", label: "Export conversation", detail: "Save this chat as Markdown", icon: "download", shortcut: "" },
        { id: "duplicate", label: "Duplicate chat", detail: "Copy this conversation", icon: "duplicate", shortcut: "Ctrl+D" },
        { id: "pin", label: "Pin or unpin chat", detail: "Keep it at the top", icon: "pin", shortcut: "" },
        { id: "clear", label: "Clear messages", detail: "Empty this chat but keep it", icon: "trash", shortcut: "" },
        { id: "reconnect", label: "Reconnect to Ollama", detail: "Refresh models and status", icon: "bolt", shortcut: "" },
        { id: "terminal", label: "Open a terminal here", detail: "In the working folder", icon: "terminal", shortcut: "" },
    ]

    property var filtered: commands
    property int highlighted: 0

    function refilter() {
        var needle = search.text.toLowerCase();
        var out = [];
        for (var i = 0; i < commands.length; i++) {
            var item = commands[i];
            if (!needle || (item.label + " " + item.detail).toLowerCase().indexOf(needle) !== -1)
                out.push(item);
        }
        filtered = out;
        highlighted = 0;
    }

    onOpened: { search.text = ""; refilter(); search.forceActiveFocus(); }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s4
        spacing: Theme.s3

        Field {
            id: search
            Layout.fillWidth: true
            implicitHeight: 44
            iconName: "search"
            placeholderText: "Type a command…"
            font.pixelSize: Theme.body
            onTextChanged: palette.refilter()
            Keys.onDownPressed: palette.highlighted = Math.min(palette.highlighted + 1, palette.filtered.length - 1)
            Keys.onUpPressed: palette.highlighted = Math.max(palette.highlighted - 1, 0)
            Keys.onReturnPressed: palette.run()
            Keys.onEnterPressed: palette.run()
            Keys.onEscapePressed: palette.close()
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: palette.filtered
            currentIndex: palette.highlighted
            highlightMoveDuration: Theme.fast
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: 46
                radius: Theme.r2
                color: index === palette.highlighted ? Theme.surfaceSelected : "transparent"
                Rectangle {
                    // Shape as well as colour, so the keyboard position is
                    // obvious without relying on a background tint alone.
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: index === palette.highlighted ? 20 : 0
                    radius: 1
                    color: Theme.accent
                    Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s3
                    anchors.rightMargin: Theme.s3
                    spacing: Theme.s3
                    Icon {
                        name: modelData.icon
                        ink: index === palette.highlighted ? Theme.accent : Theme.textMuted
                        width: 16; height: 16
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: modelData.label; color: Theme.textPrimary
                            font.family: Theme.sansFamily; font.pixelSize: Theme.label
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.detail
                            // Muted text does not carry enough contrast on the
                            // highlighted surface, so the active row steps up.
                            color: index === palette.highlighted ? Theme.textSecondary : Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        visible: !!modelData.shortcut
                        width: shortcut.implicitWidth + Theme.s3; height: 20; radius: Theme.r1
                        color: Theme.surfaceSunken
                        Text {
                            id: shortcut
                            anchors.centerIn: parent
                            text: modelData.shortcut; color: Theme.textMuted
                            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: palette.highlighted = index
                    onClicked: { palette.invoked(modelData.id); palette.close(); }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No matching command"
                color: Theme.textMuted
                font.family: Theme.sansFamily; font.pixelSize: Theme.label
            }
        }
    }

    function run() {
        if (highlighted >= 0 && highlighted < filtered.length) {
            invoked(filtered[highlighted].id);
            close();
        }
    }
}
