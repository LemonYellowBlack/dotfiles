pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.config

// Battery (UPower), backlight (sysfs, written with brightnessctl) and the eco switch that drops
// Hyprland's blur and border animation while the laptop is unplugged.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: Host.battery && dev !== null && dev.isLaptopBattery
    readonly property real level: dev ? (dev.percentage > 1 ? dev.percentage / 100 : dev.percentage) : 0
    readonly property bool charging: dev !== null && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: dev !== null && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property real watts: dev ? Math.abs(dev.changeRate) : 0
    readonly property real toEmpty: dev ? dev.timeToEmpty : 0
    readonly property real toFull: dev ? dev.timeToFull : 0
    readonly property var cell: UPower.devices.values.find(d => d.type === UPowerDeviceType.Battery) || null
    readonly property real health: cell && cell.healthSupported ? cell.healthPercentage : 0
    readonly property real energy: cell ? cell.energy : 0
    readonly property real capacity: cell ? cell.energyCapacity : 0

    function span(sec) {
        if (!(sec > 0)) return "";
        const m = Math.round(sec / 60);
        return Math.floor(m / 60) + "h " + String(m % 60).padStart(2, "0") + "m";
    }

    // Two hours of charge, one point a minute, seeded from UPower's own history file when readable.
    property var history: []
    Process {
        running: root.hasBattery
        command: ["sh", "-c", "cat /var/lib/upower/history-charge-*.dat 2>/dev/null | tail -n 600"]
        stdout: StdioCollector {
            onStreamFinished: {
                const cut = Date.now() / 1000 - 7200, pts = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length >= 2 && Number(f[0]) > cut) pts.push(Number(f[1]));
                }
                if (pts.length > 1) root.history = pts.slice(-120);
            }
        }
    }
    Timer {
        interval: 60000; repeat: true; running: root.hasBattery; triggeredOnStart: true
        onTriggered: root.history = root.history.concat([root.level * 100]).slice(-120)
    }

    property bool settled: false
    Timer { interval: 2500; running: true; onTriggered: root.settled = true }
    onChargingChanged: if (settled && hasBattery) Shell.show({ kind: "charge", on: charging }, 3000)

    // Backlight
    readonly property bool hasBacklight: Host.backlight !== ""
    property real brightness: 0
    property int maxBrightness: 1
    FileView {
        id: maxFile
        path: root.hasBacklight ? "/sys/class/backlight/" + Host.backlight + "/max_brightness" : ""
        blockLoading: true
        onLoaded: root.maxBrightness = Math.max(1, parseInt(text()))
    }
    FileView {
        id: curFile
        path: root.hasBacklight ? "/sys/class/backlight/" + Host.backlight + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const max = parseInt(maxFile.text()) || root.maxBrightness;
            const v = parseInt(text()) / max;
            if (Math.abs(v - root.brightness) > 0.004) {
                root.brightness = v;
                if (root.settled) Shell.osd(Icons.sun, v, Theme.gWarm, "brightness");
            }
        }
    }
    Process { id: bctl }
    function setBrightness(v) {
        const pct = Math.round(Math.max(0.03, Math.min(1, v)) * 100);
        bctl.command = ["brightnessctl", "-q", "set", pct + "%"];
        bctl.running = true;
    }

    // TLP owns the platform profile; the shell only shows it.
    property string profile: ""
    FileView {
        path: Host.profilePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.profile = text().trim()
    }

    // Eco: no blur and a still border while on battery. Values must match hypr/liquid.lua.
    property bool eco: Host.ecoOnBattery
    readonly property bool ecoActive: eco && hasBattery && onBattery
    Process { id: hypr }
    function applyEco() {
        if (!Host.ecoOnBattery || Quickshell.env("LIQUID_PREVIEW") === "1") return;
        const off = ecoActive;
        hypr.command = Hyprland.usingLua
            ? ["hyprctl", "eval", `hl.config({ decoration = { blur = { enabled = ${!off} } } }); hl.animation({ leaf = "borderangle", enabled = ${!off}, speed = 60, bezier = "linear", style = "loop" })`]
            : ["sh", "-c", `hyprctl --batch "keyword decoration:blur:enabled ${!off}; keyword animation borderangle,${off ? 0 : 1},60,linear,loop"`];
        hypr.running = true;
    }
    onEcoActiveChanged: applyEco()
    // Only ever switch effects off at startup; switching them on is left to liquid.lua.
    Component.onCompleted: if (ecoActive) applyEco()
}
