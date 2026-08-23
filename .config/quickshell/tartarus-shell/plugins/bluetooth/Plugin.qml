pragma ComponentBehavior: Bound

import QtQml
import "."

QtObject {
    id: root

    readonly property string pluginId: "bluetooth"
    readonly property string displayName: "Bluetooth"

    readonly property var capabilities: [
        "bar-widget",
        "panel",
        "service"
    ]

    readonly property string barSection: "right"
    readonly property int barOrder: 100

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

    readonly property Timer stopScanTimer: Timer {
        interval: 100
        repeat: false

        onTriggered: {
            if (
                !root.panelOpened
                && root.service.discovering
            ) {
                root.service.stopScan()
            }
        }
    }

    function openPanel(anchor) {
        root.stopScanTimer.stop()

        root.panelAnchor = anchor
        root.panelOpened = true
    }

    function closePanel() {
        root.panelOpened = false

        root.stopScanTimer.restart()
    }

    function togglePanel(anchor) {
        if (root.panelOpened) {
            root.closePanel()
        } else {
            root.openPanel(anchor)
        }
    }
}
