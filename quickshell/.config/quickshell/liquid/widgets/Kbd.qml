import QtQuick
import qs.config

// A key cap.
Rectangle {
    property alias text: label.text
    implicitWidth: Math.max(22, label.implicitWidth + 14)
    implicitHeight: 22
    radius: 7
    gradient: Gradient { GradientStop { position: 0; color: Theme.ink3 } GradientStop { position: 1; color: Theme.ink2 } }
    border.width: 1
    border.color: Theme.a(Theme.blue, 0.18)
    T { id: label; anchors.centerIn: parent; font.pixelSize: 11 }
}
