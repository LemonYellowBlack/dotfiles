import QtQuick
import qs.config
import qs.services

// cava-style bars. Each bar wobbles on its own phase, scaled by the real output peak level.
Row {
    id: root
    property int bars: 4
    property real barWidth: 3
    property real barHeight: 13
    property var colors: [Theme.accent, Theme.accentAlt, Theme.accentCool]
    property real t: 0
    readonly property bool live: Media.playing && visible
    spacing: 3
    height: barHeight

    FrameAnimation { running: root.live; onTriggered: root.t += frameTime }

    Repeater {
        model: root.bars
        Rectangle {
            required property int index
            readonly property real a: Math.abs(Math.sin(index * 12.9898 + 1) * 43758.5453) % 1
            readonly property real b: Math.abs(Math.sin(index * 78.233 + 2) * 12345.678) % 1
            readonly property real level: root.live ? Math.min(1, 0.25 + Media.level * 1.6) : 0.15
            width: root.barWidth
            height: root.barHeight * Math.max(0.12, level * (0.35 + 0.65 * Math.abs(Math.sin(root.t * (3 + a * 5) + b * 6.283))))
            anchors.bottom: parent.bottom
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: root.colors[2] }
                GradientStop { position: 0.5; color: root.colors[1] }
                GradientStop { position: 1; color: root.colors[0] }
            }
        }
    }
}
