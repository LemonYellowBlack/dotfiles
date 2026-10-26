import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services
import qs.widgets

// The keybind sheet, matching hypr/hyprland.lua, hypr/liquid.lua and this host's host.lua.
Item {
    id: root
    component Bind: RowLayout {
        property string keys
        property string does
        property string tag: ""
        Layout.fillWidth: true
        spacing: 10
        Row {
            Layout.preferredWidth: 190
            spacing: 4
            Repeater { model: parent.parent.keys.split(" "); Kbd { required property string modelData; text: modelData.replace(/_/g, " ") } }
        }
        T { text: parent.does; font.pixelSize: 12; color: Theme.old; Layout.fillWidth: true }
        Rectangle {
            visible: parent.tag !== ""
            implicitWidth: tagText.implicitWidth + 14; implicitHeight: 18; radius: 9
            color: parent.tag === "new" ? Theme.a(Theme.green, 0.2) : Theme.a(Theme.blue, 0.2)
            T { id: tagText; anchors.centerIn: parent; text: parent.parent.tag; font.pixelSize: 10; color: parent.parent.tag === "new" ? Theme.green : Theme.blue }
        }
    }
    component Group: ColumnLayout { property string title; Layout.fillWidth: true; spacing: 6; Label { Layout.fillWidth: true; text: parent.title } }

    Rectangle {
        anchors.centerIn: parent
        width: 1340
        height: sheet.implicitHeight + 52
        radius: 30
        color: Theme.a(Theme.ink0, 0.82)
        border.width: 1
        border.color: Theme.a(Theme.blue, 0.22)
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: sheet
            x: 30; y: 26
            width: parent.width - 60
            spacing: 20
            RowLayout {
                spacing: 14
                GradText { text: "keybinds"; font.pixelSize: 24; font.weight: Font.DemiBold }
                T { text: "SUPER /"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
                Pill { onClicked: Shell.close(); T { text: "esc close"; font.pixelSize: 12 } }
            }
            GridLayout {
                columns: 3
                columnSpacing: 30
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 20
                    Group { title: "launch"; Bind { keys: "SUPER ↵"; does: "kitty" } Bind { keys: "SUPER B"; does: "Zen Browser" } Bind { keys: "SUPER G"; does: "Google Chrome" } Bind { keys: "SUPER D"; does: "launcher, from the bottom edge"; tag: "shell" } Bind { keys: "SUPER C"; does: "clipboard history"; tag: "shell" } }
                    Group { title: "windows"; Bind { keys: "SUPER Q"; does: "close" } Bind { keys: "SUPER V"; does: "toggle floating" } Bind { keys: "SUPER F"; does: "fullscreen" } Bind { keys: "SUPER R"; does: "resize mode" } Bind { keys: "SUPER ←↑→↓"; does: "focus" } Bind { keys: "SUPER ⇧ ←↑→↓"; does: "swap" } }
                    Group { title: "workspaces"; Bind { keys: "SUPER 1…0"; does: "go to 1–10" } Bind { keys: "SUPER ⇧ 1…0"; does: "send window" } Bind { keys: "SUPER Tab"; does: "overview"; tag: "new" } }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 20
                    Group { title: "shell"; Bind { keys: "SUPER A"; does: "control center"; tag: "new" } Bind { keys: "SUPER N"; does: "notifications"; tag: "new" } Bind { keys: "SUPER F1"; does: "dashboard, was statuspopup"; tag: "shell" } Bind { keys: "SUPER F2"; does: Host.battery ? "battery, was batterypopup" : "control center"; tag: "shell" } Bind { keys: "SUPER /"; does: "this sheet"; tag: "new" } Bind { keys: "SUPER Esc"; does: "power menu"; tag: "new" } }
                    Group {
                        title: "toggles · ⇧ flips, the island confirms"
                        Bind { keys: "SUPER ⇧ F9"; does: "auto-lock"; tag: "shell" }
                        Bind { visible: Host.touchpad; keys: "SUPER ⇧ F10"; does: "touchpad"; tag: "shell" }
                        Bind { visible: Host.gpu === "prime"; keys: "SUPER ⇧ F11"; does: "dGPU"; tag: "shell" }
                        Bind { keys: "SUPER ⇧ F12"; does: "caffeine"; tag: "shell" }
                    }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 20
                    Group { title: "hardware"; Bind { keys: "vol_keys"; does: "volume, in the island"; tag: "shell" } Bind { keys: "mic_mute"; does: "mic, in the island"; tag: "shell" } Bind { visible: Host.backlight !== ""; keys: "brightness"; does: "brightness, in the island"; tag: "shell" } Bind { visible: Host.battery; keys: "lid_close"; does: "lock-if-enabled" } }
                    Group { title: "screenshots · hyprshot"; Bind { keys: "Print"; does: "whole output" } Bind { keys: "SUPER Print"; does: "region" } Bind { keys: "SUPER ⇧ Print"; does: "window" } }
                    Group { title: "session"; Bind { keys: "SUPER L"; does: "lock now" } Bind { keys: "CTRL SUPER ⇧ Del"; does: "power off" } }
                }
            }
            T { text: "Shell binds call qs ipc, e.g. qs -c liquid ipc call shell toggle control. The look (gaps, rounding, blur, the rotating border) lives in hypr/liquid.lua."; font.pixelSize: 11; color: Theme.muted }
        }
    }
}
