import QtQuick

import "../../theme" as Theme

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

    implicitWidth: Theme.Style.barControlHeight

    implicitHeight: Theme.Style.barControlHeight

    color: "transparent"

    radius: Theme.Style.barControlRadius
    border.width: 0

    Theme.MaterialIcon {
        id: keyboardIcon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.Style.barPaddingNormal
        text: "keyboard"
        font.pixelSize: Theme.Style.barIconNormal
        color: root.plugin.service.available
            ? Theme.Color.foreground
            : Theme.Color.foregroundMuted
    }

    Text {
        id: keyboardText
        visible: false

        anchors.left: keyboardIcon.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.Style.barSpacingSmall

        text: root.plugin.service.displayText
        color: root.plugin.service.available
            ? Theme.Color.foreground
            : Theme.Color.foregroundMuted
        font.pixelSize: Theme.Style.barFontNormal
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
                root.plugin.service.toggle()
            }
        }
    }
}
