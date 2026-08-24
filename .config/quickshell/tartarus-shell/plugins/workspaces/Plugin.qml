pragma ComponentBehavior: Bound

import QtQml
import "."

QtObject {
    id: root

    readonly property string pluginId: "workspaces"
    readonly property string displayName: "Workspaces"

    readonly property var capabilities: [
        "bar-widget",
        "service"
    ]

    readonly property string barSection: "left"
    readonly property int barOrder: 100

    readonly property Service service: Service {}

    readonly property Component barWidgetComponent: Component {
        BarWidget {
            plugin: root
        }
    }
}
