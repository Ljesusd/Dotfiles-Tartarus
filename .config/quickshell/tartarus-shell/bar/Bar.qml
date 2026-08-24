import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQml.Models

import "../theme"
import "components"

PanelWindow {
    id: root

    required property var launcherState
    required property var pluginRegistry

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Style.barHeight
    exclusiveZone: implicitHeight
    focusable: true

    Component.onCompleted: {
        root.launcherState.barWindow = root

        for (const plugin of root.pluginRegistry.plugins)
            root.addLeftBarPlugin(plugin)
        for (const plugin of root.pluginRegistry.plugins)
            root.addRightBarPlugin(plugin)
    }

    ListModel {
        id: leftBarPluginModel
    }

    ListModel {
        id: rightBarPluginModel
    }

    Connections {
        target: root.pluginRegistry

        function onPluginRegistered(plugin) {
            root.addLeftBarPlugin(plugin)
            root.addRightBarPlugin(plugin)
        }
    }

    function closeLauncherIfOpen() {
        if (root.launcherState.opened)
            root.launcherState.close()
    }

    function addLeftBarPlugin(plugin) {
        if (
            !plugin
            || !plugin.capabilities
            || !plugin.capabilities.includes("bar-widget")
            || plugin.barSection !== "left"
            || plugin.barWidgetComponent === undefined
            || plugin.barWidgetComponent === null
        ) {
            return
        }

        for (let i = 0; i < leftBarPluginModel.count; i++) {
            if (
                leftBarPluginModel.get(i).pluginId
                === plugin.pluginId
            ) {
                return
            }
        }

        const order = plugin.barOrder ?? 0
        let insertIndex = leftBarPluginModel.count

        for (let i = 0; i < leftBarPluginModel.count; i++) {
            if (order < leftBarPluginModel.get(i).barOrder) {
                insertIndex = i
                break
            }
        }

        leftBarPluginModel.insert(insertIndex, {
            pluginId: plugin.pluginId,
            barOrder: order,
            plugin: plugin
        })
    }

    function addRightBarPlugin(plugin) {
        if (
            !plugin
            || !plugin.capabilities
            || !plugin.capabilities.includes("bar-widget")
            || plugin.barSection !== "right"
            || plugin.barWidgetComponent === undefined
            || plugin.barWidgetComponent === null
        ) {
            return
        }

        for (let i = 0; i < rightBarPluginModel.count; i++) {
            if (
                rightBarPluginModel.get(i).pluginId
                === plugin.pluginId
            ) {
                return
            }
        }

        const order = plugin.barOrder ?? 0
        let insertIndex = rightBarPluginModel.count

        for (let i = 0; i < rightBarPluginModel.count; i++) {
            if (order < rightBarPluginModel.get(i).barOrder) {
                insertIndex = i
                break
            }
        }

        rightBarPluginModel.insert(insertIndex, {
            pluginId: plugin.pluginId,
            barOrder: order,
            plugin: plugin
        })
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closeLauncherIfOpen()
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Izquierda
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: Style.barSpacingNormal

                    Repeater {
                        model: leftBarPluginModel

                        Item {
                            id: leftPluginSlot

                            required property string pluginId
                            required property var plugin

                            implicitWidth:
                                leftPluginWidgetLoader.implicitWidth

                            implicitHeight: Style.barHeight

                            Loader {
                                id: leftPluginWidgetLoader

                                anchors.centerIn: parent

                                active:
                                    plugin.barWidgetComponent !== undefined
                                    && plugin.barWidgetComponent !== null

                                sourceComponent:
                                    active
                                    ? plugin.barWidgetComponent
                                    : null

                                onLoaded: {
                                    if (
                                        item
                                        && "panelAnchorItem" in item
                                    ) {
                                        item.panelAnchorItem = leftPluginSlot
                                    }

                                    if (
                                        item
                                        && "barScreen" in item
                                    ) {
                                        item.barScreen = root.screen
                                    }
                                }

                                Connections {
                                    target: leftPluginWidgetLoader.item

                                    ignoreUnknownSignals: true

                                    function onInteracted() {
                                        root.closeLauncherIfOpen()
                                        root.pluginRegistry.closeOpenPanelsExcept(
                                            leftPluginSlot.pluginId
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Centro
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Centro actual de la barra: busqueda real del launcher.
                LauncherSearch {
                    anchors.centerIn: parent

                    launcherState: root.launcherState
                }

                // ActiveWindow desactivado temporalmente.
                // Para recuperarlo: comenta LauncherSearch y descomenta este bloque.
                //
                // ActiveWindow {
                //     anchors.centerIn: parent
                // }
            }

            // Derecha
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: Style.barSpacingNormal

                    SystemTray {
                        launcherState: root.launcherState
                    }

                    Repeater {
                        model: rightBarPluginModel

                        Item {
                            id: pluginSlot

                            required property string pluginId
                            required property var plugin

                            implicitWidth:
                                pluginWidgetLoader.implicitWidth

                            implicitHeight: Style.barHeight

                            Loader {
                                id: pluginWidgetLoader

                                anchors.centerIn: parent

                                active:
                                    plugin.barWidgetComponent !== undefined
                                    && plugin.barWidgetComponent !== null

                                sourceComponent:
                                    active
                                    ? plugin.barWidgetComponent
                                    : null

                                onLoaded: {
                                    if (
                                        item
                                        && "panelAnchorItem" in item
                                    ) {
                                        item.panelAnchorItem = pluginSlot
                                    }

                                    if (
                                        item
                                        && "barScreen" in item
                                    ) {
                                        item.barScreen = root.screen
                                    }
                                }

                                Connections {
                                    target: pluginWidgetLoader.item

                                    ignoreUnknownSignals: true

                                    function onInteracted() {
                                        root.closeLauncherIfOpen()
                                        root.pluginRegistry.closeOpenPanelsExcept(
                                            pluginSlot.pluginId
                                        )
                                    }
                                }
                            }
                        }
                    }

                    Clock {
                        launcherState: root.launcherState
                    }
                }
            }
        }
    }
}
