import Quickshell
import QtQml

import "../bar"
import "../launcher"
import "."
import "../services"
import "../services" as Services

Scope {
    id: root

    required property var screen
    required property var launcherState
    required property var shellState
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

    ScreenState {
        id: context
        screen: root.screen
    }

    Component.onCompleted: {
        root.shellState.registerContext(context)
    }

    Component.onDestruction: {
        root.shellState.unregisterContext(context)
    }

    Bar {
        id: bar

        screen: root.screen
        launcherState: root.launcherState
        monitorContext: context
        shellState: root.shellState
        pluginRegistry: root.pluginRegistry
    }

    Launcher {
        launcherState: root.launcherState
        monitorContext: context
        shellState: root.shellState
        launcherAnchor: bar.launcherAnchor
        barWindow: bar
    }

    ToastOverlay {
        monitorScreen: root.screen
    }

    NotificationOverlay {
        monitorScreen: root.screen
        monitorContext: context
    }

    NotificationCenter {
        monitorScreen: root.screen
        monitorContext: context
    }

    OsdOverlay { monitorScreen: root.screen; monitorContext: context }
    SidebarOverlay { monitorScreen: root.screen; pluginRegistry: root.pluginRegistry; monitorContext: context }

    ClipboardOverlay {
        monitorScreen: root.screen
        monitorContext: context
    }
}
