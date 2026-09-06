import QtQuick
import QtQuick.Controls

/*!
    A small anchored surface for details that do not deserve a whole panel:
    context previews, the model picker, run details.

    Like WMenu it flips and pulls back to stay inside the window; unlike a
    sheet it never dims the app, because it is a glance, not a decision.
*/
Popup {
    id: popover
    default property alias body: holder.data
    property string preferredEdge: "below"
    property int gap: Theme.s2
    property alias title: heading.text

    padding: Theme.s4
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent | Popup.CloseOnPressOutside

    // Keep the surface inside the window: flip vertically, and pull back
    // horizontally, instead of drawing half of it outside the frame.
    // Everything is derived from `anchorX` rather than from the current `x`,
    // so opening the same popover twice puts it in the same place.
    property real anchorX: 0
    function place() {
        if (!parent || !Overlay.overlay) return;
        var below = parent.mapToItem(Overlay.overlay, 0, parent.height + gap);
        var above = parent.mapToItem(Overlay.overlay, 0, -implicitHeight - gap);
        var wantAbove = preferredEdge === "above";
        if (wantAbove && above.y < 0 && below.y + implicitHeight <= Overlay.overlay.height) wantAbove = false;
        else if (!wantAbove && below.y + implicitHeight > Overlay.overlay.height && above.y >= 0) wantAbove = true;
        y = wantAbove ? -implicitHeight - gap : parent.height + gap;

        var left = parent.mapToItem(Overlay.overlay, 0, 0).x;
        var wanted = anchorX;
        var overflow = left + wanted + width - Overlay.overlay.width + Theme.s2;
        if (overflow > 0) wanted -= overflow;
        x = Math.max(-left + Theme.s2, wanted);
    }

    onAboutToShow: place()

    background: Rectangle {
        radius: Theme.r3
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.borderStrong
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
            NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: Theme.fast; easing.type: Theme.easing }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast } }

    contentItem: Item {
        implicitWidth: holder.implicitWidth
        implicitHeight: heading.height + (heading.visible ? Theme.s3 : 0) + holder.implicitHeight

        SectionLabel {
            id: heading
            width: parent.width
            visible: text !== ""
            height: visible ? implicitHeight : 0
        }
        Item {
            id: holder
            anchors.top: heading.bottom
            anchors.topMargin: heading.visible ? Theme.s3 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }
}
