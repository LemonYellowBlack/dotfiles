import QtQuick
import qs.config
import qs.services

// The full-screen layers (overview, power, keybinds) over a veil Hyprland blurs. The last one
// stays loaded while the veil fades out.
FocusScope {
    id: root
    required property string screenName
    readonly property string which: Shell.overlay !== "" && (Shell.screen === "" || Shell.screen === screenName) ? Shell.overlay : ""
    property string last: ""
    onWhichChanged: if (which) { last = which; forceActiveFocus(); }

    property real p: which ? 1 : 0
    Behavior on p { NumberAnimation { duration: root.which ? 320 : 220; easing.type: Easing.OutCubic } }
    readonly property bool shown: p > 0.001
    visible: shown

    Keys.onEscapePressed: Shell.close()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.05, 0.05, 0.07, 0.5)
        opacity: root.p
        MouseArea { anchors.fill: parent; onClicked: Shell.close() }
    }
    Loader {
        anchors.fill: parent
        active: root.shown && root.last === "overview"
        opacity: root.p
        scale: 0.96 + 0.04 * root.p
        sourceComponent: Overview {}
    }
    Loader {
        anchors.fill: parent
        active: root.shown && root.last === "power"
        opacity: root.p
        scale: 0.96 + 0.04 * root.p
        sourceComponent: PowerMenu {}
    }
    Loader {
        anchors.fill: parent
        active: root.shown && root.last === "keys"
        opacity: root.p
        scale: 0.96 + 0.04 * root.p
        sourceComponent: Binds {}
    }
}
