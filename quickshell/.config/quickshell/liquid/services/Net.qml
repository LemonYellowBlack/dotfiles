pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs

// Wi-Fi from NetworkManager, and the Tailscale exit node the vpn script picks.
Singleton {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var link: wifi ? (wifi.networks.values.find(n => n.connected) || null) : null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property string ssid: link ? link.name : ""
    readonly property real signal: link ? link.signalStrength : 0
    readonly property string iface: wifi ? wifi.name : ""

    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled; }

    // "" when traffic goes out directly, else the exit node's city.
    property string exitNode: ""
    property bool exitBusy: false
    Process {
        id: status
        command: ["sh", "-c", "tailscale status --json | jq -r 'first(.Peer[] | select(.ExitNode) | if .Location then .Location.City else .HostName end) // \"\"'"]
        stdout: StdioCollector { onStreamFinished: root.exitNode = text.trim() }
    }
    Timer { interval: 30000; repeat: true; running: Host.exitNode; triggeredOnStart: true; onTriggered: if (!status.running) status.running = true }

    Process {
        id: vpn
        onExited: { root.exitBusy = false; status.running = true; }
    }
    // city or country as the vpn script takes them; "off" turns the exit node off
    function useExit(where) {
        exitBusy = true;
        vpn.command = ["zsh", "-c", "~/.local/bin/vpn " + where.split(" ").map(w => "'" + w.replace(/'/g, "") + "'").join(" ")];
        vpn.running = true;
    }
    function toggleExit() { useExit(exitNode ? "off" : "chicago"); }

    // Countries with Mullvad nodes, for the launcher's vpn mode.
    property var countries: []
    Process {
        id: list
        command: ["zsh", "-c", "~/.local/bin/vpn list"]
        stdout: StdioCollector {
            onStreamFinished: root.countries = text.trim().split("\n").map(l => {
                const m = l.match(/^(.*?)\s{2,}(\d+) cities\s+(\d+) servers/);
                return m ? { name: m[1].trim(), cities: Number(m[2]), servers: Number(m[3]) } : null;
            }).filter(x => x)
        }
    }
    function loadCountries() { if (Host.exitNode && countries.length === 0 && !list.running) list.running = true; }
}
