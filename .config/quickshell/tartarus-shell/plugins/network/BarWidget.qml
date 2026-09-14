import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var plugin
    property var hoverPanelController: null

    property var panelAnchorItem: null

    readonly property var service:
        root.plugin.service

    readonly property string connectionType: {
        if (root.service.ethernetConnected)
            return "ethernet"

        if (root.service.connected)
            return "wifi"

        return "disconnected"
    }

    readonly property string networkIcon: {
        if (root.connectionType === "ethernet")
                return "lan"

        if (root.connectionType === "wifi") {
            if (root.service.strength >= 75)
                return "wifi"

            if (root.service.strength >= 50)
                return "wifi"

            if (root.service.strength >= 25)
                return "wifi"

            return "wifi_2_bar"
        }

        return "wifi_off"
    }

    readonly property string connectionLabel: {
        if (root.connectionType === "ethernet") {
            if (root.service.ethernetName !== "")
                return root.service.ethernetName

            return root.service.ethernetInterface
        }

        if (root.connectionType === "wifi")
            return root.service.ssid

        return "Disconnected"
    }

    readonly property string tooltipText: {
        if (root.connectionType === "ethernet") {
            return root.service.ethernetInterface
                + " · "
                + root.service.ethernetLinkSpeed
                + " Mbps"
        }

        if (root.connectionType === "wifi") {
            return root.service.ssid
                + " · "
                + root.service.strength
                + "%"
        }

        return "No network connection"
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

    implicitWidth: Style.barControlHeight

    implicitHeight: Style.barControlHeight

    radius: Style.barControlRadius
    border.width: 0

    color: "transparent"

    RowLayout {
        id: content

        anchors.centerIn: parent

        spacing: Style.barSpacingSmall

        MaterialIcon {
            text: root.networkIcon
            iconSize: Style.barIconNormal

            color: root.connectionType !== "disconnected"
                ? Color.foreground
                : Color.foregroundMuted
        }

        Text {
            visible: false
            text: root.connectionLabel

            font.pixelSize: Style.barFontNormal

            color: root.connectionType !== "disconnected"
                ? Color.foreground
                : Color.foregroundMuted

            elide: Text.ElideRight
            maximumLineCount: 1
        }
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
