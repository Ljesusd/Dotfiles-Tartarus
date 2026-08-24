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
        for (const plugin of pluginRegistry.plugins) {
            if (
                plugin
                && plugin.panelOpened
                && typeof plugin.closePanel === "function"
            ) {
                plugin.closePanel()
            }
        }
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

        function onOpenedChanged() {
            if (launcherState.opened)
                root.closePluginPanels()
        }
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

    Item {
        id: pluginPanelHost

        width: 0
        height: 0

        ListModel {
            id: panelPluginModel
        }

        Component.onCompleted: {
            for (const plugin of pluginRegistry.plugins)
                pluginPanelHost.addPanelPlugin(plugin)
        }

        Connections {
            target: pluginRegistry

            function onPluginRegistered(plugin) {
                pluginPanelHost.addPanelPlugin(plugin)
            }
        }

        function addPanelPlugin(plugin) {
            if (
                !plugin
                || !plugin.capabilities
                || !plugin.capabilities.includes("panel")
                || plugin.panelComponent === undefined
                || plugin.panelComponent === null
            ) {
                return
            }

            for (let i = 0; i < panelPluginModel.count; i++) {
                if (
                    panelPluginModel.get(i).pluginId
                    === plugin.pluginId
                ) {
                    return
                }
            }

            panelPluginModel.append({
                pluginId: plugin.pluginId,
                plugin: plugin
            })
        }

        Repeater {
            model: panelPluginModel

            Loader {
                id: panelLoader

                required property string pluginId
                required property var plugin

                active:
                    plugin.panelComponent !== undefined
                    && plugin.panelComponent !== null

                sourceComponent:
                    active
                    ? plugin.panelComponent
                    : null

            }
        }
    }
}
