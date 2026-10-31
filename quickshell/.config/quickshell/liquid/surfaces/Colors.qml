import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The colors drawer: this machine's palette, its variation (which palette color does which job),
// and the tokens it picks for itself, all through theme/retheme. A pick re-renders every themed
// tool, from Hyprland's border to nvim, and the shell recolors as Theme.qml sees the new
// theme.json. Picks land in theme/hosts/<host>.toml in the dotfiles; everything else is shared.
Drawer {
    id: root
    kind: "corner"
    dw: 476
    maxH: height - 60
    spacing: 16

    readonly property var st: Retheme.state
    readonly property var palette: st ? st.palettes.find(p => p.id === st.palette) : null
    readonly property var variation: st ? st.variations.find(v => v.id === st.variation) : null
    readonly property var uiTokens: st ? st.tokens.filter(t => t.table === "ui") : []
    readonly property var sections: {
        const out = [];
        uiTokens.forEach(t => {
            let s = out.find(x => x.name === t.section);
            if (!s) { s = { name: t.section, tokens: [] }; out.push(s); }
            s.tokens.push(t);
        });
        return out;
    }
    readonly property int picks: st ? Object.keys(st.overrides).length : 0
    property string editing: ""        // the token whose swatches are open
    property string hoverSlot: ""
    property bool saving: false
    readonly property var tok: uiTokens.find(t => t.name === editing) || null

    onOpenChanged: {
        if (open) Retheme.refresh();
        else { editing = ""; saving = false; }
    }

    function hex(slot) { return palette && palette.slots[slot] ? palette.slots[slot] : "transparent"; }
    // A picked slot keeps the opacity the variation gives the token (textMuted is fg_dim @ 0.7).
    function pick(t, slot) {
        const m = /@\s*([0-9.]+)\s*$/.exec(t.base);
        Retheme.run(["set", t.name, m ? slot + " @ " + m[1] : slot]);
    }

    // The open token's choices: every slot of this palette, by family. A Component, not an inline
    // component, so it can see this file's ids.
    Component {
        id: picker
        Card {
            pad: 12
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { implicitWidth: 22; implicitHeight: 22; radius: 11; color: root.tok ? root.tok.color : "transparent"; border.width: 1; border.color: Theme.a(Theme.line, 0.8) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    T { text: root.tok ? root.tok.name + " · " + root.tok.value : ""; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    T { visible: text !== ""; text: root.tok ? root.tok.note : ""; font.pixelSize: 11; color: Theme.textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
                Pill {
                    visible: root.tok !== null && root.tok.overridden
                    implicitHeight: 26
                    pad: 10
                    onClicked: Retheme.run(["unset", root.tok.name])
                    Icon { path: Icons.undo; size: 12; color: Theme.textSubtle }
                    T { text: root.tok ? root.tok.base : ""; font.pixelSize: 11 }
                }
            }
            Repeater {
                model: root.st ? root.st.families : []
                RowLayout {
                    id: family
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    T { text: family.modelData.name; font.pixelSize: 10; color: Theme.textFaint; Layout.preferredWidth: 50 }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: family.modelData.slots
                            Rectangle {
                                id: swatch
                                required property string modelData
                                readonly property bool current: root.tok !== null && root.tok.slot === modelData
                                width: 24
                                height: 24
                                radius: 8
                                color: root.hex(modelData)
                                border.width: current ? 2 : 1
                                border.color: current ? Theme.text : Theme.a(Theme.line, 0.8)
                                scale: swatchMouse.containsMouse ? 1.15 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                MouseArea {
                                    id: swatchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.hoverSlot = swatch.modelData
                                    onExited: if (root.hoverSlot === swatch.modelData) root.hoverSlot = ""
                                    onClicked: root.pick(root.tok, swatch.modelData)
                                }
                            }
                        }
                    }
                }
            }
            T {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: root.hoverSlot ? Theme.textAlt : Theme.textMuted
                text: root.hoverSlot && root.palette
                    ? root.hoverSlot + (root.palette.names[root.hoverSlot] ? " · " + root.palette.names[root.hoverSlot] : "") + ": " + root.st.slotInfo[root.hoverSlot]
                    : "Pick a slot. It holds in any palette: " + (root.tok ? root.tok.name + " stays " + root.tok.slot : "the token keeps it") + " when the palette changes."
            }
        }
    }

    // ── Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            implicitWidth: 46
            implicitHeight: 46
            radius: 23
            gradient: Grad { colors: Theme.gAccent }
            Icon { anchors.centerIn: parent; path: Icons.palette; size: 22; color: Theme.textOnAccent; stroke: 2 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            T { text: "Colors"; font.weight: Font.DemiBold; font.pixelSize: 15; Layout.fillWidth: true }
            T {
                Layout.fillWidth: true
                font.pixelSize: 11
                color: Retheme.busy ? Theme.highlight : Theme.textMuted
                text: Retheme.busy ? "applying…" : (root.st ? root.st.host + " · " + root.palette.name + " · " + root.variation.name : "reading the theme…")
            }
        }
    }
    T { visible: Retheme.error !== ""; text: Retheme.error; color: Theme.danger; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

    // ── Palettes: the colors themselves
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.fillWidth: true; text: "palette"; note: root.st ? root.st.palettes.length + " to pick from" : "" }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: root.st ? root.st.palettes : []
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool current: root.st !== null && modelData.id === root.st.palette
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: 16
                    color: cardMouse.containsMouse ? Theme.pillHover : Theme.card
                    border.width: current ? 1.5 : 0
                    border.color: Theme.accent
                    Behavior on color { ColorAnimation { duration: 180 } }
                    // The palette on its own ground: its editor background, then its hues.
                    Rectangle {
                        x: 8; y: 8
                        width: parent.width - 16
                        height: 32
                        radius: 11
                        color: card.modelData.slots ? card.modelData.slots.bg3 : "transparent"
                        border.width: 1
                        border.color: card.modelData.slots ? card.modelData.slots.bg5 : "transparent"
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Repeater {
                                model: ["fg", "red", "orange", "yellow", "green", "aqua", "blue", "violet"]
                                Rectangle { required property string modelData; width: 13; height: 13; radius: 6.5; color: card.modelData.slots ? card.modelData.slots[modelData] : "transparent" }
                            }
                        }
                    }
                    RowLayout {
                        x: 12
                        y: 46
                        width: parent.width - 24
                        spacing: 6
                        T { text: card.modelData.name; font.pixelSize: 12; font.weight: card.current ? Font.DemiBold : Font.Normal; Layout.fillWidth: true }
                        T { text: card.modelData.kind || ""; font.pixelSize: 10; color: Theme.textFaint }
                        Icon { visible: card.current; path: Icons.check; size: 13; color: Theme.accent; stroke: 2.4 }
                    }
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: card.current ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!card.current && !card.modelData.error) Retheme.run(["palette", card.modelData.id])
                    }
                }
            }
        }
    }

    // ── Variations: which palette color does which job
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.fillWidth: true; text: "variation"; note: "the jobs colors do" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.st ? root.st.variations : []
                Pill {
                    id: vpill
                    required property var modelData
                    active: root.st !== null && modelData.id === root.st.variation
                    implicitHeight: 34
                    pad: 12
                    onClicked: if (!active) Retheme.run(["variation", modelData.id])
                    // What it would do here: its accents in this palette.
                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 10
                        radius: 5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: vpill.modelData.accents[0] || "transparent" }
                            GradientStop { position: 0.35; color: vpill.modelData.accents[1] || "transparent" }
                            GradientStop { position: 0.7; color: vpill.modelData.accents[2] || "transparent" }
                            GradientStop { position: 1; color: vpill.modelData.accents[3] || "transparent" }
                        }
                    }
                    T { text: vpill.modelData.name; font.pixelSize: 12 }
                }
            }
        }
        T { visible: text !== ""; text: root.variation ? root.variation.description : ""; font.pixelSize: 11; color: Theme.textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }

    // ── Tokens: this machine's own picks on top of the variation
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.fillWidth: true; text: "tokens"; note: root.picks ? root.picks + " picked on " + root.st.host : "all from " + (root.variation ? root.variation.name : "the variation") }
        Repeater {
            model: root.sections
            ColumnLayout {
                id: section
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                T { text: section.modelData.name.toLowerCase(); font.pixelSize: 11; color: Theme.textFaint }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: section.modelData.tokens
                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool open: root.editing === modelData.name
                            implicitWidth: chipRow.implicitWidth + 18
                            implicitHeight: 28
                            radius: 14
                            color: open ? Theme.a(Theme.accent, 0.2) : (chipMouse.containsMouse ? Theme.pillHover : Theme.pill)
                            border.width: open || modelData.overridden ? 1 : 0
                            border.color: Theme.a(Theme.accent, open ? 0.6 : 0.35)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { width: 14; height: 14; radius: 7; anchors.verticalCenter: parent.verticalCenter; color: chip.modelData.color; border.width: 1; border.color: Theme.a(Theme.line, 0.9) }
                                T { text: chip.modelData.name; font.pixelSize: 11; color: chip.modelData.overridden ? Theme.accent : Theme.textAlt; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.editing = chip.open ? "" : chip.modelData.name; root.hoverSlot = ""; }
                            }
                        }
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    active: section.modelData.tokens.some(t => t.name === root.editing)
                    visible: active
                    sourceComponent: picker
                }
            }
        }
    }

    // ── This machine
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.fillWidth: true; text: "this machine"; note: root.st ? "theme/hosts/" + root.st.host + ".toml" : "" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Pill {
                visible: root.picks > 0
                implicitHeight: 28
                pad: 11
                onClicked: Retheme.run(["unset", "--all"])
                Icon { path: Icons.undo; size: 13; color: Theme.textSubtle }
                T { text: root.picks === 1 ? "drop the pick" : "drop " + root.picks + " picks"; font.pixelSize: 11 }
            }
            Repeater {
                model: root.st ? root.st.hosts.filter(h => h !== root.st.host) : []
                Pill {
                    required property string modelData
                    implicitHeight: 28
                    pad: 11
                    onClicked: Retheme.run(["copy", modelData])
                    Icon { path: Icons.copy; size: 13; color: Theme.textSubtle }
                    T { text: "same as " + modelData; font.pixelSize: 11 }
                }
            }
            Pill {
                active: root.saving
                implicitHeight: 28
                pad: 11
                onClicked: { root.saving = !root.saving; if (root.saving) nameInput.forceActiveFocus(); }
                Icon { path: Icons.save; size: 13; color: Theme.textSubtle }
                T { text: "save as a variation"; font.pixelSize: 11 }
            }
        }
        Rectangle {
            visible: root.saving
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 20
            color: Theme.a(Theme.layer, 0.65)
            border.width: 1
            border.color: Theme.a(Theme.accent, nameInput.activeFocus ? 0.55 : 0.3)
            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
                selectionColor: Theme.selection
                clip: true
                // A variation's file name: lowercase, digits and dashes.
                onTextEdited: text = text.toLowerCase().replace(/[^a-z0-9-]+/g, "-")
                onAccepted: {
                    if (text.replace(/-/g, "") === "") return;
                    Retheme.run(["save", text.replace(/^-+|-+$/g, "")]);
                    text = "";
                    root.saving = false;
                }
                T {
                    visible: nameInput.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "a name for it, then ↵"
                    color: Theme.textMuted
                    font.italic: true
                }
            }
        }
        T {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Theme.textMuted
            text: "Every machine shares the palettes, variations and configs; only this file differs. Commit it to keep these picks."
        }
    }
}
