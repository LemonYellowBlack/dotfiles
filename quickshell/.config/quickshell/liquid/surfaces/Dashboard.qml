import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.config
import qs.services
import qs.widgets

// Hangs from the bar under the island. Overview: clock, calendar, the sun's arc with gammastep's
// ramp, weather, media and session. Media: big art, a wide visualizer and transport.
Drawer {
    id: root
    kind: "top"
    dw: 1040
    dx: (width - dw) / 2
    spacing: 14

    property date now: new Date()
    property int monthOff: 0
    Timer { interval: 1000; repeat: true; running: root.open; triggeredOnStart: true; onTriggered: root.now = new Date() }
    onOpenChanged: if (open) monthOff = 0

    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }

    RowLayout {
        Layout.fillWidth: true
        Rectangle {
            id: tabs
            readonly property int index: Shell.dashTab === "media" ? 1 : 0
            implicitWidth: 212
            implicitHeight: 36
            radius: 18
            color: Qt.rgba(0.165, 0.165, 0.216, 0.5)
            Rectangle {
                x: 4 + tabs.index * 104; y: 4
                width: 100; height: 28; radius: 14
                gradient: Grad { colors: [Theme.blue, Theme.violet] }
                Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
            }
            Repeater {
                model: ["overview", "media"]
                Item {
                    required property string modelData
                    required property int index
                    x: 4 + index * 104; y: 4; width: 100; height: 28
                    T { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: tabs.index === index ? Theme.ink0 : Theme.dim; font.weight: tabs.index === index ? Font.DemiBold : Font.Normal }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Shell.dashTab = modelData }
                }
            }
        }
        Item { Layout.fillWidth: true }
        T { text: "SUPER F1"; font.pixelSize: 11; color: Theme.muted }
    }

    // ---- overview ----
    RowLayout {
        visible: Shell.dashTab !== "media"
        Layout.fillWidth: true
        spacing: 18

        ColumnLayout {
            Layout.preferredWidth: 310
            Layout.alignment: Qt.AlignTop
            spacing: 14
            ColumnLayout {
                spacing: 2
                RowLayout {
                    spacing: 6
                    GradText { text: Qt.formatTime(root.now, "HH:mm"); font.pixelSize: 78; font.weight: Font.ExtraLight }
                    T { text: Qt.formatTime(root.now, "ss"); font.pixelSize: 22; font.weight: Font.ExtraLight; color: Theme.muted; Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 14 }
                }
                T { text: root.dayNames[root.now.getDay()] + ", " + root.monthNames[root.now.getMonth()] + " " + root.now.getDate(); font.pixelSize: 14; color: Theme.dim }
                T { text: "week " + root.isoWeek(root.now); font.pixelSize: 11; color: Theme.muted }
            }
            Card {
                id: calCard
                Layout.fillWidth: true
                pad: 12
                spacing: 6
                readonly property date view: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOff, 1)
                readonly property date first: new Date(view.getFullYear(), view.getMonth(), 1 - (view.getDay() + 6) % 7)
                RowLayout {
                    IconBtn { implicitWidth: 28; implicitHeight: 28; icon: "M15 18l-6-6 6-6"; onClicked: root.monthOff-- }
                    T { text: root.monthNames[calCard.view.getMonth()] + " " + calCard.view.getFullYear(); font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                    IconBtn { implicitWidth: 28; implicitHeight: 28; icon: "M9 18l6-6-6-6"; onClicked: root.monthOff++ }
                }
                GridLayout {
                    id: cal
                    columns: 8
                    columnSpacing: 0
                    rowSpacing: 0
                    Layout.fillWidth: true
                    Repeater {
                        model: ["wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        T { required property string modelData; required property int index; text: modelData; font.pixelSize: 11; color: index ? Theme.gray : Theme.violet; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; Layout.preferredHeight: 24 }
                    }
                    Repeater {
                        model: 48
                        Item {
                            required property int index
                            readonly property int row: Math.floor(index / 8)
                            readonly property int col: index % 8
                            readonly property date d: new Date(calCard.first.getFullYear(), calCard.first.getMonth(), calCard.first.getDate() + row * 7 + Math.max(0, col - 1))
                            readonly property bool today: col > 0 && d.toDateString() === root.now.toDateString()
                            readonly property bool inMonth: d.getMonth() === calCard.view.getMonth()
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            Rectangle {
                                anchors.centerIn: parent
                                width: 28; height: 28; radius: 14
                                visible: parent.today
                                gradient: Grad { colors: [Theme.blue, Theme.violet] }
                            }
                            T {
                                anchors.centerIn: parent
                                text: parent.col === 0 ? root.isoWeek(parent.d) : parent.d.getDate()
                                font.pixelSize: parent.col === 0 ? 11 : 12
                                font.weight: parent.today ? Font.Bold : Font.Normal
                                color: parent.col === 0 ? Theme.violet : (parent.today ? Theme.ink0 : (!parent.inMonth ? Theme.ink4 : (parent.col > 5 ? Theme.old : Theme.fg)))
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 14
            Card {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: "sun · night light"; note: Host.lat.toFixed(1) + " N " + Math.abs(Host.lon).toFixed(1) + " W" }
                Canvas {
                    id: arc
                    Layout.fillWidth: true
                    implicitHeight: 140
                    readonly property var curve: Sun.day.curve
                    onCurveChanged: requestPaint()
                    Connections { target: Sun; function onNowChanged() { arc.requestPaint(); } }
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const W = width, y0 = 92, k = 1.45, c = curve;
                        if (!c || c.length < 2) return;
                        const y = e => y0 - (e >= 0 ? e * k : Math.max(-60, e) * 0.55);
                        const x = i => i / (c.length - 1) * W;
                        ctx.strokeStyle = "rgba(220,215,186,0.18)"; ctx.setLineDash([3, 4]);
                        ctx.beginPath(); ctx.moveTo(0, y0); ctx.lineTo(W, y0); ctx.stroke(); ctx.setLineDash([]);
                        // daylight fill
                        const fill = ctx.createLinearGradient(0, 0, 0, y0);
                        fill.addColorStop(0, "rgba(255,160,102,0.38)"); fill.addColorStop(1, "rgba(255,160,102,0)");
                        ctx.fillStyle = fill;
                        ctx.beginPath(); ctx.moveTo(0, y0);
                        for (let i = 0; i < c.length; i++) ctx.lineTo(x(i), Math.min(y0, y(c[i])));
                        ctx.lineTo(W, y0); ctx.closePath(); ctx.fill();
                        // the whole day's curve, then the daylight part in warm gradient
                        ctx.strokeStyle = "rgba(126,156,216,0.45)"; ctx.lineWidth = 1.5;
                        ctx.beginPath(); for (let i = 0; i < c.length; i++) (i ? ctx.lineTo : ctx.moveTo).call(ctx, x(i), y(c[i])); ctx.stroke();
                        const warm = ctx.createLinearGradient(0, 0, W, 0);
                        warm.addColorStop(0, Theme.yellow); warm.addColorStop(0.5, Theme.orange); warm.addColorStop(1, Theme.red);
                        ctx.strokeStyle = warm; ctx.lineWidth = 2.5; ctx.lineCap = "round";
                        ctx.beginPath(); let on = false;
                        for (let i = 0; i < c.length; i++) { if (c[i] >= 0) { if (!on) ctx.moveTo(x(i), y(c[i])); else ctx.lineTo(x(i), y(c[i])); on = true; } else on = false; }
                        ctx.stroke();
                        ctx.fillStyle = Theme.gray; ctx.font = "10px '" + Theme.font + "'";
                        [0, 6, 12, 18, 24].forEach(h => ctx.fillText(String(h).padStart(2, "0"), Math.min(W - 14, h / 24 * W), 136));
                        const n = Sun.now, e = Sun.elevation, sx = (n.getHours() * 60 + n.getMinutes()) / 1440 * W;
                        ctx.shadowColor = e > 0 ? Theme.orange : Theme.blue; ctx.shadowBlur = 14;
                        ctx.fillStyle = e > 0 ? Theme.yellow : Theme.blue;
                        ctx.beginPath(); ctx.arc(sx, y(e), e > 0 ? 8 : 6, 0, 2 * Math.PI); ctx.fill();
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [["sunrise", Sun.hhmm(Sun.day.rise)], ["sunset", Sun.hhmm(Sun.day.set)],
                                ["daylight", Sun.day.rise && Sun.day.set ? Math.floor((Sun.day.set - Sun.day.rise) / 3600000) + "h " + String(Math.round((Sun.day.set - Sun.day.rise) / 60000) % 60).padStart(2, "0") + "m" : "--"],
                                ["gammastep", (Toggles.night ? Sun.kelvin(Sun.elevation) : 6500) + " K"]]
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0
                            T { text: modelData[0]; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true }
                            T { text: modelData[1]; font.pixelSize: 16; Layout.fillWidth: true }
                        }
                    }
                }
            }
            Card {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: "weather · " + Host.place; note: "open-meteo" }
                RowLayout {
                    spacing: 16
                    Icon { path: Icons.cloud; size: 46; stroke: 1.6; color: Theme.cyan }
                    GradText { text: Weather.now ? Weather.now.temp + "°" : "--"; font.pixelSize: 46; font.weight: Font.ExtraLight }
                    ColumnLayout {
                        spacing: 2
                        T { text: Weather.now ? Weather.describe(Weather.now.code) + " · feels " + Weather.now.feels + "°" : "fetching…"; font.pixelSize: 12 }
                        T { text: Weather.now ? "H " + Weather.now.hi + "° · L " + Weather.now.lo + "° · " + Weather.now.dir + " " + Weather.now.wind + " mph" : ""; font.pixelSize: 12; color: Theme.muted }
                    }
                }
                Spark {
                    readonly property var temps: Weather.hours.map(h => h.temp)
                    Layout.fillWidth: true; implicitHeight: 40; values: temps; color: Theme.cyan
                    lo: temps.length ? Math.min(...temps) - 2 : 0; hi: temps.length ? Math.max(...temps) + 2 : 1
                }
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: Weather.hours
                        T { required property var modelData; text: String(modelData.hour).padStart(2, "0") + "h"; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: 14
            Card {
                Layout.fillWidth: true
                visible: Media.present
                RowLayout {
                    spacing: 12
                    Art { size: 64; radius: 14 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        T { text: Media.title; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        T { text: Media.artist; font.pixelSize: 12; color: Theme.dim; Layout.fillWidth: true }
                        Viz { bars: 18; barHeight: 18; Layout.topMargin: 6 }
                    }
                }
                Meter { Layout.fillWidth: true; implicitHeight: 5; value: Media.length > 0 ? Media.position / Media.length : 0; colors: Theme.gViolet }
                RowLayout { T { text: Media.clock(Media.position); font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true } T { text: Media.length > 0 ? Media.clock(Media.length) : ""; font.pixelSize: 11; color: Theme.muted } }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14
                    IconBtn { icon: Icons.prev; onClicked: Media.prev() }
                    IconBtn { implicitWidth: 46; implicitHeight: 46; icon: Media.playing ? Icons.pause : Icons.play; iconSize: 18; fill: Theme.gViolet; onClicked: Media.toggle() }
                    IconBtn { icon: Icons.next; onClicked: Media.next() }
                }
            }
            Card {
                Layout.fillWidth: true
                spacing: 8
                Label { Layout.fillWidth: true; text: "session" }
                Repeater {
                    model: [["uptime", Sys.upText()], ["load", Sys.load1.toFixed(2) + " · " + Math.round(Sys.cpu * 100) + "% now"],
                            ["memory", Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB"], ["zram", Sys.zram || "off"]]
                    RowLayout {
                        required property var modelData
                        T { text: modelData[0]; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
                        T { text: modelData[1]; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    // ---- media ----
    RowLayout {
        visible: Shell.dashTab === "media"
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 34
        Item {
            implicitWidth: 250
            implicitHeight: 250
            Art { anchors.fill: parent; size: 250; radius: 30; glow: true }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            T { text: ("now playing · " + Media.source).toUpperCase(); font.pixelSize: 12; font.letterSpacing: 1.5; color: Theme.muted }
            GradText { text: Media.present ? Media.title : "Nothing playing"; font.pixelSize: 44; font.weight: Font.Light; Layout.maximumWidth: 640 }
            T { text: Media.artist + (Media.album ? " — " + Media.album : ""); font.pixelSize: 16; color: Theme.dim; Layout.fillWidth: true }
            Viz { bars: 56; barWidth: 6; barHeight: 70; spacing: 4 }
            Meter { Layout.fillWidth: true; implicitHeight: 6; value: Media.length > 0 ? Media.position / Media.length : 0; colors: Theme.gViolet }
            RowLayout { T { text: Media.clock(Media.position); font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true } T { text: Media.length > 0 ? Media.clock(Media.length) : ""; font.pixelSize: 12; color: Theme.muted } }
            RowLayout {
                spacing: 16
                IconBtn { implicitWidth: 44; implicitHeight: 44; icon: Icons.prev; iconSize: 17; onClicked: Media.prev() }
                IconBtn { implicitWidth: 62; implicitHeight: 62; icon: Media.playing ? Icons.pause : Icons.play; iconSize: 24; fill: Theme.gViolet; onClicked: Media.toggle() }
                IconBtn { implicitWidth: 44; implicitHeight: 44; icon: Icons.next; iconSize: 17; onClicked: Media.next() }
                Item { Layout.fillWidth: true }
                T { text: "MPRIS · " + Mpris.players.values.length + " player" + (Mpris.players.values.length === 1 ? "" : "s"); font.pixelSize: 12; color: Theme.muted }
            }
        }
    }
}
