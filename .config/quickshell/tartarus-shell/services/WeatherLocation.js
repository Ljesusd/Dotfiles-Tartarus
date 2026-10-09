// Keep the identity/coordinates of a selected place, not just its city name.
function clean(value) { return typeof value === "string" ? value.trim() : "" }
function coordinate(value, limit) {
    if (value === null || value === undefined || value === "") return null
    if (typeof value !== "number" && typeof value !== "string") return null
    if (typeof value === "string" && !value.trim()) return null
    const result = Number(value)
    return Number.isFinite(result) && Math.abs(result) <= limit ? result : null
}
function label(name, country, countryCode) {
    return [clean(name), clean(country) || clean(countryCode)].filter(Boolean).join(" / ")
}
function normalize(value) {
    if (!value || typeof value !== "object") return null
    const name = clean(value.name)
    const lat = coordinate(value.lat === undefined ? value.latitude : value.lat, 90)
    const lon = coordinate(value.lon === undefined ? value.longitude : value.lon, 180)
    if (!name || lat === null || lon === null) return null
    const country = clean(value.country)
    const countryCode = clean(value.countryCode || value.country_code).toUpperCase()
    const region = clean(value.region || value.admin1)
    const locality = clean(value.admin2)
    const detail = [region, locality].filter((part, i, all) => part && part !== name && all.indexOf(part) === i).join(" · ")
    return { id: Number.isInteger(value.id) ? value.id : null, name: name,
        country: country, countryCode: countryCode, region: region, admin2: locality,
        lat: lat, lon: lon, timezone: clean(value.timezone),
        label: label(name, country, countryCode), detail: detail }
}
function results(data) {
    if (!data || !Array.isArray(data.results)) return []
    const seen = {}
    return data.results.map(normalize).filter(place => {
        if (!place) return false
        const key = place.id === null ? place.lat + ":" + place.lon : String(place.id)
        if (seen[key]) return false
        seen[key] = true
        return true
    }).slice(0, 8)
}
function searchUrl(query, count) {
    // Accept either “Madrid, España” or the displayed “Madrid / España”.
    const name = clean(query).replace(/\s*\/\s*/g, ", ")
    return "https://geocoding-api.open-meteo.com/v1/search?language=es&format=json&count="
        + (count || 8) + "&name=" + encodeURIComponent(name)
}
