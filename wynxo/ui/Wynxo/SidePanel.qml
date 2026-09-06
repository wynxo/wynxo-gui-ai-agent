import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The machine's side of the conversation.

    The left sidebar answers "where am I"; the conversation answers "what did we
    say". This answers "what is actually happening on this computer" — the
    commands Wynxo ran and their output as it arrives, the folder it is working
    in, and any page it put on screen.

    It never switches tabs by itself. A tab you are not watching counts what it
    has to tell you and waits; moving the view is the user's decision, the same
    rule the rest of the shell follows.
*/
Item {
    id: root
    signal closeRequested()

    readonly property var tabs: bridge ? bridge.panelTabs : []
    readonly property string current: bridge ? bridge.panelTab : "terminal"

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------ the switcher
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.compact ? 46 : 52
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s2
            spacing: Theme.s1

            Repeater {
                model: root.tabs
                delegate: AbstractButton {
                    id: tab
                    required property var modelData
                    readonly property bool selected: modelData.id === root.current
                    Layout.preferredHeight: Theme.controlSmall
                    implicitWidth: tabRow.implicitWidth + Theme.s3 * 2
                    hoverEnabled: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.unseen > 0
                                     ? modelData.label + ", " + modelData.unseen + " new"
                                     : modelData.label
                    Accessible.checked: selected
                    onClicked: if (bridge) bridge.setPanelTab(modelData.id)

                    background: Rectangle {
                        radius: Theme.r2
                        color: tab.selected ? Theme.surfaceSelected
                             : tab.hovered ? Theme.surfaceHover : "transparent"
                        border.width: tab.visualFocus ? 2 : 0
                        border.color: Theme.accentEdge
                        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    }

                    contentItem: Row {
                        id: tabRow
                        spacing: Theme.s2
                        Icon {
                            name: tab.modelData.icon
                            ink: tab.selected ? Theme.textPrimary : Theme.textMuted
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: tab.modelData.label
                            color: tab.selected ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.caption
                            font.weight: tab.selected ? Font.DemiBold : Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        // What happened while you were looking somewhere else.
                        Rectangle {
                            visible: tab.modelData.unseen > 0 && !tab.selected
                            width: 6; height: 6; radius: 3
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                objectName: "panelCloseButton"
                iconName: "close"
                iconSize: 13
                tooltip: "Hide the panel"
                shortcut: "Ctrl+J"
                onClicked: root.closeRequested()
            }
        }

        Divider { Layout.fillWidth: true }

        // -------------------------------------------------------- the surface
        // All three stay loaded: a terminal that forgets where it scrolled to,
        // or a page that reloads every time you glance at the files, would make
        // the panel useless for watching a run.
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                for (var i = 0; i < root.tabs.length; i++)
                    if (root.tabs[i].id === root.current) return i;
                return 0;
            }

            TerminalView { objectName: "panelTerminal" }
            FilesView { objectName: "panelFiles" }
            BrowserView { objectName: "panelBrowser" }
        }
    }
}
