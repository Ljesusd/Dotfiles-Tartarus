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

}
