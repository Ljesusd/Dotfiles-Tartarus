import QtQuick

import "../../theme"

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

    implicitWidth: bluetoothText.implicitWidth
        + Style.barPaddingNormal * 2

    implicitHeight: Style.barControlHeight

    color: mouseArea.containsMouse
        ? Color.surfaceHover
        : "transparent"

    radius: Style.radiusSmall

    Text {
        id: bluetoothText

        anchors.centerIn: parent

        font.family: Style.iconFont
        font.pixelSize: Style.barIconNormal

        text: root.bluetoothIcon

        color:
            root.service.available
            && root.service.enabled
            ? Color.foreground
            : Color.foregroundMuted
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.interacted()
            if (root.hoverPanelController) {
                root.hoverPanelController.togglePanel(
                    root.plugin.pluginId,
                    root.panelAnchorItem ?? root
                )
            } else {
                root.plugin.panelAnchor =
                    root.panelAnchorItem ?? root
                root.plugin.togglePanel(
                    root.panelAnchorItem ?? root
                )
            }
        }
    }
}
