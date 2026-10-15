import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme

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
        radius: Theme.Style.panelRadius
        color: Qt.alpha(Theme.Color.surfaceContainer, 0.94)
        border.width: 1
        border.color: Qt.alpha(Theme.Color.outlineVariant, 0.7)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            Theme.MaterialIcon { text: "memory"; iconSize: 20; iconColor: Theme.Color.primary }
            Text { text: "Sistema"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: root.hw.available ? "Actualizado" : "Consultando…"; color: Theme.Color.foregroundMuted; font.pixelSize: 11 }
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
                    radius: Theme.Style.controlRadius
                    color: Theme.Color.surfaceContainerHigh
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 2
                        Theme.MaterialIcon { text: modelData.icon; iconSize: 18; iconColor: Theme.Color.primary }
                        Text { text: modelData.name; color: Theme.Color.foregroundMuted; font.pixelSize: 11 }
                        Text { text: modelData.value; color: Theme.Color.foreground; font.pixelSize: 18; font.bold: true }
                    }
                }
            }
        }
        Text { text: root.hw.cpuCores + " núcleos · " + root.hw.cpuTemperatureLabel; color: Theme.Color.foregroundMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
    }
}
