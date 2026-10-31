pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors come in two layers: the tokens that give each color a job, and the translucent fills and
// gradients built from them. Components only read these. The tokens are this machine's theme: a
// palette, a variation saying which of its colors does which job, and this host's own picks
// (theme/ in the dotfiles). theme/retheme writes them to ~/.config/theme/theme.json, which this
// watches, so a retheme recolors the shell in place; the theme drawer runs one from here.
// barH and edge are also the exclusive zones the shell reserves, and hypr/liquid.lua's gaps_out
// sits inside them, so change them together.
Singleton {
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/theme/theme.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: console.warn("Theme: can't read ~/.config/theme/theme.json; run theme/retheme")
    }
    // A retheme rewrites theme.json in place, so a read can land mid-write: keep the last good one.
    property var memo: ({ last: ({}) })
    readonly property var tokens: parse(file.text())
    function parse(text) {
        try { const c = JSON.parse(text).colors; if (c) memo.last = c; } catch (e) {}
        return memo.last;
    }
    // A token theme.json lacks shows up loud rather than quietly wrong.
    function c(name) { return tokens[name] ?? "#FF00FF"; }

    // ── Tokens: the job each color does. theme/variations/ says where each one is used.
    readonly property color surfaceDeep: c("surfaceDeep")
    readonly property color surface: c("surface")
    readonly property color surfaceRaised: c("surfaceRaised")
    readonly property color layer: c("layer")
    readonly property color layerHover: c("layerHover")
    readonly property color line: c("line")
    readonly property color selection: c("selection")
    readonly property color selectionDeep: c("selectionDeep")
    readonly property color shadow: c("shadow")
    readonly property color text: c("text")
    readonly property color textAlt: c("textAlt")
    readonly property color textSubtle: c("textSubtle")
    readonly property color textMuted: c("textMuted")
    readonly property color textFaint: c("textFaint")
    readonly property color textDisabled: c("textDisabled")
    readonly property color textOnAccent: c("textOnAccent")
    readonly property color caret: c("caret")
    readonly property color accent: c("accent")
    readonly property color accentSoft: c("accentSoft")
    readonly property color accentAlt: c("accentAlt")
    readonly property color accentCool: c("accentCool")
    readonly property color secondary: c("secondary")
    readonly property color info: c("info")
    readonly property color highlight: c("highlight")
    readonly property color success: c("success")
    readonly property color warning: c("warning")
    readonly property color hot: c("hot")
    readonly property color danger: c("danger")
    readonly property color dangerDeep: c("dangerDeep")

    // ── Composites, built from the tokens.
    readonly property color pill: a(layer, 0.6)
    readonly property color pillHover: a(layerHover, 0.95)
    readonly property color card: a(layer, 0.42)
    readonly property color track: a(line, 0.35)

    readonly property var gAccent: [accentSoft, accent, accentAlt]
    readonly property var gAccentCool: [info, accentCool]
    readonly property var gWarm: [warning, hot]
    readonly property var gCool: [secondary, success]
    readonly property var gHot: [hot, danger]
    readonly property var gDanger: [danger, dangerDeep]
    readonly property var gOff: [line, layerHover]

    readonly property string font: "Maple Mono NF"

    readonly property int barH: 40
    readonly property int edge: 8
    readonly property int frameR: 20
    readonly property int drawerR: 26

    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha); }
    function tempColors(t) { return t > 85 ? gHot : (t > 70 ? gWarm : gCool); }
}
