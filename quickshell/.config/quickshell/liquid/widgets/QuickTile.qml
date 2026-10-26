import QtQuick
import QtQuick.Layouts
import qs.config

// A control-center toggle: icon bubble, name and a one-line state. On, the bubble turns into a
// glowing gradient and tilts; `busy` pulses while a slow toggle (the dGPU) is working.
Rectangle {
    id: root
    property string icon
    property string label
    property string note
    property bool on: false
    property bool busy: false
    signal clicked()

    implicitHeight: 56
    radius: 20
    color: on ? Theme.a(Theme.blue, 0.17) : (mouse.containsMouse ? Qt.rgba(0.212, 0.212, 0.275, 0.85) : Qt.rgba(0.165, 0.165, 0.216, 0.55))
    border.width: on ? 1 : 0
    border.color: Theme.a(Theme.blue, 0.4)
    scale: mouse.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 300 } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 12
        spacing: 11
        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: 18
            color: root.busy || root.on ? "transparent" : Qt.rgba(0.33, 0.33, 0.43, 0.38)
            gradient: root.busy ? warm : (root.on ? blue : null)
            rotation: root.on ? -8 : 0
            Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
            Grad { id: blue; colors: Theme.gBlue }
            Grad { id: warm; colors: Theme.gWarm }
            SequentialAnimation on opacity { running: root.busy; loops: Animation.Infinite; NumberAnimation { to: 0.45; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
            Icon { anchors.centerIn: parent; path: root.icon; size: 17; stroke: 2; color: root.on || root.busy ? Theme.ink0 : Theme.dim }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T { text: root.label; font.weight: Font.DemiBold; Layout.fillWidth: true }
            T { text: root.note; font.pixelSize: 11; color: root.busy ? Theme.yellow : (root.on ? Theme.old : Theme.muted); Layout.fillWidth: true }
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
