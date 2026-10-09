// Presentation inspired by Meteobar, BOM Weather, Detailed Weather and
// guiestrela/weather. Solar geometry uses NOAA's fractional-year formula;
// the solar arc/twilight distinction follows Linecast's SunshineView.

function number(value) {
    if (value === null || value === undefined || value === "") return null
    const result = Number(value)
    return Number.isFinite(result) ? result : null
}
function rounded(value) { const n = number(value); return n === null ? null : Math.round(n) }
function at(array, index) { return Array.isArray(array) ? number(array[index]) : null }
// Forecast dates are already local to the selected location; do not parse them
// as UTC dates and accidentally shift their calendar day.
function dateLabel(date) {
    return typeof date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(date)
        ? date.slice(8, 10) + "/" + date.slice(5, 7) : ""
}

function icon(code, isDay) {
    code = number(code)
    if (code === 0) return isDay ? "sunny" : "clear_night"
    if (code === 1 || code === 2) return isDay ? "partly_cloudy_day" : "partly_cloudy_night"
    if (code === 45 || code === 48) return "foggy"
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return "rainy"
    if ([71, 73, 75, 77, 85, 86].includes(code)) return "weather_snowy"
    if ([95, 96, 99].includes(code)) return "thunderstorm"
    return "cloud"
}
function description(code) {
    return ({ 0: "Despejado", 1: "Mayormente despejado", 2: "Parcialmente nublado", 3: "Nublado",
        45: "Niebla", 48: "Niebla helada", 51: "Llovizna ligera", 53: "Llovizna", 55: "Llovizna intensa",
        56: "Llovizna helada", 57: "Llovizna helada", 61: "Lluvia ligera", 63: "Lluvia", 65: "Lluvia intensa",
        66: "Lluvia helada", 67: "Lluvia helada", 71: "Nieve ligera", 73: "Nieve", 75: "Nieve intensa",
        77: "Granizo de nieve", 80: "Chubascos", 81: "Chubascos", 82: "Chubascos intensos",
        85: "Chubascos de nieve", 86: "Chubascos de nieve", 95: "Tormenta", 96: "Tormenta con granizo",
        99: "Tormenta con granizo" })[code] || "Sin datos"
}
function uvLabel(value) {
    if (number(value) === null) return "Sin datos"
    if (value < 3) return "Bajo"
    if (value < 6) return "Moderado"
    if (value < 8) return "Alto"
    if (value < 11) return "Muy alto"
    return "Extremo"
}
function airLabel(value) {
    if (number(value) === null) return "Sin datos"
    if (value <= 20) return "Buena"
    if (value <= 40) return "Aceptable"
    if (value <= 60) return "Moderada"
    if (value <= 80) return "Mala"
    if (value <= 100) return "Muy mala"
    return "Extremadamente mala"
}
function localTime(timestamp, offset) { return new Date(timestamp + offset * 1000).toISOString().slice(0, 16) }
function minutes(time) {
    if (typeof time !== "string" || !/^\d{2}:\d{2}$/.test(time)) return null
    return Number(time.slice(0, 2)) * 60 + Number(time.slice(3, 5))
}
function clock(value) {
    if (!Number.isFinite(value)) return ""
    const n = ((Math.round(value) % 1440) + 1440) % 1440
    return String(Math.floor(n / 60)).padStart(2, "0") + ":" + String(n % 60).padStart(2, "0")
}
// Anochecer: end of civil twilight (-6°). Use the provider's sunset plus
// calculated twilight duration, preserving its more precise sunset time.
function dusk(date, latitude, sunset) {
    if (number(latitude) === null || minutes(sunset) === null) return ""
    const day = new Date(date + "T12:00:00Z")
    if (!Number.isFinite(day.getTime())) return ""
    const doy = Math.floor((day - Date.UTC(day.getUTCFullYear(), 0, 1)) / 86400000) + 1
    const gamma = 2 * Math.PI / 365 * (doy - 1)
    const decl = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma)
        - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma)
        - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma)
    const lat = latitude * Math.PI / 180
    function angle(altitude) {
        const cosine = (Math.sin(altitude * Math.PI / 180) - Math.sin(lat) * Math.sin(decl))
            / (Math.cos(lat) * Math.cos(decl))
        return cosine < -1 || cosine > 1 ? null : Math.acos(cosine)
    }
    const setAngle = angle(-0.833), civilAngle = angle(-6)
    if (setAngle === null || civilAngle === null) return ""
    return clock(minutes(sunset) + (civilAngle - setAngle) * 180 / Math.PI * 4)
}
function normalize(data, latitude) {
    if (!data || !data.current || !data.hourly || !data.daily) throw new Error("Pronóstico incompleto")
    const c = data.current, h = data.hourly, d = data.daily
    if (number(c.temperature_2m) === null || !Array.isArray(h.time) || !Array.isArray(d.time))
        throw new Error("Pronóstico sin temperatura o fechas")
    const hourIndex = h.time.findIndex(t => t.slice(0, 13) === String(c.time).slice(0, 13))
    const current = { temp: rounded(c.temperature_2m), feelsLike: rounded(c.apparent_temperature),
        humidity: number(c.relative_humidity_2m), wind: rounded(c.wind_speed_10m),
        code: number(c.weather_code), isDay: c.is_day === 1, cloud: number(c.cloud_cover),
        uv: at(h.uv_index, hourIndex), rain: at(h.precipitation_probability, hourIndex), time: String(c.time) }
    const hourly = h.time.slice(0, 50).map((time, i) => ({ time: String(time),
        temp: rounded(at(h.temperature_2m, i)), code: at(h.weather_code, i),
        rain: at(h.precipitation_probability, i), cloud: at(h.cloud_cover, i),
        uv: at(h.uv_index, i), isDay: at(h.is_day, i) === 1 })).filter(item => item.temp !== null)
    const daily = d.time.slice(0, 2).map((date, i) => {
        const sunrise = d.sunrise && d.sunrise[i] ? String(d.sunrise[i]).slice(11, 16) : ""
        const sunset = d.sunset && d.sunset[i] ? String(d.sunset[i]).slice(11, 16) : ""
        return { date: String(date), code: at(d.weather_code, i), max: rounded(at(d.temperature_2m_max, i)),
            min: rounded(at(d.temperature_2m_min, i)), rain: at(d.precipitation_probability_max, i),
            uv: at(d.uv_index_max, i), sunrise: sunrise, sunset: sunset, dusk: dusk(String(date), latitude, sunset) }
    })
    return { current: current, hourly: hourly, daily: daily, timezone: String(data.timezone || "UTC"),
        offset: number(data.utc_offset_seconds) || 0 }
}
function hoursForDay(hourly, date, now) {
    return hourly.filter(h => h.time.slice(0, 10) === date && h.time.slice(0, 13) >= now.slice(0, 13))
}
function windows(hours) {
    const runs = []
    hours.forEach(hour => {
        let label = ""
        if (icon(hour.code, hour.isDay) === "rainy") label = "Lluvia prevista"
        else if (icon(hour.code, hour.isDay) === "thunderstorm") label = "Tormenta prevista"
        else if (hour.rain !== null && hour.rain >= 40) label = "Posible lluvia"
        else if (hour.isDay && ((hour.cloud !== null && hour.cloud >= 65) || hour.code === 3)) label = "Nublado"
        else if (hour.isDay && hour.cloud !== null && hour.cloud <= 25) label = "Cielo despejado"
        if (!label) return
        const previous = runs[runs.length - 1], start = hour.time.slice(11, 16), end = clock(minutes(start) + 60)
        if (previous && previous.label === label && previous.end === start) previous.end = end
        else runs.push({ label: label, start: start, end: end })
    })
    return runs
}

