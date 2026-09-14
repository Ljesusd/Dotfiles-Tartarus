//@ pragma ShellId tartarus-shell
//@ pragma StateDir $BASE/tartarus-shell
//@ pragma CacheDir $BASE/tartarus-shell
//@ pragma DataDir $BASE/tartarus-shell
//@ pragma UseQApplication

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQml
import QtQml.Models
import QtQuick
import "bar"
import "core"
import "launcher"
import "shell/imageviewer" as ImageViewer
import "./shell" as Shell
import "services"

ShellRoot {
    id: root

    readonly property var sharedLauncherState: launcherState
    readonly property var sharedPluginRegistry: pluginRegistry

    function closePluginPanels() {
        // Paneles hover compartidos:
        // el cierre se resuelve en cada Bar.
    }

    LauncherState {
        id: launcherState
    }

    ShellState {
        id: globalShellState
    }

    PluginRegistry {
        id: pluginRegistry
    }

    PluginDiscovery {
        registry: pluginRegistry
    }

    GlobalShortcut {
        name: "launcher"
        description: "Toggle application launcher"

        onPressed: {
            const context =
                globalShellState.contextForFocusedMonitor()

            if (!context)
                return

            globalShellState.toggleLauncher(context)

            if (context.launcherOpened)
                launcherState.focusSearch()
        }
    }

    IpcHandler {
        target: "osd"
        function showVolume(): void { OsdService.showCurrentVolume() }
        function showBrightness(): void { OsdService.show("brightness", 0, false) }
        function showMute(): void { OsdService.show("volume", 0, true) }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { globalShellState.toggleSidebar(globalShellState.contextForFocusedMonitor()) }
        function open(): void { globalShellState.openSidebar(globalShellState.contextForFocusedMonitor()) }
        function close(): void { globalShellState.closeSidebar(globalShellState.contextForFocusedMonitor()) }
    }

    IpcHandler {
        target: "power"
        function lock(): void { PowerService.lock() }
        function suspend(): void { PowerService.suspend() }
        function logout(): void { PowerService.logout() }
        function reboot(): void { PowerService.reboot() }
        function shutdown(): void { PowerService.shutdown() }
    }

    GlobalShortcut {
        name: "notification-dnd"
        description: "Toggle notification Do Not Disturb"

        onPressed: NotificationService.toggleDnd()
    }

    GlobalShortcut {
        name: "notification-center"
        description: "Toggle notification center"

        onPressed: NotificationService.toggleCenter()
    }

    GlobalShortcut {
        name: "clipboard"
        description: "Toggle clipboard history"

        onPressed: ClipboardService.toggle()
    }

    IpcHandler {
        target: "notification"

        function toggleDnd(): void {
            NotificationService.toggleDnd()
        }

        function setDnd(enabled: bool): void {
            if (NotificationService.dnd === enabled)
                return

            NotificationService.toggleDnd()
        }

        function toggleCenter(): void {
            globalShellState.toggleNotificationCenter()
        }

        function openCenter(): void {
            NotificationService.centerOpen = true
        }

        function closeCenter(): void {
            globalShellState.closeNotificationCenter()
        }

        function clearHistory(): void {
            NotificationService.clearHistory()
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            globalShellState.syncClipboardState()
            const context = globalShellState.contextForFocusedMonitor()
            if (context)
                context.toggleClipboard()
            ClipboardService.open = context ? context.clipboardOpen : false
        }

        function open(): void {
            ClipboardService.open = true
        }

        function close(): void {
            ClipboardService.close()
        }

        function clear(): void {
            ClipboardService.clear()
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            const context =
                globalShellState.contextForFocusedMonitor()

            if (!context)
                return

            globalShellState.toggleLauncher(context)

            if (context.launcherOpened)
                launcherState.focusSearch()
        }

        function open(): void {
            const context =
                globalShellState.contextForFocusedMonitor()

            if (!context)
                return

            globalShellState.openLauncher(context)
            launcherState.focusSearch()
        }

        function close(): void {
            globalShellState.closeLaunchers()
        }

        function suppressFocusClose(suppressed: bool): void {
            globalShellState.setLauncherFocusCloseSuppressed(suppressed)
        }
    }

    Variants {
        model: Quickshell.screens

        Shell.MonitorShell {
            required property var modelData

            screen: modelData
            launcherState: root.sharedLauncherState
            shellState: globalShellState
            pluginRegistry: root.sharedPluginRegistry
        }
    }

    ImageViewer.ImageViewerWindow { shellState: globalShellState }

    QtObject {
        property var notificationService: NotificationService
    }

}
