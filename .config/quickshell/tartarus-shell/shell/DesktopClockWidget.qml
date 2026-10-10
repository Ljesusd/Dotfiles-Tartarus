import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Rectangle {
    id: root
    implicitWidth: 300
    implicitHeight: 132
    radius: Style.panelRadius
    color: Qt.alpha(Color.surfaceContainer, 0.92)
    border.width: 1
    border.color: Qt.alpha(Color.outlineVariant, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: 2
        Text { text: Services.LocationService.currentTime; color: Color.foreground; font.pixelSize: 48; font.bold: true; Layout.fillWidth: true }
        Text { text: Qt.formatDate(new Date(), "dddd, d 'de' MMMM"); color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
        Text { text: "Tartarus"; color: Color.primary; font.pixelSize: 11; font.letterSpacing: 1.2; Layout.topMargin: 6 }
    }
}
