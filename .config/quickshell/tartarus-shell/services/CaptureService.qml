pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string screenshotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string editorLauncher: Quickshell.shellPath("scripts/capture.sh")
    property bool busy: screenshotProcess.running || editorProcess.running
    property bool editorAvailable: false
    property string lastMode: ""
    property string errorText: ""

    property Process availabilityProcess: Process {
        id: availabilityProcess
        command: ["bash", root.editorLauncher, "--check"]
        onExited: (code, status) => root.editorAvailable = code === 0
    }

    function refresh() {
        if (!availabilityProcess.running)
            availabilityProcess.running = true
    }

    property Process screenshotProcess: Process {
        id: screenshotProcess
        onExited: (code, status) => {
            root.errorText = code === 0 ? "" : "La captura no se pudo completar"
        }
    }

    function take(mode) {
        if (root.busy)
            return false

        const script = Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh"
        root.lastMode = mode
        root.errorText = ""
        screenshotProcess.command = ["bash", script, mode]
        screenshotProcess.running = true
        return true
    }

    function launch(mode) {
        if (root.busy)
            return false


        root.lastMode = mode
        root.errorText = ""
        editorProcess.command = ["bash", root.editorLauncher, mode]
        editorProcess.running = true
        return true
    }

    property Process editorProcess: Process {
        id: editorProcess
    }

    Component.onCompleted: root.refresh()
}
