import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

// The battery: an outline that fills with the charge, gradient-filled, with a bolt while charging.
Item {
    id: root
    implicitWidth: 26
    implicitHeight: 14
    readonly property color edge: Power.charging ? Theme.green : (Power.level <= 0.15 ? Theme.red : (Power.level <= 0.3 ? Theme.yellow : Theme.fg))
    Rectangle { x: 0.5; y: 0.5; width: parent.width - 4; height: parent.height - 1; radius: 4; color: "transparent"; border.width: 1.5; border.color: Theme.a(root.edge, 0.7) }
    Rectangle { x: parent.width - 2.6; y: parent.height / 2 - 2.5; width: 2; height: 5; radius: 1; color: Theme.a(root.edge, 0.7) }
    Rectangle {
        x: 2.5; y: 2.5
        height: parent.height - 5
        width: Math.max(2, (parent.width - 8) * Power.level)
        radius: 2.5
        gradient: Grad { colors: Power.charging ? Theme.gAqua : (Power.level <= 0.15 ? Theme.gRed : ["#7FB4CA", "#957FB8"]) }
        Behavior on width { NumberAnimation { duration: 600 } }
    }
    Icon { visible: Power.charging; anchors.centerIn: parent; anchors.horizontalCenterOffset: -2; path: Icons.bolt; size: 10; stroke: 2.2; color: Theme.ink0 }
}
