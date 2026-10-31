pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// UI state shared by every screen: which drawer or overlay is open and where, and what the island
// is showing. Hyprland binds reach it through `qs -c liquid ipc call shell <fn> <arg>`.
Singleton {
    id: root

    property string drawer: ""          // control | dash | vitals | homelab | launcher | colors
    property string overlay: ""         // overview | power | keys
    property string screen: ""          // the monitor the open surface belongs to
    property string dashTab: "overview"
    property int peek: 0                // workspace whose preview is showing
    property var anchors: ({})          // bar pill centres, so a drawer can hang under its pill
    property var island: null           // { kind: osd | msg | note | charge, ... }
    property int seq: 0

    readonly property bool busy: drawer !== "" || overlay !== ""

    // SUPER Z hides the bar: Hyprland gets the space back, and the bar only drops down while a
    // drawer, overlay or island popup needs it. `top` is the frame's top edge as it animates.
    property bool barHidden: false
    readonly property bool barShown: !barHidden || busy || island !== null
    property real top: barShown ? Theme.barH : Theme.edge
    Behavior on top { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    readonly property var overlays: ["overview", "power", "keys"]

    function focusedScreen() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""; }
    function on(name, screenName) { return (drawer === name || overlay === name) && (screen === "" || screen === screenName); }

    function toggle(name, arg) {
        if (overlays.indexOf(name) >= 0) {
            overlay = overlay === name ? "" : name;
            drawer = "";
        } else {
            drawer = drawer === name && !arg ? "" : name;
            overlay = "";
        }
        if (name === "dash" && arg) dashTab = arg;
        screen = focusedScreen();
        peek = 0;
    }
    function open(name, arg) { if (drawer !== name && overlay !== name) toggle(name, arg); else if (arg) dashTab = arg; }
    function close() { drawer = ""; overlay = ""; }
    function setAnchor(name, x) { const a = Object.assign({}, anchors); a[name] = x; anchors = a; }

    function show(item, ms) {
        item.seq = ++seq;
        island = item;
        islandTimer.interval = ms || 1800;
        islandTimer.restart();
    }
    function osd(icon, value, colors, label) { show({ kind: "osd", icon: icon, value: value, colors: colors, label: label || "" }, 1500); }
    function msg(icon, text, color) { show({ kind: "msg", icon: icon, text: text, color: color || Theme.accent }, 2200); }

    Timer { id: islandTimer; onTriggered: root.island = null }

    IpcHandler {
        target: "shell"
        function toggle(name: string): void { root.toggle(name, ""); }
        function open(name: string): void { root.open(name, ""); }
        function close(): void { root.close(); }
        function tab(name: string): void { root.open("dash", name); }
        function toggleBar(): void { root.barHidden = !root.barHidden; }
    }
}
