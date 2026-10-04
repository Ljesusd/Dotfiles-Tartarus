pragma Singleton

import QtQuick
import QtQml

QtObject {
    id: root

    property bool active: false
    property bool paused: false
    property string mode: "timer"
    property string phase: ""
    property int remainingSeconds: 0
    property int totalSeconds: 0
    property int workMinutes: 25
    property int breakMinutes: 5
    property int completedWorkSessions: 0
    property int targetCycles: 4

    readonly property string label: root.mode === "pomodoro"
        ? (root.phase === "break" ? "Descanso" : "Enfoque")
        : "Temporizador"
    readonly property string cycleText: root.mode === "pomodoro"
        ? (root.completedWorkSessions + 1) + "/" + root.targetCycles
        : ""
    readonly property string displayTime: {
        const minutes = Math.floor(root.remainingSeconds / 60)
        const seconds = root.remainingSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: {
            if (root.remainingSeconds > 0)
                root.remainingSeconds--
            if (root.remainingSeconds <= 0)
                root.advance()
        }
    }

    function parseDuration(value, fallbackSeconds) {
        const source = String(value || "").trim().toLowerCase()
        if (source === "")
            return fallbackSeconds

        let total = 0
        const matches = source.match(/(\d+(?:\.\d+)?)\s*(h|m|s)?/g) || []
        matches.forEach(part => {
            const match = part.match(/(\d+(?:\.\d+)?)\s*(h|m|s)?/)
            if (!match)
                return
            const amount = Number(match[1])
            const unit = match[2] || "m"
            total += amount * (unit === "h" ? 3600 : unit === "s" ? 1 : 60)
        })

        return total > 0 ? Math.max(1, Math.round(total)) : fallbackSeconds
    }

    function startTimer(value) {
        const seconds = root.parseDuration(value, 5 * 60)
        root.mode = "timer"
        root.phase = ""
        root.remainingSeconds = seconds
        root.totalSeconds = seconds
        root.completedWorkSessions = 0
        root.paused = false
        root.active = true
    }

    function startPomodoro(value) {
        const parts = String(value || "").trim().split(/\s+/)
        const work = root.parseDuration(parts[1], root.workMinutes * 60)
        const rest = root.parseDuration(parts[2], root.breakMinutes * 60)
        const cycles = Number(parts[3])
        root.mode = "pomodoro"
        root.phase = "work"
        root.workMinutes = Math.max(1, Math.round(work / 60))
        root.breakMinutes = Math.max(1, Math.round(rest / 60))
        root.targetCycles = Number.isFinite(cycles) && cycles > 0
            ? Math.max(1, Math.floor(cycles))
            : 4
        root.remainingSeconds = work
        root.totalSeconds = work
        root.completedWorkSessions = 0
        root.paused = false
        root.active = true
    }

    function togglePause() {
        if (root.active)
            root.paused = !root.paused
    }

    function advance() {
        if (root.mode !== "pomodoro") {
            root.stop()
            return
        }

        if (root.phase === "work") {
            root.completedWorkSessions++
            if (root.completedWorkSessions >= root.targetCycles) {
                root.stop()
                return
            }
            root.phase = "break"
            root.remainingSeconds = root.breakMinutes * 60
        } else {
            root.phase = "work"
            root.remainingSeconds = root.workMinutes * 60
        }
        root.totalSeconds = root.remainingSeconds
    }

    function stop() {
        root.active = false
        root.paused = false
        root.remainingSeconds = 0
        root.totalSeconds = 0
        root.phase = ""
    }
}
