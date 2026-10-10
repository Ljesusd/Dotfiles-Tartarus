import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: 180
    radius: Style.panelRadius
    color: Qt.alpha(Color.surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Color.outlineVariant, 0.7)

    readonly property var events: Services.CalendarService.todayEvents
    readonly property var tasks: Services.CalendarService.localTasks.filter(task => task.dateKey === Services.CalendarService.selectedDate)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "calendar_month"; iconSize: 20; iconColor: Color.primary }
            Text { text: "Agenda de hoy"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: Qt.formatDate(new Date(), "d MMM"); color: Color.foregroundMuted; font.pixelSize: 11 }
        }
        Text {
            Layout.fillWidth: true
            text: root.events.length + root.tasks.length === 0 ? "Sin eventos ni tareas" : (root.events.length + root.tasks.length) + " elemento(s)"
            color: Color.primary
            font.pixelSize: 12
        }
        Repeater {
            model: root.events.slice(0, 2)
            delegate: Text { required property var modelData; Layout.fillWidth: true; text: "• " + (modelData.title || "Evento"); color: Color.foreground; font.pixelSize: 12; elide: Text.ElideRight }
        }
        Repeater {
            model: root.tasks.slice(0, 2)
            delegate: Text { required property var modelData; Layout.fillWidth: true; text: "• " + modelData.title; color: Color.foreground; font.pixelSize: 12; elide: Text.ElideRight }
        }
    }
}
