import QtQuick
import QtQuick.Controls

/*! Segmented selector with a sliding indicator. Model entries: {id,label}. */
Item {
    id: root
    property var options: []
    property string current: ""
    signal selected(string value)

    implicitHeight: Theme.control
    implicitWidth: row.implicitWidth + 6

    readonly property int currentIndex: {
        for (var i = 0; i < options.length; i++)
            if (options[i].id === current) return i;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.r2
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderSubtle
    }

    Rectangle {
        id: indicator
        y: 3; height: parent.height - 6
        radius: Theme.r1
        color: Theme.surfaceSelected
        width: repeater.count > 0 ? (root.width - 6) / repeater.count : 0
        x: 3 + width * root.currentIndex
        Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.base; easing.type: Theme.easing } }
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        Repeater {
            id: repeater
            model: root.options
            delegate: Item {
                required property var modelData
                required property int index
                width: root.width > 0 ? (root.width - 6) / repeater.count : label.implicitWidth + Theme.s5
                height: parent.height
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: index === root.currentIndex ? Theme.textPrimary : Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.caption
                    font.weight: index === root.currentIndex ? Font.DemiBold : Font.Medium
                    Behavior on color { enabled: !Theme.reducedMotion; ColorAnimation { duration: Theme.fast } }
                }
                activeFocusOnTab: true
                Keys.onReturnPressed: root.selected(modelData.id)
                Keys.onSpacePressed: root.selected(modelData.id)
                Rectangle {
                    anchors.fill: parent; radius: Theme.r1; color: "transparent"
                    border.width: parent.activeFocus ? 2 : 0; border.color: Theme.accent
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: index === root.currentIndex
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(modelData.id)
                    hoverEnabled: true
                    ToolTip.visible: containsMouse && !!modelData.detail
                    ToolTip.text: modelData.detail || ""
                    ToolTip.delay: 500
                }
            }
        }
    }
}
