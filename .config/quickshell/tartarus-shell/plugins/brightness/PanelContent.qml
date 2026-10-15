import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../theme" as Theme

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null
    property var barScreen: null

    readonly property var service:
        root.plugin.service

    readonly property var panelDisplay:
        root.service.displayForScreen(
            root.barScreen
        )

    readonly property bool brightnessAvailable:
        root.service.availableForScreen(
            root.barScreen
        )

    readonly property int brightnessValue:
        root.service.brightnessForScreen(
            root.barScreen
        )

    readonly property int brightnessPercent:
        root.service.brightnessPercentForScreen(
            root.barScreen
        )

    implicitWidth: 340
    implicitHeight:
        contentColumn.implicitHeight
        + Theme.Style.paddingLarge * 2

    Rectangle {
        id: panelContent

        anchors.fill: parent
        anchors.margins: Theme.Style.barPopupGap

        implicitHeight:
            contentColumn.implicitHeight
            + Theme.Style.paddingLarge * 2

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

        Column {
            id: contentColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.Style.paddingLarge
            }

            spacing: Theme.Style.spacingMedium

            RowLayout {
                width: parent.width

                Theme.MaterialIcon {
                    text: "brightness_6"
                    font.pixelSize: Theme.Style.materialIconMedium
                    color: root.brightnessAvailable
                        ? Theme.Color.accent
                        : Theme.Color.foregroundMuted
                }

                Text {
                    text: "Brightness"

                    font.pixelSize: Theme.Style.fontNormal
                    color: Theme.Color.foreground
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.brightnessPercent + "%"

                    font.pixelSize: Theme.Style.fontNormal
                    color: root.brightnessAvailable
                        ? Theme.Color.foreground
                        : Theme.Color.foregroundMuted
                }
            }

            Text {
                width: parent.width

                text:
                    root.panelDisplay
                    ? root.panelDisplay.name
                    : "No display"

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
                elide: Text.ElideRight
            }

            Text {
                text: "Monitores"

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
            }

            Repeater {
                model: root.service.displays

                delegate: Rectangle {
                    id: displayItem

                    required property var modelData

                    readonly property bool selected:
                        root.panelDisplay
                        && root.panelDisplay.bus
                            === modelData.bus

                    width: contentColumn.width
                    height: 52

                    radius: Theme.Style.radiusMedium
                    color: displayHover.hovered
                        ? Theme.Color.surfaceHover
                        : displayItem.selected
                            ? Theme.Color.selection
                            : Theme.Color.surface

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Theme.Style.paddingMedium
                            rightMargin: Theme.Style.paddingMedium
                        }

                        spacing: Theme.Style.spacingMedium

                        Theme.MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            text: "monitor"
                            font.pixelSize: Theme.Style.materialIconMedium
                            color: displayItem.selected
                                ? Theme.Color.accent
                                : Theme.Color.foregroundMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing: 2

                            Text {
                                Layout.fillWidth: true

                                text: displayItem.modelData.name

                                font.pixelSize: Theme.Style.fontSmall
                                color: Theme.Color.foreground

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true

                                text: "Bus " + displayItem.modelData.bus

                                font.pixelSize: Theme.Style.fontSmall
                                color: Theme.Color.foregroundMuted

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }

                    HoverHandler {
                        id: displayHover
                    }

                }
            }

            Text {
                text: "Brightness"

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
            }

            Slider {
                id: brightnessSlider

                width: contentColumn.width

                implicitHeight: Theme.Style.barControlHeight

                from: 0
                to: root.panelDisplay?.maxBrightness ?? 100
                value: root.brightnessValue

                enabled: root.brightnessAvailable

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding
                        + (brightnessSlider.availableHeight - height) / 2
                    width: brightnessSlider.availableWidth
                    implicitHeight: 6
                    radius: 3
                    color: Theme.Color.surfaceContainerHigh

                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: Theme.Color.accent
                    }
                }

                handle: Rectangle {
                    x: brightnessSlider.leftPadding
                        + brightnessSlider.visualPosition
                            * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding
                        + brightnessSlider.availableHeight / 2 - height / 2
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: 9
                    color: brightnessSlider.pressed
                        ? Theme.Color.foreground
                        : Theme.Color.accent
                    border.color: Theme.Color.background
                    border.width: 2
                }

                onMoved: {
                    root.service.setBrightnessForScreen(
                        root.barScreen,
                        value,
                        root.service.sliderCommitDelay
                    )
                }
            }

            Text {
                width: parent.width

                text: root.brightnessPercent + "%"

                font.pixelSize: Theme.Style.fontSmall
                color: root.brightnessAvailable
                    ? Theme.Color.foreground
                    : Theme.Color.foregroundMuted
            }
        }
    }
}
