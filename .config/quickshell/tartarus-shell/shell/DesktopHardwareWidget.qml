import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Item {
    id: root
    required property bool active
    required property string monitorName
    implicitWidth: 330
    implicitHeight: 185
    readonly property var hw: Services.HardwareService

    function syncConsumer() {
        root.hw.setConsumerActive("desktop-widget-" + root.monitorName, root.active, false)
    }
    Component.onCompleted: root.syncConsumer()
    onActiveChanged: root.syncConsumer()
    Component.onDestruction: root.hw.setConsumerActive("desktop-widget-" + root.monitorName, false)

    Rectangle {
        anchors.fill: parent
        radius: Style.panelRadius
        color: Qt.alpha(Color.surfaceContainer, 0.94)
        border.width: 1
        border.color: Qt.alpha(Color.outlineVariant, 0.7)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "memory"; iconSize: 20; iconColor: Color.primary }
            Text { text: "Sistema"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: root.hw.available ? "Actualizado" : "Consultando…"; color: Color.foregroundMuted; font.pixelSize: 11 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Repeater {
                model: [
                    { icon: "memory", name: "CPU", value: Math.round(root.hw.cpuUsage) + "%" },
                    { icon: "developer_board", name: "RAM", value: Math.round(root.hw.memoryUsed) + "%" },
                    { icon: "storage", name: "Disco", value: root.hw.diskUsedText }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: Style.controlRadius
                    color: Color.surfaceContainerHigh
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 2
                        MaterialIcon { text: modelData.icon; iconSize: 18; iconColor: Color.primary }
                        Text { text: modelData.name; color: Color.foregroundMuted; font.pixelSize: 11 }
                        Text { text: modelData.value; color: Color.foreground; font.pixelSize: 18; font.bold: true }
                    }
                }
            }
        }
        Text { text: root.hw.cpuCores + " núcleos · " + root.hw.cpuTemperatureLabel; color: Color.foregroundMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
    }
}
