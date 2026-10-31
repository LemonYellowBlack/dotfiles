pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state, shared by every monitor's surface (surfaces/Locker.qml): whether the
// session is locked, the password being typed and the PAM conversation that checks it. Each
// screen is captured just before locking, so the lock can show it blurred.
// `qs -c liquid ipc call lock lock` locks; hypridle's lock_cmd calls it, so SUPER L, the power
// menu, idle and sleep all come through here. `... lock preview` shows the same screen in an
// ordinary window, with the real password check, that Esc closes: for trying it out.
Singleton {
    id: root

    property bool locked: false
    property bool previewing: false
    property bool capturing: false
    readonly property bool up: locked || previewing
    property var shots: ({})                // screen name → the grab of it from just before

    property string buffer: ""
    readonly property int typed: buffer.length
    property string phase: "idle"           // idle | typing | checking | failed | done
    property string message: ""             // why the last try failed, or what PAM said
    property int fails: 0
    property bool caps: false
    property date since: new Date()

    // A drawer or overlay closing takes a moment to slide away; the capture waits it out.
    property real settled: 0
    Connections {
        target: Shell
        function onBusyChanged() { if (!Shell.busy) root.settled = Date.now() + 300; }
    }

    property bool forPreview: false
    function lock() { start(false); }
    function preview() { if (!up) start(true); }
    function start(test) {
        if (locked || capturing) return;
        previewing = false;
        forPreview = test;
        Shell.close();
        capture.interval = Math.max(0, settled - Date.now());
        capture.restart();
    }
    Timer { id: capture; onTriggered: { root.shots = ({}); root.capturing = true; captureLimit.restart(); } }
    // Locker's capture windows hand in each screen; once all have, or after the limit, go.
    function captured(name, grab) {
        const s = Object.assign({}, shots);
        s[name] = grab;
        shots = s;
        if (Object.keys(s).length >= Quickshell.screens.length) engage();
    }
    Timer { id: captureLimit; interval: 700; onTriggered: root.engage() }
    function engage() {
        if (!capturing) return;
        capturing = false;
        captureLimit.stop();
        buffer = "";
        phase = "idle";
        message = "";
        fails = 0;
        since = new Date();
        if (forPreview) previewing = true;
        else locked = true;
        readCaps();
    }

    function setBuffer(text) {
        if (phase === "checking" || phase === "done") return;
        buffer = text;
        if (text) { phase = "typing"; message = ""; }
        else if (phase === "typing") phase = "idle";
    }
    function submit() {
        if (!up || buffer === "" || phase === "checking" || phase === "done") return;
        phase = "checking";
        message = "";
        if (!pam.start()) fail("couldn't reach PAM");
    }
    // Esc with nothing typed ends a preview; a real lock ignores it.
    function cancel() { if (previewing && buffer === "") finish(); }

    // The system's login stack, as hyprlock uses: pam_unix, with faillock counting misses.
    PamContext {
        id: pam
        onPamMessage: {
            if (responseRequired) respond(root.buffer);
            else if (messageIsError) root.message = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.succeed();
            else root.fail(root.message || (result === PamResult.MaxTries ? "too many tries" : "wrong password"));
        }
        onError: error => root.fail(error === PamError.StartFailed ? "couldn't start PAM" : "PAM failed")
    }

    function succeed() {
        buffer = "";
        phase = "done";
        leave.restart();
    }
    function fail(why) {
        if (phase !== "checking") return;   // start() failing can also raise an error: count it once
        buffer = "";
        fails++;
        message = why;
        phase = "failed";
    }
    // The surfaces fade out and unblur on `done`; the session unlocks once they have.
    Timer { id: leave; interval: 420; onTriggered: root.finish() }
    function finish() {
        locked = false;
        previewing = false;
        shots = ({});
        buffer = "";
        phase = "idle";
    }

    // Caps lock, from the keyboard's LED: read on locking and after each Caps Lock press.
    Process {
        id: capsRead
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.split("\n").some(l => parseInt(l) > 0) }
    }
    Timer { id: capsSoon; interval: 80; onTriggered: if (!capsRead.running) capsRead.running = true }
    function readCaps() { capsSoon.restart(); }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function preview(): void { root.preview(); }
    }
}
