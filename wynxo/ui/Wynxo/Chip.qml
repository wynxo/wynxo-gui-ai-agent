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

    background: GlassSurface {
        radius: Theme.rPill
        tint: chip.selected ? Theme.accent
             : chip.hovered && chip.interactive ? Theme.glassTintHover : Theme.glassTint
        fillOpacity: chip.selected ? 0.14
                   : chip.hovered && chip.interactive ? 0.62 : Theme.glassThinOpacity
        strongEdge: chip.selected || (chip.hovered && chip.interactive)
        active: chip.visualFocus
        edgeColor: chip.visualFocus ? Theme.accentEdge
                 : chip.selected ? Theme.accentEdge
                 : chip.hovered && chip.interactive ? Theme.glassEdgeStrong : Theme.glassEdge
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
