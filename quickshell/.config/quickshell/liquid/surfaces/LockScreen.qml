import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs
import qs.config
import qs.services
import qs.widgets

// One monitor's lock screen. The frame and bar stay where they were and the windows inside the
// frame blur away, from a capture taken just before locking; over them sit the clock and the
// password capsule, with what's playing, the weather and the notification count along the
// bottom. services/Lock.qml holds the password and talks to PAM; this draws it and takes keys.
FocusScope {
    id: root
    property var ctl: Lock
    property var shot: null             // this screen's grab from just before locking
    property int notes: 0

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }
    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    readonly property string phase: ctl.phase
    readonly property bool failed: phase === "failed"
    readonly property bool checking: phase === "checking"
    readonly property bool leaving: phase === "done"
    readonly property color tone: failed ? Theme.danger : (checking ? Theme.info : (ctl.caps ? Theme.warning : Theme.textSubtle))
    readonly property string islandText: failed ? ctl.message + (ctl.fails > 1 ? " · " + ctl.fails : "")
        : (checking ? "checking…" : (ctl.caps ? "caps lock is on" : (ctl.previewing ? "preview · esc closes" : "locked since " + Qt.formatTime(ctl.since, "HH:mm"))))
    readonly property string islandIcon: failed ? Icons.x : (checking ? Icons.key : (ctl.caps ? Icons.keyboard : Icons.lock))

    // The accent gradient at t (0..1), for the dots.
    function blend(t) {
        const g = Theme.gAccent, s = t < 0.5 ? 0 : 1, u = t < 0.5 ? t * 2 : (t - 0.5) * 2;
        const a = g[s], b = g[s + 1];
        return Qt.rgba(a.r + (b.r - a.r) * u, a.g + (b.g - a.g) * u, a.b + (b.b - a.b) * u, 1);
    }

    // 0 → 1 as the lock comes up and back as it lets go: the blur, the dimming and everything on
    // top ride on it, so unlocking unblurs into the desktop that's really there.
    property real shown: 0
    Behavior on shown { NumberAnimation { duration: root.leaving ? 380 : 520; easing.type: Easing.OutCubic } }
    onLeavingChanged: if (leaving) shown = 0
    Component.onCompleted: { shown = 1; input.forceActiveFocus(); }

    // A click anywhere puts the keys back in the password field.
    MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

    // ── the desktop, blurred and dimmed
    Rectangle { anchors.fill: parent; color: Theme.surfaceDeep }
    Image {
        id: still
        anchors.fill: parent
        source: root.shot ? root.shot.url : ""
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: still
        visible: still.status === Image.Ready
        blurEnabled: true
        blur: root.shown
        blurMax: 64
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: Theme.surfaceDeep; opacity: 0.35 * root.shown }

    Frame { anchors.fill: parent; barTop: Theme.barH }

    component Chip: Rectangle {
        default property alias content: row.data
        property int pad: 12
        implicitHeight: 30
        implicitWidth: row.implicitWidth + pad * 2
        radius: implicitHeight / 2
        color: Theme.pill
        RowLayout { id: row; anchors.centerIn: parent; spacing: 8 }
    }

    // ── the bar: who and where on the left, the island saying what the lock is doing, status
    Item {
        width: parent.width
        height: Theme.barH
        opacity: root.shown
        RowLayout {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                T { text: "❯"; color: Theme.highlight }
                T { text: Host.name; color: Theme.secondary; font.weight: Font.DemiBold }
            }
            Chip {
                Icon { path: Icons.lock; size: 14; stroke: 2; color: Theme.accent }
                T { text: Quickshell.env("USER"); color: Theme.textSubtle }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 5
            height: 30
            width: islandRow.implicitWidth + 34
            radius: 15
            color: Theme.surfaceDeep
            border.width: 1
            border.color: root.failed ? Theme.a(Theme.danger, 0.55) : Theme.a(Theme.accent, 0.18)
            Behavior on width { NumberAnimation { duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            RowLayout {
                id: islandRow
                anchors.centerIn: parent
                spacing: 10
                Icon { path: root.islandIcon; size: 15; stroke: 2; color: root.failed || root.checking || root.ctl.caps ? root.tone : Theme.accent }
                T { text: root.islandText; color: root.tone }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Chip {
                Icon { path: Net.wifiOn && Net.ssid ? Icons.wifi : Icons.wifiOff; size: 15; stroke: 2 }
                Icon { path: Audio.muted ? Icons.volX : Icons.vol; size: 15; stroke: 2 }
                T { text: Audio.muted ? "mute" : Math.round(Audio.volume * 100) + "%" }
                BatteryGlyph { visible: Power.hasBattery }
                T { visible: Power.hasBattery; text: Math.round(Power.level * 100) + "%" }
            }
        }
    }

    // ── the clock and the capsule, in the middle of the frame
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barH + (root.height - Theme.barH - Theme.edge) / 2 - height / 2 + (1 - root.shown) * 24
        opacity: root.shown
        spacing: 0
        T {
            Layout.alignment: Qt.AlignHCenter
            text: root.dayNames[root.now.getDay()] + ", " + root.monthNames[root.now.getMonth()] + " " + root.now.getDate()
            font.pixelSize: 18
            color: Theme.textSubtle
        }
        GradText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -14
            Layout.bottomMargin: -10
            text: Qt.formatTime(root.now, "HH:mm")
            font.pixelSize: 136
            font.weight: Font.ExtraLight
        }
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            implicitWidth: 300
            implicitHeight: 48

            Rectangle {
                id: capsule
                width: parent.width
                height: parent.height
                radius: height / 2
                color: Theme.a(Theme.surfaceDeep, 0.82)
                border.width: 1
                border.color: root.failed ? Theme.a(Theme.danger, 0.8) : Theme.a(Theme.accent, root.ctl.typed > 0 ? 0.6 : 0.22)
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // The keys land here; the dots draw what's in it.
                TextInput {
                    id: input
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    readOnly: root.checking || root.leaving
                    onTextChanged: if (text !== root.ctl.buffer) root.ctl.setBuffer(text)
                    onAccepted: root.ctl.submit()
                    Keys.onEscapePressed: { if (text !== "") text = ""; else root.ctl.cancel(); }
                    Keys.onPressed: event => { if (event.key === Qt.Key_CapsLock) root.ctl.readCaps(); event.accepted = false; }
                }
                Connections {
                    target: root.ctl
                    function onBufferChanged() { if (input.text !== root.ctl.buffer) input.text = root.ctl.buffer; }
                    function onFailsChanged() { if (root.ctl.fails > 0) shake.restart(); }
                }

                Icon {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    path: Icons.lock
                    size: 16
                    stroke: 2
                    color: root.failed ? Theme.danger : Theme.accent
                }
                T {
                    anchors.centerIn: parent
                    visible: root.ctl.typed === 0
                    text: root.failed ? "try again" : "type to unlock"
                    color: Theme.textFaint
                }
                property real pulse: 0
                NumberAnimation on pulse { running: root.checking; loops: Animation.Infinite; from: 0; to: 1; duration: 900 }
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Repeater {
                        model: Math.min(root.ctl.typed, 18)
                        Rectangle {
                            required property int index
                            width: 9
                            height: 9
                            radius: 4.5
                            color: root.blend(index / Math.max(1, Math.min(root.ctl.typed, 18) - 1))
                            opacity: root.checking ? 0.35 + 0.65 * Math.abs(Math.sin((capsule.pulse + index * 0.08) * Math.PI)) : 1
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                        }
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.ctl.caps
                    path: Icons.keyboard
                    size: 16
                    stroke: 2
                    color: Theme.warning
                }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: capsule; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: capsule; property: "x"; to: 12; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: capsule; property: "x"; to: -8; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: capsule; property: "x"; to: 5; duration: 55; easing.type: Easing.InOutQuad }
                NumberAnimation { target: capsule; property: "x"; to: 0; duration: 50; easing.type: Easing.InQuad }
            }
        }
    }

    // ── along the bottom: what's playing, the weather, and how many notifications are waiting
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.edge + 22 - (1 - root.shown) * 16
        opacity: root.shown
        spacing: 10
        Chip {
            visible: Media.present
            implicitHeight: 38
            pad: 8
            Art { size: 24; radius: 7 }
            Viz { bars: 4; barHeight: 12 }
            T { text: (Media.artist ? Media.artist + " — " : "") + Media.title; color: Theme.textSubtle; Layout.maximumWidth: 300 }
            IconBtn { implicitWidth: 26; implicitHeight: 26; icon: Icons.prev; iconSize: 12; onClicked: Media.prev() }
            IconBtn { implicitWidth: 26; implicitHeight: 26; icon: Media.playing ? Icons.pause : Icons.play; iconSize: 12; fill: Theme.gAccent; onClicked: Media.toggle() }
            IconBtn { implicitWidth: 26; implicitHeight: 26; icon: Icons.next; iconSize: 12; onClicked: Media.next() }
        }
        Chip {
            visible: Weather.ok && Weather.now !== null
            implicitHeight: 38
            pad: 14
            Icon { path: Weather.now && Weather.now.code <= 1 ? (Sun.elevation > 0 ? Icons.sun : Icons.moon) : Icons.cloud; size: 15; stroke: 2; color: Theme.info }
            T { text: Weather.now ? Weather.now.temp + "°" : ""; font.weight: Font.DemiBold }
            T { text: Weather.now ? Weather.describe(Weather.now.code) : ""; color: Theme.textMuted }
        }
        Chip {
            visible: root.notes > 0
            implicitHeight: 38
            pad: 14
            Icon { path: Icons.bell; size: 15; stroke: 2; color: Theme.accent }
            T { text: root.notes + (root.notes === 1 ? " notification" : " notifications"); color: Theme.textAlt }
        }
    }
}
