pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

// The quick toggles. Each one runs the same script its SUPER+SHIFT+F-key bind already runs, so
// the shell and the binds can't disagree, and reads state from the flag files those scripts keep.
// The scripts' own notify-send confirmations land in the island.
Singleton {
    id: root

    property bool caff: false
    property bool autolock: true
    property bool touchpad: true
    property string gpu: "off"          // off | loading | on
    property bool night: true
    property bool dnd: false
    property bool sunshine: false

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    readonly property string sunshineUnit: "app-dev.lizardbyte.app.Sunshine.service"

    Process {
        id: probe
        command: ["sh", "-c", "r=\"$XDG_RUNTIME_DIR\"; c=0; [ -f \"$r/caff.pid\" ] && kill -0 \"$(cat \"$r/caff.pid\")\" 2>/dev/null && c=1; "
            + "l=1; [ -f \"$r/hypr-nolock\" ] && l=0; t=1; [ -f /tmp/touchpad-disabled ] && t=0; g=0; [ -d /sys/module/nvidia ] && g=1; "
            + "n=0; pgrep -x gammastep >/dev/null && n=1; s=0; systemctl --user is-active -q " + root.sunshineUnit + " && s=1; echo $c $l $t $g $n $s"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(" ").map(Number);
                if (f.length < 6) return;
                root.caff = f[0] === 1;
                root.autolock = f[1] === 1;
                root.touchpad = f[2] === 1;
                if (root.gpu !== "loading" || root.gpuDone) { root.gpu = f[3] === 1 ? "on" : "off"; root.gpuDone = false; }
                if (!root.nightKnown) root.night = f[4] === 1;
                root.sunshine = f[5] === 1;
            }
        }
    }
    function refresh() { if (!probe.running) probe.running = true; }
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: soon; interval: 600; onTriggered: root.refresh() }

    property bool gpuDone: false
    Process { id: run; onExited: { if (root.gpu === "loading") root.gpuDone = true; soon.restart(); } }
    function exec(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); soon.restart(); }

    property bool nightKnown: false
    function toggle(key) {
        switch (key) {
        case "caff": exec(bin + "caff"); caff = !caff; break;
        case "autolock": exec(bin + "lock-toggle"); autolock = !autolock; break;
        case "touch": exec(bin + "touchpad-toggle"); touchpad = !touchpad; break;
        case "gpu": if (gpu === "loading") return; gpu = gpu === "on" ? "off" : "loading"; run.command = [bin + "gpu-toggle"]; run.running = true; break;
        case "night": exec("pkill -USR1 -x gammastep"); night = !night; nightKnown = true;
            Shell.msg(Icons.moon, night ? "Night light on" : "Night light paused · 6500 K", night ? Theme.highlight : Theme.textMuted); break;
        case "dnd": dnd = !dnd; Shell.msg(dnd ? Icons.bellOff : Icons.bell, dnd ? "Do not disturb · popups held" : "Popups on", dnd ? Theme.textMuted : Theme.accent); break;
        case "sunshine": exec("systemctl --user " + (sunshine ? "stop " : "start ") + sunshineUnit); sunshine = !sunshine;
            Shell.msg(Icons.stream, sunshine ? "Sunshine on · Moonlight can connect" : "Sunshine stopped", sunshine ? Theme.accent : Theme.textMuted); break;
        case "wifi": Net.toggleWifi(); break;
        case "vpn": Net.toggleExit(); break;
        }
    }
}
