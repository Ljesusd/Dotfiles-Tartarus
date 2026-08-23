import Quickshell
import Quickshell.Services.Pipewire
import QtQml

QtObject {
    id: root

    readonly property ScriptModel outputsModel: ScriptModel {
        values: Pipewire.nodes.values.filter(node => {
            return node
                && node.audio
                && node.isSink
                && !node.isStream
        })
    }

    readonly property var sink:
        Pipewire.defaultAudioSink

    readonly property var currentOutput:
        Pipewire.defaultAudioSink

    readonly property bool available:
        root.sink
        && root.sink.audio

    readonly property bool muted:
        root.available
        ? root.sink.audio.muted
        : false

    readonly property real volume:
        root.available
        ? root.sink.audio.volume
        : 0

    readonly property int volumePercent:
        Math.round(root.volume * 100)

    readonly property string displayText: {
        if (!root.available)
            return "--"

        if (root.muted)
            return "Muted"

        return root.volumePercent + "%"
    }

    readonly property string outputName:
        root.outputDisplayName(root.currentOutput)

    readonly property PwObjectTracker sinkTracker: PwObjectTracker {
        objects: [root.sink]
    }

    function toggleMute() {
        if (!root.available)
            return

        root.sink.audio.muted =
            !root.sink.audio.muted
    }

    function setVolume(volume) {
        if (!root.available)
            return

        root.sink.audio.volume =
            Math.max(
                0.0,
                Math.min(volume, 1.0)
            )
    }

    function changeVolume(delta) {
        root.setVolume(
            root.volume + delta
        )
    }

    function outputDisplayName(output) {
        if (!output)
            return "Unknown output"

        return output.description
            || output.nickname
            || output.name
            || "Unknown output"
    }

    function selectOutput(output) {
        if (!output)
            return

        if (output === Pipewire.defaultAudioSink)
            return

        Pipewire.preferredDefaultAudioSink =
            output
    }
}
