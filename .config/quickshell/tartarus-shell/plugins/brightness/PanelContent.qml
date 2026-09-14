import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../theme"

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
        + Style.paddingLarge * 2

    Rectangle {
        id: panelContent

        anchors.fill: parent
        anchors.margins: Style.barPopupGap

        implicitHeight:
            contentColumn.implicitHeight
            + Style.paddingLarge * 2

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

                MaterialIcon {
                    text: "brightness_6"
                    font.pixelSize: Style.materialIconMedium
                    color: root.brightnessAvailable
                        ? Color.accent
                        : Color.foregroundMuted
                }

                Text {
                    text: "Brightness"

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: root.brightnessPercent + "%"

                    font.pixelSize: Style.fontNormal
                    color: root.brightnessAvailable
                        ? Color.foreground
                        : Color.foregroundMuted
                }
            }

            Text {
                width: parent.width

                text:
                    root.panelDisplay
                    ? root.panelDisplay.name
                    : "No display"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
                elide: Text.ElideRight
            }

            Text {
                text: "Monitores"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
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

                        MaterialIcon {
                            Layout.alignment: Qt.AlignVCenter
                            text: "monitor"
                            font.pixelSize: Style.materialIconMedium
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

                                text: "Bus " + displayItem.modelData.bus

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

                implicitHeight: Style.barControlHeight

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
                    color: Color.surfaceContainerHigh

                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: Color.accent
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
                        ? Color.foreground
                        : Color.accent
                    border.color: Color.background
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

                font.pixelSize: Style.fontSmall
                color: root.brightnessAvailable
                    ? Color.foreground
                    : Color.foregroundMuted
            }
        }
    }
}
