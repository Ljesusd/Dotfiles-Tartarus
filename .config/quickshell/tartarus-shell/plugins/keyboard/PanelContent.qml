import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null
    property var barScreen: null

    readonly property var service: root.plugin.service

    implicitWidth: 260
    implicitHeight: panelColumn.implicitHeight
        + Theme.Style.paddingLarge * 2

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.Style.barPopupGap
        radius: 0
        color: "transparent"
        border.width: 0

        HoverHandler {
            onHoveredChanged: {
                if (root.hoverPanelController) {
                    root.hoverPanelController.setPanelHovered(
                        root.plugin.pluginId,
                        hovered
                    )
                }
            }
        }

        ColumnLayout {
            id: panelColumn

            anchors.fill: parent
            anchors.margins: Theme.Style.paddingLarge
            spacing: Theme.Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                Theme.MaterialIcon {
                    text: "keyboard"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }

                Text {
                    Layout.fillWidth: true
                    text: "Keyboard layout"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontNormal
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.service.keymap !== ""
                    ? root.service.keymap
                    : "Select layout"
                color: Theme.Color.foregroundMuted
                font.pixelSize: Theme.Style.fontSmall
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.Color.surfaceHover
            }

            Repeater {
                model: [
                    { code: "us", label: "English (US)", short: "EN" },
                    { code: "br", label: "Português (Brasil)", short: "PT-BR" }
                ]

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Theme.Style.radiusMedium
                    color: root.service.currentLayoutIndex() === index
                        ? Theme.Color.selection
                        : layoutMouse.containsMouse
                            ? Theme.Color.surfaceHover
                            : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.Style.paddingMedium
                        anchors.rightMargin: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingMedium

                        Theme.MaterialIcon {
                            text: root.service.currentLayoutIndex() === index
                                ? "radio_button_checked"
                                : "radio_button_unchecked"
                            color: root.service.currentLayoutIndex() === index
                                ? Theme.Color.accent
                                : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconSmall
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontSmall
                        }

                        Text {
                            text: modelData.short
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                        }
                    }

                    MouseArea {
                        id: layoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.service.selectLayout(index)
                    }
                }
            }
        }
    }
}
