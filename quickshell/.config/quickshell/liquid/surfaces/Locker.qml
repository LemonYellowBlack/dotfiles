import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The lock: Hyprland's session lock with a LockScreen on every monitor, all sharing
// services/Lock.qml. Just before it locks, a one-pixel window on each screen captures what's
// showing so the lock can blur it; the captures are dropped when it unlocks. A preview puts the
// same screen in an ordinary overlay window instead (`qs -c liquid ipc call lock preview`).
Scope {
    Variants {
        model: Quickshell.screens
        Scope {
            id: scr
            required property var modelData

            LazyLoader {
                active: Lock.capturing
                PanelWindow {
                    screen: scr.modelData
                    anchors { top: true; left: true }
                    implicitWidth: 1
                    implicitHeight: 1
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    WlrLayershell.namespace: "liquid-capture"
                    // It sits outside its one-pixel window, so only the grab sees it. Half size
                    // is plenty for something that gets blurred.
                    ScreencopyView {
                        width: scr.modelData.width
                        height: scr.modelData.height
                        captureSource: scr.modelData
                        live: false
                        onHasContentChanged: if (hasContent) grabToImage(r => Lock.captured(scr.modelData.name, r), Qt.size(width / 2, height / 2))
                    }
                }
            }

            LazyLoader {
                active: Lock.previewing
                PanelWindow {
                    screen: scr.modelData
                    anchors { top: true; left: true; right: true; bottom: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                    WlrLayershell.namespace: "liquid-lock-preview"
                    LockScreen { anchors.fill: parent; focus: true; shot: Lock.shots[scr.modelData.name] || null; notes: Notifs.count }
                }
            }
        }
    }

    WlSessionLock {
        locked: Lock.locked
        WlSessionLockSurface {
            id: surface
            color: Theme.surfaceDeep
            LockScreen {
                anchors.fill: parent
                focus: true
                shot: surface.screen ? Lock.shots[surface.screen.name] || null : null
                notes: Notifs.count
            }
        }
    }
}
