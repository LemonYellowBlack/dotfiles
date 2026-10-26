pragma Singleton
import QtQuick
import Quickshell

// Kanagawa Wave plus the Liquid geometry. barH and edge are also the exclusive zones the shell
// reserves, and hypr/liquid.lua's gaps_out sits inside them, so change them together.
Singleton {
    readonly property color ink0: "#16161D"
    readonly property color ink1: "#1F1F28"
    readonly property color ink2: "#2A2A37"
    readonly property color ink3: "#363646"
    readonly property color ink4: "#54546D"
    readonly property color fg: "#DCD7BA"
    readonly property color old: "#C8C093"
    readonly property color muted: "#938AA9"
    readonly property color dim: "#9CABCA"
    readonly property color gray: "#727169"
    readonly property color blue: "#7E9CD8"
    readonly property color violet: "#957FB8"
    readonly property color aqua: "#7AA89F"
    readonly property color green: "#98BB6C"
    readonly property color yellow: "#E6C384"
    readonly property color orange: "#FFA066"
    readonly property color red: "#E46876"
    readonly property color cyan: "#7FB4CA"
    readonly property color pink: "#D27E99"
    readonly property color wave: "#2D4F67"
    readonly property color wave1: "#223249"
    readonly property color night: "#0d0d12"

    readonly property color surface: ink0
    readonly property color pill: Qt.rgba(0.165, 0.165, 0.216, 0.6)
    readonly property color pillHover: Qt.rgba(0.212, 0.212, 0.275, 0.95)
    readonly property color card: Qt.rgba(0.165, 0.165, 0.216, 0.42)
    readonly property color track: Qt.rgba(0.33, 0.33, 0.43, 0.35)

    readonly property string font: "Maple Mono NF"

    readonly property int barH: 40
    readonly property int edge: 8
    readonly property int frameR: 20
    readonly property int drawerR: 26

    readonly property var gBlue: ["#7FB4CA", "#7E9CD8", "#957FB8"]
    readonly property var gViolet: ["#957FB8", "#D27E99"]
    readonly property var gWarm: ["#E6C384", "#FFA066"]
    readonly property var gAqua: ["#7AA89F", "#98BB6C"]
    readonly property var gRed: ["#FFA066", "#E46876"]
    readonly property var gGray: ["#54546D", "#363646"]

    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha); }
    function tempColors(t) { return t > 85 ? gRed : (t > 70 ? gWarm : gAqua); }
}
