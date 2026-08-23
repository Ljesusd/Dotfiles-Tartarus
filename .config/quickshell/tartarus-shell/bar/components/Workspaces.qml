pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../../theme"

RowLayout {
    id: root

    property var launcherState

    spacing: Style.barWorkspaceGap

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: workspaceItem

            required property var modelData

            implicitWidth: Style.barWorkspaceSize
            implicitHeight: Style.barWorkspaceSize

            radius: Style.radiusSmall

            color: modelData.focused
                ? Color.selection
                : mouseArea.containsMouse
                    ? Color.surfaceHover
                    : "transparent"

            Text {
                id: workspaceText

                anchors.centerIn: parent

                font.pixelSize: Style.barFontSmall

                text: workspaceItem.modelData.name
                color: Color.foreground
            }

            MouseArea {
                id: mouseArea

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (
                        root.launcherState
                        && root.launcherState.opened
                    ) {
                        root.launcherState.close()
                    }

                    workspaceItem.modelData.activate()
                }
            }
        }
    }
}
