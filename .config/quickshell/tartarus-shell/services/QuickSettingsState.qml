pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml
import "WeatherLocation.js" as Places

QtObject {
    id: root

    property string lastPage: ""
    property int nightTemperature: 4000
    property bool nightPreferred: false
    property string weatherLocation: "Madrid"
    property bool weatherAutoLocation: true
    property var weatherPlace: null
    property string timeZone: "Europe/Madrid"
    readonly property var pages: ["", "wifi", "bluetooth", "audio", "microphone", "brightness", "dnd", "night", "power"]

    readonly property FileView settingsFile: FileView {
        path: Quickshell.stateDir + "/quick-settings.json"
        blockLoading: true
        printErrors: false
    }

    function load() {
        const data = settingsFile.text()
        if (!data || !data.trim()) return
        try {
            const saved = JSON.parse(data)
            if (root.pages.includes(saved.lastPage)) root.lastPage = saved.lastPage
            if (Number.isInteger(saved.nightTemperature) && saved.nightTemperature >= 2500 && saved.nightTemperature <= 6500)
            root.nightTemperature = saved.nightTemperature
            root.nightPreferred = saved.nightPreferred === true
            if (typeof saved.weatherLocation === "string" && saved.weatherLocation.trim() !== "")
                root.weatherLocation = saved.weatherLocation.trim()
            if (typeof saved.weatherAutoLocation === "boolean")
                root.weatherAutoLocation = saved.weatherAutoLocation
            const place = Places.normalize(saved.weatherPlace)
            if (place && place.name === root.weatherLocation)
                root.weatherPlace = place
            if (typeof saved.timeZone === "string" && saved.timeZone.trim() !== "")
                root.timeZone = saved.timeZone.trim()
        } catch (error) {
            console.warn("Quick settings: invalid state:", error)
        }
    }

    function save() {
        settingsFile.setText(JSON.stringify({
            lastPage: root.lastPage,
            nightTemperature: root.nightTemperature,
            nightPreferred: root.nightPreferred,
            weatherLocation: root.weatherLocation,
            weatherAutoLocation: root.weatherAutoLocation,
            weatherPlace: root.weatherPlace,
            timeZone: root.timeZone
        }))
    }

    function setPage(page) {
        if (!root.pages.includes(page)) return
        root.lastPage = page
        root.save()
    }

    function setNightTemperature(value) {
        root.nightTemperature = Math.max(2500, Math.min(6500, Math.round(value)))
        root.save()
    }

    function setWeatherLocation(value) {
        const location = String(value || "").trim()
        if (location === "") return
        root.weatherPlace = null
        root.weatherLocation = location
        root.weatherAutoLocation = false
        root.save()
    }

    function setWeatherPlace(value) {
        const place = Places.normalize(value)
        if (!place) return
        root.weatherLocation = place.name
        root.weatherPlace = place
        root.weatherAutoLocation = false
        root.save()
    }

    function setWeatherAutoLocation(value) {
        root.weatherAutoLocation = !!value
        root.save()
    }

    function setTimeZone(value) {
        const zone = String(value || "").trim()
        if (zone === "") return
        root.timeZone = zone
        root.save()
    }

    Component.onCompleted: root.load()
}
