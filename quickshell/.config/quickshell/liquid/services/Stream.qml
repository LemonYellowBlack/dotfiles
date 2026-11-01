pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

// Moonlight into the lab box. Only where the lab is remote (the XPS): the box itself has the
// Sunshine toggle instead. Starts Sunshine over SSH if labstatus says it's down, then hands off to
// `moonlight stream`, which uses the pairing Moonlight already holds for that host name.
Singleton {
    id: root

    readonly property bool available: Lab.remote
    readonly property string unit: "app-dev.lizardbyte.app.Sunshine"
    // The apps Sunshine offers on hotdog (`moonlight list hotdog`), with the launcher's short names.
    readonly property var apps: [
        { app: "Desktop", label: "Desktop" },
        { app: "Low Res Desktop", label: "Low res" },
        { app: "Steam Big Picture", label: "Big Picture" }
    ]

    // From the last labstatus run: "running", "stopped", or "" while that's unknown.
    readonly property string sunshine: {
        const u = Lab.data ? Lab.data.units.find(x => x.name === unit) : null;
        return !u ? "" : (u.state === "active" ? "running" : "stopped");
    }
    property string pending: ""     // the app being started, while the SSH step runs

    Process {
        id: wake
        // A no-op when Sunshine is already up. A cold start gets a few seconds to open its ports
        // before Moonlight knocks.
        command: ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=4", Host.labVia,
            "systemctl --user is-active -q " + root.unit + " || { systemctl --user start " + root.unit + " && sleep 3; }"]
        onExited: code => {
            const app = root.pending;
            root.pending = "";
            if (code !== 0) {
                Shell.msg(Icons.stream, code === 255 ? "ssh " + Host.labVia + " failed" : "Sunshine wouldn't start on " + Host.labName, Theme.danger);
                return;
            }
            Quickshell.execDetached(["moonlight", "stream", Host.labName, app]);
            Lab.refresh();
        }
    }

    function start(app) {
        if (!available || wake.running) return;
        pending = app;
        Shell.msg(Icons.stream, "Streaming " + Host.labName + " · " + app, Theme.accent);
        wake.running = true;
    }
}
