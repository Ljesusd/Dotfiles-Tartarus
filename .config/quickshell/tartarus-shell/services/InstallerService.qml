pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtQml

QtObject {
    id: root

    signal applicationInstalled()

    readonly property string helperPath:
        Quickshell.shellPath("scripts/app-installer.py")
    property string path: ""
    property string name: ""
    property string kind: ""
    property string kindLabel: ""
    property string detail: ""
    property string nativePackage: ""
    property string error: ""
    property string phase: "idle"
    property int progress: 0
    property string progressLabel: ""
    property bool cancelRequested: false
    property bool supported: false
    readonly property bool busy: inspectProcess.running || installProcess.running
    readonly property bool ready: root.phase === "ready"

    function clear() {
        if (root.busy)
            return
        root.path = ""
        root.name = ""
        root.kind = ""
        root.kindLabel = ""
        root.detail = ""
        root.nativePackage = ""
        root.error = ""
        root.phase = "idle"
        root.progress = 0
        root.progressLabel = ""
        root.cancelRequested = false
        root.supported = false
    }

    function localPath(url) {
        let value = String(url || "")
        if (value.startsWith("file://"))
            value = value.slice("file://".length)
        try {
            return decodeURIComponent(value)
        } catch (error) {
            return value
        }
    }

    function inspect(urlOrPath) {
        const value = root.localPath(urlOrPath)
        if (!value)
            return
        root.clear()
        root.path = value
        root.phase = "inspecting"
        root.inspectProcess.command = ["python3", root.helperPath, "inspect", value]
        root.inspectProcess.running = true
    }

    function install() {
        if (!root.ready || root.busy || !root.supported)
            return
        root.error = ""
        root.cancelRequested = false
        root.progress = root.nativePackage ? 12 : 8
        root.progressLabel = root.nativePackage
            ? "Esperando la autenticación…"
            : "Preparando la instalación…"
        root.phase = "installing"
        installProgressTimer.start()
        root.installProcess.command = ["python3", root.helperPath, "install", root.path]
        root.installProcess.running = true
    }

    function cancel() {
        if (!root.busy)
            return
        root.cancelRequested = true
        installProgressTimer.stop()
        root.installProcess.running = false
        root.phase = "cancelled"
        root.progress = 0
        root.progressLabel = ""
        root.error = "Instalación cancelada."
    }

    readonly property Timer installProgressTimer: Timer {
        interval: 700
        repeat: true
        onTriggered: {
            if (root.phase !== "installing")
                return

            // The package manager runs through Polkit when its graphical
            // agent is available. This staged value keeps the shell
            // responsive while the helper reports the final result.
            if (root.progress < 35) {
                root.progress = Math.min(35, root.progress + 4)
                root.progressLabel = root.nativePackage
                    ? "Autenticando y descargando dependencias…"
                    : "Copiando los archivos…"
            } else if (root.progress < 70) {
                root.progress = Math.min(70, root.progress + 2)
                root.progressLabel = root.nativePackage
                    ? "Instalando el paquete de Steam…"
                    : "Registrando la aplicación…"
            } else {
                root.progress = Math.min(88, root.progress + 1)
                root.progressLabel = root.nativePackage
                    ? "Configurando Steam…"
                    : "Esperando la finalización…"
            }
        }
    }

    readonly property Process inspectProcess: Process {
        id: inspectProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const result = JSON.parse(String(text).trim())
                    if (!result.ok) {
                        root.phase = "error"
                        root.error = result.error || "No se pudo leer el archivo."
                        return
                    }
                    root.path = result.path || root.path
                    root.name = result.title || result.name || "Aplicación"
                    root.kind = result.kind || "unknown"
                    root.kindLabel = result.kindLabel || "Archivo"
                    root.detail = result.detail || ""
                    root.nativePackage = result.nativePackage || ""
                    root.supported = result.supported === true
                    root.progress = 0
                    root.progressLabel = ""
                    root.phase = root.supported ? "ready" : "error"
                    root.error = root.supported ? "" : root.detail
                } catch (error) {
                    root.phase = "error"
                    root.error = "No se pudo analizar el archivo."
                }
            }
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    readonly property Process installProcess: Process {
        id: installProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector {
            id: installStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            installProgressTimer.stop()
            if (root.cancelRequested) {
                root.cancelRequested = false
                return
            }
            if (exitCode === 0) {
                root.progress = 100
                root.progressLabel = "Instalación terminada"
                root.phase = "installed"
                root.applicationInstalled()
            } else {
                root.progress = 0
                root.progressLabel = ""
                root.phase = "error"
                const detail = String(installStderr.text || "").trim()
                root.error = detail !== ""
                    ? detail.slice(-500)
                    : "La instalación terminó con código " + exitCode + "."
            }
        }
    }
}
