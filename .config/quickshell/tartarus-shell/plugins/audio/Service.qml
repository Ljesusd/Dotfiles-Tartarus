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

    // Physical input devices (microphones, line-in and USB audio inputs).
    // Streams are excluded because they belong to applications, not devices.
    readonly property ScriptModel inputsModel: ScriptModel {
        values: Pipewire.nodes.values.filter(node => {
            return node
                && node.audio
                && !node.isSink
                && !node.isStream
        })
    }

    // Playback streams are the per-application controls exposed by PipeWire.
    // Hardware sinks stay in outputsModel; streams such as Firefox, Steam or
    // a media player appear here and can be changed independently.
    readonly property ScriptModel applicationStreamsModel: ScriptModel {
        values: Pipewire.nodes.values.filter(node => {
            const mediaClass = String((node && node.properties || {})["media.class"] || "")
            return node
                && node.audio
                && (node.isStream || mediaClass.indexOf("Stream") !== -1)
        })
    }

    // PipeWire exposes several streams for one application (Vesktop, for
    // example, can create separate streams for calls, notifications and the
    // main UI). Keep the raw model for low-level consumers, but expose a
    // grouped model for user-facing controls.
    readonly property ScriptModel applicationGroupsModel: ScriptModel {
        values: root.buildApplicationGroups()
    }

    readonly property PwObjectTracker applicationStreamsTracker: PwObjectTracker {
        objects: root.applicationStreamsModel.values
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

    function inputDisplayName(input) {
        if (!input)
            return "Unknown input"

        return input.description
            || input.nickname
            || input.name
            || "Unknown input"
    }

    function streamDisplayName(stream) {
        if (!stream)
            return "Aplicación"

        const properties = stream.properties || {}
        return properties["application.name"]
            || properties["node.description"]
            || properties["media.name"]
            || stream.description
            || stream.nickname
            || stream.name
            || "Aplicación"
    }

    function streamDetail(stream) {
        if (!stream)
            return ""

        const properties = stream.properties || {}
        return properties["application.process.binary"]
            || properties["media.name"]
            || ""
    }

    function applicationKey(stream) {
        const properties = stream?.properties || {}
        return String(
            properties["application.name"]
            || properties["application.process.binary"]
            || properties["node.name"]
            || stream?.name
            || "application"
        ).trim().toLowerCase()
    }

    function buildApplicationGroups() {
        const groups = []
        const byKey = ({})

        for (const stream of root.applicationStreamsModel.values || []) {
            if (!stream)
                continue

            const key = root.applicationKey(stream)
            let group = byKey[key]
            if (!group) {
                group = {
                    key: key,
                    name: root.streamDisplayName(stream),
                    detail: root.streamDetail(stream),
                    nodes: []
                }
                byKey[key] = group
                groups.push(group)
            }
            group.nodes.push(stream)
        }

        return groups
    }

    function applicationIcon(group) {
        const name = String(group?.name || "").toLowerCase()
        const detail = String(group?.detail || "").toLowerCase()
        const value = name + " " + detail

        if (value.includes("vesktop") || value.includes("discord"))
            return "chat"
        if (value.includes("spotify") || value.includes("sung") || value.includes("music"))
            return "music_note"
        if (value.includes("firefox") || value.includes("zen") || value.includes("chrome") || value.includes("browser"))
            return "language"
        if (value.includes("steam") || value.includes("game"))
            return "sports_esports"
        return "apps"
    }

    function groupVolume(group) {
        const nodes = group?.nodes || []
        if (nodes.length === 0)
            return 0
        let total = 0
        let count = 0
        for (const node of nodes) {
            if (node?.audio) {
                total += Number(node.audio.volume) || 0
                count++
            }
        }
        return count > 0 ? total / count : 0
    }

    function groupMuted(group) {
        const nodes = group?.nodes || []
        return nodes.length > 0 && nodes.every(node => node?.audio?.muted)
    }

    function setGroupVolume(group, volume) {
        for (const node of group?.nodes || [])
            root.setStreamVolume(node, volume)
    }

    function toggleGroupMute(group) {
        const muted = root.groupMuted(group)
        for (const node of group?.nodes || []) {
            if (node?.ready && node?.audio)
                node.audio.muted = !muted
        }
    }

    function setStreamVolume(stream, volume) {
        if (!stream || !stream.ready || !stream.audio)
            return

        stream.audio.volume = Math.max(0.0, Math.min(volume, 1.0))
    }

    function toggleStreamMute(stream) {
        if (!stream || !stream.ready || !stream.audio)
            return

        stream.audio.muted = !stream.audio.muted
    }

    function selectOutput(output) {
        if (!output)
            return

        if (output === Pipewire.defaultAudioSink)
            return

        Pipewire.preferredDefaultAudioSink =
            output
    }

    function selectInput(input) {
        if (!input)
            return

        if (input === Pipewire.defaultAudioSource)
            return

        Pipewire.preferredDefaultAudioSource =
            input
    }
}
