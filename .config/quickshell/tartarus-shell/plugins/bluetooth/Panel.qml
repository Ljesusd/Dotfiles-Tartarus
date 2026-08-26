import Quickshell
import QtQuick

import "../../theme"

PopupWindow {
    id: root

    required property var plugin
    property var hoverPanelController: null

    anchor {
        item: root.plugin.panelAnchor

        edges:
            Edges.Bottom
            | Edges.Left

        gravity:
            Edges.Bottom
            | Edges.Right

        margins.bottom: Style.barPopupGap
    }

    visible:
        root.plugin.panelOpened
        && root.plugin.panelAnchor !== null

    implicitWidth: 380
    implicitHeight: 460

    color: "transparent"
    grabFocus: false

    PanelContent {
        anchors.fill: parent

        plugin: root.plugin
        hoverPanelController: root.hoverPanelController
        active: root.visible
    }
}
