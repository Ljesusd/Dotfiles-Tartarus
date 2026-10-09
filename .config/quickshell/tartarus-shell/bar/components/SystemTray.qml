import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    signal closeLauncherRequested()
    required property Item barSurface

    function materialFallback(iconName) {
        const name = String(iconName || "").split("/").pop().replace(/\.(svg|png)$/i, "")
        return ({
            "user-bookmarks-symbolic": "bookmarks",
            "audio-input-microphone-symbolic": "mic",
            "audio-speakers-symbolic": "speaker",
            "input-keyboard-symbolic": "keyboard",
            "help-contents-symbolic": "help",
            "application-exit-symbolic": "exit_to_app"
        })[name] || ""
    }

    implicitWidth: trayLayout.implicitWidth
    implicitHeight: Style.barControlHeight

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: "transparent"
        border.width: 0
    }

    RowLayout {
        id: trayLayout

        anchors.fill: parent
        anchors.leftMargin: Style.barPaddingSmall
        anchors.rightMargin: Style.barPaddingSmall
        spacing: Style.barSpacingSmall

        Repeater {
            model: SystemTray.items

        Rectangle {
            id: trayItem

            required property var modelData

            implicitWidth: Style.barControlHeight
            implicitHeight: Style.barControlHeight

            radius: Style.radiusFull

            color: "transparent"
            border.width: 0

            IconImage {
                anchors.centerIn: parent
                implicitSize: Style.barIconSmall
                visible: root.materialFallback(trayItem.modelData.icon) === ""
                source: root.materialFallback(trayItem.modelData.icon) === ""
                    ? trayItem.modelData.icon
                    : ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                iconSize: Style.barIconSmall
                text: root.materialFallback(trayItem.modelData.icon)
                visible: text !== ""
                iconColor: Color.foreground
            }

            TrayMenu {
                id: menuAnchor

                trayItem: trayItem.modelData
                anchorItem: trayItem
                anchorSurface: root.barSurface
            }

            Timer {
                id: menuHoverDelay
                interval: Style.trayHoverDelay
                repeat: false
                onTriggered: {
                    if (mouseArea.containsMouse && trayItem.modelData.hasMenu)
                        menuAnchor.popupOpen = true
                }
            }

            Timer {
                id: menuCloseDelay
                interval: Style.trayHoverDelay
                repeat: false
                onTriggered: {
                    if (!mouseArea.containsMouse && !menuAnchor.menuHovered)
                        menuAnchor.close()
                }
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
                    root.closeLauncherRequested()

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

                onEntered: {
                    menuCloseDelay.stop()
                    menuHoverDelay.restart()
                }

                onExited: {
                    menuHoverDelay.stop()
                    menuCloseDelay.restart()
                }
            }
        }
        }
    }

}
