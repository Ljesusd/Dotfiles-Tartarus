pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string appId: "io.github.tanaybhomia.Whisp"
    readonly property string exportScript:
        Quickshell.shellPath("scripts/export-whisp-to-obsidian.py")

    readonly property Process openProcess: Process {
        command: ["flatpak", "run", "--user", root.appId]
    }

    readonly property Process exportProcess: Process {
        command: ["python3", root.exportScript]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim()
                if (output !== "")
                    console.log("Whisp export:", output)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const output = this.text.trim()
                if (output !== "")
                    console.warn("Whisp export:", output)
            }
        }
    }

    function open() {
        if (!root.openProcess.running)
            root.openProcess.running = true
    }

    function exportToObsidian() {
        if (!root.exportProcess.running)
            root.exportProcess.running = true
    }
}
