pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../services" as Services
import "../theme"
import "../bar/components"
import "components"
import "pages"

Scope {
    id: root

    required property var launcherState
    required property var monitorContext
    required property var shellState
    required property var launcherAnchor
    required property var barWindow
    required property var sharedApplications
    required property var sharedLauncherActions
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
        : Math.min(controller.mode === LauncherController.Mode.Weather || controller.mode === LauncherController.Mode.Installer ? 680 : Style.launcherWidth,
            Math.max(320, (root.barWindow.screen?.width ?? 1280) - 64))
    readonly property int panelHeight: Math.min(
        controller.mode === LauncherController.Mode.Weather ? 660
            : controller.mode === LauncherController.Mode.Installer ? 430
            : controller.mode === LauncherController.Mode.Wallpaper ? 236 : Style.launcherHeight,
        Math.max(180, (root.barWindow.screen?.height ?? 800) - Style.barHeight - Style.paddingLarge * 2)
    ) + Style.barPopupGap * 2

        LauncherController {
            id: controller

            launcherState: root.launcherState
            applications: root.sharedApplications
            themes: Services.Themes
            actions: root.sharedLauncherActions
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

        // La barra vive en el borde inferior: el launcher se despliega hacia arriba.
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top

        // Reserve a stable envelope for every launcher page. Animating a native
        // Wayland popup's size also makes the compositor reposition it per frame.
        // Only the surface inside this transparent window changes geometry.
        implicitWidth: Math.min(Math.max(Style.launcherWidth, 680, 5 * 272 + 176)
                + launcherSurface.horizontalInset * 2,
            Math.max(1, (root.barWindow.screen?.width ?? 1280) - Style.paddingLarge * 2))
        implicitHeight: Math.min(Math.max(Style.launcherHeight, 660)
                + Style.barPopupGap * 2 + launcherSurface.shadowPadding,
            Math.max(1, (root.barWindow.screen?.height ?? 800) - Style.barHeight - Style.paddingLarge))
        anchor.adjustment: PopupAdjustment.Slide

        // Transparent space must not intercept clicks destined for applications.
        mask: Region { item: launcherSurface.maskItem }

        color: "transparent"

        visible: false
        grabFocus: false

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
            launcherWindow.visible = true
            launcherWindow.contentOpened = false

            Qt.callLater(() => {
                if (!root.monitorContext.launcherOpened) return
                launcherWindow.contentOpened = true

                controller.resetSelection()
                root.launcherState.focusSearch()
            })
        }

        function closeLauncher() {
            launcherWindow.contentOpened = false
            if (launcherSurface.reveal === 0) launcherWindow.visible = false
        }

        LauncherSurface {
            id: launcherSurface
            anchors.fill: parent
            contentWidth: Math.max(0, Math.min(root.panelWidth, width - horizontalInset * 2))
            contentHeight: Math.max(0, Math.min(root.panelHeight, height - shadowPadding))
            opened: launcherWindow.contentOpened
            onClosed: launcherWindow.visible = false
        }

        Item {
            id: launcherContent
            parent: launcherSurface.contentItem
            anchors.fill: parent
            clip: true
            enabled: root.monitorContext.launcherOpened

            AppsPage {
                anchors.fill: parent

                applications: root.sharedApplications
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Applications
            }

            ActionsPage {
                anchors.fill: parent

                actions: root.sharedLauncherActions
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Actions
            }

            SchemesPage {
                anchors.fill: parent

                themes: Services.Themes
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

            CalculatorPage {
                anchors.fill: parent
                controller: controller
                active:
                    controller.mode
                    === LauncherController.Mode.Calculator
            }

            WeatherPage {
                anchors.fill: parent
                active: root.monitorContext.launcherOpened && controller.mode === LauncherController.Mode.Weather
            }

            InstallerPage {
                anchors.fill: parent
                controller: controller
                active: root.monitorContext.launcherOpened && controller.mode === LauncherController.Mode.Installer
            }
        }
    }
}
