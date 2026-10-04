import QtQuick
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null

    readonly property var service:
        root.plugin.service

    implicitWidth: 360
    implicitHeight:
        contentColumn.implicitHeight
        + Style.paddingLarge * 2

    Rectangle {
        anchors.fill: parent
        anchors.margins: Style.barPopupGap

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
            id: contentColumn

            anchors {
                fill: parent
                margins: Style.paddingLarge
            }

            spacing: Style.spacingMedium

            Text {
                Layout.fillWidth: true

                text: "Audio"

                font.pixelSize: Style.fontNormal
                color: Color.foreground
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Style.spacingSmall

                Text {
                    Layout.fillWidth: true

                    text: "Output"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Text {
                    Layout.fillWidth: true

                    text: root.service.outputName

                    font.pixelSize: Style.fontNormal
                    color: root.service.available
                        ? Color.foreground
                        : Color.foregroundMuted

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Style.spacingSmall

                Text {
                    text: "Output"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Repeater {
                    model: root.service.outputsModel

                    delegate: Item {
                        id: outputRow

                        required property var modelData

                        readonly property bool selected:
                            modelData === root.service.currentOutput

                        readonly property string outputName:
                            root.service.outputDisplayName(modelData)

                        readonly property string outputIcon: {
                            if (/headphone|headset|earbud|head[- ]?phones|starship|matisse/i.test(
                                outputRow.outputName
                            )) {
                                return "headphones"
                            }

                            if (/hdmi|displayport|\bDP\b|navi|monitor|amd|intel|nvidia/i.test(
                                outputRow.outputName
                            )) {
                                return "speaker"
                            }

                            return "speaker"
                        }

                        Layout.fillWidth: true

                        width: parent ? parent.width : 0
                        implicitHeight: Style.barControlHeight

                        MaterialIcon {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: outputRow.outputIcon
                            font.pixelSize: Style.materialIconMedium
                            color: outputRow.selected
                                ? Color.accent
                                : Color.foregroundMuted
                        }

                        Text {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            leftPadding: 28
                            text: root.service.outputDisplayName(
                                outputRow.modelData
                            )

                            font.pixelSize: Style.fontNormal
                            color: outputRow.selected
                                ? Color.foreground
                                : Color.foregroundMuted

                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        MouseArea {
                            anchors.fill: parent

                            cursorShape: Qt.PointingHandCursor
                            enabled: !outputRow.selected

                            onClicked: {
                                root.service.selectOutput(
                                    outputRow.modelData
                                )
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true

                    text: "Aplicaciones"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Text {
                    visible: root.service.applicationStreamsModel.values.length === 0
                    Layout.fillWidth: true

                    text: "No hay aplicaciones reproduciendo audio"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Repeater {
                    model: root.service.applicationGroupsModel

                    delegate: ColumnLayout {
                        id: applicationRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Style.spacingSmall

                        readonly property string applicationName: modelData.name
                        readonly property string detail:
                            modelData.detail
                        readonly property real applicationVolume:
                            root.service.groupVolume(modelData)
                        readonly property bool applicationMuted:
                            root.service.groupMuted(modelData)

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                enabled: applicationRow.modelData.nodes.length > 0
                                radius: Style.controlRadius
                                color: muteButton.hovered
                                    ? Color.surfaceHover : Color.surface

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: root.service.applicationIcon(applicationRow.modelData)
                                    font.pixelSize: Style.materialIconMedium
                                    color: applicationRow.applicationMuted
                                        ? Color.foregroundMuted : Color.accent
                                }

                                HoverHandler { id: muteButton }
                                TapHandler {
                                    onTapped: root.service.toggleGroupMute(
                                        applicationRow.modelData)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true

                                    text: applicationRow.applicationName
                                    font.pixelSize: Style.fontNormal
                                    color: Color.foreground
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    visible: applicationRow.detail !== ""
                                    Layout.fillWidth: true

                                    text: applicationRow.detail
                                    font.pixelSize: Style.fontSmall
                                    color: Color.foregroundMuted
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            Text {
                                text: Math.round(applicationRow.applicationVolume * 100) + "%"
                                font.pixelSize: Style.fontSmall
                                color: Color.foregroundMuted
                            }

                        }

                        Rectangle {
                            id: applicationTrack

                            Layout.fillWidth: true
                            implicitHeight: 24
                            color: "transparent"
                            enabled: applicationRow.modelData.nodes.length > 0

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 4
                                radius: height / 2
                                color: Color.surface
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                width: parent.width * Math.max(0, Math.min(1,
                                    applicationRow.applicationVolume))
                                height: 4
                                radius: height / 2
                                color: applicationRow.applicationMuted
                                    ? Color.foregroundMuted : Color.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => root.service.setGroupVolume(
                                    applicationRow.modelData, mouse.x / width)
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        root.service.setGroupVolume(
                                            applicationRow.modelData, mouse.x / width)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                MaterialIcon {
                    text: root.service.muted ? "volume_off" : "volume_up"
                    font.pixelSize: Style.materialIconMedium
                    color: root.service.available
                        ? Color.accent
                        : Color.foregroundMuted
                }

                Text {
                    Layout.fillWidth: true

                    text: "Volume"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Text {
                    text: root.service.volumePercent + "%"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }
            }

            Rectangle {
                id: volumeTrack

                Layout.fillWidth: true

                implicitHeight: 28

                color: "transparent"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    height: 4

                    radius: height / 2
                    color: Color.surface
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    width: parent.width
                        * Math.max(
                            0,
                            Math.min(
                                root.service.volume,
                                1
                            )
                        )

                    height: 4

                    radius: height / 2
                    color: root.service.available
                        ? Color.accent
                        : Color.foregroundMuted
                }

                Rectangle {
                    x: Math.max(
                        0,
                        Math.min(
                            parent.width - width,
                            parent.width
                                * root.service.volume
                                - width / 2
                        )
                    )

                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: 14
                    height: 14

                    radius: width / 2
                    color: root.service.available
                        ? Color.accent
                        : Color.foregroundMuted
                }

                MouseArea {
                    anchors.fill: parent

                    enabled: root.service.available

                    onPressed: mouse => {
                        root.service.setVolume(
                            mouse.x / width
                        )
                    }

                    onPositionChanged: mouse => {
                        if (!pressed)
                            return

                        root.service.setVolume(
                            mouse.x / width
                        )
                    }
                }
            }

            Rectangle {
                implicitWidth: muteText.implicitWidth
                    + Style.paddingLarge * 2

                implicitHeight: 38

                radius: Style.radiusMedium

                color: muteHover.hovered
                    ? Color.surfaceHover
                    : Color.surface

                Text {
                    id: muteText

                    anchors.centerIn: parent

                    text: root.service.muted ? "Activar" : "Silenciar"

                    font.pixelSize: Style.fontSmall
                    color: root.service.available
                        ? Color.foreground
                        : Color.foregroundMuted
                }

                HoverHandler {
                    id: muteHover
                }

                TapHandler {
                    enabled: root.service.available

                    onTapped: {
                        root.service.toggleMute()
                    }
                }
            }
        }
    }
}
