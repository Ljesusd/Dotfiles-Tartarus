import QtQuick
import QtQuick.Layouts

import "../../theme"

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
            anchors {
                fill: parent
                margins: Style.paddingLarge
            }

            spacing: Style.spacingMedium

            Item {
                id: header

                Layout.fillWidth: true
                implicitHeight: Style.barControlHeight

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    text: "Bluetooth"

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    implicitWidth: toggleText.implicitWidth
                        + Style.paddingMedium * 2
                        + Style.materialIconSmall
                        + Style.spacingSmall

                    implicitHeight: 32

                    radius: Style.radiusFull

                    color: root.service.enabled
                        ? Color.primary
                        : Color.surfaceContainerHigh

                    border.width: Style.panelBorderWidth
                    border.color: root.service.enabled
                        ? Color.primary
                        : Color.outlineVariant

                    Row {
                        anchors.centerIn: parent
                        spacing: Style.spacingSmall

                        MaterialIcon {
                            text: root.service.enabled
                                ? "bluetooth_connected"
                                : "bluetooth_disabled"
                            color: root.service.enabled
                                ? Color.onPrimary
                                : Color.onSurfaceVariant
                            font.pixelSize: Style.materialIconSmall
                        }

                        Text {
                            id: toggleText

                            text: root.service.enabled
                                ? "ON"
                                : "OFF"

                            font.pixelSize: Style.fontSmall
                            font.weight: Font.DemiBold
                            color: root.service.enabled
                                ? Color.onPrimary
                                : Color.onSurfaceVariant
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

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    visible:
                        root.service.available
                        && !root.service.enabled

                    anchors.centerIn: parent

                    spacing: Style.spacingMedium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "bluetooth_disabled"
                        font.pixelSize: Style.materialIconExtraLarge
                        iconColor: Color.foregroundMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: "Bluetooth disabled"

                        font.pixelSize: Style.fontSmall
                        font.weight: Font.Medium
                        color: Color.foregroundMuted
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter

                        implicitWidth: enableText.implicitWidth
                            + Style.paddingLarge * 2

                        implicitHeight: 38

                        radius: Style.radiusFull
                        color: enableHover.hovered
                            ? Color.primary
                            : Color.primaryContainer

                        Text {
                            id: enableText

                            anchors.centerIn: parent

                            text: "Enable Bluetooth"

                            font.pixelSize: Style.fontSmall
                            color: Color.onPrimaryContainer
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

                    spacing: Style.spacingMedium

                    Text {
                        visible:
                            root.service.connectedDevices.length > 0

                        Layout.fillWidth: true

                        text: "Connected"

                        font.pixelSize: Style.fontSmall
                        color: Color.foregroundMuted
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

                        font.pixelSize: Style.fontSmall
                        color: Color.foregroundMuted
                    }

                    Text {
                        visible:
                            !root.service.discovering
                            && root.service.devices.length === 0

                        Layout.fillWidth: true

                        horizontalAlignment:
                            Text.AlignHCenter

                        text: "No Bluetooth devices found"

                        font.pixelSize: Style.fontSmall
                        color: Color.foregroundMuted
                    }

                    Text {
                        visible: root.service.discovering

                        Layout.fillWidth: true

                        text: "Scanning for devices..."

                        font.pixelSize: Style.fontSmall
                        color: Color.foregroundMuted
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        model: root.otherDevices

                        spacing: Style.spacingSmall

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

                        radius: Style.radiusMedium

                        color: scanHover.hovered
                            ? Color.surfaceHover
                            : Color.surface

                        Text {
                            anchors.centerIn: parent

                            text: root.service.discovering
                                ? "Stop scanning"
                                : "Scan devices"

                            font.pixelSize: Style.fontSmall
                            color: Color.foreground
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

        implicitHeight: Style.itemHeight

        radius: Style.radiusMedium

        color: deviceItem.device.connected
            ? Color.selection
            : deviceHover.hovered
                ? Color.surfaceHover
                : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Style.paddingMedium
                rightMargin: Style.paddingMedium
            }

            spacing: Style.spacingMedium

            MaterialIcon {
                text: deviceItem.device.connected
                    ? "bluetooth_connected"
                    : "bluetooth"

                iconSize: Style.iconMedium
                iconColor: deviceItem.device.connected
                    ? Color.accent
                    : Color.foregroundMuted
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: 2

                Text {
                    Layout.fillWidth: true

                    text: deviceItem.device.name

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true

                    text: deviceItem.statusText()

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Text {
                visible:
                    deviceItem.device.batteryAvailable

                text: deviceItem.device.battery + "%"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Rectangle {
                implicitWidth: actionText.implicitWidth
                    + Style.paddingMedium * 2

                implicitHeight: 30

                radius: Style.radiusSmall

                color: actionHover.hovered
                    ? Color.surfaceHover
                    : Color.surface

                Text {
                    id: actionText

                    anchors.centerIn: parent

                    text: deviceItem.actionText()

                    font.pixelSize: Style.fontSmall
                    color: Color.foreground
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
                    + Style.paddingMedium * 2

                implicitHeight: 30

                radius: Style.radiusSmall

                color: forgetHover.hovered
                    ? Color.surfaceHover
                    : Color.surface

                Text {
                    id: forgetText

                    anchors.centerIn: parent

                    text: "Forget"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
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
