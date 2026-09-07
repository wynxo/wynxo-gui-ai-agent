import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    One open file: code with line numbers, an image, or an honest refusal.

    It is a viewer that can also save. Editing is a plain monospaced buffer with
    an unsaved marker — not a half-built IDE. What it does, it does properly:
    the gutter stays aligned, long lines scroll rather than wrap by default, and
    the file on disk is never touched until you ask.
*/
Item {
    id: root
    signal closed()

    readonly property var dock: bridge ? bridge.workspaceDock : null
    readonly property var record: dock ? dock.file : ({})
    readonly property bool hasFile: !!(record && record.path)
    readonly property bool isImage: hasFile && !!record.image
    readonly property bool readable: hasFile && !record.error && !record.binary && !record.image
    readonly property bool editable: readable && !record.truncated
    readonly property bool dirty: !!(dock && dock.fileModified)
    property bool wrap: false
    property bool editing: false
    property bool findOpen: false
    property int findPosition: -1

    // Built once per file rather than on every repaint. Wrapping hides the
    // gutter, because a wrapped line no longer matches a numbered row.
    readonly property string numbers: {
        var total = root.readable ? Math.min(root.record.lines || 0, 50000) : 0;
        if (!total) return "";
        var out = [];
        for (var line = 1; line <= total; line++) out.push(line);
        return out.join("\n");
    }

    // Loading a different file replaces the buffer; typing in it does not.
    property string loadedPath: ""
    onRecordChanged: {
        if (record.path !== loadedPath) {
            loadedPath = record.path || "";
            editor.text = record.text || "";
            root.editing = false;
            root.findPosition = -1;
            findInput.text = "";
            root.findOpen = false;
        }
    }

    function save() { if (dock && root.editable) dock.saveFile(); }
    function openFind() {
        if (!readable) return;
        findOpen = true;
        Qt.callLater(function () { findInput.forceActiveFocus(); findInput.selectAll(); });
    }
    function closeFind() {
        findOpen = false;
        findPosition = -1;
        editor.deselect();
        editor.forceActiveFocus();
    }
    function findNext(backwards) {
        var needle = findInput.text;
        if (!needle || !readable) {
            findPosition = -1;
            editor.deselect();
            return;
        }
        var haystack = editor.text.toLowerCase();
        var query = needle.toLowerCase();
        var position = -1;
        if (backwards) {
            var before = findPosition > 0 ? findPosition - 1 : haystack.length;
            position = haystack.lastIndexOf(query, before);
            if (position < 0) position = haystack.lastIndexOf(query);
        } else {
            var after = findPosition >= 0 ? findPosition + query.length : 0;
            position = haystack.indexOf(query, after);
            if (position < 0) position = haystack.indexOf(query);
        }
        findPosition = position;
        if (position >= 0) {
            editor.select(position, position + query.length);
            editor.cursorPosition = position + query.length;
        } else {
            editor.deselect();
        }
    }

    Shortcut {
        sequences: ["Ctrl+F"]
        enabled: root.readable
        onActivated: root.openFind()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            title: root.hasFile ? (record.name + (root.dirty ? " •" : "")) : "No file open"
            detail: root.hasFile
                ? (record.relative && record.relative !== record.name
                   ? record.relative : record.sizeLabel)
                : ""
            detailFont: "mono"
            detailElide: Text.ElideLeft

            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.dirty
                iconName: "save"
                tooltip: "Save"
                shortcut: "Ctrl+S"
                tint: Theme.accent
                activeTint: Theme.accent
                onClicked: root.save()
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.dirty
                iconName: "revert"
                tooltip: "Discard unsaved edits"
                onClicked: if (root.dock) { root.dock.revertFileBuffer(); editor.text = root.record.text || ""; }
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.readable
                iconName: "search"
                tooltip: "Find in file"
                shortcut: "Ctrl+F"
                active: root.findOpen
                onClicked: root.findOpen ? root.closeFind() : root.openFind()
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.readable
                iconName: "wrap"
                tooltip: root.wrap ? "Stop wrapping long lines" : "Wrap long lines"
                active: root.wrap
                onClicked: root.wrap = !root.wrap
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.readable
                iconName: "copy"
                tooltip: "Copy the whole file"
                onClicked: if (bridge) bridge.copyText(editor.text)
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.hasFile
                iconName: "launch"
                tooltip: "Open outside Wynxo"
                onClicked: if (bridge) bridge.revealPath(root.record.path)
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.hasFile
                iconName: "close"
                tooltip: "Close file"
                onClicked: root.closed()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.findOpen ? Theme.control + Theme.s2 : 0
            visible: root.findOpen
            color: Theme.backgroundSoft
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Theme.borderSubtle
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s2
                anchors.rightMargin: Theme.s2
                anchors.topMargin: Theme.s1
                anchors.bottomMargin: Theme.s1
                spacing: Theme.s1

                Field {
                    id: findInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.controlSmall
                    iconName: "search"
                    placeholderText: "Find in file"
                    onTextChanged: {
                        root.findPosition = -1;
                        if (text.length) root.findNext(false);
                        else editor.deselect();
                    }
                    Keys.onReturnPressed: function(event) {
                        root.findNext(!!(event.modifiers & Qt.ShiftModifier));
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: function(event) { root.closeFind(); event.accepted = true; }
                }
                Text {
                    text: findInput.text.length && root.findPosition < 0 ? "No match" : ""
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
                IconButton {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    iconName: "up"; iconSize: 11
                    tooltip: "Previous match"
                    enabled: findInput.text.length > 0
                    onClicked: root.findNext(true)
                }
                IconButton {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    iconName: "down"; iconSize: 11
                    tooltip: "Next match"
                    enabled: findInput.text.length > 0
                    onClicked: root.findNext(false)
                }
                IconButton {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                    iconName: "close"; iconSize: 11
                    tooltip: "Close find"
                    onClicked: root.closeFind()
                }
            }
        }

        // -------------------------------------------------------- the code
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceSunken
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                visible: root.readable
                contentWidth: Math.max(width, editor.x + editor.contentWidth + Theme.s4)
                contentHeight: Math.max(height, editor.contentHeight + Theme.s3 * 2)
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.borderStrong }
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: root.wrap ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitHeight: 4; radius: 2; color: Theme.borderStrong }
                }

                // One Text, not one per line: a 12 000-line file would
                // otherwise put 12 000 items in the scene graph. The same font
                // and line height as the editor keeps the two in step.
                Text {
                    id: gutter
                    x: 0
                    y: Theme.s3
                    width: Math.max(30, numberMetrics.width + Theme.s3)
                    visible: root.readable && !root.wrap
                    rightPadding: Theme.s2
                    horizontalAlignment: Text.AlignRight
                    text: root.numbers
                    color: Theme.textDisabled
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.code
                    textFormat: Text.PlainText
                }

                TextMetrics {
                    id: numberMetrics
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.code
                    text: String(Math.max(1000, root.record.lines || 1000))
                }

                TextEdit {
                    id: editor
                    objectName: "fileEditor"
                    x: gutter.visible ? gutter.width : Theme.s3
                    y: Theme.s3
                    width: root.wrap ? flick.width - x - Theme.s3
                                     : Math.max(contentWidth, flick.width - x)
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.code
                    selectByMouse: true
                    readOnly: !root.editable
                    wrapMode: root.wrap ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                    textFormat: TextEdit.PlainText
                    persistentSelection: true
                    Accessible.role: root.editable ? Accessible.EditableText : Accessible.StaticText
                    Accessible.name: root.hasFile ? root.record.name : "File contents"

                    onTextChanged: if (root.dock && root.loadedPath && root.editable) root.dock.setFileBuffer(text)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                            root.save();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                            root.openFind();
                            event.accepted = true;
                        }
                    }
                }
            }

            // ------------------------------------------------------ image
            Item {
                anchors.fill: parent
                anchors.margins: Theme.s4
                visible: root.isImage
                Image {
                    id: preview
                    anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth)
                    height: Math.min(parent.height, implicitHeight)
                    source: root.isImage ? "data:image/" + (root.record.imageFormat || "png")
                                           + ";base64," + root.record.image : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    visible: preview.status === Image.Ready
                    text: preview.sourceSize.width + " × " + preview.sourceSize.height
                          + (root.record.sizeLabel ? " · " + root.record.sizeLabel : "")
                    color: Theme.textMuted
                    font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: root.hasFile && !!root.record.error
                iconName: root.record.binary ? "lock" : "warning"
                title: root.record.binary ? "Not a text file" : "Could not open this file"
                detail: root.record.error || ""
                actionText: "Open outside Wynxo"
                onActionInvoked: if (bridge) bridge.revealPath(root.record.path)
            }

            EmptyState {
                anchors.fill: parent
                visible: !root.hasFile
                iconName: "file"
                title: "No file open"
                detail: "Pick a file in the tree above to read or edit it here."
            }
        }

        // ----------------------------------------------- read-only preview
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.record.truncated ? 30 : 0
            visible: !!root.record.truncated
            color: Theme.backgroundSoft
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1; color: Theme.borderSubtle
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s3
                spacing: Theme.s2
                Icon {
                    name: "lock"
                    ink: Theme.textMuted
                    Layout.preferredWidth: 11
                    Layout.preferredHeight: 11
                }
                Text {
                    Layout.fillWidth: true
                    text: "Large-file preview · read-only to protect content not loaded into the editor"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.micro
                    elide: Text.ElideRight
                }
            }
        }

        // -------------------------------------------------- unsaved banner
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.dirty ? 30 : 0
            visible: root.dirty
            color: Theme.warningMuted
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1; color: Theme.alpha(Theme.warning, 0.3)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s2
                spacing: Theme.s2
                Icon { name: "edit"; ink: Theme.warning; Layout.preferredWidth: 11; Layout.preferredHeight: 11 }
                Text {
                    Layout.fillWidth: true
                    text: "Unsaved changes"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                }
                WButton {
                    text: "Save"
                    variant: "primary"
                    compactPadding: true
                    implicitHeight: 22
                    font.pixelSize: Theme.micro
                    onClicked: root.save()
                }
            }
        }
    }
}