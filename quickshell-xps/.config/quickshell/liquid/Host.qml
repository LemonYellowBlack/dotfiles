pragma Singleton
import Quickshell

// What the Liquid shell can expect on the XPS 15 7590. Everything else in the config is shared;
// a module whose hardware is missing here is simply not shown.
Singleton {
    readonly property string name: "xps"
    readonly property string cpu: "i7-9750H · 6C/12T"

    // Sensors are found by hwmon name, because the hwmonN numbers move between boots.
    readonly property string tempSensor: "coretemp"
    readonly property string tempInput: "temp1_input"     // Package id 0
    readonly property var fans: [
        { sensor: "dell_smm", input: "fan1_input", label: "fan1 · dell_smm" },
        { sensor: "dell_smm", input: "fan2_input", label: "fan2 · dell_smm" }
    ]

    readonly property bool battery: true
    readonly property bool ecoOnBattery: true              // drop Hyprland blur and the border animation when unplugged
    readonly property string backlight: "intel_backlight"
    readonly property string profilePath: "/sys/firmware/acpi/platform_profile"   // TLP owns it; shown read-only

    // GTX 1650: unloaded by default, loaded by gpu-toggle or the game wrapper.
    readonly property string gpu: "prime"
    readonly property string gpuName: "GTX 1650 Mobile"
    readonly property int gpuCapW: 25

    readonly property bool touchpad: true
    readonly property bool exitNode: true                  // Mullvad through Tailscale, via the vpn script
    readonly property bool sunshine: false
    readonly property bool audioSwitch: false

    // The homelab drawer runs labstatus on hotdog over SSH.
    readonly property string labName: "hotdog"
    readonly property string labVia: "hotdog"

    readonly property real lat: 37.5407
    readonly property real lon: -77.4360
    readonly property string place: "Richmond"
}
