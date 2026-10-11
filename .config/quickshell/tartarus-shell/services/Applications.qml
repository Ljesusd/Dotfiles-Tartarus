import Quickshell
import Quickshell.Io
import QtQml
import "." as Services

QtObject {
    id: root

    property var usage: ({})
    property var applicationValues: []

    readonly property FileView usageFile: FileView {
        path: Quickshell.stateDir + "/app-usage.json"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        const data = usageFile.text()

        if (data.trim() !== "") {
            try {
                usage = JSON.parse(data)
            } catch (error) {
                console.warn("No se pudo leer app-usage.json:", error)
            }
        }

        root.refresh()
    }

    readonly property var applications: ScriptModel {
        values: root.applicationValues.slice()
            .sort((a, b) => {
                return root.frequency(b) - root.frequency(a)
            })
    }

    function refresh() {
        root.applicationValues = DesktopEntries.applications.values.slice()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refresh() }
    }

    Connections {
        target: Services.InstallerService
        function onApplicationInstalled() { root.refresh() }
    }

    function filtered(query) {
        return root.applications.values.filter(app => {
            return root.matchesPrefix(app.name, query)
        })
    }

    function matchesPrefix(text, query) {
        const normalized =
            query.trim().toLowerCase()

        if (normalized === "")
            return true

        return text
            .toLowerCase()
            .split(/\s+/)
            .some(word => {
                return word.startsWith(normalized)
            })
    }

    function frequency(app) {
        return root.usage[app.id] ?? 0
    }

    function launch(app) {
        const updatedUsage = Object.assign({}, root.usage)

        updatedUsage[app.id] = root.frequency(app) + 1

        root.usage = updatedUsage

        usageFile.setText(
            JSON.stringify(root.usage, null, 2)
        )

        app.execute()
    }
}
