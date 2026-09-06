import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Wynxo's terminal, as it happens.

    Every command the model runs appears here the moment it is asked for, with
    its output streaming in while it is still going and a line that closes it.
    Your own commands run in the same folder and land in the same transcript, so
    there is one record of what happened on this machine rather than two.

    Nothing here is a second permission surface: a command Wynxo asked for is
    already approved (or refused) in the conversation, and a command you type is
    yours, so it simply runs.
*/
Item {
    id: root

    readonly property bool busy: bridge ? bridge.terminalBusy : false
    // Follow the newest line only while you are already at the bottom; reading
    // something further up must not be yanked away by the next fragment.
    property bool following: true
    property var history: []
    property int historyIndex: -1

    function jumpToEnd() { list.positionViewAtEnd(); root.following = true; }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ where
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.rowHeight
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s2
            spacing: Theme.s2

            Icon { name: "folder"; ink: Theme.textMuted; width: 12; height: 12 }
            Text {
                Layout.fillWidth: true
                text: bridge ? bridge.terminalCwdLabel : ""
                color: Theme.textMuted
                font.family: Theme.monoFamily
                font.pixelSize: Theme.micro
                elide: Text.ElideLeft
                ToolTip.visible: cwdHover.hovered
                ToolTip.text: bridge ? bridge.terminalCwd : ""
                ToolTip.delay: 700
                HoverHandler { id: cwdHover }
            }
            IconButton {
                iconName: "stop"; iconSize: 12
                visible: root.busy
                tint: Theme.danger; activeTint: Theme.danger
                tooltip: "Stop this command"
                onClicked: if (bridge) bridge.stopTerminalCommand()
            }
            IconButton {
                iconName: "copy"; iconSize: 12
                tooltip: "Copy the whole transcript"
                enabled: bridge && !bridge.terminalEmpty
                onClicked: if (bridge) bridge.copyTerminal()
            }
            IconButton {
                iconName: "trash"; iconSize: 12
                tooltip: "Clear the transcript"
                enabled: bridge && !bridge.terminalEmpty
                onClicked: if (bridge) bridge.clearTerminal()
            }
        }

        Divider { Layout.fillWidth: true }

        // -------------------------------------------------------- the record
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceSunken

            ListView {
                id: list
                objectName: "terminalTranscript"
                anchors.fill: parent
                anchors.margins: Theme.s2
                clip: true
                spacing: 1
                model: bridge ? bridge.terminalModel : null
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                onCountChanged: if (root.following) positionViewAtEnd()
                onContentHeightChanged: if (root.following) positionViewAtEnd()
                onMovementEnded: root.following = atYEnd

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderStrong }
                }

                delegate: Item {
                    id: block
                    required property string kind
                    required property string text
                    required property string source
                    required property string status
                    required property bool truncated
                    width: list.width
                    height: body.implicitHeight + (kind === "command" ? Theme.s2 : 0)
                             + (truncated ? mark.implicitHeight : 0)

                    readonly property color tone: status === "failed" ? Theme.danger
                                                : status === "stopped" || status === "declined" ? Theme.warning
                                                : status === "ok" ? Theme.success : Theme.accent

                    Row {
                        id: body
                        width: parent.width
                        y: block.kind === "command" ? Theme.s2 : 0
                        spacing: Theme.s2

                        // The prompt says who asked without needing a column of
                        // its own: ">" is yours, "$" is Wynxo's.
                        Text {
                            visible: block.kind === "command"
                            text: block.source === "you" ? ">" : "$"
                            color: block.source === "you" ? Theme.accent : Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.caption
                            font.weight: Font.DemiBold
                            width: visible ? 10 : 0
                            ToolTip.visible: promptHover.hovered
                            ToolTip.text: block.source === "you" ? "You ran this" : "Wynxo ran this"
                            ToolTip.delay: 600
                            HoverHandler { id: promptHover }
                        }
                        Icon {
                            visible: block.kind === "note"
                            name: "launch"; ink: Theme.textMuted
                            width: visible ? 11 : 0; height: 11
                            y: 3
                        }
                        Rectangle {
                            visible: block.kind === "exit"
                            width: visible ? 5 : 0; height: 5; radius: 3
                            y: 6
                            color: block.tone
                        }

                        TextEdit {
                            width: body.width - (block.kind === "output" ? 0 : 18)
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            text: block.text
                            color: block.kind === "command" ? Theme.textPrimary
                                 : block.kind === "exit" ? block.tone
                                 : block.kind === "note" ? Theme.textSecondary
                                 : Theme.textSecondary
                            font.family: Theme.monoFamily
                            font.pixelSize: block.kind === "exit" ? Theme.micro : Theme.caption
                            font.weight: block.kind === "command" ? Font.Medium : Font.Normal
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.onAccent
                            Accessible.role: Accessible.StaticText
                            Accessible.name: (block.kind !== "command" ? ""
                                              : block.source === "you" ? "Your command: "
                                              : "Wynxo ran: ") + block.text
                        }

                        // A command with nothing under it yet still says it is on.
                        StatusDot {
                            visible: block.kind === "command" && block.status === "running"
                            width: visible ? 7 : 0; height: 7
                            y: 5
                            tone: Theme.accent
                            pulsing: true
                        }
                    }

                    Text {
                        id: mark
                        anchors.right: parent.right
                        anchors.top: body.bottom
                        visible: block.truncated
                        text: "output truncated"
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                    }
                }

                // ------------------------------------------------- nothing yet
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Theme.s4
                    spacing: Theme.s2
                    visible: list.count === 0
                    Text {
                        width: parent.width
                        text: "Nothing has run yet"
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: "Commands Wynxo runs show up here as they happen, "
                              + "output and all. You can type your own below — they run "
                              + "in the same folder."
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                        wrapMode: Text.WordWrap; lineHeight: 1.45
                    }
                }
            }

            // Reading further up should not mean missing what arrived.
            WButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.s3
                visible: !root.following && list.count > 0
                text: "Jump to the latest"
                iconName: "down"
                variant: "ghost"
                onClicked: root.jumpToEnd()
            }
        }

        Divider { Layout.fillWidth: true }

        // ------------------------------------------------------- your own turn
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s2
            spacing: Theme.s2

            Field {
                id: input
                objectName: "terminalInput"
                Layout.fillWidth: true
                mono: true
                iconName: "terminal"
                enabled: !root.busy
                placeholderText: root.busy ? "Running…" : "Run a command here"
                font.pixelSize: Theme.caption
                Keys.onReturnPressed: function(event) { root.submit(); event.accepted = true; }
                Keys.onEnterPressed: function(event) { root.submit(); event.accepted = true; }
                Keys.onUpPressed: function(event) { root.recall(-1); event.accepted = true; }
                Keys.onDownPressed: function(event) { root.recall(1); event.accepted = true; }
            }
            IconButton {
                iconName: root.busy ? "stop" : "arrow"
                iconSize: 13
                tooltip: root.busy ? "Stop this command" : "Run"
                tint: root.busy ? Theme.danger : Theme.textSecondary
                enabled: root.busy || input.text.trim().length > 0
                onClicked: root.busy ? bridge.stopTerminalCommand() : root.submit()
            }
        }
    }

    function submit() {
        if (!bridge || root.busy) return;
        var command = input.text.trim();
        if (!command) return;
        // One entry per distinct command, newest last, so Up walks backwards.
        var kept = [];
        for (var i = 0; i < root.history.length; i++)
            if (root.history[i] !== command) kept.push(root.history[i]);
        kept.push(command);
        root.history = kept.slice(-50);
        root.historyIndex = root.history.length;
        input.text = "";
        root.jumpToEnd();
        bridge.runTerminalCommand(command);
    }

    function recall(step) {
        if (root.history.length === 0) return;
        var index = root.historyIndex < 0 ? root.history.length : root.historyIndex;
        index = Math.max(0, Math.min(index + step, root.history.length));
        root.historyIndex = index;
        input.text = index >= root.history.length ? "" : root.history[index];
        input.cursorPosition = input.text.length;
    }

    function focusInput() { input.forceActiveFocus(); }
}
