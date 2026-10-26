import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.widgets

// Ten workspace dots in a pill. The active one is a gradient lozenge whose leading edge moves
// first and trailing edge follows, so it stretches on its way to the next workspace.
Rectangle {
    id: root
    readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property int last: 1
    property bool rightward: true
    property real lx: 5
    property real rx: 31

    implicitWidth: 14 + 10 * 22
    implicitHeight: 30
    radius: 15
    color: Theme.pill

    function count(i) {
        const w = Hyprland.workspaces.values.find(x => x.id === i);
        return w ? w.toplevels.values.length : 0;
    }
    function go(i) {
        const w = Hyprland.workspaces.values.find(x => x.id === i);
        if (w) w.activate();
        else Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + i + " })" : "workspace " + i);
    }
    function place() { lx = 7 + (active - 1) * 22 - 2; rx = 7 + active * 22 + 2; }
    onActiveChanged: { rightward = active > last; last = active; place(); }
    Component.onCompleted: { last = active; place(); }

    Behavior on lx { SequentialAnimation { PauseAnimation { duration: root.rightward ? 90 : 0 } NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } } }
    Behavior on rx { SequentialAnimation { PauseAnimation { duration: root.rightward ? 0 : 90 } NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } } }

    Repeater {
        model: 10
        Item {
            id: slot
            required property int index
            readonly property int ws: index + 1
            readonly property int n: root.count(ws)
            x: 7 + index * 22
            width: 22
            height: 30
            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                color: hover.containsMouse ? Theme.fg : (slot.n ? "#8f8aa8" : "#3f3f52")
                scale: hover.containsMouse ? 1.7 : 1
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse) Shell.peek = slot.ws;
                    else if (Shell.peek === slot.ws) Shell.peek = 0;
                }
                onClicked: { Shell.peek = 0; root.go(slot.ws); }
                onWheel: w => root.go(Math.max(1, Math.min(10, root.active + (w.angleDelta.y < 0 ? 1 : -1))))
            }
        }
    }
    Rectangle {
        x: root.lx
        width: root.rx - root.lx
        y: 5
        height: 20
        radius: 10
        gradient: Grad { colors: [Theme.blue, Theme.violet] }
        T { anchors.centerIn: parent; text: root.active; color: Theme.ink0; font.pixelSize: 11; font.weight: Font.Bold }
    }
}
