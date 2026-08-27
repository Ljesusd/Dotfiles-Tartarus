import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQml.Models

import "../core"
import "../theme"
import "components"

PanelWindow {
    id: root

    required property var launcherState
    required property var pluginRegistry
    property Item hoveredEntry: null

    HoverPanelController {
        id: hoverPanelController

        pluginRegistry: root.pluginRegistry
    }

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

    function isEntry(item) {
        return item
            && item.isBarEntry === true
            && typeof item.entryId === "string"
            && item.entryId.length > 0
    }

    function findEntryAt(item, x, y) {
        if (!item)
            return null

        const child = item.childAt(x, y)

        if (!child)
            return null

        if (root.isEntry(child))
            return child

        if (typeof child.childAt !== "function")
            return null

        const point = item.mapToItem(
            child,
            x,
            y
        )

        return root.findEntryAt(
            child,
            point.x,
            point.y
        )
    }

    function entryAt(sourceItem, x, y) {
        if (!sourceItem)
            return null

        const point = sourceItem.mapToItem(
            barLayout,
            x,
            y
        )

        return root.findEntryAt(
            barLayout,
            point.x,
            point.y
        )
    }

    function entryIdAt(sourceItem, x, y) {
        const entry = root.entryAt(
            sourceItem,
            x,
            y
        )

        return entry
            ? entry.entryId
            : ""
    }

    function routeWheel(sourceItem, x, y, angleDelta) {
        const entry = root.entryAt(
            sourceItem,
            x,
            y
        )

        if (!entry)
            return false

        return entry.handleWheel(angleDelta)
    }

    function clearHoveredEntry() {
        if (root.hoveredEntry)
            root.hoveredEntry.handleHover(false)

        root.hoveredEntry = null
    }

    function routeHover(sourceItem, x, y) {
        const entry = root.entryAt(
            sourceItem,
            x,
            y
        )

        if (entry === root.hoveredEntry)
            return

        if (root.hoveredEntry)
            root.hoveredEntry.handleHover(false)

        root.hoveredEntry = entry

        if (root.hoveredEntry)
            root.hoveredEntry.handleHover(true)
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
        id: barSurface

        anchors.fill: parent
        color: Color.background

        HoverPanelHost {
            hoverPanelController: hoverPanelController
            anchorSurface: barLayout
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closeLauncherIfOpen()
            }
        }

        RowLayout {
            id: barLayout

            anchors.fill: parent
            spacing: 0

            HoverHandler {
                id: hoverRouter

                parent: barLayout
                target: null
                blocking: false

                onPointChanged: {
                    const position = hoverRouter.point.position

                    root.routeHover(
                        barLayout,
                        position.x,
                        position.y
                    )
                }

                onHoveredChanged: {
                    if (!hovered)
                        root.clearHoveredEntry()
                }
            }

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

                        EntryWrapper {
                            id: leftPluginSlot

                            entryId: pluginId
                            required property string pluginId
                            required property var plugin

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

                                    if (
                                        item
                                        && "hoverPanelController" in item
                                    ) {
                                        item.hoverPanelController =
                                            hoverPanelController
                                    }
                                }

                                Connections {
                                    target: leftPluginWidgetLoader.item

                                    ignoreUnknownSignals: true

                                    function onInteracted() {
                                        root.closeLauncherIfOpen()
                                    }
                                }
                            }

        MouseArea {
            id: wheelDebugArea

            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.NoButton

            onWheel: event => {
                const handled = root.routeWheel(
                    wheelDebugArea,
                    event.x,
                    event.y,
                    event.angleDelta
                )

                event.accepted = handled
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

                EntryWrapper {
                    anchors.centerIn: parent
                    entryId: "launcher-search"

                    LauncherSearch {
                        launcherState: root.launcherState
                    }
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

                    EntryWrapper {
                        entryId: "system-tray"

                        SystemTray {
                            launcherState: root.launcherState
                        }
                    }

                    Repeater {
                        model: rightBarPluginModel

                        EntryWrapper {
                            id: pluginSlot

                            entryId: pluginId
                            required property string pluginId
                            required property var plugin

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

                                    if (
                                        item
                                        && "hoverPanelController" in item
                                    ) {
                                        item.hoverPanelController =
                                            hoverPanelController
                                    }
                                }

                                Connections {
                                    target: pluginWidgetLoader.item

                                    ignoreUnknownSignals: true

                                    function onInteracted() {
                                        root.closeLauncherIfOpen()
                                    }
                                }
                            }
                        }
                    }

                    EntryWrapper {
                        entryId: "clock"

                        Clock {
                            launcherState: root.launcherState
                        }
                    }
                }
            }
        }

    }
}
