import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    Whatever is worth looking at rather than reading: an image, a capture, a
    rendered Markdown note.

    It only shows something when something has been put here — an image opened
    from the tree, a screenshot taken during a run. There is no placeholder
    preview, because a preview of nothing is not a feature.
*/
Item {
    id: root
    readonly property var dock: bridge ? bridge.workspaceDock : null
    readonly property var item: dock ? dock.preview : ({})
    readonly property string kind: item && item.kind ? item.kind : ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            title: "Preview"
            detail: root.item && root.item.title ? root.item.title : ""

            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.kind === "image" && !!root.item.path
                iconName: "launch"
                tooltip: "Open outside Wynxo"
                onClicked: if (bridge) bridge.revealPath(root.item.path)
            }
            IconButton {
                width: 28; height: 28; iconSize: 12
                visible: root.kind !== ""
                iconName: "close"
                tooltip: "Clear the preview"
                onClicked: if (root.dock) root.dock.clearPreview()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceSunken
            clip: true

            // ------------------------------------------------------ image
            Item {
                anchors.fill: parent
                anchors.margins: Theme.s4
                visible: root.kind === "image"

                Image {
                    id: picture
                    anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth)
                    height: Math.min(parent.height, implicitHeight)
                    source: root.kind === "image" && root.item.image
                            ? "data:image/png;base64," + root.item.image : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    visible: picture.status === Image.Ready
                    text: picture.sourceSize.width + " × " + picture.sourceSize.height
                    color: Theme.textMuted
                    font.family: Theme.monoFamily; font.pixelSize: Theme.micro
                }
            }

            // ------------------------------------------- markdown and text
            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.s4
                visible: root.kind === "markdown" || root.kind === "text"
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Markdown {
                    width: parent.width
                    visible: root.kind === "markdown"
                    text: root.kind === "markdown" ? (root.item.body || "") : ""
                }
            }

            Text {
                anchors.fill: parent
                anchors.margins: Theme.s4
                visible: root.kind === "text"
                text: root.item && root.item.body ? root.item.body : ""
                textFormat: Text.PlainText
                color: Theme.textSecondary
                font.family: Theme.monoFamily; font.pixelSize: Theme.code
                wrapMode: Text.WordWrap
            }

            EmptyState {
                anchors.fill: parent
                visible: root.kind === ""
                iconName: "image"
                title: "Nothing to preview"
                detail: "Open an image from the file tree, or take a screenshot, and it appears here full size."
            }
        }
    }
}
