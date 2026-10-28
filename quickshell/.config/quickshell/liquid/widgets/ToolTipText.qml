import QtQuick
import qs.config

// A small label floating above its parent while hovered.
Rectangle {
    property alias text: label.text
    z: 10
    anchors.bottom: parent.top
    anchors.bottomMargin: 6
    anchors.horizontalCenter: parent.horizontalCenter
    implicitWidth: label.implicitWidth + 16
    implicitHeight: 22
    radius: 8
    color: Theme.surfaceDeep
    border.width: 1
    border.color: Theme.a(Theme.accent, 0.3)
    T { id: label; anchors.centerIn: parent; font.pixelSize: 11; color: Theme.textAlt }
}
