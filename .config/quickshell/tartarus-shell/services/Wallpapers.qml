pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var wallpapers: []
    property string currentPath: ""
    property var pathsByMonitor: ({})
    readonly property int currentCount: root.wallpapers.length

    function filtered(query) {
        const normalized =
            query.trim().toLowerCase()

        if (normalized === "")
            return root.wallpapers

        return root.wallpapers.filter(wallpaper => {
            return root.matchesPrefix(
                wallpaper.name,
                normalized
            )
        })
    }

    function currentPathForMonitor(monitorName) {
        if (!monitorName)
            return root.currentPath || ""
        return (root.pathsByMonitor || {})[monitorName]
            || root.currentPath
            || ""
    }

    function refresh() {
        root.listProcess.running = false
        root.listProcess.running = true
    }

    function matchesPrefix(text, query) {
        const normalized =
            query.trim().toLowerCase()

        if (normalized === "")
            return true

        return text
            .toLowerCase()
            .split(/\s+/)
            .some(word => {
                return word.startsWith(normalized)
            })
    }

    function setWallpaper(path, monitor) {
        setProcess.command = [
            "python",
            Quickshell.shellPath("scripts/wallpaper.py"),
            "set",
            path,
            "--monitor",
            monitor || "",
        ]

        setProcess.running = true
    }

    function applySaved() {
        applySavedProcess.running = false
        applySavedProcess.running = true
    }

    readonly property Process listProcess: Process {
        command: [
            "python",
            Quickshell.shellPath("scripts/wallpaper.py"),
            "list",
            "--json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text === "")
                    return

                try {
                    root.wallpapers = JSON.parse(text)
                } catch (error) {
                    console.warn(
                        "Wallpapers: no se pudo interpretar la lista:",
                        error
                    )
                }
            }
        }
    }

    readonly property Process currentProcess: Process {
        command: [
            "python",
            Quickshell.shellPath("scripts/wallpaper.py"),
            "current",
            "--json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text === "")
                    return

                try {
                    const state = JSON.parse(text)
                    root.currentPath = state.path ?? ""
                    root.pathsByMonitor = state.monitors ?? {}
                } catch (error) {
                    console.warn(
                        "Wallpapers: no se pudo leer la imagen actual:",
                        error
                    )
                }
            }
        }
    }

    readonly property Process setProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text.length > 0)
                    console.warn("Wallpapers: error al aplicar wallpaper:", text)
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text.length === 0)
                    return

                if (text.startsWith("Wallpaper activo:")) {
                    root.currentProcess.running = true
                    root.refresh()
                    return
                }

                if (text.startsWith("Error:"))
                    console.warn("Wallpapers: no se pudo aplicar wallpaper:", text)
            }
        }
    }

    readonly property Process applySavedProcess: Process {
        command: [
            "python",
            Quickshell.shellPath("scripts/wallpaper.py"),
            "apply-saved"
        ]

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                if (text.length > 0)
                    console.warn("Wallpapers: no se pudo reaplicar:", text)
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.currentProcess.running = true
            root.refresh()
        }
    }

    Component.onCompleted: {
        listProcess.running = true
        currentProcess.running = true
    }
}
