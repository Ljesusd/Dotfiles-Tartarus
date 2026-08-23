pragma ComponentBehavior: Bound

import QtQml
import "."

QtObject {
    id: root

    readonly property string pluginId: "network"
    readonly property string displayName: "Network"

    readonly property var capabilities: [
        "bar-widget",
        "panel",
        "service"
    ]

    readonly property string barSection: "right"
    readonly property int barOrder: 200

    readonly property Service service: Service {}

    readonly property Component barWidgetComponent: Component {
        BarWidget {
            plugin: root
        }
    }

    readonly property Component panelComponent: Component {
        Panel {
            plugin: root
        }
    }

    property bool panelOpened: false
    property var panelAnchor: null

    function openPanel(anchor) {
        root.panelAnchor = anchor
        root.panelOpened = true
    }

    function closePanel() {
        root.panelOpened = false
    }

    function togglePanel(anchor) {
        if (root.panelOpened) {
            root.closePanel()
        } else {
            root.openPanel(anchor)
        }
    }
}
