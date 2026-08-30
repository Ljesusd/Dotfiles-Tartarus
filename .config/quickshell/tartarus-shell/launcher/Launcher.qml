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

    LauncherController {
        id: controller

        launcherState: root.launcherState
        applications: applications
        themes: themes
        actions: launcherActions

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

        implicitWidth: Style.launcherWidth
        implicitHeight: Style.launcherHeight

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

            function onQueryChanged() {
                controller.resetSelection()
            }

            function onMoveDownRequested() {
                controller.moveDown()
            }

            function onMoveUpRequested() {
                controller.moveUp()
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

            width: launcherWindow.contentOpened
                ? Style.launcherWidth
                : Style.launcherSearchWidth

            height: launcherWindow.contentOpened
                ? Style.launcherHeight
                : 0

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            opacity: launcherWindow.contentOpened
                ? 1
                : 0

            radius: Style.radiusLarge
            color: Color.background

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

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: Style.radiusLarge

                color: launcherContent.color
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
        }
    }
}
