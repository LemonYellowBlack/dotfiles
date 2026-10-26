import QtQuick
import QtQuick.Shapes
import qs.config

// A concave corner where a drawer meets the frame: an r×r square minus the quarter disc centred on
// `corner` ("tl", "tr", "bl" or "br" — where the circle sits), so the fill curves into both edges.
Shape {
    id: root
    property real r: Theme.frameR
    property color color: Theme.surface
    property string corner: "bl"
    width: r
    height: r
    preferredRendererType: Shape.CurveRenderer
    readonly property real cx: corner === "tr" || corner === "br" ? r : 0
    readonly property real cy: corner === "bl" || corner === "br" ? r : 0
    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        // From one corner beside the circle's centre, round the far corner, to the other corner
        // beside it, then back along the arc.
        startX: root.cx
        startY: root.r - root.cy
        PathLine { x: root.r - root.cx; y: root.r - root.cy }
        PathLine { x: root.r - root.cx; y: root.cy }
        PathArc {
            x: root.cx
            y: root.r - root.cy
            radiusX: root.r
            radiusY: root.r
            direction: (root.corner === "bl" || root.corner === "tr") ? PathArc.Counterclockwise : PathArc.Clockwise
        }
    }
}
