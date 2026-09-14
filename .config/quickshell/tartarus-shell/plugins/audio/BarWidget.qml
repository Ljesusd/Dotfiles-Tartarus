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

    implicitWidth: Style.barControlHeight

    implicitHeight: Style.barControlHeight

    color: "transparent"

    radius: Style.barControlRadius
    border.width: 0

    MaterialIcon {
        id: audioIcon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.barPaddingNormal
        text: root.plugin.service.muted ? "volume_off" : "volume_up"
        font.pixelSize: Style.barIconNormal
        color: root.plugin.service.muted
            ? Color.foregroundMuted
            : Color.foreground
    }

    Text {
        id: audioText
        visible: false

        anchors.left: audioIcon.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.barSpacingSmall

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
            root.hoverPanelController.togglePanel(
                root.plugin.pluginId,
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
