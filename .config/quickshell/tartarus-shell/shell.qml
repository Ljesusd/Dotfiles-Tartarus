//@ pragma ShellId tartarus-shell
//@ pragma StateDir $BASE/tartarus-shell
//@ pragma CacheDir $BASE/tartarus-shell
//@ pragma DataDir $BASE/tartarus-shell
//@ pragma UseQApplication

import Quickshell
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

    PluginRegistry {
        id: pluginRegistry
    }

    PluginDiscovery {
        registry: pluginRegistry
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcherState.toggle()
        }

        function open(): void {
            launcherState.open()
        }

        function close(): void {
            launcherState.close()
        }
    }

    Connections {
        target: launcherState

        function onOpenedChanged() {}
    }

    Variants {
        model: Quickshell.screens

        Shell.MonitorShell {
            required property var modelData

            screen: modelData
            launcherState: root.sharedLauncherState
            pluginRegistry: root.sharedPluginRegistry
        }
    }

    Launcher {
        launcherState: launcherState
    }

}
