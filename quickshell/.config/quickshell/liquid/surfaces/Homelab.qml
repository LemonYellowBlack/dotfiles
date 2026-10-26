import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services
import qs.widgets

// Hangs under the homelab pill: hotdog's GPU and who holds it, its containers and user services,
// and the GitHub runners. All of it comes from one labstatus run (local on hotdog, SSH elsewhere).
Drawer {
    id: root
    kind: "top"
    dw: 520
    dx: Math.max(28, Math.min(width - Theme.edge - 20 - dw, (Shell.anchors.homelab || width - 500) - dw / 2))
    spacing: 16

    readonly property var d: Lab.data
    readonly property var gpu: d ? d.gpu : null
    // compose names like "stt-stt-1" read better as "stt"
    function tidy(n) { n = n.replace(/-\d+$/, ""); const h = n.split("-"); return h.length === 2 && h[0] === h[1] ? h[0] : n; }
    readonly property var services: d ? d.containers.map(c => ({ name: tidy(c.name), kind: "docker", ok: c.state === "running" && c.health !== "unhealthy", warn: c.health === "unhealthy", note: c.status }))
        .concat(d.units.filter(u => !u.name.startsWith("github-runner@")).map(u => ({ name: u.name.replace(/^app-dev\.lizardbyte\.app\./, "").toLowerCase(), kind: "unit",
            ok: u.state === "active", idle: u.state === "inactive", warn: false, note: u.state + (u.sub && u.sub !== u.state ? " · " + u.sub : "") }))) : []
    readonly property var runners: d ? d.units.filter(u => u.name.startsWith("github-runner@")) : []
    function dur(s) { const m = Math.floor(s / 60); return Math.floor(m / 1440) + "d " + Math.floor((m % 1440) / 60) + "h"; }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 10; implicitHeight: 10; radius: 5
            color: Lab.ok ? (Lab.down > 0 ? Theme.yellow : Theme.green) : (Lab.error ? Theme.red : Theme.gray)
            SequentialAnimation on opacity { running: Lab.ok; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 1100 } NumberAnimation { to: 1; duration: 1100 } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T { text: Host.labName; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
            T {
                text: Lab.ok ? (Lab.remote ? "online · ssh " + Lab.ms + " ms" : "this machine") + " · up " + root.dur(root.d.uptime) + " · load " + root.d.load.toFixed(2)
                    : (Lab.error || "asking…")
                font.pixelSize: 11; color: Lab.error ? Theme.red : Theme.muted
                Layout.fillWidth: true
            }
        }
        T { visible: root.gpu !== null; text: root.gpu ? root.gpu.name.replace("NVIDIA GeForce ", "") : ""; font.pixelSize: 11; color: Theme.old }
    }

    Card {
        visible: root.gpu !== null
        Layout.fillWidth: true
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 26
            Repeater {
                model: root.gpu ? [[root.gpu.util / 100, root.gpu.util, "%", "gpu util", Theme.gBlue],
                                   [root.gpu.memUsed / root.gpu.memTotal, root.gpu.memUsed.toFixed(1), "G", "vram of " + Math.round(root.gpu.memTotal), Theme.gViolet],
                                   [root.gpu.power / root.gpu.limit, Math.round(root.gpu.power), "W", "power · " + root.gpu.temp + "°", Theme.gWarm]] : []
                ColumnLayout {
                    required property var modelData
                    spacing: 6
                    Ring {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 86; implicitHeight: 86
                        value: modelData[0]; colors: modelData[4]
                        RowLayout {
                            anchors.centerIn: parent; spacing: 1
                            T { text: modelData[1]; font.pixelSize: 20; font.weight: Font.Light }
                            T { text: modelData[2]; font.pixelSize: 11; color: Theme.muted; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 3 }
                        }
                    }
                    T { Layout.alignment: Qt.AlignHCenter; text: modelData[3]; font.pixelSize: 11; color: Theme.muted }
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.gpu ? root.gpu.apps : []
                Rectangle {
                    required property var modelData
                    implicitWidth: chip.implicitWidth + 18; implicitHeight: 22; radius: 11
                    color: Qt.rgba(0.212, 0.212, 0.275, 0.7)
                    T { id: chip; anchors.centerIn: parent; text: modelData.name + " · " + modelData.mem.toFixed(1) + " G"; font.pixelSize: 11; color: Theme.violet }
                }
            }
        }
    }

    ColumnLayout {
        visible: root.services.length > 0
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.fillWidth: true; text: "services · " + root.services.filter(s => s.ok).length + " up"; note: Lab.down > 0 ? Lab.down + " down" : "docker + systemd --user" }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 6
            rowSpacing: 5
            Repeater {
                model: root.services
                Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 12
                    color: hover.containsMouse ? Qt.rgba(0.212, 0.212, 0.275, 0.9) : Qt.rgba(0.165, 0.165, 0.216, 0.45)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Rectangle {
                            implicitWidth: 7; implicitHeight: 7; radius: 3.5
                            color: modelData.ok ? Theme.green : (modelData.idle ? Theme.gray : (modelData.warn ? Theme.yellow : Theme.red))
                            SequentialAnimation on opacity { running: modelData.ok; loops: Animation.Infinite; PauseAnimation { duration: (index * 170) % 1400 } NumberAnimation { to: 0.35; duration: 1100 } NumberAnimation { to: 1; duration: 1100 } }
                        }
                        T { text: modelData.name; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                    ToolTipText { visible: hover.containsMouse; text: modelData.kind + " · " + modelData.note }
                }
            }
        }
    }

    ColumnLayout {
        visible: root.runners.length > 0
        Layout.fillWidth: true
        spacing: 6
        Label { Layout.fillWidth: true; text: "ci runners · github-runners"; note: root.runners.filter(r => r.busy).length + " in a job" }
        Repeater {
            model: root.runners
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                T { text: modelData.name.replace("github-runner@", ""); font.pixelSize: 12; Layout.preferredWidth: 130 }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    visible: modelData.busy
                    color: Theme.a(Theme.blue, 0.25)
                    clip: true
                    Row {
                        id: stripes
                        x: -16
                        spacing: 8
                        Repeater { model: 40; Rectangle { width: 8; height: 16; y: -4; rotation: 30; color: Theme.a(Theme.blue, 0.75) } }
                        NumberAnimation on x { running: parent.visible; from: -16; to: 0; duration: 700; loops: Animation.Infinite }
                    }
                }
                Item { Layout.fillWidth: true; visible: !modelData.busy }
                T { text: modelData.busy ? "in a job" : modelData.state; font.pixelSize: 11; color: modelData.busy ? Theme.blue : (modelData.state === "active" ? Theme.muted : Theme.red) }
            }
        }
    }

    T {
        visible: !Lab.ok && Lab.remote
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 12
        color: Theme.old
        text: "Couldn't run labstatus on " + Host.labVia + ". It needs `stow --no-folding bin` there, and an SSH key the session can use without a prompt."
    }
}
