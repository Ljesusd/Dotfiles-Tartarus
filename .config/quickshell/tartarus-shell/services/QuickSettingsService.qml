pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "." as Services

QtObject {
    id: root

    readonly property bool keepAwake: inhibitor.running
    readonly property bool gaming: Services.PerformanceService.gaming
    property bool nightAvailable: false
    property string nightBackend: ""

    property Process nightProbe: Process {
        id: nightProbe
        command: ["sh", "-c", "command -v hyprsunset || command -v wlsunset || command -v gammastep"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.nightBackend = String(text).trim()
                root.nightAvailable = root.nightBackend !== ""
            }
        }
    }

    // Detecta instalaciones hechas después de iniciar Quickshell sin obligar
    // a reiniciar todo el shell.
    property Timer nightProbeTimer: Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (!root.nightAvailable && !nightProbe.running)
                nightProbe.running = true
        }
    }

    property Process nightAction: Process { id: nightAction }
    readonly property bool night: Services.QuickSettingsState.nightPreferred

    property Process inhibitor: Process {
        id: inhibitor
        command: [
            "systemd-inhibit",
            "--what=idle:sleep",
            "--who=Tartarus",
            "--why=El usuario solicitó mantener despierto el equipo",
            "--mode=block",
            "sleep",
            "infinity"
        ]
    }

    property Process gamingProcess: Process {
        id: gamingProcess
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/steam-gaming-mode.sh"]
    }

    function toggleKeepAwake() {
        inhibitor.running = !root.keepAwake
    }

    function toggleGaming() {
        if (!gamingProcess.running)
            gamingProcess.running = true
    }

    function toggleNight() {
        if (!root.nightAvailable)
            return

        const enabled = !root.night
        Services.QuickSettingsState.nightPreferred = enabled
        Services.QuickSettingsState.save()
        if (root.nightBackend.endsWith("hyprsunset")) {
            nightAction.command = enabled
                ? ["hyprctl", "hyprsunset", "temperature", String(Services.QuickSettingsState.nightTemperature)]
                : ["hyprctl", "hyprsunset", "identity"]
        } else if (root.nightBackend.endsWith("gammastep")) {
            nightAction.command = enabled
                ? [root.nightBackend, "-O", String(Services.QuickSettingsState.nightTemperature)]
                : [root.nightBackend, "-x"]
        } else {
            nightAction.command = enabled
                ? [root.nightBackend, "-t", String(Services.QuickSettingsState.nightTemperature)]
                : ["pkill", "-x", "wlsunset"]
        }
        nightAction.running = true
    }

    Component.onCompleted: nightProbe.running = true
}
