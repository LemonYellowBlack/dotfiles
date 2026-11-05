import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// What the desktop does on its way out (Shell.leave), on every screen above everything else: see
// OutroView. Shell.leaveMs after it begins, the action runs; a preview plays it back instead.
Scope {
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: Shell.leaving !== ""
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "liquid-outro"

            OutroView {
                id: view
                anchors.fill: parent
                kind: Shell.leaving
                // Decoded while the power menu is open, so it's ready by the time a hold finishes.
                loadWallpaper: Shell.overlay === "power" || win.visible
                NumberAnimation on p {
                    id: run
                    running: false
                    from: 0; to: 1; duration: Shell.leaveMs - 50
                    onFinished: if (view.kind === "preview") back.restart()
                }
                NumberAnimation on p { id: back; running: false; from: 1; to: 0; duration: Shell.previewBackMs - 50 }
            }
            onVisibleChanged: if (visible) { view.p = 0; run.restart(); }
        }
    }
}