function adviceRanges(hours, now) {
    const ranges = []
    hours.forEach(hour => {
        const originalStart = hour.time.slice(11, 16)
        const end = clock(minutes(originalStart) + 60)
        const previous = ranges[ranges.length - 1]
        const start = hour.time.slice(0, 13) === now.slice(0, 13) ? now.slice(11, 16) : originalStart
        if (previous && previous.end === originalStart) previous.end = end
        else ranges.push({ start: start, end: end })
    })
    return ranges.slice(0, 3).map(range => range.start + "–" + range.end).join(" · ")
        + (ranges.length > 3 ? " · …" : "")
}

// UV >= 3 follows WHO guidance; sunscreen complements shade/protective clothing.
// https://www.who.int/news-room/fact-sheets/detail/ultraviolet-radiation
// Rain >= 40% is a planning preference, not an official weather-warning threshold.
function planningAdvice(hourly, day, now, current) {
    if (!day || !day.date || !now) return []
    const today = day.date === now.slice(0, 10)
    const currentHour = today && current && typeof current.time === "string"
        && current.time.slice(0, 13) === now.slice(0, 13)
    const hours = hoursForDay(hourly || [], day.date, now).map(hour => {
        if (!currentHour || hour.time.slice(0, 13) !== now.slice(0, 13)) return hour
        // Current conditions can supersede the forecast, without mutating it.
        return Object.assign({}, hour, {
            code: number(current.code) === null ? hour.code : current.code,
            rain: number(current.rain) === null ? hour.rain : current.rain,
            uv: number(current.uv) === null ? hour.uv : current.uv,
            isDay: typeof current.isDay === "boolean" ? current.isDay : hour.isDay
        })
    })
    if (currentHour && !hours.some(hour => hour.time.slice(0, 13) === now.slice(0, 13)))
        hours.unshift(Object.assign({}, current, { time: now.slice(0, 13) + ":00" }))
    const period = today ? "Hoy" : "Mañana"
    const when = selected => !today ? "Mañana" : selected[0].time.slice(0, 13) === now.slice(0, 13) ? "Ahora" : "Más tarde"
    const rainy = hours.filter(hour => ["rainy", "thunderstorm"].includes(icon(hour.code, hour.isDay))
        || (number(hour.rain) !== null && hour.rain >= 40))
    const sunny = hours.filter(hour => hour.isDay === true && number(hour.uv) !== null && hour.uv >= 3)
    const advice = []
    if (rainy.length) {
        const storms = rainy.filter(hour => icon(hour.code, hour.isDay) === "thunderstorm")
        const probabilities = rainy.map(hour => number(hour.rain)).filter(value => value !== null)
        const probability = probabilities.length ? Math.max(...probabilities) : null
        advice.push({ kind: "rain", severity: "info", icon: "umbrella", title: "Paraguas a mano",
            when: when(rainy), text: "Si sales, lleva un paraguas: hay lluvia prevista o una posibilidad apreciable.",
            detail: period + " · " + adviceRanges(rainy, now)
                + (probability === null ? " · Lluvia prevista" : " · Probabilidad máx. " + Math.round(probability) + "%") })
        if (storms.length) advice.unshift({ kind: "storm", severity: "danger", icon: "thunderstorm",
            title: "Planifica resguardo", when: when(storms),
            text: "Si hay tormenta, busca un lugar cerrado. El paraguas no protege de los rayos.",
            detail: period + " · " + adviceRanges(storms, now) + " · Tormentas previstas" })
    }
    if (sunny.length) {
        const peak = Math.max(...sunny.map(hour => Number(hour.uv)))
        advice.push({ kind: "sun", severity: peak >= 8 ? "danger" : "warning", icon: "sunny",
            title: "Usa bloqueador solar", when: when(sunny),
            text: peak >= 8 ? "Evita el sol directo. Si sales, combina bloqueador solar, sombra y ropa protectora."
                : "Si sales, usa bloqueador solar y acompáñalo con sombra, sombrero y ropa protectora.",
            detail: period + " · " + adviceRanges(sunny, now) + " · UV máx. " + peak.toFixed(1) + " (" + uvLabel(peak) + ")" })
    }
    if (!advice.length) {
        const complete = hours.length && hours.every(hour =>
            number(hour.code) !== null && number(hour.rain) !== null
            && (hour.isDay === false || (hour.isDay === true && number(hour.uv) !== null)))
        advice.push({ kind: "summary", severity: "muted", icon: "info", when: "",
            title: complete ? "Sin avisos por ahora" : "Faltan datos para recomendar",
            text: complete ? (today ? "Sin avisos de lluvia o UV elevado en las horas que quedan." : "Sin avisos de lluvia o UV elevado para mañana.")
                : "No hay suficientes datos horarios de lluvia o UV. Revisa el pronóstico antes de salir.",
            detail: "La previsión puede cambiar; no es una garantía." })
    }
    return advice
}
