pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "." as Services

QtObject {
    id: root
    property string currentTime: "--:--"

    function refresh() {
        if (!clockProcess.running)
            clockProcess.running = true
    }

    property Process clockProcess: Process {
        id: clockProcess
        command: ["sh", "-c", "TZ='" + Services.QuickSettingsState.timeZone.replace(/'/g, "") + "' date '+%H:%M'"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const value = String(text).trim()
                if (/^\d{2}:\d{2}$/.test(value)) root.currentTime = value
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 30 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    property Connections settingsConnection: Connections {
        target: Services.QuickSettingsState
        function onTimeZoneChanged() { root.refresh() }
    }

    Component.onCompleted: root.refresh()
}
