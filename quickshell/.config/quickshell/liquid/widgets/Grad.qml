import QtQuick
import qs.config

// A two- or three-stop gradient from one of Theme's lists.
Gradient {
    id: g
    property var colors: Theme.gAccent
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: g.colors[0] }
    GradientStop { position: g.colors.length > 2 ? 0.5 : 1; color: g.colors[1] }
    GradientStop { position: 1; color: g.colors[g.colors.length - 1] }
}
