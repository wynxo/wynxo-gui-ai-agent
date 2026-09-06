import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A page, inside Wynxo.

    Wynxo can put something in front of you here — documentation it wants you to
    read, a local service it just started — and you can drive it yourself. The
    page is shown, never scraped: nothing on it is fed back to the model, so a
    page cannot tell Wynxo what to do next.

    Qt WebEngine is an optional part of PySide6, so this may have no engine to
    render with. That case is stated plainly and the page is handed to the
    browser you already use, rather than pretending nothing was asked for.
*/
Item {
    id: root

    readonly property bool ready: bridge ? bridge.browserAvailable : false
    readonly property string address: bridge ? bridge.browserUrl : ""
    // The live page, once one is loaded; null whenever there is nothing to drive.
    readonly property var page: pageLoader.status === Loader.Ready ? pageLoader.item : null

    onAddressChanged: field.text = address

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- controls
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.rowHeight + Theme.s2
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s2
            spacing: Theme.s1

            IconButton {
                iconName: "chevronLeft"; iconSize: 13
                tooltip: "Back"
                enabled: root.page && root.page.canGoBack
                visible: root.ready
                onClicked: root.page.back()
            }
            IconButton {
                iconName: "chevron"; iconSize: 13
                tooltip: "Forward"
                enabled: root.page && root.page.canGoForward
                visible: root.ready
                onClicked: root.page.forward()
            }
            IconButton {
                iconName: root.page && root.page.loading ? "close" : "retry"
                iconSize: 12
                tooltip: root.page && root.page.loading ? "Stop loading" : "Reload"
                enabled: !!root.page
                visible: root.ready
                onClicked: root.page.loading ? root.page.stopLoading() : root.page.reload()
            }

            Field {
                id: field
                objectName: "browserAddress"
                Layout.fillWidth: true
                iconName: "globe"
                mono: true
                placeholderText: "example.com"
                font.pixelSize: Theme.caption
                Component.onCompleted: text = root.address
                Keys.onReturnPressed: function(event) { root.go(); event.accepted = true; }
                Keys.onEnterPressed: function(event) { root.go(); event.accepted = true; }
                Keys.onEscapePressed: function(event) { text = root.address; event.accepted = true; }
            }

            IconButton {
                iconName: "launch"; iconSize: 12
                tooltip: "Open in your own browser"
                enabled: root.address !== ""
                onClicked: if (bridge) bridge.openBrowserExternally()
            }
        }

        // A thin line is enough to say a page is still arriving.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: "transparent"
            visible: !!root.page && root.page.loading
            Rectangle {
                height: parent.height
                width: parent.width * (root.page ? root.page.progress : 0)
                color: Theme.accent
                Behavior on width { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast } }
            }
        }

        Divider { Layout.fillWidth: true }

        // ------------------------------------------------------- the page
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface

            // The web view lives in its own file so that a PySide6 without Qt
            // WebEngine fails to load one component instead of the whole panel.
            Loader {
                id: pageLoader
                anchors.fill: parent
                active: root.ready && root.address !== ""
                source: active ? "WebPage.qml" : ""
                onLoaded: item.target = root.address
                Binding {
                    target: pageLoader.item
                    property: "target"
                    value: root.address
                    when: pageLoader.status === Loader.Ready
                }
            }

            // ------------------------------------------------ nothing loaded
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - Theme.s7, 360)
                spacing: Theme.s3
                visible: pageLoader.status !== Loader.Ready

                Icon {
                    name: "globe"; ink: Theme.textMuted
                    width: 22; height: 22
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: !root.ready ? "No built-in browser"
                        : root.address === "" ? "No page open"
                        : "That page could not be shown here"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: !root.ready
                        ? "Qt WebEngine is not installed, so pages open in your own browser instead. "
                          + "Installing the full PySide6 package brings the view back."
                        : root.address === ""
                        ? "Type an address above, or ask Wynxo to open one for you. "
                          + "Nothing on the page is read back into the conversation."
                        : "Try opening it in your own browser."
                    color: Theme.textMuted
                    font.family: Theme.sansFamily; font.pixelSize: Theme.caption
                    wrapMode: Text.WordWrap; lineHeight: 1.45
                }
                WButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.address !== ""
                    text: "Open in your browser"
                    iconName: "launch"
                    variant: "ghost"
                    onClicked: if (bridge) bridge.openBrowserExternally()
                }
            }
        }
    }

    function go() {
        if (bridge) bridge.navigate(field.text);
    }

    function focusAddress() { field.forceActiveFocus(); field.selectAll(); }
}
