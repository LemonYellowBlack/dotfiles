import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Every workspace as a card with its windows where Hyprland put them, each a capture of the
// window. Click a card to go there; drag a window onto another card to move it.
Item {
    id: root
    readonly property int current: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property real cardW: 332
    readonly property real cardH: 187
    readonly property real sx: cardW / Math.max(1, Screen.width)

    function workspace(i) { return Hyprland.workspaces.values.find(x => x.id === i) ?? null; }
    function go(i) {
        const w = workspace(i);
        if (w) w.activate();
        else Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + i + " })" : "workspace " + i);
        Shell.close();
    }
    function moveTo(toplevel, i) {
        if (!toplevel || (toplevel.workspace && toplevel.workspace.id === i)) return;
        const addr = toplevel.address.startsWith("0x") ? toplevel.address : "0x" + toplevel.address;
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.window.move({ workspace = " + i + ", window = \"address:" + addr + "\", silent = true })"
            : "movetoworkspacesilent " + i + ",address:" + addr);
    }

    // Tiles are drawn from lastIpcObject, which only changes when the clients are fetched again:
    // fetch them on open and whenever a window opens, closes or moves (hyprctl reports where the
    // layout is heading, not where its animation is).
    Component.onCompleted: Hyprland.refreshToplevels()
    Timer { id: refetch; interval: 100; onTriggered: Hyprland.refreshToplevels() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen"].includes(event.name)) refetch.restart();
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 28
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            GradText { text: "workspaces"; font.pixelSize: 26; font.weight: Font.DemiBold }
            T { text: "drag a window to move it · click a card to switch · SUPER Tab"; font.pixelSize: 12; color: Theme.muted; Layout.fillWidth: true }
            Pill { onClicked: Shell.close(); T { text: "esc close"; font.pixelSize: 12 } }
        }
        GridLayout {
            columns: 5
            columnSpacing: 28
            rowSpacing: 30
            Repeater {
                model: 10
                ColumnLayout {
                    id: slot
                    required property int index
                    readonly property int ws: index + 1
                    // The workspace's own model, so a window arriving or leaving adds or removes
                    // one tile instead of rebuilding (and recapturing) the card.
                    readonly property var space: root.workspace(ws)
                    readonly property int count: space ? space.toplevels.values.length : 0
                    spacing: 10
                    opacity: 0
                    scale: 0.9
                    Component.onCompleted: { opacity = 1; scale = 1; }
                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 40 + slot.index * 35 } NumberAnimation { duration: 320 } } }
                    Behavior on scale { SequentialAnimation { PauseAnimation { duration: 40 + slot.index * 35 } NumberAnimation { duration: 480; easing.type: Easing.OutBack } } }

                    Rectangle {
                        id: card
                        readonly property bool dropHere: drop.containsDrag && !(ghost.toplevel && ghost.toplevel.workspace && ghost.toplevel.workspace.id === slot.ws)
                        implicitWidth: root.cardW
                        implicitHeight: root.cardH
                        radius: 18
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.wave1 }
                            GradientStop { position: 1; color: Theme.ink0 }
                        }
                        border.width: slot.ws === root.current ? 2 : 1
                        border.color: card.dropHere ? Theme.yellow : (slot.ws === root.current ? Theme.blue : Theme.a(Theme.ink4, 0.6))
                        scale: card.dropHere ? 1.05 : (cardMouse.containsMouse && !ghost.toplevel ? 1.03 : 1)
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(slot.ws) }
                        DropArea { id: drop; anchors.fill: parent; onDropped: d => root.moveTo(d.source.toplevel, slot.ws) }

                        Repeater {
                            model: slot.space ? slot.space.toplevels : null
                            Rectangle {
                                id: win
                                required property var modelData
                                readonly property var o: modelData.lastIpcObject || {}
                                readonly property bool dragging: dragArea.drag.active
                                x: o.at ? (o.at[0] % Screen.width) * root.sx : 6
                                y: o.at ? (o.at[1] % Screen.height) * root.sx : 6
                                width: o.size ? o.size[0] * root.sx : root.cardW - 12
                                height: o.size ? o.size[1] * root.sx : root.cardH - 12
                                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                onWidthChanged: settle.again()
                                onHeightChanged: settle.again()
                                onDraggingChanged: if (dragging) { ghost.tile = shot; ghost.toplevel = modelData; }
                                opacity: ghost.toplevel === modelData ? 0.3 : 1
                                radius: 8
                                color: Qt.rgba(0.12, 0.12, 0.157, 0.9)
                                border.width: 1
                                border.color: modelData.activated ? Theme.a(Theme.blue, 0.8) : Theme.a(Theme.ink4, 0.6)
                                clip: true
                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.wayland
                                    // The capture arrives as an opaque texture, so its transparent
                                    // pixels would punch through the overlay to the windows below;
                                    // drawing it through a layer blends them over the tile instead.
                                    layer.enabled: true
                                }
                                // A window still growing into a new layout is captured at its old
                                // size with the rest left transparent, so take two more frames once
                                // the layout has had time to settle (a frame waits for the screen
                                // to next change).
                                Timer {
                                    id: settle
                                    property int shots: 0
                                    function again() { shots = 0; restart(); }
                                    interval: 400
                                    repeat: true
                                    running: true
                                    onTriggered: {
                                        if (shot.hasContent) shot.captureFrame();
                                        if (++shots >= 2) stop();
                                    }
                                }
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    visible: !shot.hasContent
                                    spacing: 4
                                    AppIcon { Layout.alignment: Qt.AlignHCenter; size: 28; iconName: DesktopEntries.heuristicLookup(win.o.class || "") ? DesktopEntries.heuristicLookup(win.o.class).icon : ""; glyph: Icons.term; colors: Theme.gAqua }
                                    T { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: win.width - 10; text: win.modelData.title; font.pixelSize: 10; color: Theme.muted }
                                }
                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: ghost
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    onPressed: {
                                        const r = win.mapToItem(root, 0, 0, win.width, win.height);
                                        ghost.x = r.x; ghost.y = r.y; ghost.width = r.width; ghost.height = r.height;
                                    }
                                    onReleased: if (ghost.toplevel) { ghost.Drag.drop(); ghost.end(); }
                                    onCanceled: ghost.end()
                                    onClicked: root.go(slot.ws)
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: slot.ws === root.current ? "transparent" : Qt.rgba(0.212, 0.212, 0.275, 0.8)
                            gradient: slot.ws === root.current ? g : null
                            Grad { id: g; colors: Theme.gBlue }
                            T { anchors.centerIn: parent; text: slot.ws; font.pixelSize: 11; font.weight: Font.Bold; color: slot.ws === root.current ? Theme.ink0 : Theme.fg }
                        }
                        T { text: slot.count ? slot.count + (slot.count > 1 ? " windows" : " window") : "empty"; font.pixelSize: 12; color: Theme.muted }
                    }
                }
            }
        }
    }

    // The window being dragged, drawn over every card while its tile waits dimmed in place (a
    // card clips its tiles, so the tile itself would vanish at the card's edge).
    Rectangle {
        id: ghost
        property var toplevel: null
        property Item tile: null
        function end() { toplevel = null; tile = null; }
        visible: toplevel !== null
        radius: 8
        color: Qt.rgba(0.12, 0.12, 0.157, 0.95)
        border.width: 2
        border.color: Theme.yellow
        scale: 1.06
        Drag.active: toplevel !== null
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        ShaderEffectSource {
            anchors.fill: parent
            anchors.margins: 2
            sourceItem: ghost.tile
        }
    }
}
