import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The screen frame: a 40 px bar on top (8 px while the bar is hidden), 8 px on the other sides,
// and rounded inner corners. The lock screen keeps the bar down, whatever SUPER Z says.
// One even-odd path, the screen minus the rounded hole, so it costs one shape to draw.
// `grown` takes the frame from nothing (0) to all of it (1): it grows in from the screen's edges as
// a session starts or the greeter comes up, and lets go of them as the session ends.
Shape {
    id: root
    preferredRendererType: Shape.CurveRenderer
    property real grown: 1
    property real barTop: Shell.top
    readonly property real topY: barTop * grown
    readonly property real edge: Theme.edge * grown
    readonly property real radius: Theme.frameR * grown
    readonly property real iw: width - 2 * edge
    readonly property real ih: height - topY - edge
    visible: grown > 0
    ShapePath {
        fillColor: Theme.surface
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
        PathRectangle { x: root.edge; y: root.topY; width: root.iw; height: root.ih; radius: root.radius }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.a(Theme.accent, 0.09 * root.grown)
        strokeWidth: 1
        PathRectangle { x: root.edge + 0.5; y: root.topY + 0.5; width: root.iw - 1; height: root.ih - 1; radius: root.radius }
    }
}
