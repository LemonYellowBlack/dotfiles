pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// The MPRIS player worth showing: the one playing, else the first. The visualizer follows the
// default sink's real peak level instead of a canned animation.
Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    readonly property bool present: player !== null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle || player.identity) : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    readonly property string art: player ? player.trackArtUrl : ""
    readonly property string source: player ? player.identity : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    property real position: 0

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function prev() { if (player && player.canGoPrevious) player.previous(); }
    function clock(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // MPRIS doesn't push position updates; poll while something is playing.
    Timer {
        interval: 1000; repeat: true; running: root.playing; triggeredOnStart: true
        onTriggered: if (root.player) { root.player.positionChanged(); root.position = root.player.position; }
    }

    readonly property real level: peaks.peak
    PwNodePeakMonitor { id: peaks; node: Pipewire.defaultAudioSink; enabled: root.playing }
}
