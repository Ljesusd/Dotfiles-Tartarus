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
            return "󰈀"

        if (root.connectionType === "wifi") {
            if (root.service.strength >= 75)
                return "󰤨"

            if (root.service.strength >= 50)
                return "󰤥"

            if (root.service.strength >= 25)
                return "󰤢"

            return "󰤟"
        }

        return "󰤭"
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

    implicitWidth: content.implicitWidth
        + Style.barPaddingNormal * 2

    implicitHeight: Style.barControlHeight

    radius: Style.radiusSmall

    color: mouseArea.containsMouse
        ? Color.surfaceHover
        : "transparent"

    RowLayout {
        id: content

        anchors.centerIn: parent

        spacing: Style.barSpacingSmall

        Text {
            text: root.networkIcon

            font.family: Style.iconFont
            font.pixelSize: Style.barIconNormal

            color: root.connectionType !== "disconnected"
                ? Color.foreground
                : Color.foregroundMuted
        }

        Text {
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
            root.plugin.panelAnchor =
                root.panelAnchorItem ?? root
            root.plugin.togglePanel(
                root.panelAnchorItem ?? root
            )
        }
    }
}
