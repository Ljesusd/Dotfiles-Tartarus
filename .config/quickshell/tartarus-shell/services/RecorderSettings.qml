pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    readonly property string defaultOutputDirectory:
        Quickshell.env("HOME") + "/Videos/Recordings"

    property int fps: 60
    property string framerateMode: "cfr"
    property string quality: "very_high"
    property string codec: "h264"
    property string encoder: "gpu"
    property bool cursor: true
    property string outputDirectory: root.defaultOutputDirectory

    property string captureMode: "monitor"
    property string monitorName: ""
    property var region: ({
        screen: "",
        x: 0,
        y: 0,
        width: 0,
        height: 0
    })

    property bool desktopAudio: false
    property string desktopAudioDevice: "default_output"
    property bool microphone: false
    property string microphoneDevice: "default_input"

    property string hudEdge: "bottom"
    property real hudOffset: 0.5

    readonly property FileView stateFile: FileView {
        path: Quickshell.stateDir + "/recording-settings.json"
        blockLoading: true
        printErrors: false
    }

    function defaults() {
        return {
            fps: 60,
            framerateMode: "cfr",
            quality: "very_high",
            codec: "h264",
            encoder: "gpu",
            cursor: true,
            outputDirectory: root.defaultOutputDirectory,
            captureMode: "monitor",
            monitorName: "",
            region: {
                screen: "",
                x: 0,
                y: 0,
                width: 0,
                height: 0
            },
            desktopAudio: false,
            desktopAudioDevice: "default_output",
            microphone: false,
            microphoneDevice: "default_input",
            hudEdge: "bottom",
            hudOffset: 0.5
        }
    }

    function normalizedRegion(value) {
        const candidate = value && typeof value === "object" ? value : {}
        const number = key => {
            const parsed = Number(candidate[key])
            return isFinite(parsed) ? Math.round(parsed) : 0
        }

        return {
            screen: typeof candidate.screen === "string" ? candidate.screen : "",
            x: number("x"),
            y: number("y"),
            width: Math.max(0, number("width")),
            height: Math.max(0, number("height"))
        }
    }

    function normalized(value) {
        const candidate = value && typeof value === "object" ? value : {}
        const allowedModes = ["cfr", "vfr", "content"]
        const allowedQualities = ["very_high", "high", "medium", "ultra"]
        const allowedCodecs = ["h264", "hevc", "av1", "vp8", "vp9"]
        const allowedEncoders = ["gpu", "cpu"]
        const allowedEdges = ["top", "right", "bottom", "left"]
        const fpsValue = Number(candidate.fps)

        return {
            fps: isFinite(fpsValue) ? Math.max(15, Math.min(240, Math.round(fpsValue))) : 60,
            framerateMode: allowedModes.includes(candidate.framerateMode)
                ? candidate.framerateMode : "cfr",
            quality: allowedQualities.includes(candidate.quality)
                ? candidate.quality : "very_high",
            codec: allowedCodecs.includes(candidate.codec)
                ? candidate.codec : "h264",
            encoder: allowedEncoders.includes(candidate.encoder)
                ? candidate.encoder : "gpu",
            cursor: candidate.cursor !== false,
            outputDirectory: typeof candidate.outputDirectory === "string"
                && candidate.outputDirectory.trim() !== ""
                ? candidate.outputDirectory.trim() : root.defaultOutputDirectory,
            captureMode: candidate.captureMode === "region" ? "region" : "monitor",
            monitorName: typeof candidate.monitorName === "string" ? candidate.monitorName : "",
            region: root.normalizedRegion(candidate.region),
            desktopAudio: candidate.desktopAudio === true,
            desktopAudioDevice: typeof candidate.desktopAudioDevice === "string"
                && candidate.desktopAudioDevice !== ""
                ? candidate.desktopAudioDevice : "default_output",
            microphone: candidate.microphone === true,
            microphoneDevice: typeof candidate.microphoneDevice === "string"
                && candidate.microphoneDevice !== ""
                ? candidate.microphoneDevice : "default_input",
            hudEdge: allowedEdges.includes(candidate.hudEdge)
                ? candidate.hudEdge : "bottom",
            hudOffset: isFinite(Number(candidate.hudOffset))
                ? Math.max(0, Math.min(1, Number(candidate.hudOffset))) : 0.5
        }
    }

    function snapshot() {
        return {
            fps: root.fps,
            framerateMode: root.framerateMode,
            quality: root.quality,
            codec: root.codec,
            encoder: root.encoder,
            cursor: root.cursor,
            outputDirectory: root.outputDirectory,
            captureMode: root.captureMode,
            monitorName: root.monitorName,
            region: root.normalizedRegion(root.region),
            desktopAudio: root.desktopAudio,
            desktopAudioDevice: root.desktopAudioDevice,
            microphone: root.microphone,
            microphoneDevice: root.microphoneDevice,
            hudEdge: root.hudEdge,
            hudOffset: root.hudOffset
        }
    }

    function save() {
        root.stateFile.setText(JSON.stringify(root.snapshot()))
    }

    function apply(value) {
        const next = root.normalized(value)
        root.fps = next.fps
        root.framerateMode = next.framerateMode
        root.quality = next.quality
        root.codec = next.codec
        root.encoder = next.encoder
        root.cursor = next.cursor
        root.outputDirectory = next.outputDirectory
        root.captureMode = next.captureMode
        root.monitorName = next.monitorName
        root.region = next.region
        root.desktopAudio = next.desktopAudio
        root.desktopAudioDevice = next.desktopAudioDevice
        root.microphone = next.microphone
        root.microphoneDevice = next.microphoneDevice
        root.hudEdge = next.hudEdge
        root.hudOffset = next.hudOffset
        root.save()
    }

    function reset() {
        root.apply(root.defaults())
    }

    function load() {
        const text = root.stateFile.text()
        if (!text || !text.trim())
            return

        try {
            root.apply(JSON.parse(text))
        } catch (error) {
            console.warn("RecorderSettings: configuración inválida; se usarán los valores actuales", error)
        }
    }

    Component.onCompleted: root.load()
}
