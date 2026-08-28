import QtQml

QtObject {
    id: root

    enum Mode {
        Applications,
        Actions,
        Schemes
    }

    required property var launcherState
    required property var applications
    required property var themes
    required property var actions

    property int selectedIndex: 0

    readonly property string normalizedQuery:
        root.launcherState.query
            .trim()
            .toLowerCase()

    readonly property int mode: {
        if (root.normalizedQuery.startsWith(">scheme"))
            return LauncherController.Mode.Schemes

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

    readonly property string schemeQuery: {
        if (root.mode !== LauncherController.Mode.Schemes)
            return ""

        const prefix = ">scheme"

        return root.launcherState.query
            .slice(prefix.length)
            .trim()
    }

    readonly property int currentCount: {
        switch (root.mode) {
        case LauncherController.Mode.Applications:
            return (
                root.applications
                && root.applications.applications
                && root.applications.applications.values
            )
                ? root.applications.applications.values.length
                : 0
        case LauncherController.Mode.Actions: {
            const items = root.actions
                ? root.actions.filtered(root.actionQuery)
                : []

            return items ? items.length : 0
        }
        case LauncherController.Mode.Schemes: {
            const items = root.themes
                ? root.themes.filtered(root.schemeQuery)
                : []

            return items ? items.length : 0
        }
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
        root.launcherState.close()
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
        }
    }

    function close() {
        root.launcherState.close()
    }

    function backFromSchemes() {
        root.launcherState.query = ">"
        root.launcherState.focusSearch()
    }

    function backFromActions() {
        root.launcherState.query = ""
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
        case LauncherController.Mode.Applications:
        default:
            root.close()
            break
        }
    }
}
