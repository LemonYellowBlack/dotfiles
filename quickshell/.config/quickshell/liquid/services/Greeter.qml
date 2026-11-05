pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

// The greeter's side of the lock screen. greeter.qml shows surfaces/LockScreen.qml with this as
// its controller in place of services/Lock.qml: the same capsule, but the password goes to greetd,
// and once it's right the screen goes to black and greetd starts the session there. Who logs in
// comes from LIQUID_USER, which boot/install puts in greetd's config.
//
// Run from a session (no greetd) it's a preview: nothing is checked, "fail" fails and anything
// else succeeds, and Esc with nothing typed closes it.
Singleton {
    id: root

    readonly property string user: Quickshell.env("LIQUID_USER") || Quickshell.env("USER")
    readonly property bool live: Greetd.available
    readonly property bool previewing: !live

    property string buffer: ""
    readonly property int typed: buffer.length
    property string phase: "idle"           // idle | typing | checking | failed | done
    property string message: ""
    property int fails: 0
    property bool caps: false
    property date since: new Date()

    // What the island says while nothing's happening, and what it says on the way out.
    property string farewell: ""
    property date now: new Date()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.now = new Date() }
    readonly property string greeting: {
        const h = now.getHours();
        return h < 5 ? "good night" : (h < 12 ? "good morning" : (h < 18 ? "good afternoon" : "good evening"));
    }
    // greeter.qml fades the screen to black while this is true, before anything leaves.
    property bool leaving: false

    function setBuffer(text) {
        if (phase === "checking" || phase === "done" || leaving) return;
        buffer = text;
        if (text) { phase = "typing"; message = ""; }
        else if (phase === "typing") phase = "idle";
    }

    property bool answered: false
    function submit() {
        if (buffer === "" || phase === "checking" || phase === "done" || leaving) return;
        phase = "checking";
        message = "";
        if (!live) { previewCheck.restart(); return; }
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        answered = false;
        Greetd.createSession(user);
    }
    function cancel() { if (previewing && buffer === "" && !leaving) Qt.quit(); }

    Timer { id: previewCheck; interval: 700; onTriggered: root.buffer === "fail" ? root.fail("wrong password (preview)") : root.succeed() }

    Connections {
        target: Greetd
        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (!responseRequired) {
                if (error) root.message = text;
                return;
            }
            // One password is all this asks for; a second question (a token, an expired password)
            // gets an answer at a terminal instead.
            if (root.answered) {
                Greetd.cancelSession();
                root.fail(text || "PAM asks for more than a password");
                return;
            }
            root.answered = true;
            Greetd.respond(root.buffer);
        }
        function onAuthFailure(text) { root.fail(text || "wrong password"); }
        function onReadyToLaunch() { root.succeed(); }
        function onError(text) { root.fail(text || "greetd failed"); }
    }

    function succeed() {
        if (phase !== "checking") return;
        buffer = "";
        phase = "done";
        farewell = "welcome back";
        // LockScreen unblurs and lets its chips go on `done`; then the screen goes to black.
        outro.restart();
    }
    function fail(why) {
        if (phase !== "checking") return;
        buffer = "";
        fails++;
        message = why;
        phase = "failed";
    }
    Timer { id: outro; interval: 420; onTriggered: { root.leaving = true; launch.restart(); } }
    Timer { id: launch; interval: 400; onTriggered: root.start() }

    // The session is the user's login shell starting Hyprland, as logging in at the TTY did.
    property string shell: "/bin/sh"
    Process {
        running: true
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split(":"); if (f.length >= 7 && f[6]) root.shell = f[6]; } }
    }
    function start() {
        if (!live) { Qt.quit(); return; }
        Greetd.launch([shell, "-l", "-c", "exec start-hyprland"],
                      ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"], true);
    }

    // Suspend, restart or shut down from the greeter: the screen goes to black first, as it does
    // when the desktop leaves, so the boot splash picks up from black either way.
    function power(kind) {
        if (leaving || phase === "checking" || phase === "done") return;
        if (kind === "suspend") { Quickshell.execDetached(["systemctl", "suspend"]); return; }
        farewell = kind === "reboot" ? "restarting" : "shutting down";
        powerKind = kind;
        powerGo.restart();
    }
    property string powerKind: ""
    Timer { id: powerGo; interval: 500; onTriggered: { root.leaving = true; powerRun.restart(); } }
    Timer {
        id: powerRun
        interval: 400
        onTriggered: {
            if (!root.live) { Qt.quit(); return; }
            Quickshell.execDetached(["systemctl", root.powerKind === "reboot" ? "reboot" : "poweroff"]);
        }
    }

    // Caps lock, from the keyboard's LED, as the lock screen reads it.
    Process {
        id: capsRead
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.split("\n").some(l => parseInt(l) > 0) }
    }
    Timer { id: capsSoon; interval: 80; onTriggered: if (!capsRead.running) capsRead.running = true }
    function readCaps() { capsSoon.restart(); }
    Component.onCompleted: readCaps()
}
