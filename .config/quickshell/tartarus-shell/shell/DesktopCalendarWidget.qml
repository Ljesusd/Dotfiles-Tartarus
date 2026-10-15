import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme

Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: 180
    radius: Theme.Style.panelRadius
    color: Qt.alpha(Theme.Color.surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Theme.Color.outlineVariant, 0.7)

    readonly property var events: Services.CalendarService.todayEvents

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            Theme.MaterialIcon { text: "calendar_month"; iconSize: 20; iconColor: Theme.Color.primary }
            Text { text: "Agenda de hoy"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: Qt.formatDate(new Date(), "d MMM"); color: Theme.Color.foregroundMuted; font.pixelSize: 11 }
        }
        Text {
            Layout.fillWidth: true
            text: root.events.length === 0 ? "Sin eventos ni tareas" : root.events.length + " elemento(s)"
            color: Theme.Color.primary
            font.pixelSize: 12
        }
        Repeater {
            model: root.events.slice(0, 4)
            delegate: Text { required property var modelData; Layout.fillWidth: true; text: "• " + (modelData.title || "Evento"); color: Theme.Color.foreground; font.pixelSize: 12; elide: Text.ElideRight }
        }
    }
}
