import QtQuick
import QtQuick.Layouts
import qs.config
import qs.widgets

// A drawer that grows out of the frame. It lives in Surface's inner clip area (the screen below
// the bar), so while it slides it seems to come out from under the edge it belongs to.
//   kind "top"     hangs from the bar at dx
//   kind "corner"  sits in the top-right corner against the right edge
//   kind "bottom"  rises from the bottom edge at dx
// It carries an extra `ext` px hidden under the edge, so the spring's overshoot never opens a gap.
Item {
    id: root
    property string kind: "top"
    property bool open: false
    property real dx: 0
    property real dw: 420
    property real maxH: height - 40
    property int pad: 20
    property alias spacing: col.spacing
    default property alias content: col.data

    readonly property real ext: 26
    readonly property real r: Theme.frameR
    readonly property real bodyH: Math.min(maxH, col.implicitHeight + pad * 2)
    readonly property real bx: kind === "corner" ? width - Theme.edge - dw : dx
    readonly property bool shown: open || slide.running

    anchors.fill: parent
    visible: shown

    property real p: open ? 1 : 0
    Behavior on p {
        NumberAnimation {
            id: slide
            duration: root.open ? 540 : 240
            easing.type: root.open ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.05
        }
    }

    readonly property real yOpen: kind === "bottom" ? height - bodyH : -ext
    readonly property real yShut: kind === "bottom" ? height + 12 : -(bodyH + ext) - 12

    // Concave joins with the frame. The fixed ones fade in once the drawer has arrived.
    Fillet { x: root.bx - root.r; y: 0; corner: "bl"; visible: root.kind !== "bottom"; opacity: Math.max(0, (root.p - 0.8) * 5) }
    Fillet { x: root.bx + root.dw; y: 0; corner: "br"; visible: root.kind === "top"; opacity: Math.max(0, (root.p - 0.8) * 5) }
    Fillet { x: root.bx - root.r; y: root.height - root.r; corner: "tl"; visible: root.kind === "bottom"; opacity: Math.max(0, (root.p - 0.8) * 5) }
    Fillet { x: root.bx + root.dw; y: root.height - root.r; corner: "tr"; visible: root.kind === "bottom"; opacity: Math.max(0, (root.p - 0.8) * 5) }

    Rectangle {
        id: body
        x: root.bx
        y: root.yShut + (root.yOpen - root.yShut) * root.p
        width: root.dw
        height: root.bodyH + root.ext
        color: Theme.surface
        topLeftRadius: root.kind === "bottom" ? Theme.drawerR : 0
        topRightRadius: root.kind === "bottom" ? Theme.drawerR : 0
        bottomLeftRadius: root.kind === "bottom" ? 0 : Theme.drawerR
        bottomRightRadius: root.kind === "top" ? Theme.drawerR : 0

        // Swallow clicks on the drawer's own background so they don't reach the close-catcher.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = false }

        // The corner drawer's lower join slides along the right edge with it.
        Fillet { x: root.dw - root.r; y: parent.height; corner: "bl"; visible: root.kind === "corner" }

        Flickable {
            id: flick
            x: root.pad
            y: (root.kind === "bottom" ? 0 : root.ext) + root.pad
            width: root.dw - root.pad * 2
            height: root.bodyH - root.pad * 2
            contentHeight: col.implicitHeight
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds
            opacity: Math.max(0, Math.min(1, (root.p - 0.25) / 0.6))
            ColumnLayout { id: col; width: flick.width; spacing: 16 }
        }
    }
}
