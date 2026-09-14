import QtQml
import "../services" as Services

QtObject {
    id: root

    signal closeRequested()

    enum Mode {
        Applications,
        Actions,
        Schemes,
        Wallpaper
    }

    required property var launcherState
    required property var applications
    required property var themes
    required property var actions
    required property var wallpapers
    required property string monitorName

    property int selectedIndex: 0

    readonly property string normalizedQuery:
        root.launcherState.query
            .trim()
            .toLowerCase()

    readonly property int mode: {
        if (root.normalizedQuery.startsWith(">scheme"))
            return LauncherController.Mode.Schemes

        if (root.normalizedQuery.startsWith(">wallpaper"))
            return LauncherController.Mode.Wallpaper

        if (root.normalizedQuery.startsWith(">"))
            return LauncherController.Mode.Actions

        return LauncherController.Mode.Applications
    }

    readonly property string applicationQuery:
        root.mode === LauncherController.Mode.Applications
            ? root.launcherState.query
            : ""

    readonly property string actionQuery:
        root.mode === LauncherController.Mode.Actions
            ? root.launcherState.query
                .slice(1)
                .trim()
            : ""

    readonly property string wallpaperQuery: {
        if (root.mode !== LauncherController.Mode.Wallpaper)
            return ""

        const prefix = ">wallpaper"

        return root.launcherState.query
            .slice(prefix.length)
            .trim()
    }

    readonly property string schemeQuery: {
        if (root.mode !== LauncherController.Mode.Schemes)
            return ""

        const prefix = ">scheme"

        return root.launcherState.query
            .slice(prefix.length)
            .trim()
    }

    readonly property int currentCount: {
        let itemCount = 0
        switch (root.mode) {
        case LauncherController.Mode.Applications:
            return (
                root.applications
                && root.applications.applications
                && root.applications.applications.values
            )
                ? root.applications.applications.values.length
                : 0
        case LauncherController.Mode.Actions:
            itemCount = root.actions
                ? root.actions.filtered(root.actionQuery).length
                : 0
            return itemCount
        case LauncherController.Mode.Schemes:
            itemCount = root.themes
                ? root.themes.filtered(root.schemeQuery).length
                : 0
            return itemCount
        case LauncherController.Mode.Wallpaper:
            itemCount = root.wallpapers
                ? root.wallpapers.filtered(root.wallpaperQuery).length
                : 0
            return itemCount
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

        if (root.mode === LauncherController.Mode.Wallpaper) {
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

        if (root.mode === LauncherController.Mode.Wallpaper) {
            root.selectedIndex = root.wrapIndex(
                root.selectedIndex + 1,
                root.currentCount
            )
            return
        }

        root.moveDown()
    }

    function acceptApplication() {
        const values = (
            root.applications
            && root.applications.applications
            && root.applications.applications.values
        )
            ? root.applications.applications.values
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
        if (root.selectedIndex < 0)
            return

        switch (root.mode) {
        case LauncherController.Mode.Applications:
            root.acceptApplication()
            break
        case LauncherController.Mode.Actions:
            root.acceptAction()
            break
        case LauncherController.Mode.Schemes:
            root.acceptScheme()
            break
        case LauncherController.Mode.Wallpaper:
            root.acceptWallpaper()
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
        case LauncherController.Mode.Schemes:
            root.backFromSchemes()
            break
        case LauncherController.Mode.Actions:
            root.backFromActions()
            break
        case LauncherController.Mode.Wallpaper:
            root.backFromWallpapers()
            break
        case LauncherController.Mode.Applications:
        default:
            root.close()
            break
        }
    }
}
