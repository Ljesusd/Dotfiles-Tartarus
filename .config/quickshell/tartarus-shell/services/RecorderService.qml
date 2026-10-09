pragma Singleton

import Quickshell.Io
import Quickshell
import QtQuick
import QtQml

QtObject {
    id: root

    property bool available: false
    readonly property bool active: recorderProcess.running
    property bool stopping: false
    property bool finishing: false
    property string recordingScreen: ""
    property string outputPath: ""
    property string errorText: ""
    property int elapsedSeconds: 0
    readonly property string displayTime: {
        const minutes = Math.floor(root.elapsedSeconds / 60)
        const seconds = root.elapsedSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    property Process availabilityProcess: Process {
        id: availabilityProcess
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        stdout: StdioCollector { waitForEnd: true }
        onExited: (code, status) => root.available = code === 0
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
        running: root.active
        onTriggered: root.elapsedSeconds++
    }

    function refresh() {
        if (!availabilityProcess.running)
            availabilityProcess.running = true
    }

    function notify(title, body) {
        ToastService.push(root.recordingScreen, "videocam", title, body, 6000)
    }

    function start(monitorName) {
        if (root.active || root.finishing)
            return
        root.recordingScreen = String(monitorName || "")
        if (!root.available) {
            root.notify("Grabador no disponible", "No se encontró gpu-screen-recorder.")
            root.refresh()
            return
        }
        if (!root.recordingScreen || !Quickshell.screens.some(screen => screen.name === root.recordingScreen
                && screen.name !== "FALLBACK")) {
            root.notify("No se pudo grabar", "El monitor seleccionado ya no está disponible.")
            return
        }
        const folder = Quickshell.env("HOME") + "/Videos/Recordings"
        root.outputPath = folder + "/recording-"
            + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss-zzz") + ".mp4"
        root.errorText = ""
        root.stopping = false
        root.elapsedSeconds = 0
        // exec gives Process ownership of the recorder PID. Arguments are
        // separate from shell source, including paths with spaces or quotes.
        recorderProcess.command = ["sh", "-c",
            "mkdir -p -- \"$1\" && exec gpu-screen-recorder -w \"$2\" -f 60 -o \"$3\"",
            "tartarus-record", folder, root.recordingScreen, root.outputPath]
        recorderProcess.running = true
    }

    function stop() {
        if (!root.active || root.stopping)
            return
        root.stopping = true
        // SIGINT lets the encoder finish the MP4; never kill other recorders.
        recorderProcess.signal(2)
    }

    function finishCapture(code) {
        root.elapsedSeconds = 0
        root.stopping = false
        if (code !== 0) {
            root.notify("No se pudo completar la grabación",
                root.errorText.trim().slice(-500) || "El grabador terminó con código " + code + ".")
            return
        }
        root.finishing = true
        savedFileProcess.command = ["test", "-s", root.outputPath]
        savedFileProcess.running = true
    }

    function finishSave(code) {
        root.finishing = false
        root.notify(code === 0 ? "Grabación guardada" : "No se generó un vídeo",
            code === 0 ? root.outputPath : "El grabador terminó sin crear un archivo con contenido.")
    }

    Component.onCompleted: root.refresh()
}
