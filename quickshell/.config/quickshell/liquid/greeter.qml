import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.surfaces

// The Liquid greeter: the lock screen over the wallpaper, logging in through greetd
// (surfaces/GreeterScreen.qml, services/Greeter.qml). greetd runs it as its greeter user in a
// Hyprland of its own (boot/greeter/start). From a session,
// `qs -p ~/.config/quickshell/liquid/greeter.qml` shows a preview that checks nothing; Esc closes it.
ShellRoot {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "liquid-greeter"
            GreeterScreen { anchors.fill: parent; focus: true }
        }
    }
}
