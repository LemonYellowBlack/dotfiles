pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The colors drawer's side of theme/retheme: this machine's theme as `retheme json` describes it,
// and the edits the drawer makes (`retheme palette kanagawa-dragon`, `retheme set accent blue`,
// ...), run one after another. Each edit re-renders every themed tool; the shell itself recolors
// when Theme.qml sees the new theme.json. Edits land in theme/hosts/<host>.toml in the dotfiles.
Singleton {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/dotfiles/theme/retheme"
    property var state: null            // `retheme json`: palettes, variations, tokens, overrides
    property string error: ""           // the last edit's complaint, until the next one
    property var queue: []
    readonly property bool busy: runner.running || reader.running || queue.length > 0

    // One stream with the exit status on the end, so the complaint and the code can't race.
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if ((lines.pop() || "") !== "exit:0")
                    root.error = lines.filter(l => l.startsWith("retheme:")).map(l => l.slice(9)).join("\n") || "retheme failed";
                root.next();
            }
        }
    }
    Process {
        id: reader
        command: ["sh", "-c", "\"$0\" json 2>&1", root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); }
                catch (e) { root.error = text.trim().replace(/^retheme: /, "") || "can't read the theme"; }
            }
        }
    }

    function refresh() { if (!reader.running) reader.running = true; }
    function run(args) {
        queue = queue.concat([args]);
        if (!runner.running) next();
    }
    function next() {
        if (queue.length === 0) { refresh(); return; }
        error = "";
        runner.command = ["sh", "-c", "\"$0\" \"$@\" 2>&1; echo exit:$?", bin].concat(queue[0]);
        queue = queue.slice(1);
        runner.running = true;
    }
}
