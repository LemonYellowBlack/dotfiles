import QtQuick
import QtQuick.Effects
import qs.config

// Text filled with a horizontal gradient (the big clocks and titles), via a mask over a gradient.
Item {
    id: root
    property alias text: label.text
    property alias font: label.font
    property var colors: [Theme.accentSoft, Theme.accent, Theme.accentAlt]
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // The software scene graph (offscreen previews) can't run the shader; fall back to plain text.
    readonly property bool soft: GraphicsInfo.api === GraphicsInfo.Software
    T {
        id: label
        visible: root.soft
        color: root.colors[1]
        layer.enabled: !root.soft
        elide: Text.ElideNone
    }
    Rectangle {
        id: fill
        anchors.fill: label
        visible: false
        layer.enabled: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.colors[0] }
            GradientStop { position: 0.4; color: root.colors[Math.min(1, root.colors.length - 1)] }
            GradientStop { position: 0.75; color: root.colors[Math.min(2, root.colors.length - 1)] }
            GradientStop { position: 1; color: root.colors[root.colors.length - 1] }
        }
    }
    // The mask's default threshold and spread follow the glyphs' own antialiasing; raising the
    // spread at a zero threshold lets every pixel through and paints a solid gradient bar.
    MultiEffect {
        visible: !root.soft
        anchors.fill: label
        source: fill
        maskEnabled: true
        maskSource: label
    }
}
