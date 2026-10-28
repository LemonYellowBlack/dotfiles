import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.config
import qs.services
import qs.widgets

// Lock and suspend take a click; log out, reboot and shut down want a one-second hold, drawn as a
// ring filling around the button. Let go early and nothing happens.
Item {
    id: root
    property bool firmware: false
    property string status: "hold to confirm · logind ignores the power key"
    property color statusColor: Theme.textMuted

    function logout() { Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit"); }
    readonly property var actions: [
        { id: "lock", name: "Lock", hint: "L · click", icon: Icons.lock, colors: Theme.gAccent, hold: false, run: () => { Shell.close(); Quickshell.execDetached(["loginctl", "lock-session"]); } },
        { id: "suspend", name: "Suspend", hint: "S · click", icon: Icons.moon, colors: Theme.gAccentCool, hold: false, run: () => { Shell.close(); Quickshell.execDetached(["systemctl", "suspend"]); } },
        { id: "logout", name: "Log out", hint: "O · hold 1 s", icon: Icons.logout, colors: Theme.gWarm, hold: true, run: () => root.logout() },
        { id: "reboot", name: "Reboot", hint: "R · hold 1 s", icon: Icons.reboot, colors: Theme.gHot, hold: true,
          run: () => Quickshell.execDetached(root.firmware ? ["systemctl", "reboot", "--firmware-setup"] : ["systemctl", "reboot"]) },
        { id: "poweroff", name: "Shut down", hint: "P · hold 1 s", icon: Icons.power, colors: Theme.gDanger, hold: true, run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 30
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Ring {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 96; implicitHeight: 96; thickness: 3; value: 1; glow: false
                Rectangle {
                    anchors.centerIn: parent; width: 76; height: 76; radius: 38
                    gradient: Gradient { GradientStop { position: 0; color: Theme.selection } GradientStop { position: 1; color: Theme.selectionDeep } }
                    T { anchors.centerIn: parent; text: Quickshell.env("USER").slice(0, 1); font.pixelSize: 30; font.weight: Font.Bold }
                }
            }
            T { Layout.alignment: Qt.AlignHCenter; text: "see you, " + Quickshell.env("USER"); font.pixelSize: 20; font.weight: Font.DemiBold }
            T {
                Layout.alignment: Qt.AlignHCenter
                text: "up " + Sys.upText() + (Power.hasBattery ? " · battery " + Math.round(Power.level * 100) + "%" : "") + " · auto-lock " + (Toggles.autolock ? "on" : "off until reboot")
                font.pixelSize: 12; color: Theme.textMuted
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 44
            Repeater {
                model: root.actions
                ColumnLayout {
                    id: btn
                    required property var modelData
                    required property int index
                    property real held: 0
                    spacing: 10
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 60 + btn.index * 50 } NumberAnimation { duration: 300 } } }
                    NumberAnimation on held {
                        id: hold
                        running: false
                        from: 0; to: 1; duration: 1000
                        onFinished: if (btn.held >= 1) { root.status = "confirmed: " + btn.modelData.name.toLowerCase(); root.statusColor = Theme.success; btn.modelData.run(); }
                    }
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 112
                        implicitHeight: 112
                        Rectangle {
                            id: face
                            anchors.centerIn: parent
                            width: 96; height: 96; radius: 48
                            color: mouse.containsMouse ? Theme.a(btn.modelData.colors[0], 0.2) : Theme.a(Theme.layer, 0.65)
                            border.width: 1
                            border.color: mouse.containsMouse ? btn.modelData.colors[0] : Theme.a(Theme.line, 0.7)
                            scale: mouse.containsMouse || btn.held > 0 ? 1.1 : 1
                            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 250 } }
                            Icon { anchors.centerIn: parent; path: btn.modelData.icon; size: 32; color: btn.modelData.colors[0] }
                        }
                        Ring { anchors.fill: parent; thickness: 4; value: btn.held; colors: btn.modelData.colors; visible: btn.held > 0 }
                        MouseArea {
                            id: mouse
                            anchors.fill: face
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (!btn.modelData.hold) { btn.modelData.run(); return; }
                                root.status = "keep holding…"; root.statusColor = Theme.warning;
                                hold.restart();
                            }
                            onReleased: {
                                if (!btn.modelData.hold || btn.held >= 1) return;
                                hold.stop(); btn.held = 0;
                                root.status = "released early, nothing ran"; root.statusColor = Theme.textMuted;
                            }
                        }
                    }
                    T { Layout.alignment: Qt.AlignHCenter; text: btn.modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold }
                    T { Layout.alignment: Qt.AlignHCenter; text: btn.modelData.hint; font.pixelSize: 11; color: Theme.textMuted }
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Pill { active: root.firmware; onClicked: root.firmware = !root.firmware; Icon { path: Icons.cpu; size: 14; stroke: 2 } T { text: "reboot to firmware"; font.pixelSize: 12; color: root.firmware ? Theme.highlight : Theme.text } }
        }
        T { Layout.alignment: Qt.AlignHCenter; text: root.status; font.pixelSize: 12; color: root.statusColor }
    }
}
