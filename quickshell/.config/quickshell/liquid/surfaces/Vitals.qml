import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services
import qs.widgets

// Hangs under the vitals pill: gauges, load and per-thread bars, the temperature log, fans and
// the NVIDIA card. On the XPS the card loads and unloads the GTX 1650; on hotdog it's always on.
Drawer {
    id: root
    kind: "top"
    dw: 548
    dx: Math.max(28, Math.min(width - Theme.edge - 20 - dw, (Shell.anchors.vitals || width - 600) - dw / 2))
    spacing: 16

    readonly property bool gpuOn: Sys.gpuLoaded && Sys.gpu !== null
    component Gauge: ColumnLayout {
        id: g
        property real value
        property string big
        property string unit
        property string label
        property var colors: Theme.gBlue
        property real size: 88
        spacing: 6
        Ring {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: g.size; implicitHeight: g.size
            value: g.value; colors: g.colors
            RowLayout {
                anchors.centerIn: parent
                spacing: 1
                T { text: g.big; font.pixelSize: 20; font.weight: Font.Light }
                T { text: g.unit; font.pixelSize: 11; color: Theme.muted; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 3 }
            }
        }
        T { Layout.alignment: Qt.AlignHCenter; text: g.label; font.pixelSize: 11; color: Theme.muted }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        AppIcon { size: 30; glyph: Icons.cpu; colors: Theme.gBlue }
        T { text: Host.cpu; font.weight: Font.DemiBold; Layout.fillWidth: true }
        Rectangle {
            visible: Power.profile !== ""
            implicitWidth: profileText.implicitWidth + 18; implicitHeight: 22; radius: 11; color: Qt.rgba(0.212, 0.212, 0.275, 0.7)
            T { id: profileText; anchors.centerIn: parent; text: Power.profile; font.pixelSize: 11; color: Theme.old }
        }
    }

    Card {
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Gauge { size: root.gpuOn ? 78 : 88; value: Sys.cpu; big: Math.round(Sys.cpu * 100); unit: "%"; label: "load" }
            Gauge { size: root.gpuOn ? 78 : 88; value: (Sys.temp - 30) / 70; big: Math.round(Sys.temp); unit: "°"; label: "package"; colors: Theme.tempColors(Sys.temp) }
            Gauge { size: root.gpuOn ? 78 : 88; value: Sys.memTotal ? Sys.memUsed / Sys.memTotal : 0; big: Sys.memUsed.toFixed(1); unit: "G"; label: "memory"; colors: Theme.gAqua }
            Gauge { visible: Power.hasBattery; size: root.gpuOn ? 78 : 88; value: Power.watts / 45; big: Power.watts.toFixed(1); unit: "W"; label: Power.charging ? "charging" : "draw"; colors: Theme.gWarm }
            Gauge { visible: root.gpuOn; size: 78; value: root.gpuOn ? (Sys.gpu.temp - 30) / 60 : 0; big: root.gpuOn ? Math.round(Sys.gpu.temp) : ""; unit: "°"; label: "gpu"; colors: Theme.gRed }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.fillWidth: true; text: "load · 1 min"; note: Sys.threads.length + " threads" }
        Spark { Layout.fillWidth: true; implicitHeight: 54; values: Sys.loadHist; lo: 0; hi: 100; color: Theme.blue }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 6
            Repeater {
                model: Sys.threads
                Rectangle {
                    required property real modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: Qt.rgba(0.33, 0.33, 0.43, 0.25)
                    clip: true
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(3, parent.height * modelData)
                        radius: 6
                        gradient: Gradient { GradientStop { position: 0; color: Theme.violet } GradientStop { position: 1; color: Theme.blue } }
                        Behavior on height { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.fillWidth: true; text: "thermals · " + Host.tempSensor; note: "30 min" }
        Spark { Layout.fillWidth: true; implicitHeight: 80; values: Sys.tempHist; lo: 30; hi: 100; limit: 90; color: Sys.temp > 70 ? Theme.yellow : Theme.aqua }
        Repeater {
            model: Host.fans
            RowLayout {
                required property var modelData
                required property int index
                readonly property int rpm: Sys.fanRpm[index] || 0
                Layout.fillWidth: true
                spacing: 10
                Icon {
                    path: Icons.fan; size: 18; color: Theme.cyan; opacity: parent.rpm ? 1 : 0.5
                    RotationAnimation on rotation { running: parent.rpm > 0; loops: Animation.Infinite; from: 0; to: 360; duration: parent.rpm < 2600 ? 1200 : (parent.rpm < 3200 ? 800 : 500) }
                }
                T { text: modelData.label; color: Theme.muted; font.pixelSize: 12; Layout.preferredWidth: 130 }
                Meter { Layout.fillWidth: true; value: parent.rpm / 5100; colors: Theme.gBlue }
                T { text: parent.rpm ? parent.rpm.toLocaleString(Qt.locale("en_US"), "f", 0) + " rpm" : "idle"; font.pixelSize: 12; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
            }
        }
    }

    Card {
        visible: Host.gpu !== "none"
        Layout.fillWidth: true
        border.width: root.gpuOn && Host.gpu === "prime" ? 1 : 0
        border.color: Theme.a(Theme.orange, 0.45)
        RowLayout {
            spacing: 10
            AppIcon { size: 30; glyph: Icons.gpu; colors: root.gpuOn ? Theme.gRed : Theme.gGray }
            T { text: Host.gpuName; font.weight: Font.DemiBold }
            T { text: root.gpuOn ? "loaded" : (Toggles.gpu === "loading" ? "loading" : "unloaded"); font.pixelSize: 11; color: root.gpuOn ? Theme.orange : Theme.muted; Layout.fillWidth: true }
            Pill {
                visible: Host.gpu === "prime"
                implicitHeight: 30
                active: !root.gpuOn
                onClicked: Toggles.toggle("gpu")
                T { text: root.gpuOn ? "unload · gpu-off" : (Toggles.gpu === "loading" ? "loading…" : "load · gpu-on"); font.pixelSize: 12 }
            }
        }
        T {
            visible: Host.gpu === "prime" && !root.gpuOn
            text: "Unloaded and blacklisted at boot. Games load it through the game wrapper and unload it on exit."
            font.pixelSize: 12; color: Theme.old; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }
        GridLayout {
            visible: root.gpuOn
            columns: 4
            Layout.fillWidth: true
            Repeater {
                model: root.gpuOn ? [["util", Sys.gpu.util + "%"], ["power", Sys.gpu.power.toFixed(1) + " / " + Math.round(Sys.gpu.limit) + " W"],
                                     ["vram", Sys.gpu.memUsed.toFixed(1) + " / " + Sys.gpu.memTotal.toFixed(0) + " G"], ["clock", Sys.gpu.clock + " MHz · " + Sys.gpu.pstate]] : []
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    T { text: modelData[0]; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true }
                    T { text: modelData[1]; font.pixelSize: 14; Layout.fillWidth: true }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        T { text: "memory " + Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB" + (Sys.zram ? " · zram " + Sys.zram : ""); font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
        T { visible: Power.hasBattery; text: (Power.charging ? "+" : "−") + Power.watts.toFixed(1) + " W"; font.pixelSize: 12 }
    }
}
