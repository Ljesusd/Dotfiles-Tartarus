import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../theme"

RowLayout {
    id: root

    property var launcherState

    spacing: Style.barSpacingSmall

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: trayItem

            required property var modelData

            implicitWidth: Style.barControlHeight
            implicitHeight: Style.barControlHeight

            radius: Style.radiusSmall

            color: mouseArea.containsMouse
                ? Color.surfaceHover
                : "transparent"

            Image {
                anchors.centerIn: parent

                width: Style.barIconSmall
                height: Style.barIconSmall

                source: trayItem.modelData.icon
                fillMode: Image.PreserveAspectFit
            }

            QsMenuAnchor {
                id: menuAnchor

                anchor.item: trayItem
                menu: trayItem.modelData.menu
            }

            MouseArea {
                id: mouseArea

                anchors.fill: parent

                acceptedButtons:
                    Qt.LeftButton
                    | Qt.RightButton
                    | Qt.MiddleButton

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                ToolTip.visible: containsMouse
                ToolTip.delay: 500

                ToolTip.text: {
                    const title =
                        trayItem.modelData.tooltipTitle
                        || trayItem.modelData.title

                    const description =
                        trayItem.modelData.tooltipDescription

                    if (description)
                        return title + "\n" + description

                    return title
                }

                onClicked: mouse => {
                    if (
                        root.launcherState
                        && root.launcherState.opened
                    ) {
                        root.launcherState.close()
                    }

                    if (mouse.button === Qt.RightButton) {
                        if (trayItem.modelData.hasMenu)
                            menuAnchor.open()

                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate()

                    } else if (mouse.button === Qt.LeftButton) {
                        if (trayItem.modelData.onlyMenu) {
                            if (trayItem.modelData.hasMenu)
                                menuAnchor.open()
                        } else {
                            trayItem.modelData.activate()
                        }
                    }
                }

                onWheel: event => {
                    if (event.angleDelta.y !== 0) {
                        trayItem.modelData.scroll(
                            event.angleDelta.y,
                            false
                        )
                    }

                    if (event.angleDelta.x !== 0) {
                        trayItem.modelData.scroll(
                            event.angleDelta.x,
                            true
                        )
                    }
                }
            }
        }
    }
}
