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

    readonly property bool showEthernet:
        root.service.ethernetAvailable

    readonly property string ethernetStatus: {
        if (!root.service.ethernetAvailable)
            return ""

        if (root.service.ethernetConnected)
            return "Connected"

        if (root.service.ethernetHasLink)
            return "Not connected"

        return "Cable disconnected"
    }

    readonly property string ethernetDetails: {
        if (!root.service.ethernetConnected)
            return root.ethernetStatus

        if (root.service.ethernetLinkSpeed > 0) {
            return root.ethernetStatus
                + " · "
                + root.service.ethernetLinkSpeed
                + " Mbps"
        }

        return root.ethernetStatus
    }

    implicitWidth: 360
    implicitHeight: 420

    onActiveChanged: {
        if (root.active) {
            root.service.setScanning(true)
            root.service.scan()
        } else {
            root.service.setScanning(false)
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
            id: contentLayout

            anchors {
                fill: parent
                margins: Style.paddingLarge
            }

            spacing: Style.spacingMedium

            RowLayout {
                id: headerRow

                Layout.fillWidth: true

                Text {
                    id: networkTitle

                    Layout.fillWidth: true

                    text: "Network"

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground
                }

                Rectangle {
                    implicitWidth: wifiToggleText.implicitWidth
                        + Style.paddingMedium * 2

                    implicitHeight: 30

                    radius: Style.radiusFull

                    color: wifiToggleHover.hovered
                        ? Color.surfaceHover
                        : Color.surface

                    Text {
                        id: wifiToggleText

                        anchors.centerIn: parent

                        text: root.service.wifiEnabled
                            ? "Wi-Fi On"
                            : "Wi-Fi Off"

                        font.pixelSize: Style.fontSmall
                        color: Color.foregroundMuted
                    }

                    HoverHandler {
                        id: wifiToggleHover
                    }

                    TapHandler {
                        onTapped: {
                            const nextEnabled =
                                !root.service.wifiEnabled

                            root.service.setWifiEnabled(
                                nextEnabled
                            )

                            if (nextEnabled)
                                root.service.scan()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingMedium

                Repeater {
                    model: [
                        { label: "↑", value: root.service.uploadSpeed, color: Color.accent },
                        { label: "↓", value: root.service.downloadSpeed, color: Color.primary }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        readonly property real rate: Number(modelData.value) || 0
                        readonly property color rateColor: modelData.color
                        Layout.fillWidth: true
                        spacing: Style.spacingXs
                        Text { text: modelData.label; color: modelData.color; font.bold: true }
                        Row {
                            spacing: 2
                            Repeater {
                                model: 8
                                delegate: Rectangle {
                                    required property int index
                                    width: 3
                                    height: 5 + ((index + Math.floor(rate / 1024 / 8)) % 5) * 3
                                    radius: 2
                                    color: rateColor
                                    opacity: rate > 0 ? 0.9 : 0.3
                                }
                            }
                        }
                        Text { text: root.service.formatRate(rate); color: Color.foregroundMuted; font.pixelSize: Style.fontSmall }
                    }
                }
            }

            ColumnLayout {
                visible: root.showEthernet

                Layout.fillWidth: true

                spacing: Style.spacingSmall

                Text {
                    Layout.fillWidth: true

                    text: "Ethernet"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }

                Rectangle {
                    Layout.fillWidth: true

                    implicitHeight: ethernetContent.implicitHeight
                        + Style.paddingMedium * 2

                    radius: Style.radiusMedium
                    color: Color.surface

                    RowLayout {
                        id: ethernetContent

                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Style.paddingMedium
                            rightMargin: Style.paddingMedium
                        }

                        spacing: Style.spacingMedium

                        MaterialIcon {
                            text: "lan"

                            iconSize: Style.iconMedium
                            iconColor: root.service.ethernetConnected
                                ? Color.accent
                                : Color.foregroundMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing: 2

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.service.ethernetName !== ""
                                    ? root.service.ethernetName
                                    : root.service.ethernetInterface

                                font.pixelSize: Style.fontNormal
                                color: Color.foreground

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                visible:
                                    root.service.ethernetName !== ""
                                    && root.service.ethernetInterface !== ""

                                Layout.fillWidth: true

                                text: root.service.ethernetInterface

                                font.pixelSize: Style.fontSmall
                                color: Color.foregroundMuted

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true

                                text: root.ethernetDetails

                                font.pixelSize: Style.fontSmall
                                color: Color.foregroundMuted

                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        Rectangle {
                            visible:
                                root.service.ethernetConnected
                                || root.service.ethernetHasLink

                            implicitWidth: ethernetActionText.implicitWidth
                                + Style.paddingMedium * 2

                            implicitHeight: 30

                            radius: Style.radiusSmall

                            color: ethernetActionHover.hovered
                                ? Color.surfaceHover
                                : Color.background

                            Text {
                                id: ethernetActionText

                                anchors.centerIn: parent

                                text: root.service.ethernetConnected
                                    ? "Disconnect"
                                    : "Connect"

                                font.pixelSize: Style.fontSmall
                                color: Color.foreground
                            }

                            HoverHandler {
                                id: ethernetActionHover
                            }

                            TapHandler {
                                onTapped: {
                                    if (root.service.ethernetConnected) {
                                        root.service.disconnectEthernet()
                                    } else {
                                        root.service.connectEthernet()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.showEthernet

                Layout.fillWidth: true

                implicitHeight: 1

                color: Color.surface
            }

            Rectangle {
                Layout.fillWidth: true

                implicitHeight: 64

                visible:
                    root.service.wifiEnabled
                    && root.service.connected

                radius: Style.radiusMedium
                color: Color.surface

                RowLayout {
                    anchors {
                        fill: parent
                        margins: Style.paddingMedium
                    }

                    spacing: Style.spacingMedium

                    MaterialIcon {
                        text: "wifi"

                        iconSize: Style.iconMedium
                        iconColor: Color.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 2

                        Text {
                            Layout.fillWidth: true

                            text: root.service.ssid

                            font.pixelSize: Style.fontNormal
                            color: Color.foreground

                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            text: root.service.strength + "%"

                            font.pixelSize: Style.fontSmall
                            color: Color.foregroundMuted
                        }
                    }
                }
            }

            Text {
                visible: root.service.scanning

                Layout.fillWidth: true

                text: "Scanning..."

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Item {
                id: wifiDisabledState
                visible:
                    !root.service.wifiEnabled

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: 150

                Column {
                    anchors.centerIn: parent
                    spacing: Style.spacingSmall

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "wifi_off"
                        iconSize: Style.materialIconExtraLarge
                        iconColor: Color.foregroundMuted
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Wi-Fi disabled"
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.Medium
                        color: Color.foregroundMuted
                    }
                }
            }

            Text {
                visible:
                    root.service.wifiEnabled
                    &&
                    !root.service.scanning
                    && root.service.networks.length === 0

                Layout.fillWidth: true

                horizontalAlignment:
                    Text.AlignHCenter

                text: "No networks found"

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            ListView {
                id: networkList

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                visible: root.service.wifiEnabled

                model: root.service.networks

                spacing: Style.spacingSmall

                delegate: Rectangle {
                    id: networkItem

                    required property var modelData

                    width: ListView.view.width
                    height: Style.itemHeight

                    radius: Style.radiusMedium

                    color: networkItem.modelData.connected
                        ? Color.selection
                        : hoverHandler.hovered
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
                            text: networkItem.modelData.connected ? "wifi" : "wifi_off"

                            iconSize: Style.iconMedium
                            iconColor: networkItem.modelData.connected
                                ? Color.accent
                                : Color.foregroundMuted
                        }

                        Text {
                            Layout.fillWidth: true

                            text: networkItem.modelData.ssid

                            font.pixelSize: Style.fontNormal
                            color: Color.foreground

                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            text:
                                networkItem.modelData.strength
                                + "%"

                            font.pixelSize: Style.fontSmall
                            color: Color.foregroundMuted
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    TapHandler {
                        onTapped: {
                            if (networkItem.modelData.connected) {
                                root.service.disconnect()
                            } else {
                                root.service.connectNetwork(
                                    networkItem.modelData
                                )
                            }
                        }
                    }
                }
            }
        }
    }

}
