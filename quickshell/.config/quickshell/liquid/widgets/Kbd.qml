import QtQuick
import qs.config

// A key cap.
Rectangle {
    property alias text: label.text
    implicitWidth: Math.max(22, label.implicitWidth + 14)
    implicitHeight: 22
    radius: 7
    gradient: Gradient { GradientStop { position: 0; color: Theme.layerHover } GradientStop { position: 1; color: Theme.layer } }
    border.width: 1
    border.color: Theme.a(Theme.accent, 0.18)
    T { id: label; anchors.centerIn: parent; font.pixelSize: 11 }
}
