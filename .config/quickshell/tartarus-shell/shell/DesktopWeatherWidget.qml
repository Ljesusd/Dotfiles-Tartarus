import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: 190
    radius: Style.panelRadius
    color: Qt.alpha(Color.surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Color.outlineVariant, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "partly_cloudy_day"; iconSize: 20; iconColor: Color.primary }
            Text { text: "Clima"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: Services.WeatherService.location || "Sin ubicación"; color: Color.foregroundMuted; font.pixelSize: 11; elide: Text.ElideRight; Layout.maximumWidth: 150 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            MaterialIcon {
                text: Services.WeatherService.current ? Services.WeatherService.icon(Services.WeatherService.current.code, Services.WeatherService.current.isDay) : "cloud"
                iconSize: 48
                iconColor: Color.primary
            }
            Text {
                text: Services.WeatherService.current ? Services.WeatherService.current.temp + "°" : "—"
                color: Color.foreground
                font.pixelSize: 44
                font.bold: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: Services.WeatherService.current ? Services.WeatherService.description(Services.WeatherService.current.code) : "Consultando…"; color: Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: Services.WeatherService.current ? "Sensación " + Services.WeatherService.current.feelsLike + "°C" : ""; color: Color.foregroundMuted; font.pixelSize: 11 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: Services.WeatherService.current ? "Humedad " + Services.WeatherService.current.humidity + "%" : ""; color: Color.foregroundMuted; font.pixelSize: 11; Layout.fillWidth: true }
            Text { text: Services.WeatherService.current ? "UV " + Services.WeatherService.current.uv : ""; color: Color.foregroundMuted; font.pixelSize: 11 }
        }
    }
}
