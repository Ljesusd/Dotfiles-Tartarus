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

    readonly property string brightnessIcon: {
        if (!root.service.available)
            return "󰃞"

        const percent =
            root.service.brightnessPercent

        if (percent >= 75)
            return "󰃠"

        if (percent >= 40)
            return "󰃟"

        return "󰃞"
    }

    readonly property string brightnessText:
        root.service.available
        ? root.service.brightnessPercent + "%"
        : "N/A"

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
            text: root.brightnessIcon

            font.family: Style.iconFont
            font.pixelSize: Style.barIconNormal

            color: root.service.available
                ? Color.foreground
                : Color.foregroundMuted
        }

        Text {
            text: root.brightnessText

            font.pixelSize: Style.barFontNormal

            color: root.service.available
                ? Color.foreground
                : Color.foregroundMuted
        }
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

    WheelHandler {
        id: brightnessWheel

        target: null

        acceptedDevices:
            PointerDevice.Mouse
            | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.service.available)
                return

            const deltaY =
                event.angleDelta.y

            if (deltaY === 0)
                return

            root.interacted()

            root.service.changeBrightness(
                deltaY > 0 ? 5 : -5
            )

            event.accepted = true
        }
    }
}
