pragma ComponentBehavior: Bound

import QtQuick

import "../../../theme" as Theme
import "../../../utils"

Rectangle {
    id: root

    required property int workspaceId
    required property var barScreen
    required property var service
    required property int maxWindowIcons
    required property int activeWorkspaceId
    property bool showUnoccupied: false
    property bool showWindowIcons: true
    property bool interactive: true
    property bool usePrimaryContentColor: false

    signal interacted()

    readonly property bool active:
        workspaceId === root.activeWorkspaceId

    readonly property bool occupied:
        root.service.isOccupied(workspaceId)

    readonly property var windows:
        root.service.windowsForWorkspace(workspaceId)

    readonly property int windowCount:
        Math.min(
            windows.length,
            root.maxWindowIcons
        )

    readonly property int baseSize:
        Theme.Style.barWorkspaceBaseSize

    readonly property bool hasWindows:
        root.showWindowIcons && windowCount > 0
    readonly property bool shouldShow:
        root.showUnoccupied || root.active || root.occupied
    // Caelestia's compact shape language: active is represented by the
    // moving pill, occupied workspaces by a rounded square and empty ones by
    // a small dot.
    readonly property color contentColor:
        root.active ? Theme.Color.onPrimary : Theme.Color.foregroundMuted
    readonly property real contentOpacity:
        root.active || root.occupied ? 1.0 : 0.42

    implicitWidth: root.shouldShow ? Math.max(
        root.baseSize,
        content.implicitWidth + Theme.Style.spacingSm
    ) : 0
    implicitHeight: root.baseSize
    opacity: root.shouldShow ? 1 : 0

    radius: Theme.Style.radiusFull

    color:
            root.interactive
            && !root.active
            && mouseArea.containsMouse
            ? Theme.Color.surfaceHover
            : "transparent"

    Behavior on color {
        Theme.ColorAnim { }
    }
    Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
    Behavior on implicitWidth { Theme.Anim { duration: Theme.Style.motionNormal } }
    Behavior on scale { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutBack } }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.Style.barWorkspaceContentSpacing

        Item {
            width: Theme.Style.barWorkspaceIconSize
            height: Theme.Style.barWorkspaceIconSize

            Text {
                anchors.centerIn: parent
                text: root.workspaceId
                color: root.contentColor
                opacity: root.contentOpacity
                font.pixelSize: Theme.Style.barFontSmall
                font.bold: root.active
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Row {
            id: windowIcons

            spacing: Theme.Style.barWorkspaceContentSpacing
            visible: root.hasWindows

            Repeater {
                model: root.windowCount

                Item {
                    required property int index

                    width: Theme.Style.barWorkspaceIconSize
                    height: Theme.Style.barWorkspaceIconSize

                    Theme.MaterialIcon {
                        anchors.centerIn: parent
                        text: Icons.iconForWindow(
                            root.windows[index],
                            "apps"
                        )
                        iconSize: Theme.Style.barWorkspaceIconSize
                        iconColor: root.contentColor
                        opacity: root.contentOpacity
                        fill: 0
                        grade: 0
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent

        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor

        onClicked: {
            root.interacted()

            if (root.active) {
                root.service.activateWorkspaceForScreen(
                    root.barScreen,
                    root.workspaceId
                )
                root.service.toggleLastSpecialWorkspaceForScreen(root.barScreen)
                return
            }

            root.service.activateWorkspaceForScreen(
                root.barScreen,
                root.workspaceId
            )
        }
    }
}
