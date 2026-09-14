import Quickshell
import Quickshell.Services.Pipewire
import QtQml
import "../../services" as Services

QtObject {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property PwObjectTracker sourceTracker: PwObjectTracker {
        objects: [root.source]
    }
    // Settle the initial device snapshot before showing change feedback.
    property bool outputArmed: false
    property bool inputArmed: false
    readonly property Timer outputBaseline: Timer {
        interval: 500
        running: true
        onTriggered: root.outputArmed = root.available
    }
    readonly property Timer inputBaseline: Timer {
        interval: 500
        running: true
        onTriggered: root.inputArmed = !!(root.source && root.source.audio)
    }
    onSinkChanged: {
        outputArmed = false
        outputFeedback.stop()
        outputBaseline.restart()
    }
    onSourceChanged: {
        inputArmed = false
        inputFeedback.stop()
        inputBaseline.restart()
    }
    readonly property string outputSnapshot: root.available
        ? root.volumePercent + ":" + root.muted : ""
    readonly property string inputSnapshot: root.source && root.source.audio
        ? Math.round(root.source.audio.volume * 100) + ":" + root.source.audio.muted : ""
    onOutputSnapshotChanged: {
        if (outputArmed && available) outputFeedback.restart()
        else outputBaseline.restart()
    }
    onInputSnapshotChanged: {
        if (inputArmed && inputSnapshot.length > 0) inputFeedback.restart()
        else inputBaseline.restart()
    }
    readonly property Timer outputFeedback: Timer {
        interval: 20
        onTriggered: {
            if (root.available)
                Services.OsdService.show("volume", root.volumePercent, root.muted)
        }
    }
    readonly property Timer inputFeedback: Timer {
        interval: 20
        onTriggered: {
            if (root.source && root.source.audio)
                Services.OsdService.show("microphone",
                    Math.round(root.source.audio.volume * 100), root.source.audio.muted)
        }
    }

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
        Services.OsdService.show("volume", root.volumePercent, root.muted)
    }

    function setVolume(volume) {
        if (!root.available)
            return

        root.sink.audio.volume =
            Math.max(
                0.0,
                Math.min(volume, 1.0)
            )
        Services.OsdService.show("volume", Math.round(Math.max(0, Math.min(volume, 1.0)) * 100), root.muted)
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
