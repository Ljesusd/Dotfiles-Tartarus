pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var state: ({})

    readonly property FileView stateFile: FileView {
        path: Quickshell.stateDir + "/desktop-widgets.json"
        blockLoading: true
        printErrors: false
    }

    function load() {
        const raw = stateFile.text()
        if (!raw || !raw.trim())
            return

        try {
            const saved = JSON.parse(raw)
            if (saved && typeof saved === "object" && !Array.isArray(saved))
                root.state = saved
        } catch (error) {
            console.warn("No se pudo leer desktop-widgets.json:", error)
        }
    }

    function cloneState() {
        return JSON.parse(JSON.stringify(root.state || {}))
    }

    function monitor(name) {
        const key = String(name || "default")
        if (!root.state[key] || typeof root.state[key] !== "object")
            root.state[key] = {}
        return root.state[key]
    }

    function music(name) {
        return root.widget(name, "music")
    }

    function widget(name, widgetId) {
        const value = monitor(name)[widgetId]
        return {
            enabled: value?.enabled !== false,
            locked: value?.locked === true,
            x: Number.isFinite(value?.x) ? value.x : -1,
            y: Number.isFinite(value?.y) ? value.y : -1,
            scale: Number.isFinite(value?.scale) ? Math.max(0.7, Math.min(1.4, value.scale)) : 1
        }
    }

    function updateMusic(name, changes) {
        root.updateWidget(name, "music", changes)
    }

    function updateWidget(name, widgetId, changes) {
        const next = root.cloneState()
        const key = String(name || "default")
        if (!next[key] || typeof next[key] !== "object")
            next[key] = {}
        next[key][widgetId] = Object.assign({}, next[key][widgetId] || {}, changes)
        root.state = next
        stateFile.setText(JSON.stringify(next, null, 2))
    }

    function setMusicPosition(name, x, y) {
        root.updateMusic(name, { x: Math.round(x), y: Math.round(y) })
    }

    function setMusicScale(name, scale) {
        root.updateMusic(name, { scale: Math.max(0.7, Math.min(1.4, scale)) })
    }

    function setMusicLocked(name, locked) {
        root.updateWidget(name, "music", { locked: !!locked })
    }

    function setWidgetPosition(name, widgetId, x, y) {
        root.updateWidget(name, widgetId, { x: Math.round(x), y: Math.round(y) })
    }

    function setWidgetScale(name, widgetId, scale) {
        root.updateWidget(name, widgetId, { scale: Math.max(0.7, Math.min(1.4, scale)) })
    }

    Component.onCompleted: root.load()
}
