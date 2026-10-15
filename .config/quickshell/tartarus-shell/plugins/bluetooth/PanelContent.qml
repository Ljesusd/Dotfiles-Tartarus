import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme

Item {
    id: root

    required property var plugin
    property var hoverPanelController: null
    property bool active: false

    readonly property var service:
        root.plugin.service

    readonly property var otherDevices:
        root.service.devices.filter(device => {
            return !device.connected
        })

    implicitWidth: 380
    implicitHeight: 460

    onActiveChanged: {
        if (
            root.active
            && root.service.available
            && root.service.enabled
        ) {
            root.service.startScan()
        } else if (
            !root.active
            && root.service.discovering
        ) {
            root.service.stopScan()
        }
    }

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
            anchors {
                fill: parent
                margins: Theme.Style.paddingLarge
            }

            spacing: Theme.Style.spacingMedium

            Item {
                id: header

                Layout.fillWidth: true
                implicitHeight: Theme.Style.barControlHeight

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    text: "Bluetooth"

                    font.pixelSize: Theme.Style.fontNormal
                    color: Theme.Color.foreground
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    implicitWidth: toggleText.implicitWidth
                        + Theme.Style.paddingMedium * 2
                        + Theme.Style.materialIconSmall
                        + Theme.Style.spacingSmall

                    implicitHeight: 32

                    radius: Theme.Style.radiusFull

                    color: root.service.enabled
                        ? Theme.Color.primary
                        : Theme.Color.surfaceContainerHigh

                    border.width: Theme.Style.panelBorderWidth
                    border.color: root.service.enabled
                        ? Theme.Color.primary
                        : Theme.Color.outlineVariant

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.Style.spacingSmall

                        Theme.MaterialIcon {
                            text: root.service.enabled
                                ? "bluetooth_connected"
                                : "bluetooth_disabled"
                            color: root.service.enabled
                                ? Theme.Color.onPrimary
                                : Theme.Color.onSurfaceVariant
                            font.pixelSize: Theme.Style.materialIconSmall
                        }

                        Text {
                            id: toggleText

                            text: root.service.enabled
                                ? "ON"
                                : "OFF"

                            font.pixelSize: Theme.Style.fontSmall
                            font.weight: Font.DemiBold
                            color: root.service.enabled
                                ? Theme.Color.onPrimary
                                : Theme.Color.onSurfaceVariant
                        }
                    }

                    TapHandler {
                        onTapped: {
                            root.service.setEnabled(
                                !root.service.enabled
                            )
                        }
                    }
                }
            }

            Text {
                visible: !root.service.available

                Layout.fillWidth: true

                horizontalAlignment:
                    Text.AlignHCenter

                text: "Bluetooth unavailable"

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    visible:
                        root.service.available
                        && !root.service.enabled

                    anchors.centerIn: parent

                    spacing: Theme.Style.spacingMedium

                    Theme.MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "bluetooth_disabled"
                        font.pixelSize: Theme.Style.materialIconExtraLarge
                        iconColor: Theme.Color.foregroundMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: "Bluetooth disabled"

                        font.pixelSize: Theme.Style.fontSmall
                        font.weight: Font.Medium
                        color: Theme.Color.foregroundMuted
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter

                        implicitWidth: enableText.implicitWidth
                            + Theme.Style.paddingLarge * 2

                        implicitHeight: 38

                        radius: Theme.Style.radiusFull
                        color: enableHover.hovered
                            ? Theme.Color.primary
                            : Theme.Color.primaryContainer

                        Text {
                            id: enableText

                            anchors.centerIn: parent

                            text: "Enable Bluetooth"

                            font.pixelSize: Theme.Style.fontSmall
                            color: Theme.Color.onPrimaryContainer
                        }

                        TapHandler {
                            onTapped: {
                                root.service.setEnabled(true)
                            }
                        }

                        HoverHandler { id: enableHover }
                    }
                }

                ColumnLayout {
                    visible:
                        root.service.available
                        && root.service.enabled

                    anchors.fill: parent

                    spacing: Theme.Style.spacingMedium

                    Text {
                        visible:
                            root.service.connectedDevices.length > 0

                        Layout.fillWidth: true

                        text: "Connected"

                        font.pixelSize: Theme.Style.fontSmall
                        color: Theme.Color.foregroundMuted
                    }

                    Repeater {
                        model: root.service.connectedDevices

                        delegate: DeviceItem {
                            required property var modelData

                            Layout.fillWidth: true

                            device: modelData
                            service: root.service
                        }
                    }

                    Text {
                        Layout.fillWidth: true

                        text: "Devices"

                        font.pixelSize: Theme.Style.fontSmall
                        color: Theme.Color.foregroundMuted
                    }

                    Text {
                        visible:
                            !root.service.discovering
                            && root.service.devices.length === 0

                        Layout.fillWidth: true

                        horizontalAlignment:
                            Text.AlignHCenter

                        text: "No Bluetooth devices found"

                        font.pixelSize: Theme.Style.fontSmall
                        color: Theme.Color.foregroundMuted
                    }

                    Text {
                        visible: root.service.discovering

                        Layout.fillWidth: true

                        text: "Scanning for devices..."

                        font.pixelSize: Theme.Style.fontSmall
                        color: Theme.Color.foregroundMuted
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        model: root.otherDevices

                        spacing: Theme.Style.spacingSmall

                        delegate: DeviceItem {
                            required property var modelData

                            width: ListView.view.width

                            device: modelData
                            service: root.service
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true

                        implicitHeight: 38

                        radius: Theme.Style.radiusMedium

                        color: scanHover.hovered
                            ? Theme.Color.surfaceHover
                            : Theme.Color.surface

                        Text {
                            anchors.centerIn: parent

                            text: root.service.discovering
                                ? "Stop scanning"
                                : "Scan devices"

                            font.pixelSize: Theme.Style.fontSmall
                            color: Theme.Color.foreground
                        }

                        HoverHandler {
                            id: scanHover
                        }

                        TapHandler {
                            onTapped: {
                                if (root.service.discovering) {
                                    root.service.stopScan()
                                } else {
                                    root.service.startScan()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceItem: Rectangle {
        id: deviceItem

        required property var device
        required property var service

        implicitHeight: Theme.Style.itemHeight

        radius: Theme.Style.radiusMedium

        color: deviceItem.device.connected
            ? Theme.Color.selection
            : deviceHover.hovered
                ? Theme.Color.surfaceHover
                : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.Style.paddingMedium
                rightMargin: Theme.Style.paddingMedium
            }

            spacing: Theme.Style.spacingMedium

            Theme.MaterialIcon {
                text: deviceItem.device.connected
                    ? "bluetooth_connected"
                    : "bluetooth"

                iconSize: Theme.Style.iconMedium
                iconColor: deviceItem.device.connected
                    ? Theme.Color.accent
                    : Theme.Color.foregroundMuted
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: 2

                Text {
                    Layout.fillWidth: true

                    text: deviceItem.device.name

                    font.pixelSize: Theme.Style.fontNormal
                    color: Theme.Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true

                    text: deviceItem.statusText()

                    font.pixelSize: Theme.Style.fontSmall
                    color: Theme.Color.foregroundMuted

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Text {
                visible:
                    deviceItem.device.batteryAvailable

                text: deviceItem.device.battery + "%"

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
            }

            Rectangle {
                implicitWidth: actionText.implicitWidth
                    + Theme.Style.paddingMedium * 2

                implicitHeight: 30

                radius: Theme.Style.radiusSmall

                color: actionHover.hovered
                    ? Theme.Color.surfaceHover
                    : Theme.Color.surface

                Text {
                    id: actionText

                    anchors.centerIn: parent

                    text: deviceItem.actionText()

                    font.pixelSize: Theme.Style.fontSmall
                    color: Theme.Color.foreground
                }

                HoverHandler {
                    id: actionHover
                }

                TapHandler {
                    enabled:
                        !deviceItem.device.connecting
                        && !deviceItem.device.disconnecting

                    onTapped: {
                        deviceItem.activate()
                    }
                }
            }

            Rectangle {
                visible:
                    deviceItem.device.paired
                    || deviceItem.device.bonded

                implicitWidth: forgetText.implicitWidth
                    + Theme.Style.paddingMedium * 2

                implicitHeight: 30

                radius: Theme.Style.radiusSmall

                color: forgetHover.hovered
                    ? Theme.Color.surfaceHover
                    : Theme.Color.surface

                Text {
                    id: forgetText

                    anchors.centerIn: parent

                    text: "Forget"

                    font.pixelSize: Theme.Style.fontSmall
                    color: Theme.Color.foregroundMuted
                }

                HoverHandler {
                    id: forgetHover
                }

                TapHandler {
                    enabled:
                        !deviceItem.device.connecting
                        && !deviceItem.device.disconnecting
                        && !deviceItem.device.pairing

                    onTapped: {
                        deviceItem.service.forgetDevice(
                            deviceItem.device
                        )
                    }
                }
            }
        }

        HoverHandler {
            id: deviceHover
        }

        function statusText() {
            if (deviceItem.device.connected)
                return "Connected"

            if (deviceItem.device.connecting)
                return "Connecting..."

            if (deviceItem.device.disconnecting)
                return "Disconnecting..."

            if (deviceItem.device.pairing)
                return "Pairing..."

            if (deviceItem.device.paired)
                return "Paired"

            return "Available"
        }

        function actionText() {
            if (deviceItem.device.connecting)
                return "Connecting..."

            if (deviceItem.device.disconnecting)
                return "Disconnecting..."

            if (deviceItem.device.connected)
                return "Disconnect"

            if (deviceItem.device.pairing)
                return "Cancel"

            if (deviceItem.device.paired)
                return "Connect"

            return "Pair"
        }

        function activate() {
            if (deviceItem.device.connected) {
                deviceItem.service.disconnectDevice(
                    deviceItem.device
                )
            } else if (deviceItem.device.pairing) {
                deviceItem.service.cancelPairing(
                    deviceItem.device
                )
            } else if (deviceItem.device.paired) {
                deviceItem.service.connectDevice(
                    deviceItem.device
                )
            } else {
                deviceItem.service.pairDevice(
                    deviceItem.device
                )
            }
        }
    }
}
