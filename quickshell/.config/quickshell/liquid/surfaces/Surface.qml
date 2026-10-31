import QtQuick
import qs.config
import qs.services

// Everything the main layer surface draws for one screen: the frame, the drawers that grow out of
// it, and the bar with its island. One surface, so the drawers can slide out from under the bar.
FocusScope {
    id: root
    required property string screenName
    readonly property bool mine: Shell.screen === "" || Shell.screen === screenName
    readonly property bool drawerOpen: Shell.drawer !== "" && mine
    readonly property alias inputArea: inputArea
    readonly property alias island: bar.island
    onDrawerOpenChanged: if (drawerOpen) forceActiveFocus()
    Keys.onEscapePressed: Shell.close()

    // While a drawer is open, a click anywhere else closes it. The launcher also dims the desk.
    MouseArea { anchors.fill: parent; enabled: root.drawerOpen; onClicked: Shell.close() }
    Rectangle {
        anchors.fill: parent
        color: Theme.a(Theme.surfaceDeep, 0.55)
        opacity: Shell.drawer === "launcher" && root.mine ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Frame { anchors.fill: parent }

    Item {
        id: inner
        y: Shell.top
        width: parent.width
        height: parent.height - Shell.top - Theme.edge
        clip: true
        ControlCenter { open: Shell.drawer === "control" && root.mine }
        Dashboard { open: Shell.drawer === "dash" && root.mine }
        Vitals { open: Shell.drawer === "vitals" && root.mine }
        Homelab { open: Shell.drawer === "homelab" && root.mine }
        Launcher { open: Shell.drawer === "launcher" && root.mine }
        Colors { open: Shell.drawer === "colors" && root.mine }
    }

    // Slides up and fades with the frame's top edge when SUPER Z hides it.
    Bar { id: bar; y: Shell.top - Theme.barH; opacity: (Shell.top - Theme.edge) / (Theme.barH - Theme.edge); visible: opacity > 0; width: parent.width; screenName: root.screenName }

    // The input region: the bar alone, or the whole screen while a drawer wants clicks.
    Item { id: inputArea; width: parent.width; height: root.drawerOpen ? parent.height : Shell.top }
}
