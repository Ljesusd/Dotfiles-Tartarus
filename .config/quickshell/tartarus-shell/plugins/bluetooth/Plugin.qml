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

    readonly property Component panelContentComponent: Component {
        PanelContent {
            plugin: root
        }
    }
}
