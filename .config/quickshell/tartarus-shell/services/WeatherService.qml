pragma Singleton

import QtQuick
import "." as Services
import "WeatherModel.js" as Model
import "WeatherLocation.js" as Places

QtObject {
    id: root
    readonly property int maxAge: 15 * 60 * 1000
    property string location: ""
    property string locationSource: ""
    property string locationNotice: ""
    property var current: null
    property var hourly: []
    property var daily: []
    property var air: null
    property bool loading: false
    property bool airLoading: false
    property string error: ""
    property string airError: ""
    property double lastUpdate: 0
    property double lastAttempt: 0
    property double airUpdate: 0
    property double now: Date.now()
    property string timezone: "UTC"
    property int utcOffset: 0
    property var coordinates: null
    property double locatedAt: 0
    property int requestId: 0
    readonly property bool available: root.current !== null
    readonly property string localNow: Model.localTime(root.now, root.utcOffset)
    readonly property string localDate: root.localNow.slice(0, 10)
    readonly property var days: root.daily.filter(day => day.date >= root.localDate)
    readonly property bool automatic: Services.QuickSettingsState.weatherAutoLocation

    function icon(code, isDay) { return Model.icon(code, isDay) }
    function description(code) { return Model.description(code) }
    function airLabel(value) { return Model.airLabel(value) }
    function uvLabel(value) { return Model.uvLabel(value) }

    function refresh(force) {
        root.now = Date.now()
        if (root.loading) return
        if (!force && root.lastAttempt && root.now - root.lastAttempt < 2 * 60 * 1000) return
        const wrongDay = root.daily.length && root.daily[0].date !== root.localDate
        if (!force && !wrongDay && root.lastUpdate && root.now - root.lastUpdate < root.maxAge) return
        const id = ++root.requestId
        root.lastAttempt = root.now
        root.loading = true
        root.error = ""
        airRequest.cancel()
        root.airLoading = false
        const city = Services.QuickSettingsState.weatherLocation.trim()
        const savedPlace = Places.normalize(Services.QuickSettingsState.weatherPlace)
        if (!root.automatic && savedPlace && savedPlace.name === city) {
            root.fetchForecast(Object.assign({}, savedPlace, { city: city, source: "manual" }), id)
            return
        }
        if (root.automatic && (force || !root.coordinates || root.now - root.locatedAt > 60 * 60 * 1000)) {
            locationRequest.start("https://ipwho.is/?fields=success,city,region,country,country_code,latitude,longitude&lang=es", data => {
                if (id !== root.requestId) return
                if (data && data.success && Model.number(data.latitude) !== null && Model.number(data.longitude) !== null) {
                    root.locatedAt = Date.now()
                    root.locationNotice = ""
                    root.fetchForecast({ city: "", lat: Number(data.latitude), lon: Number(data.longitude),
                        name: String(data.city || data.region || "Mi ubicación"),
                        country: String(data.country || ""), countryCode: String(data.country_code || ""),
                        region: String(data.region || ""), source: "ip" }, id)
                } else if (root.coordinates) {
                    root.locationNotice = "No se pudo detectar la ubicación; se conserva la última"
                    root.fetchForecast(root.coordinates, id)
                } else {
                    root.locationNotice = "Detección no disponible; se usa la ciudad de Ajustes"
                    root.geocode(city, id, "fallback")
                }
            })
        } else if (root.coordinates && (root.automatic || root.coordinates.city === city)) {
            root.fetchForecast(root.coordinates, id)
        } else root.geocode(city, id, "manual")
    }

    function geocode(city, id, source) {
        locationRequest.start(Places.searchUrl(city, 1), data => {
            if (id !== root.requestId) return
            const found = Places.results(data)[0]
            if (!found) { root.loading = false; root.error = "No se encontró la ciudad. Revisa la ubicación."; return }
            root.fetchForecast(Object.assign({}, found, { city: city, source: source }), id)
        })
    }

    function fetchForecast(coords, id) {
        const base = "&latitude=" + coords.lat + "&longitude=" + coords.lon + "&timezone=auto"
        forecastRequest.start("https://api.open-meteo.com/v1/forecast?forecast_days=2" + base
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day,cloud_cover"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day,cloud_cover,uv_index"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,sunrise,sunset", data => {
            if (id !== root.requestId) return
            let result
            try { result = Model.normalize(data, coords.lat) }
            catch (error) { root.loading = false; root.error = "No se pudo actualizar el pronóstico"; return }
            const moved = root.coordinates && (root.coordinates.lat !== coords.lat || root.coordinates.lon !== coords.lon)
            if (moved) { root.air = null; root.airUpdate = 0 }
            root.coordinates = coords
            root.locationSource = coords.source
            root.current = result.current
            root.hourly = result.hourly
            root.daily = result.daily
            root.timezone = result.timezone
            root.utcOffset = result.offset
            root.location = Places.label(coords.name, coords.country, coords.countryCode)
            root.lastUpdate = Date.now()
            root.now = root.lastUpdate
            root.loading = false
            root.error = ""
            root.fetchAir(coords, id)
        })
    }

    function fetchAir(coords, id) {
        root.airLoading = true
        airRequest.start("https://air-quality-api.open-meteo.com/v1/air-quality?current=european_aqi,pm2_5,pm10"
            + "&latitude=" + coords.lat + "&longitude=" + coords.lon + "&timezone=auto", data => {
            if (id !== root.requestId) return
            root.airLoading = false
            const value = data && data.current ? Model.number(data.current.european_aqi) : null
            if (value === null) { root.airError = "No se pudo actualizar la calidad del aire"; return }
            root.air = { aqi: value, pm25: Model.number(data.current.pm2_5), pm10: Model.number(data.current.pm10),
                time: String(data.current.time || "") }
            root.airUpdate = Date.now()
            root.airError = ""
        })
    }

    function resetLocation() {
        ++root.requestId
        locationRequest.cancel()
        forecastRequest.cancel()
        airRequest.cancel()
        root.loading = false
        root.airLoading = false
        root.coordinates = null
        root.current = null
        root.hourly = []
        root.daily = []
        root.air = null
        root.location = ""
        root.locationNotice = ""
        root.airError = ""
        root.lastUpdate = 0
        root.lastAttempt = 0
        root.airUpdate = 0
        settingsDelay.restart()
    }

    property WeatherRequest locationRequest: WeatherRequest { id: locationRequest }
    property WeatherRequest forecastRequest: WeatherRequest { id: forecastRequest }
    property WeatherRequest airRequest: WeatherRequest { id: airRequest }
    property Timer updateTimer: Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: { root.now = Date.now(); root.refresh(false) }
    }
    property Timer settingsDelay: Timer {
        id: settingsDelay
        interval: 0
        onTriggered: root.refresh(true)
    }
    property Connections settingsConnection: Connections {
        target: Services.QuickSettingsState
        function onWeatherLocationChanged() { root.resetLocation() }
        function onWeatherAutoLocationChanged() { root.resetLocation() }
        function onWeatherPlaceChanged() { root.resetLocation() }
    }
    Component.onCompleted: root.refresh(false)
}
