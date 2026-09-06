import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*!
    A compact token: an attached piece of context, or a small inline control.

    Built on AbstractButton so an interactive chip is reachable by keyboard and
    announced as a button; a chip that only carries a remove action is not.
*/
AbstractButton {
    id: chip
    property string iconName: ""
    property string subtitle: ""
    property bool removable: false
    property bool interactive: true
    property bool selected: false
    property color tone: selected ? Theme.accent : Theme.textMuted
    signal removed()

    implicitHeight: Theme.controlSmall
    implicitWidth: layout.implicitWidth + leftPadding + rightPadding
    leftPadding: Theme.s2 + 2
    rightPadding: removable ? 2 : Theme.s2 + 2
    hoverEnabled: true
    enabled: interactive || removable
    focusPolicy: interactive ? Qt.StrongFocus : Qt.NoFocus
    Accessible.role: interactive ? Accessible.Button : Accessible.StaticText
    Accessible.name: subtitle ? text + ", " + subtitle : text
    ToolTip.delay: 500

    background: Rectangle {
        radius: Theme.r2
        color: chip.selected ? Theme.accentMuted
             : chip.hovered && chip.interactive ? Theme.surfaceHover : Theme.surfaceRaised
        border.width: 1
        border.color: chip.selected ? Theme.accentEdge
                    : chip.hovered && chip.interactive ? Theme.borderStrong : Theme.borderSubtle
        Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
        Behavior on border.color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            visible: chip.visualFocus
            border.width: 2
            border.color: Theme.accentEdge
        }
    }

    contentItem: RowLayout {
        id: layout
        spacing: Theme.s2

        Icon {
            visible: chip.iconName !== ""
            name: chip.iconName
            ink: chip.tone
            Layout.preferredWidth: 13; Layout.preferredHeight: 13
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: chip.text
            color: chip.selected ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.sansFamily; font.pixelSize: Theme.caption
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }
        Text {
            visible: chip.subtitle !== ""
            text: chip.subtitle
            color: Theme.textMuted
            font.family: Theme.sansFamily; font.pixelSize: Theme.micro
            elide: Text.ElideRight
            Layout.maximumWidth: 150
        }
        IconButton {
            visible: chip.removable
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            iconSize: 11
            iconName: "close"
            tooltip: "Remove " + chip.text
            onClicked: chip.removed()
        }
    }

    // A cursor only where there is something to click.
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: chip.removable ? 26 : 0
        acceptedButtons: Qt.NoButton
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
