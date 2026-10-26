import QtQuick
import qs.config

// A slider with a gradient fill and a glowing thumb. `value` is 0..1; `moved` fires while dragging.
Item {
    id: root
    property real value: 0
    property var colors: Theme.gBlue
    property bool dim: false
    signal moved(real v)
    implicitHeight: 28
    readonly property real shown: Math.max(0, Math.min(1, mouse.pressed ? mouse.v : value))
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.track }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(6, parent.width * root.shown)
        height: 6
        radius: 3
        gradient: Grad { colors: root.dim ? Theme.gGray : root.colors }
        Behavior on width { enabled: !mouse.pressed; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        id: thumb
        x: parent.width * root.shown - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: Theme.fg
        border.width: 4
        border.color: Theme.a(Theme.fg, 0.12)
        scale: mouse.pressed || mouse.containsMouse ? 1.18 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        Behavior on x { enabled: !mouse.pressed; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: mouse
        property real v: 0
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(x) { v = Math.max(0, Math.min(1, x / width)); root.moved(v); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
