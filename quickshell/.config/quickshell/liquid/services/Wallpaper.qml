pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The image neowall draws behind everything, from the first `path` and `mode` in
// ~/.config/neowall/config.vibe. The greeter shows it before there's a desktop, and the outro
// brings it back over the windows as the desktop goes; boot/plymouth/render reads the same lines,
// so the boot splash shows it too. Empty while neowall runs a shader with no image.
Singleton {
    id: root

    FileView {
        id: file
        path: Theme.home + "/.config/neowall/config.vibe"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var conf: parse(file.text())
    readonly property string path: conf.path
    readonly property string url: path ? "file://" + path : ""
    // neowall's modes, as Image fill modes; neowall's own default is fill.
    readonly property int fillMode: ({ stretch: Image.Stretch, fit: Image.PreserveAspectFit, center: Image.Pad, tile: Image.Tile })[conf.mode] ?? Image.PreserveAspectCrop

    function parse(text) {
        let path = "", mode = "";
        for (const raw of (text || "").split("\n")) {
            const line = raw.split("#")[0].trim();
            const m = line.match(/^(path|mode)\s+(.+)$/);
            if (!m) continue;
            if (m[1] === "path" && !path) path = m[2].trim().replace(/^~\//, Theme.home + "/");
            if (m[1] === "mode" && !mode) mode = m[2].trim();
        }
        return { path: path, mode: mode };
    }
}
