import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null

    readonly property var service:
        root.plugin.service

    implicitWidth: 340
    implicitHeight: panelContent.implicitHeight

    Rectangle {
        id: panelContent

        anchors.fill: parent

        implicitHeight:
            contentColumn.implicitHeight
            + Style.paddingLarge * 2

        radius: Style.radiusLarge
        color: Color.background

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

        Column {
            id: contentColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.paddingLarge
            }

            spacing: Style.spacingMedium

            RowLayout {
                width: parent.width

                Text {
                    text: "Brightness"

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.service.brightnessPercent + "%"

                    font.pixelSize: Style.fontNormal
                    color: root.service.available
                        ? Color.foreground
                        : Color.foregroundMuted
                }
            }

            Text {
                width: parent.width

                text:
                    root.service.currentDisplay
                    ? root.service.currentDisplay.name
                    : "No display"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
                elide: Text.ElideRight
            }

            Text {
                text: "Displays"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Repeater {
                model: root.service.displays

                delegate: Rectangle {
                    id: displayItem

                    required property var modelData

                    readonly property bool selected:
                        root.service.currentDisplay
                        && root.service.currentDisplay.bus
                            === modelData.bus

                    width: contentColumn.width
                    height: 52

                    radius: Style.radiusMedium
                    color: displayHover.hovered
                        ? Color.surfaceHover
                        : displayItem.selected
                            ? Color.selection
                            : Color.surface

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Style.paddingMedium
                            rightMargin: Style.paddingMedium
                        }

                        spacing: Style.spacingMedium

                        Text {
                            text: displayItem.selected
                                ? "●"
                                : "○"

                            font.pixelSize: Style.fontSmall
                            color: displayItem.selected
                                ? Color.accent
                                : Color.foregroundMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing: 2

                            Text {
                                Layout.fillWidth: true

                                text: displayItem.modelData.name

                                font.pixelSize: Style.fontSmall
                                color: Color.foreground

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true

                                text: "I²C bus " + displayItem.modelData.bus

                                font.pixelSize: Style.fontSmall
                                color: Color.foregroundMuted

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    HoverHandler {
                        id: displayHover
                    }

                    TapHandler {
                        onTapped: {
                            root.service.selectDisplay(
                                displayItem.modelData.bus
                            )
                        }
                    }
                }
            }

            Text {
                text: "Brightness"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Slider {
                id: brightnessSlider

                width: contentColumn.width

                from: 0
                to: root.service.maxBrightness
                value: root.service.brightness

                enabled: root.service.available

                onMoved: {
                    root.service.setBrightness(
                        value,
                        root.service.sliderCommitDelay
                    )
                }
            }

            Text {
                width: parent.width

                text: root.service.brightnessPercent + "%"

                font.pixelSize: Style.fontSmall
                color: root.service.available
                    ? Color.foreground
                    : Color.foregroundMuted

                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
