pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../theme"
import "components"
import "pages"

Scope {
    id: root

    required property var launcherState
    required property var monitorContext
    required property var shellState
    required property var launcherAnchor
    required property var barWindow
    readonly property var wallpapers: Wallpapers

    readonly property int wallpaperSlots: {
        const available = (root.barWindow.screen?.width ?? 1280) - 64 - 176
        const count = wallpapers.filtered(controller.wallpaperQuery).length
        let slots = Math.min(5, Math.max(1, Math.floor(available / 272)), count)
        if (slots > 1 && slots % 2 === 0)
            slots--
        return Math.max(1, slots)
    }
    readonly property int panelWidth: controller.mode === LauncherController.Mode.Wallpaper
        ? Math.min(root.wallpaperSlots * 272 + 176,
            (root.barWindow.screen?.width ?? 1280) - 64)
        : Style.launcherWidth

        LauncherController {
            id: controller

            launcherState: root.launcherState
            applications: applications
            themes: themes
            actions: launcherActions
            wallpapers: root.wallpapers
            monitorName: root.monitorContext.name
            dockerPage: dockerPage

        onCloseRequested: {
            root.shellState.closeLauncher(
                root.monitorContext
            )
        }
    }

    HyprlandFocusGrab {
        id: launcherFocusGrab

        windows: [
            root.barWindow,
            launcherWindow
        ]

        active: root.monitorContext.launcherOpened

        onCleared: {
            if (root.shellState.launcherFocusCloseSuppressed)
                return

            if (launcherWindow.outsideClickArmed)
                root.shellState.closeLauncher(
                    root.monitorContext
                )
        }
    }

    PopupWindow {
        id: launcherWindow

        property bool contentOpened: false
        property bool outsideClickArmed: false

        anchor.item:
            root.launcherAnchor

        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth: root.panelWidth
        implicitHeight: controller.mode
            === LauncherController.Mode.Wallpaper
                ? 236
                : Style.launcherHeight

        color: "transparent"

        visible: false
        grabFocus: false

        Applications {
            id: applications

            query: controller.applicationQuery
        }

            Themes {
                id: themes
            }

            LauncherActions {
                id: launcherActions
            }

        Timer {
            id: closeTimer

            interval: Style.animationNormal
            repeat: false

            onTriggered: {
                launcherWindow.visible = false
            }
        }

        Timer {
            id: outsideClickArmTimer

            interval: 120
            repeat: false

            onTriggered: {
                launcherWindow.outsideClickArmed = true
            }
        }

        Connections {
            target: root.launcherState
            enabled: root.monitorContext.launcherOpened

            function onQueryChanged() {
                controller.resetSelection()
            }

            function onMoveDownRequested() {
                controller.moveDown()
            }

            function onMoveUpRequested() {
                controller.moveUp()
            }

            function onMoveLeftRequested() {
                controller.moveLeft()
            }

            function onMoveRightRequested() {
                controller.moveRight()
            }

            function onAcceptRequested() {
                controller.accept()
            }

            function onEscapeRequested() {
                if (!root.monitorContext.launcherOpened)
                    return

                controller.goBack()
            }
        }

        Connections {
            target: root.monitorContext

            function onLauncherOpenedChanged() {
                if (root.monitorContext.launcherOpened) {
                    launcherWindow.outsideClickArmed = false
                    outsideClickArmTimer.restart()
                    launcherWindow.openLauncher()
                } else {
                    outsideClickArmTimer.stop()
                    launcherWindow.outsideClickArmed = false
                    launcherWindow.closeLauncher()
                }
            }
        }

        function openLauncher() {
            closeTimer.stop()

            launcherWindow.visible = true
            launcherWindow.contentOpened = false

            Qt.callLater(() => {
                launcherWindow.contentOpened = true

                controller.resetSelection()
                root.launcherState.focusSearch()
            })
        }

        function closeLauncher() {
            launcherWindow.contentOpened = false
            closeTimer.restart()
        }

        Rectangle {
            id: launcherContent

            clip: true
            enabled: root.monitorContext.launcherOpened

            width: launcherWindow.contentOpened
                ? root.panelWidth - Style.barPopupGap * 2
                : Style.launcherSearchWidth - Style.barPopupGap * 2

            height: launcherWindow.contentOpened
                ? controller.mode
                    === LauncherController.Mode.Wallpaper
                        ? 236
                        : Style.launcherHeight
                : 0

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: Style.barPopupGap
            }

            opacity: launcherWindow.contentOpened
                ? 1
                : 0

            radius: Style.radiusLarge
            color: Color.backgroundAlt
            border.width: Style.panelBorderWidth
            border.color: Color.outline

            Behavior on width {
                NumberAnimation {
                    duration: Style.animationNormal
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Style.animationNormal
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animationFast
                }
            }

            AppsPage {
                anchors.fill: parent

                applications: applications
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Applications
            }

            ActionsPage {
                anchors.fill: parent

                actions: launcherActions
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Actions
            }

            SchemesPage {
                anchors.fill: parent

                themes: themes
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Schemes
            }

            WallpapersPage {
                anchors.fill: parent
                visibleSlots: root.wallpaperSlots
                monitorName: root.monitorContext.name

                wallpapers: root.wallpapers
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Wallpaper
            }

            DockerPage {
                id: dockerPage
                anchors.fill: parent
                controller: controller
                consumerKey: root.monitorContext.name
                active: root.monitorContext.launcherOpened
                    && controller.mode === LauncherController.Mode.Docker
            }
        }
    }
}
