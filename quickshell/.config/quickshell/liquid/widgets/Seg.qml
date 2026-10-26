import QtQuick
import qs.config

// Segmented choice with a knob that springs between options. `readOnly` shows state without
// taking clicks (the platform profile belongs to TLP).
Rectangle {
    id: root
    property var options: []
    property string current: ""
    property bool readOnly: false
    signal picked(string v)
    readonly property int index: Math.max(0, options.indexOf(current))
    implicitHeight: 36
    radius: 18
    color: Qt.rgba(0.165, 0.165, 0.216, 0.55)
    Rectangle {
        y: 3
        height: parent.height - 6
        width: (parent.width - 6) / Math.max(1, root.options.length)
        x: 3 + root.index * width
        radius: height / 2
        visible: root.options.indexOf(root.current) >= 0
        gradient: Grad { colors: Theme.gBlue }
        Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
    }
    Row {
        x: 3
        Repeater {
            model: root.options
            Item {
                required property string modelData
                width: (root.width - 6) / Math.max(1, root.options.length)
                height: root.height
                T { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: modelData === root.current ? Theme.ink0 : Theme.dim; font.weight: modelData === root.current ? Font.DemiBold : Font.Normal }
                MouseArea { anchors.fill: parent; enabled: !root.readOnly; cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor; onClicked: root.picked(modelData) }
            }
        }
    }
}
