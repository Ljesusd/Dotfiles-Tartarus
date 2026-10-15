import QtQuick

import "../../theme" as Theme

Rectangle {
    id: root

    required property var plugin
    property var hoverPanelController: null

    property var panelAnchorItem: null

    readonly property var service:
        root.plugin.service

    readonly property int connectedCount:
        root.service.connectedDevices.length

    readonly property string statusText: {
        if (!root.service.available)
            return "Bluetooth unavailable"

        if (!root.service.enabled)
            return "Bluetooth disabled"

        if (root.connectedCount === 0)
            return "Bluetooth"

        if (root.connectedCount === 1)
            return root.service.connectedDevices[0].name

        return root.connectedCount + " devices"
    }

    readonly property string bluetoothIcon: {
        if (!root.service.available)
            return "󰂲"

        if (!root.service.enabled)
            return "󰂲"

        if (root.connectedCount > 0)
            return "󰂱"

        return "󰂯"
    }

    signal interacted()

    function handleHover(hovered, anchorEntry) {
        if (!root.hoverPanelController)
            return false

        root.hoverPanelController.setEntryHovered(
            root.plugin.pluginId,
            hovered,
            anchorEntry ?? root.panelAnchorItem ?? root
        )

        return true
    }

    implicitWidth: Theme.Style.barControlHeight

    implicitHeight: Theme.Style.barControlHeight

    color: "transparent"

    radius: Theme.Style.barControlRadius
    border.width: 0

    Theme.MaterialIcon {
        id: bluetoothText

        anchors.centerIn: parent

        text: root.bluetoothIcon === "󰂲"
            ? "bluetooth_disabled"
            : root.bluetoothIcon === "󰂱"
                ? "bluetooth_connected"
                : "bluetooth"

        iconSize: Theme.Style.barIconNormal

        iconColor:
            root.service.available
            && root.service.enabled
            ? Theme.Color.foreground
            : Theme.Color.foregroundMuted
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.interacted()
            root.hoverPanelController.togglePanel(
                root.plugin.pluginId,
                root.panelAnchorItem ?? root
            )
        }
    }
}
