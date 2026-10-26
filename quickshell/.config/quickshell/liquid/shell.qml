import QtQuick
import Quickshell
import qs.services
import qs.surfaces

// Liquid: a frame around the screen that drawers grow out of, an island in the bar, and one
// Host.qml per machine (quickshell-xps, quickshell-hotdog) saying what hardware there is.
// Run with `qs -c liquid`; Hyprland side in hypr/liquid.lua.
ShellRoot {
    Variants {
        model: Quickshell.screens
        ScreenShell {}
    }
    // Singletons start on first use; the notification server and the eco switch must not wait.
    Component.onCompleted: { Notifs.count; Power.eco; Toggles.refresh(); }
}
