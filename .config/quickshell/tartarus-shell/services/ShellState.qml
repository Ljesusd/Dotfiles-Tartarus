import Quickshell.Hyprland
import QtQml

QtObject {
    id: root

    property var monitorContexts: []

    function registerContext(context) {
        if (
            !context
            || root.monitorContexts.indexOf(context) !== -1
        ) {
            return
        }

        const next = root.monitorContexts.slice()
        next.push(context)
        root.monitorContexts = next
    }

    function unregisterContext(context) {
        root.monitorContexts =
            root.monitorContexts.filter(candidate => {
                return candidate !== context
            })
    }

    function closeLaunchers() {
        for (const context of root.monitorContexts)
            context.launcherOpened = false
    }

    function closeLauncher(context) {
        if (!context)
            return

        context.launcherOpened = false
    }

    function openLauncher(context) {
        if (!context)
            return

        for (const candidate of root.monitorContexts) {
            candidate.launcherOpened =
                candidate === context
        }
    }

    function toggleLauncher(context) {
        if (!context)
            return

        const shouldOpen =
            !context.launcherOpened

        for (const candidate of root.monitorContexts) {
            candidate.launcherOpened =
                shouldOpen
                && candidate === context
        }
    }

    function contextForFocusedMonitor() {
        const focused = Hyprland.focusedMonitor

        if (!focused)
            return null

        for (const context of root.monitorContexts) {
            const monitor = Hyprland.monitorFor(
                context.screen
            )

            if (monitor === focused)
                return context
        }

        return null
    }
}
