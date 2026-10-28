import QtQuick
import QtQuick.Shapes
import qs.config

// A 24×24 Lucide path from config/Icons.qml, stroked at 1.8 and scaled to `size`.
Item {
    id: root
    property string path
    property color color: Theme.text
    property real size: 16
    property real stroke: 1.8
    implicitWidth: size
    implicitHeight: size
    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        visible: root.path !== ""
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
