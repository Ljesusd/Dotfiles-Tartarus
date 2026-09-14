import QtQuick
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null
    property var barScreen: null

    readonly property var service: root.plugin.service

    implicitWidth: 260
    implicitHeight: panelColumn.implicitHeight
        + Style.paddingLarge * 2

    Rectangle {
        anchors.fill: parent
        anchors.margins: Style.barPopupGap
        radius: Style.radiusLarge
        color: Color.surfaceContainer
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant

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
            anchors.margins: Style.paddingLarge
            spacing: Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                MaterialIcon {
                    text: "keyboard"
                    color: Color.foreground
                    font.pixelSize: Style.materialIconMedium
                }

                Text {
                    Layout.fillWidth: true
                    text: "Keyboard layout"
                    color: Color.foreground
                    font.pixelSize: Style.fontNormal
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.service.keymap !== ""
                    ? root.service.keymap
                    : "Select layout"
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.surfaceHover
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
                    radius: Style.radiusMedium
                    color: root.service.currentLayoutIndex() === index
                        ? Color.selection
                        : layoutMouse.containsMouse
                            ? Color.surfaceHover
                            : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.paddingMedium
                        anchors.rightMargin: Style.paddingMedium
                        spacing: Style.spacingMedium

                        MaterialIcon {
                            text: root.service.currentLayoutIndex() === index
                                ? "radio_button_checked"
                                : "radio_button_unchecked"
                            color: root.service.currentLayoutIndex() === index
                                ? Color.accent
                                : Color.foregroundMuted
                            font.pixelSize: Style.materialIconSmall
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Color.foreground
                            font.pixelSize: Style.fontSmall
                        }

                        Text {
                            text: modelData.short
                            color: Color.foregroundMuted
                            font.pixelSize: Style.fontSmall
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
