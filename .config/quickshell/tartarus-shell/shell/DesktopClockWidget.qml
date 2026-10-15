import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme

Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: 132
    radius: Theme.Style.panelRadius
    color: Qt.alpha(Theme.Color.surfaceContainer, 0.92)
    border.width: 1
    border.color: Qt.alpha(Theme.Color.outlineVariant, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: 2
        Text { text: Services.LocationService.currentTime; color: Theme.Color.foreground; font.pixelSize: 48; font.bold: true; Layout.fillWidth: true }
        Text { text: Qt.formatDate(new Date(), "dddd, d 'de' MMMM"); color: Theme.Color.foregroundMuted; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
        Text { text: "Tartarus"; color: Theme.Color.primary; font.pixelSize: 11; font.letterSpacing: 1.2; Layout.topMargin: 6 }
    }
}
