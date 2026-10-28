import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.config
import qs.services
import qs.widgets

// The top-right drawer: sliders, quick toggles, the platform profile, battery and notifications.
// Tiles and cards for hardware this host doesn't have (Host.qml) are left out.
Drawer {
    id: root
    kind: "corner"
    dw: 452
    maxH: height - 60
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Ring {
            implicitWidth: 46; implicitHeight: 46; thickness: 2.5; glow: false; value: 1
            Rectangle {
                anchors.centerIn: parent; width: 34; height: 34; radius: 17
                gradient: Gradient { GradientStop { position: 0; color: Theme.selection } GradientStop { position: 1; color: Theme.selectionDeep } }
                T { anchors.centerIn: parent; text: "r"; font.weight: Font.Bold }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T { text: Quickshell.env("USER") + "@" + Host.name; font.weight: Font.DemiBold; Layout.fillWidth: true }
            T { text: "up " + Sys.upText() + " · load " + Sys.load1.toFixed(2); font.pixelSize: 11; color: Theme.textMuted; Layout.fillWidth: true }
        }
        IconBtn { icon: Icons.camera; onClicked: { Shell.close(); Quickshell.execDetached(["sh", "-c", "sleep 0.4; hyprshot -m region -o ~/Pictures/Screenshots"]); } }
        IconBtn { icon: Icons.lock; onClicked: { Shell.close(); Quickshell.execDetached(["loginctl", "lock-session"]); } }
        IconBtn { icon: Icons.power; iconColor: Theme.danger; onClicked: Shell.toggle("power", "") }
    }

    Card {
        Layout.fillWidth: true
        pad: 12
        spacing: 6
        RowLayout {
            spacing: 10
            IconBtn { implicitWidth: 34; implicitHeight: 34; icon: Audio.muted ? Icons.volX : Icons.vol; iconColor: Audio.muted ? Theme.danger : Theme.text; onClicked: Audio.toggleMute() }
            LSlider { Layout.fillWidth: true; value: Audio.volume; dim: Audio.muted; colors: Theme.gAccent; onMoved: v => Audio.setVolume(v) }
            T { text: Audio.muted ? "mute" : Math.round(Audio.volume * 100) + "%"; color: Theme.textAlt; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
        }
        RowLayout {
            visible: Audio.source !== null
            spacing: 10
            IconBtn { implicitWidth: 34; implicitHeight: 34; icon: Audio.micMuted ? Icons.micOff : Icons.mic; iconColor: Audio.micMuted ? Theme.danger : Theme.text; onClicked: Audio.toggleMic() }
            LSlider { Layout.fillWidth: true; value: Audio.mic; dim: Audio.micMuted; colors: Theme.gCool; onMoved: v => Audio.setMic(v) }
            T { text: Audio.micMuted ? "mute" : Math.round(Audio.mic * 100) + "%"; color: Theme.textAlt; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
        }
        RowLayout {
            visible: Power.hasBacklight
            spacing: 10
            IconBtn { implicitWidth: 34; implicitHeight: 34; icon: Icons.sun; iconColor: Theme.highlight }
            LSlider { Layout.fillWidth: true; value: Power.brightness; colors: Theme.gWarm; onMoved: v => Power.setBrightness(v) }
            T { text: Math.round(Power.brightness * 100) + "%"; color: Theme.textAlt; font.pixelSize: 12; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
        }
        // hotdog has two outputs worth switching between: the USB interface and the TV.
        Flow {
            visible: Host.audioSwitch && Audio.sinks.length > 1
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Audio.sinks
                Pill {
                    required property var modelData
                    implicitHeight: 26
                    pad: 10
                    active: Audio.sink === modelData
                    onClicked: Audio.useSink(modelData)
                    T { text: (modelData.description || modelData.nickname || modelData.name).replace(/^.*?(Speakers|Headphones|S\/PDIF|HDMI).*$/, "$1"); font.pixelSize: 11 }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 10
        rowSpacing: 10
        QuickTile { Layout.fillWidth: true; icon: Net.wifiOn ? Icons.wifi : Icons.wifiOff; label: "Wi-Fi"; on: Net.wifiOn; note: Net.wifiOn ? (Net.ssid ? Net.iface + " · " + Math.round(Net.signal * 100) + "%" : "not connected") : "radio off"; onClicked: Toggles.toggle("wifi") }
        QuickTile { Layout.fillWidth: true; visible: Host.exitNode; icon: Icons.shield; label: "Exit node"; on: Net.exitNode !== ""; busy: Net.exitBusy; note: Net.exitBusy ? "switching…" : (Net.exitNode || "Mullvad via Tailscale"); onClicked: Toggles.toggle("vpn") }
        QuickTile { Layout.fillWidth: true; icon: Icons.coffee; label: "Caffeine"; on: Toggles.caff; note: Toggles.caff ? "idle + lid inhibited" : "sleep allowed"; onClicked: Toggles.toggle("caff") }
        QuickTile { Layout.fillWidth: true; icon: Toggles.autolock ? Icons.lock : Icons.unlock; label: "Auto-lock"; on: Toggles.autolock; note: Toggles.autolock ? "idle 5 min · lid" : "off until reboot"; onClicked: Toggles.toggle("autolock") }
        QuickTile { Layout.fillWidth: true; visible: Host.touchpad; icon: Icons.pad; label: "Touchpad"; on: Toggles.touchpad; note: Toggles.touchpad ? "tap to click" : "disabled"; onClicked: Toggles.toggle("touch") }
        QuickTile { Layout.fillWidth: true; visible: Host.gpu === "prime"; icon: Icons.gpu; label: "dGPU"; on: Toggles.gpu === "on"; busy: Toggles.gpu === "loading"; note: Toggles.gpu === "loading" ? "gpu-toggle…" : (Toggles.gpu === "on" ? Host.gpuName + " · " + Host.gpuCapW + " W" : "unloaded"); onClicked: Toggles.toggle("gpu") }
        QuickTile { Layout.fillWidth: true; visible: Host.sunshine; icon: Icons.stream; label: "Sunshine"; on: Toggles.sunshine; note: Toggles.sunshine ? "Moonlight can connect" : "stopped"; onClicked: Toggles.toggle("sunshine") }
        QuickTile { Layout.fillWidth: true; icon: Icons.moon; label: "Night light"; on: Toggles.night; note: Toggles.night ? "3500 K at night" : "paused · 6500 K"; onClicked: Toggles.toggle("night") }
        QuickTile { Layout.fillWidth: true; icon: Toggles.dnd ? Icons.bellOff : Icons.bell; label: "Do not disturb"; on: Toggles.dnd; note: Toggles.dnd ? "popups held" : "popups on"; onClicked: Toggles.toggle("dnd") }
    }

    ColumnLayout {
        visible: Power.profile !== ""
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.fillWidth: true; text: "platform profile"; note: "TLP sets this" }
        Seg { Layout.fillWidth: true; options: ["cool", "quiet", "balanced", "performance"]; current: Power.profile; readOnly: true }
    }

    Card {
        visible: Power.hasBattery
        Layout.fillWidth: true
        RowLayout {
            spacing: 16
            Ring {
                implicitWidth: 84; implicitHeight: 84; thickness: 7
                value: Power.level
                colors: Power.charging ? Theme.gCool : (Power.level <= 0.15 ? Theme.gHot : Theme.gAccent)
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    T { Layout.alignment: Qt.AlignHCenter; text: Math.round(Power.level * 100) + "%"; font.pixelSize: 20; font.weight: Font.Light }
                    T { Layout.alignment: Qt.AlignHCenter; text: Power.charging ? "charging" : (Power.full ? "full" : "battery"); font.pixelSize: 10; color: Power.charging ? Theme.success : Theme.textMuted }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    T { text: Power.charging ? (Power.toFull > 0 ? "full in " + Power.span(Power.toFull) : "charging") : (Power.toEmpty > 0 ? Power.span(Power.toEmpty) + " left" : "on AC"); font.pixelSize: 12; Layout.fillWidth: true }
                    T { text: (Power.charging ? "+" : "−") + Power.watts.toFixed(1) + " W"; font.pixelSize: 12 }
                }
                Spark { Layout.fillWidth: true; implicitHeight: 44; values: Power.history; lo: 0; hi: 100; color: Power.charging ? Theme.success : Theme.accent }
                T {
                    text: Power.energy.toFixed(1) + " / " + Power.capacity.toFixed(1) + " Wh" + (Power.health > 0 ? " · " + Math.round(Power.health) + "% health" : "")
                    font.pixelSize: 11; color: Theme.textMuted
                }
            }
        }
        RowLayout {
            visible: Host.ecoOnBattery
            spacing: 8
            T { text: "eco on battery: blur and the border animation pause while unplugged"; font.pixelSize: 11; color: Theme.textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Pill { implicitHeight: 24; pad: 9; active: Power.eco; onClicked: Power.eco = !Power.eco; T { text: Power.eco ? "on" : "off"; font.pixelSize: 11 } }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        RowLayout {
            Label { Layout.fillWidth: true; text: "notifications · " + Notifs.count }
            Pill { visible: Notifs.count > 0; implicitHeight: 24; pad: 9; onClicked: Notifs.clear(); T { text: "clear all"; font.pixelSize: 11 } }
        }
        T { visible: Toggles.dnd; text: "Do not disturb · popups held until you turn it off"; font.pixelSize: 12; color: Theme.warning }
        Repeater {
            model: Notifs.list
            NoteCard { required property var modelData; note: modelData; Layout.fillWidth: true }
        }
        T { visible: Notifs.count === 0; text: "All clear."; color: Theme.textMuted; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6 }
    }
}
