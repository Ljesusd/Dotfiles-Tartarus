pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string helperPath: Quickshell.shellPath("scripts/monitor-control.py")
    property bool active: false
    property bool loading: false
    property bool previewActive: false
    property int previewSeconds: 0
    property string selectedName: ""
    property string errorMessage: ""
    property bool managerConflict: false
    property var monitors: []
    property var draftMonitors: []
    property var snapshotMonitors: []
    property string operation: ""

    function clone(value) {
        return JSON.parse(JSON.stringify(value || []))
    }

    function refresh() {
        if (!root.snapshotProcess.running)
            root.snapshotProcess.running = true
        if (!root.managerProcess.running)
            root.managerProcess.running = true
    }

    function normalizeMode(monitor) {
        const modes = monitor.availableModes || []
        const currentPrefix = String(monitor.width) + "x" + String(monitor.height) + "@"
        const currentRate = Number(monitor.refreshRate || 0)
        const matching = modes.find(mode => {
            const value = String(mode)
            if (!value.startsWith(currentPrefix))
                return false
            const rateMatch = /@([0-9.]+)(?:Hz)?$/.exec(value)
            return rateMatch && Math.abs(Number(rateMatch[1]) - currentRate) < 0.2
        }) || modes.find(mode => String(mode).startsWith(currentPrefix))
        return String(matching || (currentPrefix + Number(monitor.refreshRate || 60).toFixed(2) + "Hz"))
            .replace(/Hz$/, "")
    }

    function normalize(raw) {
        return (raw || []).filter(monitor => monitor && monitor.name && monitor.name !== "FALLBACK").map(monitor => ({
            name: String(monitor.name),
            description: String(monitor.description || ""),
            make: String(monitor.make || ""),
            model: String(monitor.model || monitor.description || monitor.name),
            serial: String(monitor.serial || ""),
            width: Number(monitor.width || 0),
            height: Number(monitor.height || 0),
            refreshRate: Number(monitor.refreshRate || 0),
            x: Number(monitor.x || 0),
            y: Number(monitor.y || 0),
            scale: Number(monitor.scale || 1),
            transform: Number(monitor.transform || 0),
            disabled: Boolean(monitor.disabled),
            focused: Boolean(monitor.focused),
            dpmsStatus: Boolean(monitor.dpmsStatus),
            mirrorOf: String(monitor.mirrorOf || "none"),
            availableModes: (monitor.availableModes || []).map(mode => String(mode)),
            mode: root.normalizeMode(monitor)
        }))
    }

    function updateSnapshot(text) {
        try {
            const parsed = JSON.parse(String(text || "[]").trim() || "[]")
            const next = root.normalize(parsed)
            root.monitors = next
            // While applying or previewing, the live compositor snapshot must
            // never replace the user's draft. Applying a monitor can take more
            // than one refresh interval, especially when scale changes.
            if (!root.previewActive && root.operation === "") {
                root.draftMonitors = root.clone(next)
                root.snapshotMonitors = root.clone(next)
            }
            const names = next.map(monitor => monitor.name)
            if (!names.includes(root.selectedName))
                root.selectedName = names[0] || ""
            root.loading = false
            root.errorMessage = ""
        } catch (error) {
            root.loading = false
            root.errorMessage = "No se pudo leer el estado de los monitores"
            console.warn("MonitorService:", error)
        }
    }

    function selectedMonitor() {
        return root.draftMonitors.find(monitor => monitor.name === root.selectedName) || null
    }

    function select(name) {
        if (root.draftMonitors.some(monitor => monitor.name === name))
            root.selectedName = name
    }

    function setDraftField(name, field, value) {
        if (root.previewActive)
            return
        const next = root.clone(root.draftMonitors)
        const item = next.find(monitor => monitor.name === name)
        if (!item)
            return
        item[field] = value
        root.draftMonitors = next
    }

    function moveDraft(name, x, y) {
        if (root.previewActive)
            return
        const next = root.clone(root.draftMonitors)
        const item = next.find(monitor => monitor.name === name)
        if (!item)
            return
        item.x = Math.round(Number(x || 0) / 10) * 10
        item.y = Math.round(Number(y || 0) / 10) * 10
        root.draftMonitors = next
    }

    function hasDraftChanges() {
        return JSON.stringify(root.draftMonitors) !== JSON.stringify(root.snapshotMonitors)
    }

    function startOperation(action, layout) {
        if (root.operationProcess.running)
            return
        root.operation = action
        root.operationProcess.command = ["python3", root.helperPath, action === "persist" ? "persist" : "apply", JSON.stringify(layout)]
        root.operationProcess.running = true
    }

    function applyPreview() {
        if (!root.active || root.previewActive || root.managerConflict || !root.hasDraftChanges())
            return
        root.errorMessage = ""
        root.snapshotMonitors = root.clone(root.monitors)
        root.startOperation("preview", root.draftMonitors)
    }

    function keepChanges() {
        if (!root.previewActive)
            return
        root.previewTimer.stop()
        if (root.managerConflict) {
            root.previewActive = false
            root.errorMessage = "El layout quedó aplicado solo hasta el próximo reload porque hyprmoncfg está activo"
            return
        }
        root.startOperation("persist", root.draftMonitors)
    }

    function revertChanges() {
        if (!root.previewActive)
            return
        root.previewTimer.stop()
        root.startOperation("revert", root.snapshotMonitors)
    }

    function resetDraft() {
        if (root.previewActive)
            return
        root.draftMonitors = root.clone(root.monitors)
    }

    function focusMonitor(name) {
        // Hyprland 0.55+ parses `dispatch` as a Lua dispatcher. Passing the
        // old `focusmonitor NAME` form is interpreted as invalid Lua.
        const selector = "hl.dsp.focus({ monitor = " + JSON.stringify(String(name)) + " })"
        root.focusProcess.command = ["hyprctl", "dispatch", selector]
        root.errorMessage = ""
        root.focusProcess.running = true
    }

    property Process snapshotProcess: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateSnapshot(this.text)
        }
        onStarted: root.loading = true
    }

    property Process managerProcess: Process {
        command: ["systemctl", "--user", "is-active", "hyprmoncfgd.service"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.managerConflict = String(this.text).trim() === "active"
        }
    }

    property Process operationProcess: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            const action = root.operation
            root.operation = ""
            if (exitCode !== 0) {
                root.errorMessage = "Hyprland rechazó el cambio de monitores"
                if (action === "preview" && root.snapshotMonitors.length > 0)
                    root.startOperation("revert", root.snapshotMonitors)
                return
            }
            if (action === "preview") {
                root.previewActive = true
                root.previewSeconds = 30
                root.previewTimer.restart()
                root.refresh()
            } else if (action === "revert") {
                root.previewActive = false
                root.draftMonitors = root.clone(root.snapshotMonitors)
                root.refresh()
            } else if (action === "persist") {
                root.previewActive = false
                root.snapshotMonitors = root.clone(root.draftMonitors)
                root.refresh()
            }
        }
    }

    property Process focusProcess: Process {
        stdout: StdioCollector { id: focusOutput; waitForEnd: true }
        stderr: StdioCollector { id: focusError; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const detail = String(focusError.text || focusOutput.text || "").trim()
                root.errorMessage = detail || "No se pudo enfocar el monitor"
            } else {
                root.refresh()
            }
        }
    }

    property Timer previewTimer: Timer {
        interval: 1000
        repeat: true
        onTriggered: {
            root.previewSeconds--
            if (root.previewSeconds <= 0)
                root.revertChanges()
        }
    }

    property Timer refreshTimer: Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    onActiveChanged: if (root.active) root.refresh()
    Component.onCompleted: root.refresh()
}
