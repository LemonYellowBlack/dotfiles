import QtQuick
import qs.config

// A thin progress bar with a gradient fill that grows in when it appears.
Rectangle {
    id: root
    property real value: 0
    property var colors: Theme.gBlue
    property real shown: 0
    implicitHeight: 6
    radius: height / 2
    color: Theme.track
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    Component.onCompleted: shown = Qt.binding(() => Math.max(0, Math.min(1, root.value)))
    Rectangle {
        width: Math.max(parent.height, parent.width * root.shown)
        height: parent.height
        radius: parent.radius
        visible: root.shown > 0.002
        gradient: Grad { colors: root.colors }
    }
}
