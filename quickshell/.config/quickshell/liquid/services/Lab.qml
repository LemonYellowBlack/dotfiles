pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// hotdog's state, from bin/labstatus: run in place on hotdog, over SSH from the XPS. Polls every
// five seconds while the homelab drawer is open and once a minute otherwise, for the pill's dot.
Singleton {
    id: root

    property var data: null
    property bool ok: false
    property string error: ""
    property int ms: 0
    readonly property bool remote: Host.labVia !== ""
    // Stopped compose containers and failed units. Inactive units are timer-driven one-shots.
    readonly property int down: data ? data.containers.filter(c => c.state !== "running").length
                                       + data.units.filter(u => u.state === "failed").length : 0

    property real started: 0
    Process {
        id: fetch
        // Falls back to the repo copy until `stow --no-folding bin` has linked it into ~/.local/bin.
        readonly property string find: "p=~/.local/bin/labstatus; [ -x \"$p\" ] || p=~/dotfiles/bin/.local/bin/labstatus; exec \"$p\""
        command: root.remote
            ? ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", Host.labVia, find]
            : ["sh", "-c", find]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    root.data = JSON.parse(text);
                    root.ok = true;
                    root.error = "";
                    root.ms = Date.now() - root.started;
                } catch (e) {
                    root.ok = false;
                    root.error = "labstatus printed something that isn't JSON";
                }
            }
        }
        onExited: code => {
            if (code === 255) { root.ok = false; root.error = "ssh " + Host.labVia + " failed"; }
            else if (code === 127) { root.ok = false; root.error = "labstatus isn't installed on " + Host.labName; }
        }
    }
    function refresh() { if (!fetch.running) { started = Date.now(); fetch.running = true; } }
    Timer { interval: Shell.drawer === "homelab" ? 5000 : 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Connections { target: Shell; function onDrawerChanged() { if (Shell.drawer === "homelab") root.refresh(); } }
}
