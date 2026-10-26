import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.config
import qs.services
import qs.widgets

// The island in the middle of the bar: a clock until something happens, then it becomes that
// thing for a moment (a level, a toggle's confirmation, the charger, a notification) and springs
// back. Each kind keeps its last item, so it can fade out after Shell.island clears.
Rectangle {
    id: root
    readonly property var item: Shell.island
    readonly property string kind: item ? item.kind : "clock"
    property var last: ({})
    onItemChanged: if (item) { const l = Object.assign({}, last); l[item.kind] = item; last = l; }

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

    readonly property var days: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var mons: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    width: kind === "osd" ? 340 : (kind === "note" ? 440 : (kind === "charge" ? 340 : (kind === "msg" ? Math.min(480, msgText.implicitWidth + 84) : clockRow.implicitWidth + 34)))
    height: kind === "note" ? 84 : 30
    radius: kind === "note" ? 26 : 16
    color: Theme.night
    border.width: 1
    border.color: kind === "note" ? Theme.a(Theme.violet, 0.45) : Theme.a(Theme.blue, hover.containsMouse ? 0.45 : 0.18)
    clip: true
    Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
    Behavior on height { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
    Behavior on radius { NumberAnimation { duration: 400 } }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.toggle(root.kind === "note" ? "control" : "dash", "")
    }

    component Layer: Item {
        property bool on: false
        anchors.fill: parent
        opacity: on ? 1 : 0
        scale: on ? 1 : 0.94
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
    }

    Layer {
        on: root.kind === "clock"
        RowLayout {
            id: clockRow
            anchors.centerIn: parent
            spacing: 10
            T { text: root.days[root.now.getDay()] + " " + root.mons[root.now.getMonth()] + " " + root.now.getDate(); color: Theme.dim }
            T { text: Qt.formatTime(root.now, "HH:mm"); font.weight: Font.Bold }
            Viz { visible: Media.playing; bars: 4; barHeight: 12 }
        }
    }

    Layer {
        id: osdL
        on: root.kind === "osd"
        readonly property var it: root.last.osd || { icon: "", value: 0, colors: Theme.gBlue }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            Icon { path: osdL.it.icon; size: 17; stroke: 2; color: osdL.it.colors[1] }
            Meter { Layout.fillWidth: true; implicitHeight: 8; value: osdL.it.value; colors: osdL.it.colors }
            T { text: Math.round(osdL.it.value * 100); font.weight: Font.DemiBold; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
        }
    }

    Layer {
        id: msgL
        on: root.kind === "msg"
        readonly property var it: root.last.msg || { icon: "", text: "", color: Theme.blue }
        RowLayout {
            anchors.centerIn: parent
            spacing: 10
            Icon { visible: msgL.it.icon !== ""; path: msgL.it.icon; size: 16; stroke: 2; color: msgL.it.color }
            T { id: msgText; text: msgL.it.text }
        }
    }

    Layer {
        id: chargeL
        on: root.kind === "charge"
        readonly property bool plugged: (root.last.charge || { on: false }).on
        RowLayout {
            anchors.centerIn: parent
            spacing: 10
            Icon {
                path: Icons.bolt; size: 16; stroke: 2; color: Theme.green
                SequentialAnimation on y { running: Power.charging; loops: Animation.Infinite; NumberAnimation { to: -2; duration: 800; easing.type: Easing.InOutSine } NumberAnimation { to: 2; duration: 800; easing.type: Easing.InOutSine } }
            }
            T { text: chargeL.plugged ? "Charging" : "On battery" }
            T { text: chargeL.plugged ? (Power.toFull > 0 ? "full in " + Power.span(Power.toFull) : "") : Power.span(Power.toEmpty) + " left"; color: Theme.muted; font.pixelSize: 12 }
            BatteryGlyph { implicitWidth: 30; implicitHeight: 16 }
        }
    }

    Layer {
        id: noteL
        on: root.kind === "note"
        readonly property var n: (root.last.note || { note: null }).note
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 20
            spacing: 12
            AppIcon {
                size: 40
                iconName: noteL.n ? (noteL.n.image || noteL.n.appIcon) : ""
                glyph: Icons.bell
                colors: Theme.gWarm
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                T { text: noteL.n ? noteL.n.appName + "  now" : ""; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true }
                T { text: noteL.n ? noteL.n.summary : ""; font.weight: Font.DemiBold; Layout.fillWidth: true }
                T { text: noteL.n ? noteL.n.body.replace(/\n/g, " ") : ""; font.pixelSize: 12; color: Theme.old; Layout.fillWidth: true }
            }
        }
    }
}
