import Quickshell.Hyprland
import QtQuick

import "../../theme"
import "../../utils"

Item {
    id: root

    required property var workspaceService
    required property var screen

    property int refreshRevision: 0

    readonly property int workspaceId: root.workspaceService
        ? root.workspaceService.activeWorkspaceIdForScreen(root.screen)
        : -1
    readonly property var windows: {
        root.refreshRevision
        if (!root.workspaceService || root.workspaceId < 1)
            return []
        return root.workspaceService.windowsForWorkspace(root.workspaceId)
    }

    implicitWidth: Math.min(240, appList.contentWidth)
    implicitHeight: Style.barInnerHeight

    Connections {
        target: Hyprland

        function onRawEvent() {
            root.refreshRevision++
        }
    }

    ListView {
        id: appList
        anchors.verticalCenter: parent.verticalCenter
        width: contentWidth
        height: Style.barInnerHeight
        orientation: ListView.Horizontal
        spacing: Style.barWorkspaceContentSpacing
        interactive: false
        clip: true
        model: root.windows

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.motionFast }
                NumberAnimation { property: "scale"; from: 0.7; to: 1; duration: Style.motionNormal; easing.type: Easing.OutBack }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Style.motionFast }
                NumberAnimation { property: "scale"; to: 0.7; duration: Style.motionFast }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x"; duration: Style.motionNormal; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: appItem
            required property var modelData

            width: Style.barControlHeight
            height: Style.barInnerHeight
            scale: appHover.hovered ? 1.12 : 1

            Behavior on scale {
                Anim { duration: Style.motionFast; easing.type: Easing.OutCubic }
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: Icons.iconForWindow(appItem.modelData, "apps")
                iconSize: Style.barIconSmall
                iconColor: appHover.hovered ? Color.primary : Color.foreground
                fill: 0
                grade: 0
            }

            HoverHandler { id: appHover }
            TapHandler {
                onTapped: {
                    if (appItem.modelData && typeof appItem.modelData.activate === "function")
                        appItem.modelData.activate()
                }
            }
        }
    }
}
