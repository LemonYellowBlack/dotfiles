import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.services

// The current track's cover, rounded, or a dusk-gradient stand-in when the player has none.
// `glow` puts a blurred copy behind it.
Item {
    id: root
    property real size: 64
    property real radius: 14
    property bool glow: false
    implicitWidth: size
    implicitHeight: size

    MultiEffect {
        visible: root.glow
        anchors.fill: cover
        anchors.margins: 10
        source: cover
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.4
        opacity: 0.85
    }
    ClippingRectangle {
        id: cover
        anchors.fill: parent
        radius: root.radius
        color: Theme.selectionDeep
        Rectangle {
            anchors.fill: parent
            visible: img.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.selectionDeep }
                GradientStop { position: 0.45; color: Theme.accentAlt }
                GradientStop { position: 0.62; color: Theme.hot }
                GradientStop { position: 0.63; color: "#1a2436" }
                GradientStop { position: 1; color: "#1a2436" }
            }
            Rectangle {
                width: parent.width * 0.44; height: width; radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.62 - height / 2
                gradient: Gradient { GradientStop { position: 0; color: "#FFF1C9" } GradientStop { position: 1; color: Theme.hot } }
            }
            Rectangle { width: parent.width; height: Math.max(1, parent.height * 0.03); y: parent.height * 0.66; color: Theme.hot; opacity: 0.9 }
        }
        Image {
            id: img
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
        }
    }
}
