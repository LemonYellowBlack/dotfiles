import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

// One screen of the greeter (greeter.qml): the lock screen with services/Greeter.qml as its
// controller, over the wallpaper neowall will show once the session is up.
//
// It comes in from the black the boot splash fades to: the wallpaper first, as the desktop will
// show it, then the blur, the frame growing in from the screen's edges, and the clock. Logging in
// runs that backwards and goes to black again, which is where the session starts from.
FocusScope {
    id: root
    property bool revealed: false
    property bool autoStart: true       // a harness drives these itself

    LockScreen {
        id: lock
        anchors.fill: parent
        focus: true
        ctl: Greeter
        shot: Wallpaper.url ? { url: Wallpaper.url } : null
        fillMode: Wallpaper.fillMode
        user: Greeter.user
        idleText: Greeter.farewell || Greeter.greeting
        promptText: "type to log in"
        sound: false
        growFrame: true
        autoShow: false
        barExtra: powerChip
    }
    property alias lockScreen: lock

    // Black at first, then the wallpaper; black again on the way out.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Greeter.leaving ? 1 : (root.revealed ? 0 : 1)
        Behavior on opacity { NumberAnimation { duration: Greeter.leaving ? 360 : 450; easing.type: Easing.InOutQuad } }
    }
    Timer { running: root.autoStart; interval: 120; onTriggered: root.revealed = true }
    Timer { running: root.autoStart; interval: 420; onTriggered: lock.show() }

    Component {
        id: powerChip
        // The power button opens into suspend, restart and shut down; one more click does it.
        Rectangle {
            id: chip
            property bool open: false
            implicitHeight: 30
            implicitWidth: row.implicitWidth + 8
            radius: 15
            color: Theme.pill
            border.width: open ? 1 : 0
            border.color: Theme.a(Theme.danger, 0.35)
            Behavior on implicitWidth { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: chip.open ? [["suspend", Icons.moon, Theme.info], ["reboot", Icons.reboot, Theme.warning], ["poweroff", Icons.power, Theme.danger]] : []
                    IconBtn {
                        required property var modelData
                        implicitWidth: 26
                        implicitHeight: 26
                        color: "transparent"
                        icon: modelData[1]
                        iconSize: 14
                        iconColor: modelData[2]
                        onClicked: Greeter.power(modelData[0])
                    }
                }
                IconBtn {
                    implicitWidth: 26
                    implicitHeight: 26
                    color: "transparent"
                    icon: chip.open ? Icons.x : Icons.power
                    iconSize: 14
                    iconColor: chip.open ? Theme.textMuted : Theme.danger
                    onClicked: chip.open = !chip.open
                }
            }
        }
    }
}
