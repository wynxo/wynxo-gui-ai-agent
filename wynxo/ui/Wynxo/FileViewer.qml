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
    readonly property bool dirty: !!(dock && dock.fileModified)
    property bool wrap: false
    property bool editing: false

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
        }
    }

    function save() { if (dock) dock.saveFile(); }

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
                    wrapMode: root.wrap ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                    textFormat: TextEdit.PlainText
                    persistentSelection: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: root.hasFile ? root.record.name : "File contents"

                    onTextChanged: if (root.dock && root.loadedPath) root.dock.setFileBuffer(text)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                            root.save();
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
