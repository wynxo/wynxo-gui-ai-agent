import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The folder Wynxo is working in.

    A tree rooted at the project — your home folder when there is no project —
    and a read-only preview of whatever you click. Read-only is the point: the
    panel is for seeing what Wynxo is touching, and a file is changed by asking
    for it, not by a second editor nobody watches.

    Any file here can go straight to the composer as context, which is the one
    thing the file list used to make you do by hand.
*/
Item {
    id: root

    readonly property bool previewing: bridge ? bridge.previewActive : false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------- where
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.rowHeight
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s2
            spacing: Theme.s2

            Icon {
                name: bridge && bridge.projectPath ? "folderOpen" : "folder"
                ink: Theme.textMuted; width: 12; height: 12
            }
            Text {
                Layout.fillWidth: true
                text: bridge ? bridge.fileRootLabel : ""
                color: Theme.textSecondary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.micro
                elide: Text.ElideLeft
                ToolTip.visible: rootHover.hovered
                ToolTip.text: bridge ? bridge.fileRoot : ""
                ToolTip.delay: 700
                HoverHandler { id: rootHover }
            }
            IconButton {
                iconName: "eye"; iconSize: 12
                active: bridge && bridge.showHiddenFiles
                tooltip: bridge && bridge.showHiddenFiles ? "Hide dotfiles" : "Show dotfiles"
                onClicked: if (bridge) bridge.setShowHiddenFiles(!bridge.showHiddenFiles)
            }
            IconButton {
                iconName: "retry"; iconSize: 12
                tooltip: "Read the folder again"
                onClicked: if (bridge) bridge.refreshFiles()
            }
            IconButton {
                iconName: "launch"; iconSize: 12
                tooltip: "Open in your file manager"
                onClicked: if (bridge) bridge.revealPath(bridge.fileRoot)
            }
        }

        Divider { Layout.fillWidth: true }

        // -------------------------------------------------------- the tree
        ListView {
            id: tree
            objectName: "fileTree"
            Layout.fillWidth: true
            Layout.fillHeight: !root.previewing
            Layout.preferredHeight: root.previewing ? Math.round(root.height * 0.4) : -1
            Layout.topMargin: Theme.s1
            clip: true
            model: bridge ? bridge.fileRows : []
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 3; radius: 2; color: Theme.borderSubtle }
            }

            delegate: AbstractButton {
                id: entry
                required property var modelData
                width: tree.width
                height: Theme.compact ? 24 : 27
                hoverEnabled: true
                readonly property bool selected: !modelData.dir && bridge
                                                 && bridge.previewPath === modelData.path
                Accessible.name: (modelData.dir ? "Folder " : "File ") + modelData.name
                onClicked: {
                    if (!bridge) return;
                    if (modelData.dir) bridge.toggleFolder(modelData.rel);
                    else bridge.openInPanel(modelData.path);
                }

                background: Rectangle {
                    color: entry.selected ? Theme.surfaceSelected
                         : entry.hovered ? Theme.surfaceHover : "transparent"
                    border.width: entry.visualFocus ? 2 : 0
                    border.color: Theme.accentEdge
                }

                contentItem: Row {
                    leftPadding: Theme.s3 + entry.modelData.depth * 12
                    rightPadding: Theme.s3
                    spacing: Theme.s2

                    Icon {
                        visible: entry.modelData.dir
                        name: "chevron"
                        ink: Theme.textMuted
                        width: visible ? 9 : 0; height: 9
                        rotation: entry.modelData.expanded ? 90 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on rotation { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
                    }
                    Item { width: entry.modelData.dir ? 0 : 9; height: 1 }
                    Icon {
                        name: entry.modelData.dir ? (entry.modelData.expanded ? "folderOpen" : "folder") : "file"
                        ink: entry.modelData.dir ? Theme.textSecondary : Theme.textMuted
                        width: 12; height: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: entry.modelData.name
                        color: entry.modelData.dir ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.caption
                        font.weight: entry.modelData.dir ? Font.Medium : Font.Normal
                        elide: Text.ElideMiddle
                        width: Math.min(implicitWidth, entry.width - Theme.s6 - entry.modelData.depth * 12 - 60)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: entry.modelData.subtitle
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        visible: entry.hovered && !!text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }

            Column {
                anchors.top: parent.top
                anchors.topMargin: Theme.s4
                x: Theme.s3
                width: parent.width - Theme.s6
                spacing: Theme.s2
                visible: tree.count === 0
                Text {
                    width: parent.width
                    text: "Nothing to show"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: "This folder is empty, or everything in it is hidden. "
                          + "Caches and dependency folders are always left out."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.45
                }
            }
        }

        // ------------------------------------------------------- the preview
        Divider { Layout.fillWidth: true; visible: root.previewing }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: root.previewing
            visible: root.previewing
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.rowHeight
                Layout.leftMargin: Theme.s3
                Layout.rightMargin: Theme.s2
                spacing: Theme.s2

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: bridge ? bridge.previewName : ""
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily; font.pixelSize: Theme.label
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !!text
                        text: {
                            if (!bridge) return "";
                            var parts = [];
                            if (bridge.previewLanguage) parts.push(bridge.previewLanguage);
                            if (bridge.previewSubtitle) parts.push(bridge.previewSubtitle);
                            return parts.join(" · ");
                        }
                        color: Theme.textMuted
                        font.family: Theme.sansFamily; font.pixelSize: Theme.micro
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    iconName: "paperclip"; iconSize: 12
                    tooltip: "Attach to the conversation"
                    onClicked: if (bridge) bridge.attachFromPanel(bridge.previewPath)
                }
                IconButton {
                    iconName: "copy"; iconSize: 12
                    tooltip: "Copy the text"
                    visible: bridge && !bridge.previewIsImage
                    onClicked: if (bridge) bridge.copyPreview()
                }
                IconButton {
                    iconName: "close"; iconSize: 12
                    tooltip: "Close the preview"
                    onClicked: if (bridge) bridge.closePreview()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surfaceSunken

                // Something unreadable says so rather than showing an empty box.
                Text {
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    visible: bridge && bridge.previewError !== ""
                    text: bridge ? bridge.previewError : ""
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.45
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    visible: bridge && bridge.previewIsImage && bridge.previewImage !== ""
                    source: bridge && bridge.previewImage ? bridge.previewImage : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                // Code keeps its own line breaks and scrolls both ways rather
                // than reflowing an expression across the panel's narrow width.
                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    visible: bridge && !bridge.previewIsImage && bridge.previewError === ""
                    clip: true
                    contentWidth: previewText.implicitWidth
                    contentHeight: previewText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    TextEdit {
                        id: previewText
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.RichText
                        text: bridge ? bridge.previewHtml : ""
                        color: Theme.codePalette.text
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.caption
                        wrapMode: TextEdit.NoWrap
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        Accessible.role: Accessible.StaticText
                        Accessible.name: bridge ? "Preview of " + bridge.previewName : ""
                    }
                }
            }
        }
    }
}
