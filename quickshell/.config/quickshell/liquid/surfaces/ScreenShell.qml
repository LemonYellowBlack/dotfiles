import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// One screen's worth of shell. Four invisible zones reserve the frame so Hyprland tiles inside it;
// one full-screen layer draws the frame, bar and drawers with an input mask cut to what's visible;
// another, above everything, holds the overview, power menu and keybinds over a blurred veil.
Scope {
    id: root
    required property var modelData

    // Inline components can't see this file's ids, so each Zone is given its screen below.
    component Zone: PanelWindow {
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "liquid-zone"
    }
    Zone { screen: root.modelData; anchors { top: true; left: true; right: true } implicitHeight: Theme.barH; exclusiveZone: Theme.barH }
    Zone { screen: root.modelData; anchors { left: true; top: true; bottom: true } implicitWidth: Theme.edge; exclusiveZone: Theme.edge }
    Zone { screen: root.modelData; anchors { right: true; top: true; bottom: true } implicitWidth: Theme.edge; exclusiveZone: Theme.edge }
    Zone { screen: root.modelData; anchors { bottom: true; left: true; right: true } implicitHeight: Theme.edge; exclusiveZone: Theme.edge }

    PanelWindow {
        screen: root.modelData
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "liquid"
        WlrLayershell.keyboardFocus: surface.drawerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: surface.inputArea; Region { item: surface.island } }
        Surface { id: surface; anchors.fill: parent; screenName: root.modelData.name; focus: true }
    }

    PanelWindow {
        screen: root.modelData
        visible: overlays.shown
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "liquid-veil"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Overlays { id: overlays; anchors.fill: parent; screenName: root.modelData.name; focus: true }
    }
}
