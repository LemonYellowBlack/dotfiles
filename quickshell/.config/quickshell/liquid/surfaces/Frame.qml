import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The screen frame: a 40 px bar on top (8 px while the bar is hidden), 8 px on the other sides,
// and rounded inner corners.
// One even-odd path, the screen minus the rounded hole, so it costs one shape to draw.
Shape {
    id: root
    preferredRendererType: Shape.CurveRenderer
    readonly property real iw: width - 2 * Theme.edge
    readonly property real ih: height - Shell.top - Theme.edge
    ShapePath {
        fillColor: Theme.surface
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
        PathRectangle { x: Theme.edge; y: Shell.top; width: root.iw; height: root.ih; radius: Theme.frameR }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.a(Theme.accent, 0.09)
        strokeWidth: 1
        PathRectangle { x: Theme.edge + 0.5; y: Shell.top + 0.5; width: root.iw - 1; height: root.ih - 1; radius: Theme.frameR }
    }
}
