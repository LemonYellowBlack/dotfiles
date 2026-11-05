import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// The outro, drawn at p from 0 to 1: the wallpaper comes back over the windows while the island
// says where the desktop is going, the frame lets go of the screen's edges, and it all goes to
// black. The boot splash and the greeter start from black, so whatever comes next starts from the
// same place this ends. Each part takes its own stretch of p.
Item {
    id: root
    property real p: 0
    property string kind: ""
    property bool loadWallpaper: true

    readonly property var words: ({
        logout: ["see you", Icons.logout], reboot: ["restarting", Icons.reboot],
        firmware: ["restarting to firmware", Icons.cpu], poweroff: ["shutting down", Icons.power],
        preview: ["shutting down", Icons.power]
    })[kind] || ["", ""]

    function span(a, b) { const x = Math.max(0, Math.min(1, (p - a) / (b - a))); return x * x * (3 - 2 * x); }
    readonly property real clear: span(0, 0.36)        // the wallpaper over the windows
    readonly property real hold: 1 - span(0.34, 0.68)  // the frame, letting go
    readonly property real dark: span(0.62, 0.96)      // and black

    // No input reaches the desktop while it goes.
    MouseArea { anchors.fill: parent; hoverEnabled: true }
    Keys.onPressed: event => event.accepted = true
    focus: true

    Rectangle { anchors.fill: parent; color: Theme.surfaceDeep; opacity: wall.status === Image.Ready ? 0 : root.clear }
    Image {
        id: wall
        anchors.fill: parent
        source: root.loadWallpaper ? Wallpaper.url : ""
        fillMode: Wallpaper.fillMode
        opacity: root.clear
        asynchronous: true
    }
    // The shell's own frame is underneath, identical; this one fades in over the bar's modules,
    // then lets go.
    Frame { anchors.fill: parent; barTop: Shell.top; grown: root.hold; opacity: root.clear }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
        height: 30
        width: row.implicitWidth + 34
        radius: 15
        color: Theme.surfaceDeep
        border.width: 1
        border.color: Theme.a(Theme.accent, 0.18)
        opacity: root.span(0.05, 0.3)
        scale: 0.94 + 0.06 * opacity
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Icon { path: root.words[1]; size: 15; stroke: 2; color: Theme.accent }
            T { text: root.words[0]; color: Theme.textSubtle }
        }
    }

    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dark }
}
