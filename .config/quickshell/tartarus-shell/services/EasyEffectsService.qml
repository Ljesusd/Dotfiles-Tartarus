pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool running: false
    property bool available: false

    function refresh() {
        if (!probe.running) probe.running = true
        if (!availability.running) availability.running = true
    }

    function open() {
        if (!root.running && !launcher.running)
            launcher.running = true
    }

    property Process availability: Process {
        command: ["sh", "-c", "command -v easyeffects || (command -v flatpak && flatpak info com.github.wwmm.easyeffects >/dev/null 2>&1 && printf flatpak)"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.available = String(text || "").trim() !== ""
        }
    }

    property Process probe: Process {
        command: ["sh", "-c", "pgrep -x easyeffects >/dev/null && printf yes || printf no"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.running = String(text).trim() === "yes"
        }
    }

    property Process launcher: Process {
        command: ["sh", "-c", "if command -v easyeffects >/dev/null; then exec easyeffects; else exec flatpak run com.github.wwmm.easyeffects; fi"]
        onRunningChanged: if (!running) root.refresh()
    }

    property Timer poller: Timer {
        interval: 2500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
