import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../theme" as Theme
import "../services" as Services
import "../core"
import "components"

PanelWindow {
    id: root

    required property var launcherState
    required property var monitorContext
    required property var shellState
    required property var pluginRegistry
    readonly property Item notificationAnchor: notificationPopupAnchor
    readonly property Item popupAnchorSurface: barSurface
    readonly property var launcherAnchor:
        launcherPopupAnchor

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: 0
        left: 16
        right: 16
    }

    // The transparent layer is taller, while barSurface keeps the original
    // visual height so the widgets do not grow with the reserved area.
    implicitHeight: Theme.Style.barHeight + 16
    exclusiveZone: Theme.Style.barHeight + 16
    focusable: true
    color: "transparent"

    function closeLauncherIfOpen() {
        root.shellState.closeLaunchers()
    }

    HoverPanelController {
        id: hoverPanelController
        pluginRegistry: root.pluginRegistry
    }

    Rectangle {
        id: barSurface

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 10
            bottomMargin: 10
        }
        radius: Theme.Style.radiusFull
        color: Theme.Color.surfaceContainer
        border.width: 0
        border.color: "transparent"

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 0
            color: "transparent"
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closeLauncherIfOpen()
            }
        }

        RowLayout {
            id: barLayout

            anchors {
                top: barSurface.top
                bottom: barSurface.bottom
                left: barSurface.left
                right: barSurface.right
                leftMargin: Theme.Style.barContentHorizontalPadding
                rightMargin: Theme.Style.barContentHorizontalPadding
            }
            spacing: 0

            // Izquierda
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: Theme.Style.barSpacingNormal

                    EntryWrapper {
                        entryId: "workspaces"

                        Loader {
                            id: leftWorkspaceLoader
                            sourceComponent: {
                                const workspacePlugin = root.pluginRegistry.plugin("workspaces")
                                return workspacePlugin ? workspacePlugin.barWidgetComponent : null
                            }
                            onLoaded: if (item && "barScreen" in item) item.barScreen = root.screen

                            Connections {
                                target: leftWorkspaceLoader.item
                                ignoreUnknownSignals: true

                                function onInteracted() {
                                    root.closeLauncherIfOpen()
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: Math.min(190, activeWindow.implicitWidth + Theme.Style.barPaddingSmall * 2)
                        Layout.preferredHeight: Theme.Style.barInnerHeight
                        visible: activeWindow.text !== ""
                        clip: true

                        ActiveWindow {
                            id: activeWindow
                            anchors.centerIn: parent
                            width: parent.width - Theme.Style.barPaddingSmall * 2
                            font.pixelSize: Theme.Style.barFontSmall
                            elide: Text.ElideRight
                            color: Qt.rgba(Theme.Color.foreground.r, Theme.Color.foreground.g, Theme.Color.foreground.b, 0.72)
                        }
                    }
                }
            }

            // Centro
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                DynamicIsland {
                    id: dynamicIsland
                    anchors.centerIn: parent
                    launcherState: root.launcherState
                    monitorContext: root.monitorContext
                    shellState: root.shellState
                    workspaceService: root.pluginRegistry.plugin("workspaces")?.service
                    screen: root.screen
                    onMusicRequested: musicPopup.toggle()
                }

                // Compact local assistant pill. Its popup uses the same
                // connected surface as the launcher and stays beside the island.
                Item {
                    id: rashinChatAnchor
                    x: Math.max(0, dynamicIsland.x + (dynamicIsland.width - width) / 2)
                    y: 0
                    width: 360
                    height: 1
                    opacity: 0
                }

                RashinPill {
                    id: rashinPill
                    anchors.left: dynamicIsland.right
                    anchors.leftMargin: Theme.Style.spacingSmall
                    anchors.verticalCenter: dynamicIsland.verticalCenter
                    anchorItem: rashinChatAnchor
                    barWindow: root
                    monitorContext: root.monitorContext
                }
            }

            // Derecha
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: Theme.Style.barSpacingNormal

                    RowLayout {
                        spacing: Theme.Style.barSpacingNormal

                        EntryWrapper {
                            entryId: "audio"

                            Loader {
                                sourceComponent: root.pluginRegistry.plugin("audio")?.barWidgetComponent || null
                                onLoaded: {
                                    if (item && "hoverPanelController" in item)
                                        item.hoverPanelController = hoverPanelController
                                    if (item && "panelAnchorItem" in item)
                                        item.panelAnchorItem = parent
                                }
                            }
                        }

                        EntryWrapper {
                            entryId: "system-tray"

                            SystemTray {
                                barSurface: barSurface
                                onCloseLauncherRequested: root.closeLauncherIfOpen()
                            }
                        }

                        EntryWrapper {
                            entryId: "calendar"

                            CalendarWidget {
                                anchorSurface: barSurface
                                shellState: root.shellState
                                onCloseLauncherRequested: root.closeLauncherIfOpen()
                            }
                        }

                        Theme.MaterialIcon {
                            id: notificationIcon
                            Layout.preferredWidth: Theme.Style.barControlHeight
                            Layout.preferredHeight: Theme.Style.barControlHeight
                            text: "notifications"
                            iconSize: Theme.Style.barIconNormal
                            iconColor: Theme.Color.foreground

                            Rectangle {
                                id: notificationBadge
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                width: Math.max(16, badgeText.implicitWidth + 6)
                                height: 16
                                radius: Theme.Style.radiusFull
                                color: Theme.Color.primary
                                border.width: 1
                                border.color: Theme.Color.surfaceContainer
                                visible: Services.NotificationService.notifications.count > 0

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: Math.min(Services.NotificationService.notifications.count, 99)
                                        + (Services.NotificationService.notifications.count > 99 ? "+" : "")
                                    color: Theme.Color.onPrimary
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Process {
                                id: notificationProcess
                                command: ["qs", "-c", "tartarus-shell", "ipc", "call", "notification", "toggleCenter"]
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notificationProcess.running = true
                            }
                        }

                        ProfileButton {
                            Layout.preferredWidth: Theme.Style.barControlHeight
                            Layout.preferredHeight: Theme.Style.barControlHeight
                            shellState: root.shellState
                            anchorSurface: barSurface
                            barWindow: root
                        }
                    }
                }
            }
        }

        HoverPanelHost {
            id: hoverPanelHost
            hoverPanelController: hoverPanelController
            anchorSurface: barSurface
            barScreen: root.screen
        }

        Item {
            id: musicAnchor
            x: barSurface.mapFromItem(dynamicIsland, dynamicIsland.width / 2, 0).x - width / 2
            y: 0
            width: 360
            height: 1
        }

        MusicPopup {
            id: musicPopup
            anchorItem: musicAnchor
            barWindow: root
            monitorContext: root.monitorContext
        }

        // Anchor invisible at the roof of the bar. The launcher is positioned
        // from here so its surface can meet the bar without a floating gap.
        Item {
            id: launcherPopupAnchor

            x: Math.max(
                0,
                Math.min(
                    barSurface.width - width,
                    barSurface.mapFromItem(dynamicIsland, 0, 0).x
                        + (dynamicIsland.width - width) / 2
                )
            )
            // Meet the bar at its upper edge. The shared surface removes the
            // seam without covering the controls inside the bar.
            y: 0
            width: Theme.Style.launcherWidth
            height: 1
            opacity: 0
        }

        // Use the same wide invisible anchor as the launcher. Anchoring the
        // notification drawer to the icon itself makes the compositor align
        // the popup by its left edge; this keeps the curved bridge centered on
        // the notification control while still allowing edge adjustment.
        Item {
            id: notificationPopupAnchor

            readonly property real anchorWidth: Math.min(
                440,
                Math.max(300, barSurface.width - Theme.Style.spacingLarge * 2)
            )

            x: Math.max(
                0,
                Math.min(
                    barSurface.width - width,
                    barSurface.mapFromItem(
                        notificationIcon,
                        notificationIcon.width / 2,
                        0
                    ).x - width / 2
                )
            )
            y: 0
            width: anchorWidth
            height: 1
            opacity: 0
        }

        // Ryoku's stash accepts a file at the shell edge and routes it to the
        // installer. Keep the drop target small and explicit: normal bar
        // clicks keep their existing handlers, while a drag gets a clear
        // visual landing zone and opens the installer with the file selected.
        DropArea {
            id: installerDropArea
            anchors.fill: barSurface
            z: 20

            onDropped: drop => {
                if (!drop.urls || drop.urls.length === 0)
                    return

                const droppedUrl = drop.urls[0]
                root.shellState.openLauncher(root.monitorContext)
                Qt.callLater(() => {
                    root.launcherState.query = ">install"
                    Services.InstallerService.inspect(droppedUrl)
                    root.launcherState.focusSearch()
                })
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(360, parent.width - Theme.Style.paddingLarge * 2)
                height: 44
                radius: Theme.Style.radiusFull
                visible: installerDropArea.containsDrag
                color: Theme.Color.primaryContainer
                border.width: 1
                border.color: Theme.Color.primary
                Text {
                    anchors.centerIn: parent
                    text: "Suelta aquí para instalar"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                    font.bold: true
                }
            }
        }

    }
}
