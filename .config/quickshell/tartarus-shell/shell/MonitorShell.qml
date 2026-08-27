import Quickshell
import QtQml

import "../bar"

Scope {
    id: root

    required property var screen
    required property var launcherState
    required property var pluginRegistry

    readonly property string screenName:
        root.screen ? root.screen.name : ""

    readonly property real screenX:
        root.screen ? root.screen.x : 0

    readonly property real screenY:
        root.screen ? root.screen.y : 0

    readonly property real screenWidth:
        root.screen ? root.screen.width : 0

    readonly property real screenHeight:
        root.screen ? root.screen.height : 0

    readonly property real screenScale:
        root.screen ? root.screen.devicePixelRatio : 1.0

    readonly property rect screenGeometry: Qt.rect(
        root.screenX,
        root.screenY,
        root.screenWidth,
        root.screenHeight
    )

    readonly property alias monitorContext: context

    QtObject {
        id: context

        readonly property var screen: root.screen

        readonly property string name:
            root.screenName

        readonly property real x:
            root.screenX

        readonly property real y:
            root.screenY

        readonly property real width:
            root.screenWidth

        readonly property real height:
            root.screenHeight

        readonly property real scale:
            root.screenScale

        readonly property rect geometry:
            root.screenGeometry
    }

    Bar {
        screen: root.screen
        launcherState: root.launcherState
        pluginRegistry: root.pluginRegistry
    }
}
