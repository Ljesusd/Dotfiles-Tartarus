import Quickshell
import Quickshell.Io
import QtQuick
import QtQml

QtObject {
    id: root

    property string layout: "us"
    property string keymap: ""
    property bool available: false
    property bool switching: false

    readonly property string displayText:
        root.layout === "br" ? "PT-BR" : "EN"

    readonly property Process queryProcess: Process {
        command: [
            "hyprctl",
            "devices",
            "-j"
        ]

        stdout: StdioCollector {
            id: queryOutput

            onStreamFinished: {
                root.parseDevices(queryOutput.text)
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.switching = false
            pollTimer.restart()
        }
    }

    readonly property Process switchProcess: Process {
        command: [
            "hyprctl",
            "switchxkblayout",
            "all",
            "next"
        ]

        onStarted: root.switching = true

        onExited: (exitCode, exitStatus) => {
            root.switching = false
            root.query()
        }
    }

    property int requestedLayoutIndex: -1

    readonly property Process persistProcess: Process {}

    readonly property Timer pollTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.query()
    }

    function query() {
        if (root.queryProcess.running)
            return

        root.queryProcess.running = true
    }

    function toggle() {
        if (!root.available || root.switchProcess.running)
            return

        root.switchProcess.running = true
    }

    function selectLayout(index) {
        if (!root.available || root.switchProcess.running)
            return

        const layouts = root.currentLayouts()

        if (index < 0 || index >= layouts.length)
            return

        if (index === root.currentLayoutIndex())
            return

        root.requestedLayoutIndex = index
        root.persistProcess.command = [
            "/bin/sh", "-c",
            "mkdir -p \"$HOME/.local/state/tartarus-shell\"; printf '%s\\n' \"$1\" > \"$HOME/.local/state/tartarus-shell/keyboard-layout\"",
            "tartarus-keyboard-state", `${index}`
        ]
        root.persistProcess.running = true
        root.switchProcess.command = [
            "hyprctl",
            "switchxkblayout",
            "all",
            `${index}`
        ]
        root.switchProcess.running = true
    }

    function currentLayouts() {
        return root._layouts ?? ["us", "br"]
    }

    function currentLayoutIndex() {
        return root._activeLayoutIndex
    }

    property var _layouts: ["us", "br"]
    property int _activeLayoutIndex: 0

    function parseDevices(text) {
        const raw = text.trim()

        if (raw === "")
            return

        try {
            const data = JSON.parse(raw)
            const keyboards = data.keyboards || []
            let keyboard = keyboards.find(item => item.main)

            if (!keyboard && keyboards.length > 0)
                keyboard = keyboards[0]

            if (!keyboard) {
                root.available = false
                return
            }

            const layouts = `${keyboard.layout || "us"}`.split(",")
            const index = Number(keyboard.active_layout_index) || 0

            root._layouts = layouts
            root._activeLayoutIndex = index
            root.layout = layouts[index] || layouts[0] || "us"
            root.keymap = `${keyboard.active_keymap || ""}`
            root.available = true
        } catch (error) {
            root.available = false
        }
    }

    Component.onCompleted: root.query()
}
