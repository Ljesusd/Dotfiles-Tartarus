// Keep page ids outside a QML enum: Quickshell hot reload can retain the old
// enum metadata, leaving newly added pages undefined until a full restart.
var Mode = Object.freeze({
    Applications: 0,
    Actions: 1,
    Schemes: 2,
    Wallpaper: 3,
    Docker: 4,
    Calculator: 5,
    Weather: 6,
    Installer: 7,
    Store: 8,
    Rashin: 9
})

function resolve(query) {
    const value = String(query || "").trim().toLowerCase()
    if (/^>docker(?:\s|$)/.test(value)) return Mode.Docker
    if (/^>calc(?:\s|$)/.test(value)) return Mode.Calculator
    if (/^>weather(?:\s|$)/.test(value)) return Mode.Weather
    if (/^>install(?:er)?(?:\s|$)/.test(value)) return Mode.Installer
    if (/^>store(?:\s|$)/.test(value)) return Mode.Store
    if (value.startsWith("\\")) return Mode.Rashin
    if (value.startsWith(">scheme")) return Mode.Schemes
    if (value.startsWith(">wallpaper")) return Mode.Wallpaper
    if (value.startsWith(">")) return Mode.Actions
    return Mode.Applications
}
