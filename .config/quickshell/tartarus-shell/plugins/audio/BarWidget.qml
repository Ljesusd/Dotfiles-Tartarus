import QtQuick

import "../../theme"

Rectangle {
    id: root

    required property var plugin
    property var hoverPanelController: null

    property var panelAnchorItem: null

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

    implicitWidth: audioText.implicitWidth
        + Style.barPaddingNormal * 2

    implicitHeight: Style.barControlHeight

    color: mouseArea.containsMouse
        ? Color.surfaceHover
        : "transparent"

    radius: Style.radiusSmall

    Text {
        id: audioText

        anchors.centerIn: parent

        font.pixelSize: Style.barFontNormal

        text: root.plugin.service.displayText

        color: {
            if (!root.plugin.service.available)
                return Color.foregroundMuted

            if (root.plugin.service.muted)
                return Color.foregroundMuted

            return Color.foreground
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

        onWheel: event => {
            if (!root.plugin.service.available)
                return

            root.interacted()

            const step = 0.05

            if (event.angleDelta.y > 0) {
                root.plugin.service.changeVolume(step)
            } else if (event.angleDelta.y < 0) {
                root.plugin.service.changeVolume(-step)
            }
        }
    }
}
