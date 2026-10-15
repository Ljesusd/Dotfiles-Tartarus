pragma Singleton

import Quickshell.Io
import Quickshell
import QtQuick
import QtQml

QtObject {
    id: root

    property bool available: false
    readonly property bool active: recorderProcess.running
    readonly property bool busy: root.starting || root.active || root.finishing
    property bool starting: false
    property bool paused: false
    property bool stopping: false
    property bool finishing: false
    property bool cancelStart: false
    property string recordingScreen: ""
    property string captureTarget: ""
    property string outputPath: ""
    property string errorText: ""
    property int elapsedSeconds: 0
    property var audioDevices: []
    property bool regionPickerOpen: false
    property string regionPickerScreen: ""

    signal regionSelected(string screenName, real x, real y, real width, real height)
    signal regionSelectionCancelled()

    readonly property string displayTime: {
        const minutes = Math.floor(root.elapsedSeconds / 60)
        const seconds = root.elapsedSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    property Process availabilityProcess: Process {
        id: availabilityProcess
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        stdout: StdioCollector { waitForEnd: true }
        onExited: (code, status) => {
            root.available = code === 0
            if (root.available)
                root.refreshAudioDevices()
        }
    }

    property Process audioDevicesProcess: Process {
        id: audioDevicesProcess
        command: ["gpu-screen-recorder", "--list-audio-devices"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseAudioDevices(text)
        }
    }

    property Process directoryProcess: Process {
        id: directoryProcess
        onExited: (code, status) => {
            if (root.cancelStart) {
                root.starting = false
                root.cancelStart = false
                return
            }

            if (code !== 0) {
                root.starting = false
                root.notify("No se pudo preparar la grabación", "No se pudo crear la carpeta de destino.")
                return
            }

            root.launchRecorder()
        }
    }

    property Process recorderProcess: Process {
        id: recorderProcess
        stderr: SplitParser {
            onRead: data => {
                root.errorText = (root.errorText + "\n" + data).slice(-1500)
            }
        }
        onExited: (code, status) => root.finishCapture(code)
    }

    property Process savedFileProcess: Process {
        id: savedFileProcess
        onExited: (code, status) => root.finishSave(code)
    }

    property Timer poller: Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: root.elapsedSeconds++
    }

    property Timer stopAfterResume: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (root.active)
                recorderProcess.signal(2)
        }
    }

    function refresh() {
        if (!availabilityProcess.running)
            availabilityProcess.running = true
    }

    function refreshAudioDevices() {
        if (root.available && !audioDevicesProcess.running)
            audioDevicesProcess.running = true
    }

    function parseAudioDevices(value) {
        const entries = []
        for (const line of String(value || "").split(/\r?\n/)) {
            const trimmed = line.trim()
            if (!trimmed || trimmed.startsWith("["))
                continue
            const separator = trimmed.indexOf("|")
            if (separator < 0)
                continue
            const id = trimmed.slice(0, separator).trim()
            const label = trimmed.slice(separator + 1).trim()
            if (id !== "")
                entries.push({ id: id, label: label || id })
        }
        root.audioDevices = entries
    }

    function notify(title, body) {
        ToastService.push(root.recordingScreen, "videocam", title, body, 6000)
    }

    function expandHome(path) {
        const value = String(path || "").trim()
        const home = Quickshell.env("HOME")
        if (value === "~")
            return home
        if (value.startsWith("~/"))
            return home + value.slice(1)
        return value
    }

    function validScreen(name) {
        return String(name || "") !== ""
            && String(name) !== "FALLBACK"
            && Quickshell.screens.some(screen => screen
                && screen.name === String(name)
                && screen.width > 0
                && screen.height > 0)
    }

    function screenFor(name) {
        return Quickshell.screens.find(screen => screen
            && screen.name === String(name || "")
            && screen.name !== "FALLBACK"
            && screen.width > 0
            && screen.height > 0) || null
    }

    function firstScreen() {
        const candidate = Quickshell.screens.find(screen => screen
            && screen.name
            && screen.name !== "FALLBACK"
            && screen.width > 0
            && screen.height > 0)
        return candidate ? candidate.name : ""
    }

    function validRegion(region) {
        const screen = root.screenFor(region ? region.screen : "")
        if (!screen)
            return false

        const screenX = Number(screen.x) || 0
        const screenY = Number(screen.y) || 0
        const x = Number(region.x)
        const y = Number(region.y)
        const width = Number(region.width)
        const height = Number(region.height)
        return isFinite(x) && isFinite(y) && isFinite(width) && isFinite(height)
            && width > 0
            && height > 0
            && x >= screenX
            && y >= screenY
            && x + width <= screenX + Number(screen.width)
            && y + height <= screenY + Number(screen.height)
    }

    function regionArgument(region) {
        return Math.round(Number(region.width)) + "x"
            + Math.round(Number(region.height)) + "+"
            + Math.round(Number(region.x)) + "+"
            + Math.round(Number(region.y))
    }

    function buildCommand(settings, screenName, outputPath) {
        const config = settings || RecorderSettings.snapshot()
        const targetRegion = config.captureMode === "region"
            && root.validRegion(config.region)
            ? config.region : null
        const target = targetRegion ? "region" : screenName
        const args = ["gpu-screen-recorder", "-w", target]

        if (targetRegion)
            args.push("-region", root.regionArgument(targetRegion))

        args.push(
            "-f", String(config.fps),
            "-fm", String(config.framerateMode),
            "-q", String(config.quality),
            "-k", String(config.codec),
            "-encoder", String(config.encoder),
            "-cursor", config.cursor ? "yes" : "no"
        )

        const audio = []
        if (config.desktopAudio && config.desktopAudioDevice)
            audio.push(String(config.desktopAudioDevice))
        if (config.microphone && config.microphoneDevice)
            audio.push(String(config.microphoneDevice))
        if (audio.length > 0)
            args.push("-a", audio.join("|"))

        args.push("-o", outputPath)
        return args
    }

    function start(monitorName) {
        if (root.starting || root.active || root.finishing)
            return

        const config = RecorderSettings.snapshot()
        const requestedScreen = monitorName === undefined || monitorName === null
            ? String(config.monitorName || root.firstScreen())
            : String(monitorName)
        const regionMode = config.captureMode === "region" && root.validRegion(config.region)
        root.recordingScreen = regionMode ? String(config.region.screen) : requestedScreen

        if (!root.available) {
            root.notify("Grabador no disponible", "No se encontró gpu-screen-recorder.")
            root.refresh()
            return
        }

        if (!root.validScreen(root.recordingScreen)) {
            root.notify("No se pudo grabar", "El monitor seleccionado ya no está disponible.")
            return
        }

        if (config.captureMode === "region" && !regionMode) {
            root.notify("Región no disponible", "Selecciona una región válida en los ajustes de grabación.")
            return
        }

        const folder = root.expandHome(config.outputDirectory)
        if (!folder) {
            root.notify("No se pudo grabar", "La carpeta de destino está vacía.")
            return
        }

        root.outputPath = folder + "/recording-"
            + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss-zzz") + ".mp4"
        root.errorText = ""
        root.paused = false
        root.stopping = false
        root.finishing = false
        root.cancelStart = false
        root.elapsedSeconds = 0
        root.captureTarget = regionMode ? "region" : root.recordingScreen
        root.starting = true
        root.directoryProcess.command = ["mkdir", "-p", folder]
        root.directoryProcess.running = true
    }

    function launchRecorder() {
        if (root.cancelStart) {
            root.starting = false
            root.cancelStart = false
            return
        }

        const command = root.buildCommand(
            RecorderSettings.snapshot(),
            root.recordingScreen,
            root.outputPath
        )
        root.starting = false
        recorderProcess.command = command
        recorderProcess.running = true
    }

    function togglePause() {
        if (!root.active || root.stopping)
            return

        if (root.paused) {
            recorderProcess.signal(18)
            root.paused = false
            return
        }

        recorderProcess.signal(19)
        root.paused = true
    }

    function stop() {
        if (root.starting) {
            root.cancelStart = true
            return
        }
        if (!root.active || root.stopping)
            return

        root.stopping = true
        if (root.paused) {
            recorderProcess.signal(18)
            root.paused = false
            root.stopAfterResume.restart()
        } else {
            // SIGINT lets the encoder finish the MP4; never kill other recorders.
            recorderProcess.signal(2)
        }
    }

    function requestRegionSelection(screenName) {
        const target = String(screenName || RecorderSettings.monitorName || root.firstScreen())
        if (!root.validScreen(target)) {
            root.notify("No se pudo seleccionar la región", "No hay un monitor disponible.")
            return
        }
        root.regionPickerScreen = target
        root.regionPickerOpen = true
    }

    function cancelRegionSelection() {
        root.regionPickerOpen = false
        root.regionSelectionCancelled()
    }

    function completeRegionSelection(screenName, x, y, width, height) {
        if (!root.validScreen(screenName)
                || Number(width) <= 0
                || Number(height) <= 0) {
            root.cancelRegionSelection()
            return
        }
        root.regionPickerOpen = false
        root.regionSelected(
            String(screenName),
            Math.round(Number(x)),
            Math.round(Number(y)),
            Math.round(Number(width)),
            Math.round(Number(height))
        )
    }

    function finishCapture(code) {
        root.elapsedSeconds = 0
        root.paused = false
        root.stopping = false
        if (code !== 0) {
            root.notify("No se pudo completar la grabación",
                root.errorText.trim().slice(-500)
                    || "El grabador terminó con código " + code + ".")
            return
        }
        root.finishing = true
        savedFileProcess.command = ["test", "-s", root.outputPath]
        savedFileProcess.running = true
    }

    function finishSave(code) {
        root.finishing = false
        root.notify(code === 0 ? "Grabación guardada" : "No se generó un vídeo",
            code === 0 ? root.outputPath
                : "El grabador terminó sin crear un archivo con contenido.")
    }

    Component.onCompleted: root.refresh()
}
