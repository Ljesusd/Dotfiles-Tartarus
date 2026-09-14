import Quickshell.Hyprland
import QtQml

QtObject {
    id: root

    readonly property var workspaceBaseByMonitor: ({
        "DP-2": 1,
        "HDMI-A-1": 6
    })
    readonly property var specialWorkspaceIcons: ({
        scratchpad: "layers",
        gaming: "sports_esports",
        communication: "forum",
        music: "music_note"
    })
    property var lastSpecialByMonitor: ({})

    readonly property var workspaces:
        Hyprland.workspaces.values

    readonly property var activeWorkspace:
        Hyprland.focusedWorkspace

    readonly property int activeWorkspaceId:
        root.activeWorkspace
        ? root.activeWorkspace.id
        : -1

    readonly property var focusedMonitor:
        Hyprland.focusedMonitor

    readonly property Connections hyprlandConnections: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activespecial")
                return

            Hyprland.refreshMonitors()
        }
    }

    function monitorForScreen(screen) {
        if (!screen)
            return null

        return Hyprland.monitorFor(screen)
    }

    function activeWorkspaceForScreen(screen) {
        const monitor = root.monitorForScreen(screen)

        return monitor
            ? monitor.activeWorkspace
            : null
    }

    function activeWorkspaceIdForScreen(screen) {
        const workspace =
            root.activeWorkspaceForScreen(screen)

        return workspace
            ? workspace.id
            : -1
    }

    function firstWorkspaceForScreen(screen) {
        if (!screen)
            return 1

        const monitor = root.monitorForScreen(screen)
        const monitorName =
            monitor?.name
            ?? screen.name
            ?? ""

        const base =
            root.workspaceBaseByMonitor[monitorName]

        return typeof base === "number" && base > 0
            ? base
            : 1
    }

    function activeSpecialWorkspaceNameForScreen(screen) {
        const monitor = root.monitorForScreen(screen)

        if (!monitor)
            return ""

        return monitor.lastIpcObject
            ?.specialWorkspace
            ?.name
            ?? ""
    }

    function hasActiveSpecialWorkspaceForScreen(screen) {
        return root.activeSpecialWorkspaceNameForScreen(screen)
            !== ""
    }

    function specialWorkspacesForScreen(screen) {
        const monitor = root.monitorForScreen(screen)
        const names = new Set()
        const specials = []

        for (const workspace of root.workspaces) {
            const workspaceName =
                workspace?.name ?? ""

            if (!workspaceName.startsWith("special:"))
                continue

            if (monitor && workspace.monitor !== monitor)
                continue

            const key = root.specialWorkspaceKey(workspaceName)

            if (names.has(key))
                continue

            names.add(key)
            specials.push(workspace)
        }

        specials.sort((left, right) => {
            const leftName = root.specialWorkspaceKey(left?.name)
            const rightName = root.specialWorkspaceKey(right?.name)

            if (leftName < rightName)
                return -1

            if (leftName > rightName)
                return 1

            return 0
        })

        return specials
    }

    function workspace(id) {
        for (const candidate of root.workspaces) {
            if (candidate.id === id)
                return candidate
        }

        return null
    }

    function specialWorkspaceKey(name) {
        if (!name)
            return ""

        return name.startsWith("special:")
            ? name.slice(8)
            : name
    }

    function specialWorkspaceLabel(name) {
        const key = root.specialWorkspaceKey(name)

        if (!key)
            return "Special"

        return key.charAt(0).toUpperCase()
            + key.slice(1)
    }

    function specialWorkspaceIcon(name) {
        const key = root.specialWorkspaceKey(name)
        const configuredIcon =
            root.specialWorkspaceIcons[key]

        if (configuredIcon)
            return configuredIcon

        return key.length > 0
            ? key.charAt(0).toUpperCase()
            : "layers"
    }

    function windowsForWorkspace(id) {
        const target = root.workspace(id)

        return target
            ? target.toplevels.values
            : []
    }

    function isOccupied(id) {
        return root.windowsForWorkspace(id).length > 0
    }

    function focusMonitorForScreen(screen) {
        const monitor = root.monitorForScreen(screen)

        if (!monitor)
            return false

        const monitorName =
            monitor.name ?? screen?.name ?? ""

        if (!monitorName)
            return false

        if (Hyprland.usingLua) {
            Hyprland.dispatch(
                `hl.dsp.focus({ monitor = "${monitorName}" })`
            )
        } else {
            Hyprland.dispatch(
                `focusmonitor ${monitorName}`
            )
        }

        return true
    }

    function activateWorkspace(id) {
        if (id < 1)
            return false

        const target = root.workspace(id)

        if (target) {
            if (!target.focused)
                target.activate()

            return true
        }

        const workspaceName = String(id)

        if (Hyprland.usingLua) {
            Hyprland.dispatch(
                `hl.dsp.focus({ workspace = "${workspaceName}" })`
            )
        } else {
            Hyprland.dispatch(
                `workspace ${workspaceName}`
            )
        }

        return true
    }

    function activateWorkspaceForScreen(screen, id) {
        if (id < 1)
            return false

        if (!root.focusMonitorForScreen(screen))
            return false

        return root.activateWorkspace(id)
    }

    function toggleSpecialWorkspace(name) {
        if (!name)
            return false

        const specialName = name.startsWith("special:")
            ? name.slice(8)
            : name

        if (Hyprland.usingLua) {
            Hyprland.dispatch(
                `hl.dsp.workspace.toggle_special("${specialName}")`
            )
        } else {
            Hyprland.dispatch(
                `togglespecialworkspace ${specialName}`
            )
        }

        return true
    }

    function toggleSpecialWorkspaceForScreen(screen, name) {
        if (!name)
            return false

        if (!root.focusMonitorForScreen(screen))
            return false

        const monitor = root.monitorForScreen(screen)
        const key = monitor?.name ?? screen?.name ?? ""
        if (key) {
            const next = Object.assign({}, root.lastSpecialByMonitor)
            next[key] = root.specialWorkspaceKey(name)
            root.lastSpecialByMonitor = next
        }
        return root.toggleSpecialWorkspace(name)
    }

    function toggleLastSpecialWorkspaceForScreen(screen) {
        const monitor = root.monitorForScreen(screen)
        const key = monitor?.name ?? screen?.name ?? ""
        const remembered = key ? root.lastSpecialByMonitor[key] : ""
        return root.toggleSpecialWorkspaceForScreen(
            screen,
            remembered || "special"
        )
    }
}
