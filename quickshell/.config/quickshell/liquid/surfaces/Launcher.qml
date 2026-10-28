import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services
import qs.widgets

// Rises out of the bottom edge. Type to search apps and actions; = calculates, : searches the
// clipboard history, vpn picks an exit node. One highlight glides between the rows.
Drawer {
    id: root
    kind: "bottom"
    dw: 720
    dx: (width - dw) / 2
    pad: 18
    spacing: 14

    property int sel: 0
    readonly property var items: Apps.items
    onItemsChanged: sel = Math.min(sel, Math.max(0, items.length - 1))
    onOpenChanged: if (open) { Apps.setQuery(""); sel = 0; input.text = ""; input.forceActiveFocus(); }

    function run(i) { const it = items[i]; if (it) it.run(); }
    function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function marked(it) {
        if (!it.pos) return esc(it.name);
        const hit = {};
        it.pos.forEach(p => hit[p] = true);
        return it.name.split("").map((c, i) => hit[i] ? "<font color=\"" + Theme.highlight + "\"><b>" + esc(c) + "</b></font>" : esc(c)).join("");
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 27
        color: Theme.a(Theme.layer, 0.65)
        border.width: 1
        border.color: Theme.a(Theme.accent, input.activeFocus ? 0.55 : 0.3)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 12
            spacing: 12
            GradText { text: "❯"; font.pixelSize: 20; font.weight: Font.Bold }
            TextInput {
                id: input
                Layout.fillWidth: true
                font.family: Theme.font
                font.pixelSize: 17
                color: Theme.text
                selectionColor: Theme.selection
                cursorDelegate: Rectangle { width: 2; color: Theme.highlight; SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                clip: true
                onTextEdited: { Apps.setQuery(text); root.sel = 0; }
                Connections { target: Apps; function onQueryChanged() { if (input.text !== Apps.query) input.text = Apps.query; } }
                T {
                    visible: input.text === ""
                    text: "apps, actions · = calc · : clipboard" + (Host.exitNode ? " · vpn" : "")
                    color: Theme.textMuted
                    font.italic: true
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Down) { root.sel = Math.min(root.sel + 1, root.items.length - 1); e.accepted = true; }
                    else if (e.key === Qt.Key_Up) { root.sel = Math.max(root.sel - 1, 0); e.accepted = true; }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.run(root.sel); e.accepted = true; }
                    else if (e.key === Qt.Key_Tab) {
                        const order = ["", "=", ":"].concat(Host.exitNode ? ["vpn "] : []);
                        const at = ["apps", "calc", "clip", "vpn"].indexOf(Apps.mode);
                        Apps.setQuery(order[(at + 1) % order.length]);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Escape) {
                        if (input.text) Apps.setQuery(""); else Shell.close();
                        e.accepted = true;
                    }
                }
            }
            Rectangle {
                implicitWidth: modeText.implicitWidth + 18
                implicitHeight: 22
                radius: 11
                gradient: Grad { colors: Theme.gAccent }
                T { id: modeText; anchors.centerIn: parent; text: Apps.mode; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.textOnAccent }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: list.implicitHeight
        Rectangle {
            visible: root.items.length > 0
            width: parent.width
            height: 52
            y: root.sel * 54
            radius: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.a(Theme.accent, 0.3) }
                GradientStop { position: 1; color: Theme.a(Theme.accentAlt, 0.14) }
            }
            border.width: 1
            border.color: Theme.a(Theme.accent, 0.5)
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        }
        ColumnLayout {
            id: list
            width: parent.width
            spacing: 2
            Repeater {
                model: root.items
                Item {
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.sel
                    Layout.fillWidth: true
                    implicitHeight: 52
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 14
                        AppIcon {
                            size: 36
                            iconName: modelData.iconName || ""
                            glyph: modelData.icon || ""
                            colors: Theme.gAccent
                            scale: parent.parent.on ? 1.1 : 1
                            rotation: parent.parent.on ? -4 : 0
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            T { text: root.marked(modelData); textFormat: Text.StyledText; font.pixelSize: 14; font.weight: parent.parent.parent.on ? Font.DemiBold : Font.Normal; Layout.fillWidth: true }
                            T { text: modelData.desc || ""; font.pixelSize: 11; color: parent.parent.parent.on ? Theme.textAlt : Theme.textMuted; Layout.fillWidth: true; visible: text !== "" }
                        }
                        Kbd { visible: (modelData.hint || "") !== ""; text: modelData.hint || "" }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) root.sel = parent.index
                        onClicked: root.run(parent.index)
                    }
                }
            }
            T { visible: root.items.length === 0; text: "No match."; color: Theme.textMuted; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 24; Layout.bottomMargin: 24 }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Repeater {
            model: [["↑↓", "move"], ["↵", "run"], ["tab", "mode"], ["esc", "close"]]
            RowLayout { required property var modelData; spacing: 5; Kbd { text: modelData[0] } T { text: modelData[1]; font.pixelSize: 11; color: Theme.textMuted } }
        }
        Item { Layout.fillWidth: true }
        T { text: root.items.length + " shown"; font.pixelSize: 11; color: Theme.textMuted }
    }
}
