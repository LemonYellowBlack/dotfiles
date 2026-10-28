pragma Singleton
import Quickshell

// What the Liquid shell can expect on hotdog. Everything else in the config is shared;
// a module whose hardware is missing here is simply not shown.
Singleton {
    readonly property string name: "hotdog"
    readonly property string cpu: "Ryzen 7 7800X3D · 8C/16T"

    // Sensors are found by hwmon name, because the hwmonN numbers move between boots.
    readonly property string tempSensor: "k10temp"
    readonly property string tempInput: "temp1_input"     // Tctl
    readonly property var fans: []                         // the asus hwmon exposes no fan inputs

    readonly property bool battery: false
    readonly property bool ecoOnBattery: false
    readonly property string backlight: ""                 // the TV has no backlight device
    readonly property string profilePath: ""

    // RTX 4070 Ti: always loaded (Sunshine's NVENC, ollama and the other GPU services).
    readonly property string gpu: "always"
    readonly property string gpuName: "RTX 4070 Ti"
    readonly property int gpuCapW: 285

    readonly property bool touchpad: false
    readonly property bool exitNode: false
    readonly property bool sunshine: true                  // Moonlight streams this desktop
    readonly property bool audioSwitch: true               // USB interface or the TV over HDMI

    // The homelab drawer runs labstatus right here.
    readonly property string labName: "hotdog"
    readonly property string labVia: ""

    readonly property real lat: 37.5407
    readonly property real lon: -77.4360
    readonly property string place: "Richmond"
}
