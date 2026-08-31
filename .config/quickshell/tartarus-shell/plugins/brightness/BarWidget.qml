import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var plugin
    property var hoverPanelController: null
    property var barScreen: null

    property var panelAnchorItem: null

    readonly property var service:
        root.plugin.service

    readonly property bool brightnessAvailable:
        root.service.availableForScreen(
            root.barScreen
        )

    readonly property int brightnessPercent:
        root.service.brightnessPercentForScreen(
            root.barScreen
        )

    readonly property string brightnessIcon: {
        if (!root.brightnessAvailable)
            return "󰃞"

        const percent =
            root.brightnessPercent

        if (percent >= 75)
            return "󰃠"

        if (percent >= 40)
            return "󰃟"

        return "󰃞"
    }

    readonly property string brightnessText:
        root.brightnessAvailable
        ? root.brightnessPercent + "%"
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

            color: root.brightnessAvailable
                ? Color.foreground
                : Color.foregroundMuted
        }

        Text {
            text: root.brightnessText

            font.pixelSize: Style.barFontNormal

            color: root.brightnessAvailable
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
            root.hoverPanelController.togglePanel(
                root.plugin.pluginId,
                root.panelAnchorItem ?? root
            )
        }
    }

    WheelHandler {
        id: brightnessWheel

        target: null

        acceptedDevices:
            PointerDevice.Mouse
            | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.brightnessAvailable)
                return

            const deltaY =
                event.angleDelta.y

            if (deltaY === 0)
                return

            root.interacted()

            root.service.changeBrightnessForScreen(
                root.barScreen,
                deltaY > 0 ? 5 : -5
            )

            event.accepted = true
        }
    }

}
