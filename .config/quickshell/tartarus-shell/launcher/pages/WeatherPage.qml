pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../services" as Services
import "../../services/WeatherModel.js" as Model
import "../../theme"
import "../components"

// Meteobar's hero/hourly/range composition with the metric grouping of
// Detailed Weather and the explicit feels-like reading of BOM Weather.
Item {
    id: root
    required property bool active
    visible: active
    readonly property var weather: Services.WeatherService
    property int selectedDay: 0
    property bool editingLocation: false
    readonly property var day: weather.days[selectedDay] || null
    readonly property var hours: day ? Model.hoursForDay(weather.hourly, day.date, weather.localNow) : []
    readonly property var windows: Model.windows(root.hours)
    readonly property var advice: Model.planningAdvice(weather.hourly, root.day, weather.localNow, weather.current)
    readonly property bool narrow: width < 480
    readonly property var uv: day ? (selectedDay === 0 && weather.current ? weather.current.uv : day.uv) : null
    readonly property color uvColor: uv === null || uv < 3 ? Color.success : uv < 6 ? Color.warning : Color.error

    function value(number, unit) { return number === null || number === undefined ? "—" : number + (unit || "") }
    function editLocation() {
        editingLocation = !editingLocation
        if (editingLocation) {
            cityPicker.begin(weather.automatic ? "" : Services.QuickSettingsState.weatherLocation)
        }
    }
    onActiveChanged: {
        if (active) { selectedDay = 0; weather.refresh(false) }
        else editingLocation = false
    }
    Connections {
        target: root.weather
        function onLocalDateChanged() { root.selectedDay = 0 }
    }

    Flickable {
        id: viewport
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        anchors.bottomMargin: Style.paddingLarge + Style.barPopupGap * 2
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            width: viewport.width
            spacing: Style.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: "partly_cloudy_day"; iconColor: Color.primary; iconSize: 24 }
                WeatherText { text: "Clima"; font.pixelSize: Style.fontLarge; font.bold: true; Layout.fillWidth: true }
                WeatherButton { text: "Ubicación"; onClicked: root.editLocation() }
                WeatherButton {
                    text: root.weather.loading ? "Consultando…" : "Actualizar"
                    enabled: !root.weather.loading
                    onClicked: root.weather.refresh(true)
                }
            }

            ColumnLayout {
                visible: root.editingLocation
                Layout.fillWidth: true
                spacing: Style.spacingSmall
                WeatherLocationPicker {
                    id: cityPicker
                    Layout.fillWidth: true
                    active: root.active && root.editingLocation
                    onLocationSelected: place => {
                        Services.QuickSettingsState.setWeatherPlace(place)
                        root.editingLocation = false
                    }
                    onEscapePressed: root.editingLocation = false
                }
                WeatherButton {
                    text: root.weather.automatic ? "Ubicación automática activada" : "Usar ubicación del PC"
                    enabled: !root.weather.automatic
                    onClicked: { Services.QuickSettingsState.setWeatherAutoLocation(true); root.editingLocation = false }
                }
                WeatherText { text: "Elige una sugerencia con clic o ↑ ↓ y Enter. La ubicación por IP es aproximada."; color: Color.foregroundMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: 11 }
            }

            WeatherText {
                visible: root.weather.error !== "" || root.weather.locationNotice !== ""
                text: root.weather.error ? root.weather.error + (root.weather.available ? " · Últimos datos disponibles" : "") : root.weather.locationNotice
                color: Color.warning
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            WeatherText {
                visible: !root.weather.available
                text: root.weather.loading ? "Detectando ubicación y consultando el clima…" : "No hay un pronóstico disponible. Revisa la ubicación o vuelve a actualizar."
                color: Color.foregroundMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.weather.available
                Layout.fillWidth: true
                implicitHeight: hero.implicitHeight + 32
                radius: Style.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.tint(Color.surfaceContainerHigh, Qt.alpha(Color.primary, 0.12)) }
                    GradientStop { position: 1; color: Color.surfaceContainerHigh }
                }
                ColumnLayout {
                    id: hero
                    x: 16; y: 16; width: parent.width - 32
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        MaterialIcon { text: "location_on"; iconSize: 16; iconColor: Color.primary }
                        WeatherText { text: root.weather.location; font.bold: true; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WordWrap }
                        WeatherText { text: root.weather.locationSource === "ip" ? "POR IP" : "CIUDAD FIJA"; color: Color.foregroundMuted; font.pixelSize: 10 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        MaterialIcon { text: root.weather.current ? root.weather.icon(root.weather.current.code, root.weather.current.isDay) : "cloud"; iconSize: root.narrow ? 46 : 64; iconColor: Color.primary }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            WeatherText { text: root.weather.current ? root.value(root.weather.current.temp, "°") : "—"; font.pixelSize: root.narrow ? 48 : 64; font.bold: true }
                            WeatherText { text: root.weather.current ? "Sensación " + root.value(root.weather.current.feelsLike, "°C") : ""; color: Color.primary; font.pixelSize: 14 }
                        }
                        ColumnLayout {
                            visible: !root.narrow
                            Layout.maximumWidth: hero.width * 0.43
                            WeatherText { text: root.weather.current ? root.weather.description(root.weather.current.code) : ""; font.pixelSize: 18; font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            WeatherText { text: "Ahora · " + (root.weather.current ? root.weather.current.time.slice(11, 16) : ""); color: Color.foregroundMuted }
                        }
                    }
                    WeatherText { visible: root.narrow; text: root.weather.current ? root.weather.description(root.weather.current.code) : ""; color: Color.foregroundMuted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
            }

            RowLayout {
                visible: root.weather.days.length > 0
                Layout.fillWidth: true
                spacing: Style.spacingSmall
                Repeater {
                    model: root.weather.days
                    delegate: WeatherButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        emphasized: root.selectedDay === index
                        multiline: root.narrow
                        text: (modelData.date === root.weather.localDate ? "Hoy" : "Mañana")
                            + " · " + Model.dateLabel(modelData.date)
                            + (root.narrow ? "\n" : " · ")
                            + root.value(modelData.min, "°") + " / " + root.value(modelData.max, "°")
                        onClicked: root.selectedDay = index
                    }
                }
            }

            WeatherSection {
                visible: root.weather.available && root.day !== null
                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon { text: "tips_and_updates"; iconSize: 20; iconColor: Color.primary }
                    WeatherText { text: root.selectedDay === 0 ? "Para lo que queda de hoy" : "Prepárate para mañana"; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
                Repeater {
                    model: root.advice
                    delegate: WeatherAdvice {
                        required property var modelData
                        Layout.fillWidth: true
                        advice: modelData
                    }
                }
                WeatherText { text: "Orientativo, según el pronóstico por horas."; color: Color.foregroundSubtle; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            }

            GridLayout {
                visible: root.weather.available
                Layout.fillWidth: true
                columns: root.narrow ? 2 : 3
                columnSpacing: 8
                rowSpacing: 8
                WeatherMetric { Layout.fillWidth: true; label: "Humedad"; detail: "Ahora"; icon: "humidity_percentage"; value: root.weather.current ? root.value(root.weather.current.humidity, "%") : "—"; level: root.weather.current && root.weather.current.humidity !== null ? root.weather.current.humidity / 100 : -1 }
                WeatherMetric { Layout.fillWidth: true; label: root.selectedDay === 0 ? "UV de esta hora" : "UV máximo mañana"; icon: "sunny"; value: root.uv === null ? "—" : root.uv.toFixed(1); detail: root.weather.uvLabel(root.uv) + (root.day && root.day.uv !== null ? " · máx. " + root.day.uv.toFixed(1) : ""); accent: root.uvColor; level: root.uv === null ? -1 : root.uv / 11 }
                WeatherMetric { Layout.fillWidth: true; label: root.narrow ? "Lluvia" : "Probabilidad de lluvia"; icon: "rainy"; value: root.day ? root.value(root.day.rain, "%") : "—"; detail: root.selectedDay === 0 ? "Máxima de hoy" : "Máxima de mañana"; accent: Color.info; level: root.day && root.day.rain !== null ? root.day.rain / 100 : -1 }
                WeatherMetric { Layout.fillWidth: true; visible: root.narrow; label: "Viento ahora"; icon: "air"; value: root.weather.current ? root.value(root.weather.current.wind, " km/h") : "—" }
            }

            WeatherSection {
                visible: root.day !== null
                WeatherText { text: (root.selectedDay === 0 ? "Hoy" : "Mañana") + " · " + (root.day ? root.weather.description(root.day.code) : ""); font.pixelSize: Style.fontNormal; font.bold: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                WeatherText { text: root.selectedDay === 0 ? "Lo que queda del día, hora por hora" : "El día completo, hora por hora"; color: Color.foregroundMuted }

                Flickable {
                    id: hoursViewport
                    Layout.fillWidth: true
                    implicitHeight: 208
                    clip: true
                    contentWidth: Math.max(width, root.hours.length * 80)
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    Controls.ScrollBar.horizontal: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                    readonly property real slotWidth: root.hours.length ? contentWidth / root.hours.length : 80
                    onWidthChanged: forecastCurve.requestPaint()
                    onContentWidthChanged: forecastCurve.requestPaint()
                    Canvas {
                        id: forecastCurve
                        width: hoursViewport.contentWidth
                        height: 58
                        onPaint: {
                            const ctx = getContext("2d"), points = root.hours
                            ctx.clearRect(0, 0, width, height)
                            if (!points.length || width <= 0) return
                            const temps = points.map(h => h.temp), low = Math.min(...temps) - 1
                            const range = Math.max(2, Math.max(...temps) - low + 1)
                            ctx.lineWidth = 2
                            ctx.strokeStyle = Color.primary
                            ctx.beginPath()
                            points.forEach((h, i) => {
                                const x = (i + 0.5) * hoursViewport.slotWidth, y = 8 + (1 - (h.temp - low) / range) * 42
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            })
                            ctx.stroke()
                            points.forEach((h, i) => {
                                ctx.beginPath(); ctx.arc((i + 0.5) * hoursViewport.slotWidth, 8 + (1 - (h.temp - low) / range) * 42, 3, 0, Math.PI * 2)
                                ctx.fillStyle = Color.primary; ctx.fill()
                            })
                        }
                    }
                    Row {
                        y: 64
                        Repeater {
                            model: root.hours
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: hoursViewport.slotWidth
                                height: 130
                                radius: Style.controlRadius
                                color: index === 0 && root.selectedDay === 0 ? Qt.alpha(Color.primary, 0.1) : "transparent"
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    spacing: 4
                                    WeatherText { text: modelData.time.slice(11, 13) === root.weather.localNow.slice(11, 13) && root.selectedDay === 0 ? "AHORA" : modelData.time.slice(11, 16); color: Color.foregroundMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                                    MaterialIcon { text: root.weather.icon(modelData.code, modelData.isDay); iconSize: 24; iconColor: modelData.isDay && modelData.cloud !== null && modelData.cloud <= 25 ? Color.warning : Color.primary; Layout.alignment: Qt.AlignHCenter }
                                    WeatherText { text: root.value(modelData.temp, "°"); font.pixelSize: 17; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                    WeatherText { text: root.value(modelData.rain, "%") + " lluvia"; color: Color.info; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                    WeatherText { text: root.weather.description(modelData.code); color: Color.foregroundMuted; font.pixelSize: 10; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
                WeatherText { visible: root.hours.length === 0; text: "No quedan horas disponibles para este día"; color: Color.foregroundMuted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                Repeater {
                    model: root.windows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        MaterialIcon { text: modelData.label === "Tormenta prevista" ? "thunderstorm" : modelData.label.toLowerCase().includes("lluvia") ? "rainy" : modelData.label === "Nublado" ? "cloud" : "sunny"; iconSize: 16; iconColor: modelData.label === "Cielo despejado" ? Color.warning : Color.info }
                        WeatherText { text: modelData.label; Layout.fillWidth: true; color: Color.foregroundMuted }
                        WeatherText { text: modelData.start + "–" + modelData.end; font.bold: true }
                    }
                }
            }

            WeatherSun { Layout.fillWidth: true; visible: root.day !== null; day: root.day; localNow: root.weather.localNow }

            WeatherSection {
                visible: root.weather.available
                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon { text: "air"; iconSize: 22; iconColor: Color.primary }
                    WeatherText { text: "Calidad del aire"; font.bold: true; Layout.fillWidth: true }
                    WeatherText { text: root.weather.air ? Math.round(root.weather.air.aqi) + " · " + root.weather.airLabel(root.weather.air.aqi) : "—"; color: Color.primary; font.bold: true }
                }
                WeatherText {
                    text: root.weather.air ? "AQI europeo estimado · PM2.5 " + root.value(root.weather.air.pm25, " µg/m³") + " · PM10 " + root.value(root.weather.air.pm10, " µg/m³") : root.weather.airLoading ? "Consultando calidad del aire…" : "Calidad del aire no disponible"
                    color: Color.foregroundMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }
                WeatherText { visible: root.weather.airError !== ""; text: root.weather.airError + (root.weather.air ? " · Se conserva la lectura anterior" : ""); color: Color.warning; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
            WeatherText {
                text: "Open-Meteo · " + root.weather.timezone + (root.weather.lastUpdate ? " · Consultado " + Model.localTime(root.weather.lastUpdate, root.weather.utcOffset).slice(11, 16) : "")
                color: Color.foregroundSubtle; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }
    }
    onHoursChanged: { hoursViewport.contentX = 0; forecastCurve.requestPaint() }
    Connections { target: Color; function onPrimaryChanged() { forecastCurve.requestPaint() } }

    component WeatherText: Text {
        textFormat: Text.PlainText
        color: Color.foreground
        font.pixelSize: Style.fontSmall
    }
    component WeatherButton: Controls.Button {
        id: button
        property bool emphasized: false
        property bool multiline: false
        implicitHeight: multiline ? 50 : 34
        leftPadding: 12
        rightPadding: 12
        contentItem: Text { text: button.text; textFormat: Text.PlainText; color: button.emphasized ? Color.onPrimary : Color.foreground; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { radius: Style.controlRadius; color: button.emphasized ? Color.primary : button.hovered ? Color.surfaceHover : Color.surfaceContainerHigh; opacity: button.enabled ? 1 : 0.55 }
    }
    component WeatherSection: Rectangle {
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + Style.paddingMedium * 2
        radius: Style.cardRadius
        color: Color.surfaceContainerHigh
        ColumnLayout { id: body; x: Style.paddingMedium; y: Style.paddingMedium; width: parent.width - Style.paddingMedium * 2; spacing: Style.spacingSmall }
    }
}
