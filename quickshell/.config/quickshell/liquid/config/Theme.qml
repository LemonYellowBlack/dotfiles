pragma Singleton
import QtQuick
import Quickshell

// Colors come in three layers: the Kanagawa palette by its own names, the tokens that give each
// palette color a job, and the translucent fills and gradients built from those tokens. Components
// only read tokens and composites, so retheming means pointing a token at a different palette color.
// barH and edge are also the exclusive zones the shell reserves, and hypr/liquid.lua's gaps_out
// sits inside them, so change them together.
Singleton {
    // ── Palette: Kanagawa Wave, named as in kanagawa.nvim. Only the tokens below read these.
    readonly property color sumiInk0: "#16161D"
    readonly property color sumiInk1: "#181820"
    readonly property color sumiInk2: "#1A1A22"
    readonly property color sumiInk3: "#1F1F28"
    readonly property color sumiInk4: "#2A2A37"
    readonly property color sumiInk5: "#363646"
    readonly property color sumiInk6: "#54546D"
    readonly property color waveBlue1: "#223249"
    readonly property color waveBlue2: "#2D4F67"
    readonly property color winterGreen: "#2B3328"
    readonly property color winterYellow: "#49443C"
    readonly property color winterRed: "#43242B"
    readonly property color winterBlue: "#252535"
    readonly property color autumnGreen: "#76946A"
    readonly property color autumnRed: "#C34043"
    readonly property color autumnYellow: "#DCA561"
    readonly property color samuraiRed: "#E82424"
    readonly property color roninYellow: "#FF9E3B"
    readonly property color waveAqua1: "#6A9589"
    readonly property color waveAqua2: "#7AA89F"
    readonly property color dragonBlue: "#658594"
    readonly property color fujiWhite: "#DCD7BA"
    readonly property color oldWhite: "#C8C093"
    readonly property color fujiGray: "#727169"
    readonly property color katanaGray: "#717C7C"
    readonly property color oniViolet: "#957FB8"
    readonly property color oniViolet2: "#B8B4D0"
    readonly property color crystalBlue: "#7E9CD8"
    readonly property color springViolet1: "#938AA9"
    readonly property color springViolet2: "#9CABCA"
    readonly property color springBlue: "#7FB4CA"
    readonly property color lightBlue: "#A3D4D5"
    readonly property color springGreen: "#98BB6C"
    readonly property color boatYellow1: "#938056"
    readonly property color boatYellow2: "#C0A36E"
    readonly property color carpYellow: "#E6C384"
    readonly property color sakuraPink: "#D27E99"
    readonly property color waveRed: "#E46876"
    readonly property color peachRed: "#FF5D62"
    readonly property color surimiOrange: "#FFA066"
    // Off-palette: a deeper ink than sumiInk0, for the island, tooltips and scrims.
    readonly property color abyss: "#0D0D12"

    // ── Tokens: the job each color does. Retheme here.
    // Surfaces, darkest first.
    readonly property color surfaceDeep: abyss         // island, tooltips, scrims
    readonly property color surface: sumiInk0          // frame, drawers, bar
    readonly property color surfaceRaised: sumiInk3    // window thumbnails and tags
    readonly property color layer: sumiInk4            // pills, cards, tiles, buttons
    readonly property color layerHover: sumiInk5
    readonly property color line: sumiInk6             // tracks and idle borders
    readonly property color selection: waveBlue2      // text selection, avatars
    readonly property color selectionDeep: waveBlue1  // window previews, cover-art backdrop

    // Text, brightest first.
    readonly property color text: fujiWhite
    readonly property color textAlt: oldWhite          // values, notification bodies
    readonly property color textSubtle: springViolet2  // subtitles, artists, unselected tabs
    readonly property color textMuted: springViolet1   // captions, hints, section labels
    readonly property color textFaint: fujiGray        // idle states, chart axes
    readonly property color textDisabled: sumiInk6
    readonly property color textOnAccent: sumiInk0     // text over accent fills and gradients

    // Accents and states.
    readonly property color accent: crystalBlue        // focus, active, primary
    readonly property color accentAlt: oniViolet       // the second stop of accent fills
    readonly property color accentPop: sakuraPink      // the last stop of decorative gradients
    readonly property color secondary: waveAqua2       // host and app names
    readonly property color info: springBlue           // weather, fans, streaming
    readonly property color highlight: carpYellow      // search matches, cursor, drop targets, lit toggles
    readonly property color success: springGreen
    readonly property color warning: carpYellow
    readonly property color hot: surimiOrange          // heavy load, the sun
    readonly property color danger: waveRed
    readonly property color dangerDeep: autumnRed

    // ── Composites, built from the tokens.
    readonly property color pill: a(layer, 0.6)
    readonly property color pillHover: a(layerHover, 0.95)
    readonly property color card: a(layer, 0.42)
    readonly property color track: a(line, 0.35)

    readonly property var gAccent: [info, accent, accentAlt]
    readonly property var gAccentAlt: [accentAlt, accentPop]
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
