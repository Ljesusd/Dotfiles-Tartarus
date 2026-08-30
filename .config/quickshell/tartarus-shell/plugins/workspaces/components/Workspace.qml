pragma ComponentBehavior: Bound

import QtQuick

import "../../../theme"
import "../../../utils"

Rectangle {
    id: root

    required property int workspaceId
    required property var barScreen
    required property var service
    required property int maxWindowIcons
    required property int activeWorkspaceId
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
        Style.barWorkspaceBaseSize

    readonly property bool hasWindows:
        windowCount > 0
    readonly property color contentColor:
        Color.onSurfaceVariant
    readonly property real contentOpacity:
        root.active
        ? 1.0
        : root.occupied
            ? 0.85
            : 0.35

    implicitWidth: Math.max(
        root.baseSize,
        content.implicitWidth + Style.spacingSm
    )
    implicitHeight: root.baseSize

    radius: Style.radiusSmall

    color:
            root.interactive
            && !root.active
            && mouseArea.containsMouse
            ? Color.surfaceHover
            : "transparent"

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Style.barWorkspaceContentSpacing

        Item {
            width: Style.barWorkspaceIconSize
            height: Style.barWorkspaceIconSize

            Text {
                anchors.centerIn: parent

                text: root.workspaceId

                font.pixelSize: Style.barFontSmall
                color: root.contentColor
                opacity: root.contentOpacity

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Row {
            id: windowIcons

            spacing: Style.barWorkspaceContentSpacing
            visible: root.hasWindows

            Repeater {
                model: root.windowCount

                Item {
                    required property int index

                    width: Style.barWorkspaceIconSize
                    height: Style.barWorkspaceIconSize

                    MaterialIcon {
                        anchors.centerIn: parent

                        text: Icons.iconForWindow(
                            root.windows[index],
                            "apps"
                        )

                        iconSize: Style.barWorkspaceIconSize
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
                root.service.toggleSpecialWorkspaceForScreen(
                    root.barScreen,
                    "special"
                )
                return
            }

            root.service.activateWorkspaceForScreen(
                root.barScreen,
                root.workspaceId
            )
        }
    }
}
