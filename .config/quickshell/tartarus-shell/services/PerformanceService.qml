pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Estado compartido del modo Gaming. El script de Hyprland lo actualiza por
// IPC, de modo que también funciona al activar SUPER+G fuera del panel.
QtObject {
    id: root

    property bool gaming: false
    readonly property string statePath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/tartarus-steam-gaming.state"

    property Process stateProbe: Process {
        id: stateProbe
        command: ["sh", "-c", "state=\"" + root.statePath + "\"; pid=$(awk -F= '$1 == \"gamescope_pid\" { print $2; exit }' \"$state\" 2>/dev/null); if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then printf 1; else printf 0; fi"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.gaming = String(text).trim() === "1"
        }
    }

    property Timer stateTimer: Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!stateProbe.running)
                stateProbe.running = true
        }
    }

    function setGaming(enabled) {
        root.gaming = !!enabled
    }

    function toggleGaming() {
        root.setGaming(!root.gaming)
    }
}
