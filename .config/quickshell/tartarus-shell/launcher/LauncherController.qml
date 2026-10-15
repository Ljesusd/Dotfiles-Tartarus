import QtQml
import "../services" as Services
import "LauncherModes.js" as Modes

QtObject {
    id: root

    signal closeRequested()

    required property var launcherState
    required property var applications
    required property var themes
    required property var actions
    required property var wallpapers
    required property string monitorName
    property var shellState: null
    property var dockerPage: null

    property int selectedIndex: 0

    readonly property string normalizedQuery:
        root.launcherState.query
            .trim()
            .toLowerCase()

    readonly property int mode: Modes.resolve(root.normalizedQuery)

    readonly property string applicationQuery:
        root.mode === Modes.Mode.Applications
            ? root.launcherState.query
            : ""

    readonly property string dockerQuery: root.mode === Modes.Mode.Docker
        ? root.launcherState.query.trim().slice(7).trim() : ""

    readonly property string calculatorQuery: root.mode === Modes.Mode.Calculator
        ? root.launcherState.query.trim().slice(5).trim() : ""

    readonly property string installerQuery: root.mode === Modes.Mode.Installer
        ? root.launcherState.query.trim().replace(/^>install(?:er)?\s*/, "") : ""

    readonly property string storeQuery: root.mode === Modes.Mode.Store
        ? root.launcherState.query.trim().slice(6).trim() : ""

    readonly property string rashinQuery: root.mode === Modes.Mode.Rashin
        ? root.launcherState.query.trim().slice(1).trim() : ""

    readonly property string actionQuery:
        root.mode === Modes.Mode.Actions
            ? root.launcherState.query
                .slice(1)
                .trim()
            : ""

    readonly property string wallpaperQuery: {
        if (root.mode !== Modes.Mode.Wallpaper)
            return ""

        const prefix = ">wallpaper"

        return root.launcherState.query
            .slice(prefix.length)
            .trim()
    }

    readonly property string schemeQuery: {
        if (root.mode !== Modes.Mode.Schemes)
            return ""

        const prefix = ">scheme"

        return root.launcherState.query
            .slice(prefix.length)
            .trim()
    }

    readonly property int currentCount: {
        let itemCount = 0
        switch (root.mode) {
        case Modes.Mode.Docker:
            return Services.DockerService.grouped(root.dockerQuery).length
        case Modes.Mode.Applications:
            return root.applications
                ? root.applications.filtered(root.applicationQuery).length
                : 0
        case Modes.Mode.Actions:
            itemCount = root.actions
                ? root.actions.filtered(root.actionQuery).length
                : 0
            return itemCount
        case Modes.Mode.Schemes:
            itemCount = root.themes
                ? root.themes.filtered(root.schemeQuery).length
                : 0
            return itemCount
        case Modes.Mode.Wallpaper:
            itemCount = root.wallpapers
                ? root.wallpapers.filtered(root.wallpaperQuery).length
                : 0
            return itemCount
        case Modes.Mode.Calculator:
            return 0
        case Modes.Mode.Installer:
            return 0
        case Modes.Mode.Store:
            return Services.FlatpakStoreService.results.length
        case Modes.Mode.Rashin:
            return 0
        default:
            return 0
        }
    }

    function select(index) {
        const count = root.currentCount

        if (count <= 0) {
            root.selectedIndex = -1
            return
        }

        root.selectedIndex = Math.max(
            0,
            Math.min(index, count - 1)
        )
    }

    function resetSelection() {
        root.selectedIndex =
            root.currentCount > 0
                ? 0
                : -1
    }

    function moveUp() {
        if (root.currentCount <= 0)
            return

        root.select(root.selectedIndex - 1)
    }

    function moveDown() {
        if (root.currentCount <= 0)
            return

        root.select(root.selectedIndex + 1)
    }

    function wrapIndex(index, count) {
        return ((index % count) + count) % count
    }

    function moveLeft() {
        if (root.currentCount <= 0)
            return

        if (root.mode === Modes.Mode.Wallpaper) {
            root.selectedIndex = root.wrapIndex(
                root.selectedIndex - 1,
                root.currentCount
            )
            return
        }

        root.moveUp()
    }

    function moveRight() {
        if (root.currentCount <= 0)
            return

        if (root.mode === Modes.Mode.Wallpaper) {
            root.selectedIndex = root.wrapIndex(
                root.selectedIndex + 1,
                root.currentCount
            )
            return
        }

        root.moveDown()
    }

    function acceptApplication() {
        const values = root.applications
            ? root.applications.filtered(root.applicationQuery)
            : null
        const index = root.selectedIndex

        if (!values || index < 0 || index >= values.length)
            return

        const app = values[index]

        if (!app)
            return

        root.applications.launch(app)
        root.launcherState.query = ""
        root.closeRequested()
    }

    function acceptAction() {
        const items = root.actions
            ? root.actions.filtered(root.actionQuery)
            : null
        const index = root.selectedIndex

        if (!items || index < 0 || index >= items.length)
            return

        const action = items[index]

        if (!action)
            return

        if (action.command === "clipboard") {
            root.launcherState.query = ""
            root.closeRequested()
            Services.ClipboardService.open = true
            Services.ClipboardService.query = ""
            Services.ClipboardService.selectedIndex = 0
            return
        }

        if (action.command === "wallpaper") {
            root.launcherState.query = ">wallpaper"
            root.launcherState.focusSearch()
            root.resetSelection()
            return
        }

        if (action.command === "reapply-wallpapers") {
            root.wallpapers.applySaved()
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        if (action.command === "calc") {
            root.launcherState.query = ">calc"
            root.launcherState.focusSearch()
            root.resetSelection()
            return
        }

        if (action.command === "install") {
            root.launcherState.query = ">install"
            root.launcherState.focusSearch()
            root.resetSelection()
            return
        }

        if (action.command === "store") {
            root.launcherState.query = ">store"
            root.launcherState.focusSearch()
            root.resetSelection()
            return
        }

        if (action.command === "timer") {
            Services.TimerService.startTimer(
                root.actionQuery.slice("timer".length).trim()
            )
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        if (action.command === "pomodoro") {
            Services.TimerService.startPomodoro(root.actionQuery)
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        if (action.command === "record") {
            Services.RecorderService.start(root.monitorName)
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        if (action.command === "whisp") {
            Services.WhispService.open()
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        if (action.command === "weather") {
            root.launcherState.query = ">weather"
            root.launcherState.focusSearch()
            root.resetSelection()
            return
        }

        if (action.command === "whisp-export") {
            Services.WhispService.exportToObsidian()
            root.launcherState.query = ""
            root.closeRequested()
            return
        }

        root.launcherState.query =
            ">" + action.command
        root.launcherState.focusSearch()
        root.resetSelection()
    }

    function acceptScheme() {
        const items = root.themes
            ? root.themes.filtered(root.schemeQuery)
            : null
        const index = root.selectedIndex

        if (!items || index < 0 || index >= items.length)
            return

        const theme = items[index]

        if (!theme)
            return

        root.themes.setTheme(theme.slug)
    }

    function accept() {
        if (root.mode === Modes.Mode.Docker) {
            if (root.dockerPage) root.dockerPage.acceptSelection()
            return
        }
        if (root.mode === Modes.Mode.Rashin) {
            root.acceptRashin()
            return
        }
        if (root.selectedIndex < 0)
            return

        switch (root.mode) {
        case Modes.Mode.Applications:
            root.acceptApplication()
            break
        case Modes.Mode.Actions:
            root.acceptAction()
            break
        case Modes.Mode.Schemes:
            root.acceptScheme()
            break
        case Modes.Mode.Wallpaper:
            root.acceptWallpaper()
            break
        case Modes.Mode.Calculator:
        case Modes.Mode.Weather:
        case Modes.Mode.Installer:
            break
        case Modes.Mode.Store:
            root.acceptStore()
            break
        }
    }

    function acceptWallpaper() {
        const items = root.wallpapers
            ? root.wallpapers.filtered(root.wallpaperQuery)
            : null
        const index = root.selectedIndex

        if (!items || index < 0 || index >= items.length)
            return

        const wallpaper = items[index]

        if (!wallpaper || !wallpaper.path) {
            return
        }

        root.wallpapers.setWallpaper(wallpaper.path, root.monitorName)
    }

    function acceptStore() {
        const items = Services.FlatpakStoreService.results
        const index = root.selectedIndex

        if (!items || index < 0 || index >= items.length)
            return

        Services.FlatpakStoreService.install(items[index])
    }

    function acceptRashin() {
        Services.RashinService.ask(root.rashinQuery)
        root.launcherState.query = "\\"
        root.launcherState.focusSearch()
    }

    function openRashinSettings() {
        root.closeRequested()
        if (root.shellState)
            root.shellState.openControlCenterPage(18)
    }

    function close() {
        root.closeRequested()
    }

    function backFromSchemes() {
        root.launcherState.query = ">"
        root.launcherState.focusSearch()
    }

    function backFromActions() {
        root.launcherState.query = ""
        root.launcherState.focusSearch()
    }

    function backFromWallpapers() {
        root.launcherState.query = ">"
        root.launcherState.focusSearch()
    }

    function goBack() {
        switch (root.mode) {
        case Modes.Mode.Docker:
            if (root.dockerPage && root.dockerPage.back()) return
            root.launcherState.query = ">"
            root.launcherState.focusSearch()
            break
        case Modes.Mode.Schemes:
            root.backFromSchemes()
            break
        case Modes.Mode.Actions:
            root.backFromActions()
            break
        case Modes.Mode.Wallpaper:
            root.backFromWallpapers()
            break
        case Modes.Mode.Calculator:
        case Modes.Mode.Weather:
        case Modes.Mode.Installer:
        case Modes.Mode.Store:
            if (root.mode === Modes.Mode.Installer
                    && Services.InstallerService.busy)
                return
            root.launcherState.query = ">"
            root.launcherState.focusSearch()
            break
        case Modes.Mode.Rashin:
            root.launcherState.query = ""
            root.launcherState.focusSearch()
            break
        case Modes.Mode.Applications:
        default:
            root.close()
            break
        }
    }
}
