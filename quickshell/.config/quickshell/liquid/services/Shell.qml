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

    // ── Arriving and leaving. A session's first shell grows the frame in from the screen's edges,
    // as the greeter did before it (`intro` 0 → 1); a restart of the shell later on doesn't. One
    // flag file per Hyprland instance tells them apart.
    property real intro: 1
    Behavior on intro { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    FileView {
        id: introSeen
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/liquid-intro-" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        blockLoading: true
    }
    Timer { id: introGo; interval: 350; onTriggered: root.intro = 1 }
    Component.onCompleted: {
        if (Quickshell.env("LIQUID_PREVIEW") === "1" || introSeen.loaded) return;
        intro = 0;
        introSeen.setText("seen\n");
        introGo.restart();
    }

    // Logging out, restarting and shutting down play surfaces/Outro.qml first: the desktop clears
    // to the wallpaper, the frame lets go, and the screen goes to black, which is where the boot
    // splash and the greeter take over. `run` happens once it's dark, whatever the animation did.
    // kind: logout | reboot | firmware | poweroff, or preview to watch it and come back.
    property string leaving: ""
    property var leaveRun: null
    readonly property int leaveMs: 1250
    readonly property int previewBackMs: 800
    function leave(kind, run) {
        if (leaving !== "") return;
        leaveRun = run || null;
        leaving = kind;             // before close(): the outro keeps the wallpaper the menu loaded
        close();
        leaveTimer.restart();
    }
    Timer {
        id: leaveTimer
        interval: root.leaveMs
        onTriggered: {
            const run = root.leaveRun;
            root.leaveRun = null;
            if (root.leaving === "preview") previewBack.restart();
            else if (run) run();
        }
    }
    Timer { id: previewBack; interval: root.previewBackMs; onTriggered: root.leaving = "" }

    IpcHandler {
        target: "shell"
        function toggle(name: string): void { root.toggle(name, ""); }
        function open(name: string): void { root.open(name, ""); }
        function close(): void { root.close(); }
        function tab(name: string): void { root.open("dash", name); }
        function toggleBar(): void { root.barHidden = !root.barHidden; }
        // `leave preview` plays the outro and comes back; the rest really log out, restart or
        // shut down, after it.
        function leave(kind: string): void {
            const run = {
                logout: () => Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit"),
                reboot: () => Quickshell.execDetached(["systemctl", "reboot"]),
                firmware: () => Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]),
                poweroff: () => Quickshell.execDetached(["systemctl", "poweroff"])
            }[kind];
            if (run || kind === "preview") root.leave(kind, run);
        }
        // Re-read the config: for edits the shell missed (an editor that saves by replacing the
        // file, a git pull). Windows and notifications carry over.
        function reload(): void { Quickshell.reload(false); }
    }
}
