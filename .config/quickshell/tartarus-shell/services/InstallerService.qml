pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    readonly property string helperPath:
        Quickshell.shellPath("scripts/app-installer.py")
    property string path: ""
    property string name: ""
    property string kind: ""
    property string kindLabel: ""
    property string detail: ""
    property string error: ""
    property string phase: "idle"
    property bool supported: false
    readonly property bool busy: inspectProcess.running || installProcess.running
    readonly property bool ready: root.phase === "ready"

    function clear() {
        root.path = ""
        root.name = ""
        root.kind = ""
        root.kindLabel = ""
        root.detail = ""
        root.error = ""
        root.phase = "idle"
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
        root.phase = "installing"
        root.installProcess.command = ["python3", root.helperPath, "install", root.path]
        root.installProcess.running = true
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
                    root.supported = result.supported === true
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
            if (exitCode === 0)
                root.phase = "installed"
            else {
                root.phase = "error"
                const detail = String(installStderr.text || "").trim()
                root.error = detail !== ""
                    ? detail.slice(-500)
                    : "La instalación terminó con código " + exitCode + "."
            }
        }
    }
}
