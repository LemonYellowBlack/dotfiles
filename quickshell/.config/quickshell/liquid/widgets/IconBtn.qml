import QtQuick
import qs.config

// A round icon button; `fill` gives it a gradient face for primary actions.
Rectangle {
    id: root
    property string icon
    property real iconSize: 16
    property color iconColor: Theme.textSubtle
    property var fill: null
    signal clicked()

    implicitWidth: 36
    implicitHeight: 36
    radius: width / 2
    color: fill ? "transparent" : (mouse.containsMouse ? Theme.a(Theme.accent, 0.22) : Theme.a(Theme.layer, 0.7))
    gradient: fill ? grad : null
    scale: mouse.pressed ? 0.94 : (mouse.containsMouse ? 1.08 : 1)
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: 180 } }
    Grad { id: grad; colors: root.fill || Theme.gAccent }
    Icon { anchors.centerIn: parent; path: root.icon; size: root.iconSize; color: root.fill ? Theme.textOnAccent : (mouse.containsMouse ? Theme.text : root.iconColor); stroke: 2 }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
