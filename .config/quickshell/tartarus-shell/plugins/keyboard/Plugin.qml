pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import "."

QtObject {
    id: root

    readonly property string pluginId: "keyboard"
    readonly property string displayName: "Keyboard"

    readonly property var capabilities: [
        "bar-widget",
        "panel",
        "service"
    ]

    readonly property string barSection: "right"
    readonly property int barOrder: 275

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
