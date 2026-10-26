pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// Default sink and source from PipeWire. Any volume change, from keys, pavucontrol or the shell,
// shows in the island, which is why the volume keys no longer need volnotify.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null

    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property real mic: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property string sinkName: sink ? (sink.nickname || sink.description || sink.name) : ""
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio !== null)

    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks).filter(x => x !== null) }

    function setVolume(v) { if (!ready) return; sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)); }
    function setMic(v) { if (!source || !source.audio) return; source.audio.muted = false; source.audio.volume = Math.max(0, Math.min(1, v)); }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted; }
    function useSink(node) { Pipewire.preferredDefaultAudioSink = node; }

    // Don't greet the session with an OSD for the volume it restored.
    property bool settled: false
    Timer { interval: 2000; running: true; onTriggered: root.settled = true }
    onVolumeChanged: if (settled) Shell.osd(muted ? Icons.volX : Icons.vol, muted ? 0 : volume, Theme.gBlue, "volume")
    onMutedChanged: if (settled) Shell.osd(muted ? Icons.volX : Icons.vol, muted ? 0 : volume, muted ? Theme.gGray : Theme.gBlue, muted ? "muted" : "volume")
    onMicMutedChanged: if (settled) Shell.msg(micMuted ? Icons.micOff : Icons.mic, micMuted ? "Microphone muted" : "Microphone on", micMuted ? Theme.red : Theme.aqua)
}
