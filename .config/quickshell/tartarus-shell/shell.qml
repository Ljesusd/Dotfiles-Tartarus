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

        Bar {
            required property var modelData

            screen: modelData

            launcherState: root.sharedLauncherState
            pluginRegistry: root.sharedPluginRegistry
        }
    }

    Launcher {
        launcherState: launcherState
    }

    Instantiator {
        id: pluginPanelHost

        model: pluginRegistry.plugins

        delegate: Loader {
            required property var modelData

            readonly property var plugin: modelData

            active:
                plugin
                && plugin.capabilities
                && plugin.capabilities.includes("panel")
                && plugin.panelComponent !== undefined
                && plugin.panelComponent !== null

            sourceComponent:
                active
                ? plugin.panelComponent
                : null
        }
    }

}
