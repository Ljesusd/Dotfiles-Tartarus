import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme
import "../../services" as Services
import "../../launcher/components" as LauncherComponents

PopupWindow {
    id: root

    required property Item anchorItem
    required property Item anchorSurface
    required property var barWindow
    required property var shellState

    property bool popupOpen: false

    readonly property var entries: [
        { key: "settings", icon: "settings", title: "Configuración", subtitle: "Centro de control" },
        { key: "reboot", icon: "restart_alt", title: "Reiniciar", subtitle: "Reiniciar el equipo" },
        { key: "suspend", icon: "bedtime", title: "Suspender", subtitle: "Suspender la sesión" },
        { key: "shutdown", icon: "power_settings_new", title: "Apagar", subtitle: "Apagar el equipo" },
        { key: "logout", icon: "logout", title: "Cerrar sesión", subtitle: "Salir de la sesión actual" }
    ]

    readonly property real menuWidth: Math.min(
        320,
        Math.max(250, (root.barWindow?.screen?.width ?? 1280) * 0.22)
    )
    readonly property real menuHeight: Math.min(
        390,
        menuColumn.implicitHeight + Theme.Style.paddingMedium * 2
    )

    function open() {
        root.popupOpen = true
    }

    function close() {
        root.popupOpen = false
    }

    function trigger(key) {
        root.close()

        switch (key) {
        case "settings":
            root.shellState.toggleControlCenter()
            break
        case "reboot":
            Services.PowerService.reboot()
            break
        case "suspend":
            Services.PowerService.suspend()
            break
        case "shutdown":
            Services.PowerService.shutdown()
            break
        case "logout":
            Services.PowerService.logout()
            break
        }
    }

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: Math.min(
        root.menuWidth + surface.horizontalInset * 2,
        Math.max(1, root.barWindow?.screen?.width ?? 1280)
    )
    implicitHeight: 390 + surface.shadowPadding
    color: "transparent"
    visible: root.popupOpen || surface.reveal > 0
    mask: Region { item: surface.maskItem }

    HyprlandFocusGrab {
        windows: [root.barWindow, root]
        active: root.popupOpen

        onCleared: root.close()
    }

    LauncherComponents.LauncherSurface {
        id: surface
        anchors.fill: parent
        opened: root.popupOpen
        contentWidth: root.menuWidth
        contentHeight: root.menuHeight

        Item {
            id: content
            parent: surface.contentItem
            anchors.fill: parent
            anchors.leftMargin: Theme.Style.paddingMedium
            anchors.rightMargin: Theme.Style.paddingMedium
            anchors.topMargin: Theme.Style.paddingSmall
            anchors.bottomMargin: Theme.Style.paddingMedium
            clip: true

            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                spacing: Theme.Style.spacingXs

                Repeater {
                    model: root.entries

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: Theme.Style.controlRadius
                        color: itemHover.hovered
                            ? Theme.Color.surfaceHover
                            : "transparent"

                        HoverHandler { id: itemHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.Style.paddingSmall
                            anchors.rightMargin: Theme.Style.paddingSmall
                            spacing: Theme.Style.spacingMedium

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: Theme.Style.radiusFull
                                color: Theme.Color.primaryContainer

                                Theme.MaterialIcon {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    iconSize: Theme.Style.materialIconSmall
                                    iconColor: Theme.Color.onPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: Theme.Color.foreground
                                    font.pixelSize: Theme.Style.fontSmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.subtitle
                                    color: Theme.Color.foregroundMuted
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Theme.MaterialIcon {
                                text: "chevron_right"
                                iconSize: Theme.Style.materialIconSmall
                                iconColor: Theme.Color.foregroundMuted
                            }
                        }

                        TapHandler {
                            onTapped: root.trigger(modelData.key)
                        }
                    }
                }
            }
        }
    }
}
