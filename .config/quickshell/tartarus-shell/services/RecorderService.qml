pragma Singleton

import Quickshell.Io
import QtQuick
import QtQml

QtObject {
    id: root

    property bool available: false
    property bool active: false
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

    property Process stateProcess: Process {
        id: stateProcess
        command: ["sh", "-c", "pgrep -x gpu-screen-recorder >/dev/null"]
        onExited: (code, status) => {
            root.active = code === 0
            if (!root.active)
                root.elapsedSeconds = 0
        }
    }

    property Process recorderProcess: Process {
        id: recorderProcess
        command: [
            "sh", "-c",
            "mkdir -p \"$HOME/Videos/Recordings\" && gpu-screen-recorder -w monitor -f 60 -o \"$HOME/Videos/Recordings/recording-$(date +%Y%m%d-%H%M%S).mp4\""
        ]
        onRunningChanged: {
            if (!running)
                root.refresh()
        }
    }

    property Process stopProcess: Process {
        id: stopProcess
        command: ["pkill", "-INT", "-x", "gpu-screen-recorder"]
    }

    property Timer poller: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.refresh()
            if (root.active)
                root.elapsedSeconds++
        }
    }

    function refresh() {
        if (!availabilityProcess.running)
            availabilityProcess.running = true
        if (!stateProcess.running)
            stateProcess.running = true
    }

    function start() {
        if (!root.available || root.active || recorderProcess.running)
            return
        root.elapsedSeconds = 0
        recorderProcess.running = true
    }

    function stop() {
        if (root.active)
            stopProcess.running = true
    }

    Component.onCompleted: root.refresh()
}
