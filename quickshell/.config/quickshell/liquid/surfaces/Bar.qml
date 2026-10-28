import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.config
import qs.services
import qs.widgets

// The bar is the top edge of the frame. Left: prompt, workspaces, overview, focused window.
// Centre: the island. Right: media, indicators, vitals, homelab, status, notifications, power.
Item {
    id: root
    required property string screenName
    implicitHeight: Theme.barH

    function hang(name, pill) { Shell.setAnchor(name, pill.mapToItem(null, pill.width / 2, 0).x); Shell.toggle(name, ""); }
    function on(name) { return Shell.on(name, root.screenName); }

    readonly property var active: Hyprland.activeToplevel
    readonly property string appClass: active && active.lastIpcObject ? (active.lastIpcObject.class || "") : ""
    readonly property var entry: appClass ? DesktopEntries.heuristicLookup(appClass) : null

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Pill {
            active: root.on("launcher")
            onClicked: Shell.toggle("launcher", "")
            T { text: "❯"; color: Theme.highlight }
            T { text: Host.name; color: Theme.secondary; font.weight: Font.DemiBold }
        }
        Workspaces { id: workspaces }
        Pill {
            pad: 8
            active: root.on("overview")
            onClicked: Shell.toggle("overview", "")
            Icon { path: Icons.grid; size: 14; stroke: 2; color: Theme.textSubtle }
        }
        RowLayout {
            spacing: 8
            Layout.leftMargin: 6
            Layout.maximumWidth: 300
            visible: root.active !== null
            AppIcon { size: 16; iconName: root.entry ? root.entry.icon : ""; glyph: Icons.term; colors: Theme.gCool }
            T { text: root.entry ? root.entry.name : root.appClass; color: Theme.secondary }
            T { text: root.active ? root.active.title : ""; color: Theme.textSubtle; Layout.fillWidth: true; Layout.maximumWidth: 220 }
        }
    }

    property alias island: island
    Island {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Pill {
            visible: Media.present
            onClicked: Shell.open("dash", "media")
            Viz { bars: 4; barHeight: 13 }
            T { text: (Media.artist ? Media.artist + " — " : "") + Media.title; color: Theme.textSubtle; Layout.maximumWidth: 210 }
        }

        Pill {
            id: flags
            readonly property var list: [
                Toggles.caff ? [Icons.coffee, Theme.highlight, ""] : null,
                !Toggles.autolock ? [Icons.unlock, Theme.textMuted, ""] : null,
                Toggles.night && Sun.elevation < 3 ? [Icons.moon, Theme.highlight, ""] : null,
                Net.exitNode ? [Icons.shield, Theme.success, Net.exitNode.slice(0, 3).toUpperCase()] : null,
                Host.gpu === "prime" && Toggles.gpu !== "off" ? [Icons.gpu, Toggles.gpu === "on" ? Theme.hot : Theme.warning, Sys.gpu ? Math.round(Sys.gpu.temp) + "°" : "…"] : null,
                Host.sunshine && Toggles.sunshine ? [Icons.stream, Theme.info, ""] : null,
                Toggles.dnd ? [Icons.bellOff, Theme.textMuted, ""] : null
            ].filter(x => x)
            visible: list.length > 0
            onClicked: Shell.toggle("control", "")
            Repeater {
                model: flags.list
                RowLayout {
                    required property var modelData
                    spacing: 4
                    Icon { path: modelData[0]; size: 14; stroke: 2; color: modelData[1] }
                    T { visible: modelData[2] !== ""; text: modelData[2]; font.pixelSize: 11; color: modelData[1] }
                }
            }
        }

        Pill {
            id: vitals
            pad: 8
            active: root.on("vitals")
            onClicked: root.hang("vitals", vitals)
            Ring { implicitWidth: 22; implicitHeight: 22; thickness: 3; glow: false; value: (Sys.temp - 30) / 70; colors: Theme.tempColors(Sys.temp) }
            T { text: Math.round(Sys.temp) + "°"; Layout.rightMargin: 4 }
        }

        Pill {
            id: lab
            active: root.on("homelab")
            onClicked: root.hang("homelab", lab)
            Rectangle {
                implicitWidth: 8; implicitHeight: 8; radius: 4
                color: Lab.ok ? (Lab.down > 0 ? Theme.warning : Theme.success) : (Lab.error ? Theme.danger : Theme.textFaint)
                SequentialAnimation on opacity { running: Lab.ok; loops: Animation.Infinite; NumberAnimation { to: 0.4; duration: 1100 } NumberAnimation { to: 1; duration: 1100 } }
            }
            T { text: Host.labName; color: Theme.textAlt }
        }

        Pill {
            active: root.on("control")
            onClicked: Shell.toggle("control", "")
            Icon { path: Net.wifiOn && Net.ssid ? Icons.wifi : Icons.wifiOff; size: 15; stroke: 2 }
            Icon { path: Audio.muted ? Icons.volX : Icons.vol; size: 15; stroke: 2 }
            T { text: Audio.muted ? "mute" : Math.round(Audio.volume * 100) + "%"; Layout.minimumWidth: 34 }
            BatteryGlyph { visible: Power.hasBattery }
            T { visible: Power.hasBattery; text: Math.round(Power.level * 100) + "%"; Layout.preferredWidth: 34 }
        }

        Pill {
            pad: 9
            active: root.on("control")
            onClicked: Shell.toggle("control", "")
            Icon { path: Toggles.dnd ? Icons.bellOff : Icons.bell; size: 15; stroke: 2 }
            Rectangle {
                visible: Notifs.count > 0 && !Toggles.dnd
                implicitWidth: Math.max(16, badge.implicitWidth + 8)
                implicitHeight: 16
                radius: 8
                gradient: Grad { colors: [Theme.accent, Theme.accentAlt] }
                T { id: badge; anchors.centerIn: parent; text: Notifs.count; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.textOnAccent }
            }
        }

        Pill {
            pad: 9
            active: root.on("power")
            onClicked: Shell.toggle("power", "")
            Icon { path: Icons.power; size: 15; stroke: 2.2; color: Theme.danger }
        }
    }

    // Hovering a workspace dot previews that workspace's windows, laid out as Hyprland has them.
    Rectangle {
        id: peek
        readonly property int ws: Shell.peek
        readonly property var wsObj: ws ? Hyprland.workspaces.values.find(w => w.id === ws) : null
        readonly property var wins: wsObj ? wsObj.toplevels.values : []
        visible: opacity > 0
        opacity: ws > 0 && !Shell.busy ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        x: workspaces.mapToItem(root, 0, 0).x + 7 + Math.max(0, ws - 1) * 22 + 11 - width / 2
        y: Theme.barH + 4
        width: 236
        height: 156
        radius: 14
        color: Theme.a(Theme.surface, 0.94)
        border.width: 1
        border.color: Theme.a(Theme.accent, 0.25)
        T { x: 12; y: 8; text: "workspace " + peek.ws; font.pixelSize: 11; font.weight: Font.DemiBold }
        T { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; text: peek.wins.length ? peek.wins.length + (peek.wins.length > 1 ? " windows" : " window") : "empty"; font.pixelSize: 11; color: Theme.textMuted }
        Rectangle {
            id: mini
            x: 12; y: 30
            width: parent.width - 24
            height: parent.height - 42
            radius: 9
            color: Theme.selectionDeep
            clip: true
            readonly property real sx: width / Math.max(1, Screen.width)
            Repeater {
                model: peek.wins
                Rectangle {
                    required property var modelData
                    readonly property var o: modelData.lastIpcObject || {}
                    x: o.at ? (o.at[0] % Screen.width) * mini.sx : 0
                    y: o.at ? (o.at[1] % Screen.height) * mini.sx : 0
                    width: o.size ? o.size[0] * mini.sx : mini.width
                    height: o.size ? o.size[1] * mini.sx : mini.height
                    radius: 5
                    color: Theme.a(Theme.surfaceRaised, 0.9)
                    border.width: 1
                    border.color: modelData.activated ? Theme.a(Theme.accent, 0.7) : Theme.a(Theme.line, 0.6)
                    T { anchors.centerIn: parent; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; text: parent.o.class || ""; font.pixelSize: 9; color: Theme.textMuted }
                }
            }
        }
    }
}
