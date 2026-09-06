import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    The dock's rail: one icon per tool, always on the right edge.

    The rail is the dock's affordance. It stays even when the panel is closed,
    so the tools are one click away and the window never loses its right-hand
    anchor. Clicking the tab that is already showing closes the panel — the same
    gesture opens and dismisses.

    Plan is intentionally a presentation tab rather than another backend tool.
    It shows the agent-authored, persisted execution plan while Activity remains
    the detailed audit trail of commands and desktop actions.
*/
Item {
    id: root
    property string current: ""
    property bool panelOpen: false
    property bool planSelected: false
    signal picked(string id)
    signal pickedPlan()
    signal toggleDock()

    implicitWidth: Theme.railWidth

    readonly property var entries: bridge && bridge.workspaceDock ? bridge.workspaceDock.tabs : []

    Rectangle {
        anchors.fill: parent
        color: Theme.backgroundSoft
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Theme.borderSubtle
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.s2
        anchors.bottomMargin: Theme.s2
        spacing: 2

        // Plan sits first because it describes the task itself; the remaining
        // tabs are concrete work surfaces used to carry that task out.
        AbstractButton {
            id: planTab
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 34
            implicitHeight: 34
            hoverEnabled: true
            readonly property bool chosen: root.panelOpen && root.planSelected

            Accessible.role: Accessible.Button
            Accessible.name: "Plan"
            Accessible.checked: chosen
            onClicked: root.pickedPlan()

            ToolTip.visible: hovered
            ToolTip.text: "Plan · live task steps"
            ToolTip.delay: 450

            background: Rectangle {
                radius: Theme.r2
                color: planTab.down ? Theme.surfacePressed
                     : planTab.chosen ? Theme.surfaceSelected
                     : planTab.hovered ? Theme.surfaceHover : "transparent"
                Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    visible: planTab.visualFocus
                    border.width: 2
                    border.color: Theme.accentEdge
                }
            }

            contentItem: Item {
                Icon {
                    anchors.centerIn: parent
                    name: "clipboard"
                    ink: planTab.chosen ? Theme.textPrimary
                       : planTab.hovered ? Theme.textSecondary : Theme.textMuted
                    width: 15; height: 15
                    weight: 1.7
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -Theme.s2 - 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: planTab.chosen ? 18 : 0
                radius: 1
                color: Theme.accent
                Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
            }

            // If a plan exists while the dock is closed, this tiny mark says
            // the task has structure without stealing the current workspace.
            Rectangle {
                visible: !root.panelOpen && bridge && bridge.planSteps && bridge.planSteps.length >= 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: 5; height: 5; radius: 2.5
                color: Theme.accent
            }

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
        }

        Repeater {
            model: root.entries
            delegate: AbstractButton {
                id: tab
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34
                implicitHeight: 34
                hoverEnabled: true
                readonly property bool chosen: root.panelOpen && !root.planSelected && root.current === modelData.id
                readonly property bool marked: !root.panelOpen && !root.planSelected && root.current === modelData.id

                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.checked: chosen
                onClicked: root.picked(modelData.id)

                ToolTip.visible: hovered
                ToolTip.text: modelData.label + " · " + modelData.shortcut
                ToolTip.delay: 450

                background: Rectangle {
                    radius: Theme.r2
                    color: tab.down ? Theme.surfacePressed
                         : tab.chosen ? Theme.surfaceSelected
                         : tab.hovered ? Theme.surfaceHover : "transparent"
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        visible: tab.visualFocus
                        border.width: 2
                        border.color: Theme.accentEdge
                    }
                }

                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        name: tab.modelData.icon
                        ink: tab.chosen ? Theme.textPrimary
                           : tab.hovered || tab.marked ? Theme.textSecondary : Theme.textMuted
                        width: 15; height: 15
                        weight: 1.7
                    }
                }

                // The open tab keeps a short accent marker on the window edge.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.s2 - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: tab.chosen ? 18 : 0
                    radius: 1
                    color: Theme.accent
                    Behavior on height { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                }

                // Unread-style dot: the panel has something new while closed.
                Rectangle {
                    visible: !root.panelOpen && tab.modelData.id === "activity"
                             && bridge && bridge.workspaceDock && bridge.workspaceDock.activityRunning
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: 5; height: 5; radius: 2.5
                    color: Theme.accent
                }

                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.PointingHandCursor }
            }
        }

        Item { Layout.fillHeight: true }

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            width: 30; height: 30
            iconSize: 13
            iconName: root.panelOpen ? "forward" : "back"
            tooltip: root.panelOpen ? "Close the workspace dock" : "Open the workspace dock"
            shortcut: "Ctrl+Shift+B"
            onClicked: root.toggleDock()
        }
    }
}
