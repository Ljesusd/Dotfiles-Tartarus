import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property string query: ""
    property var usage: ({})

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
    }

    readonly property var applications: ScriptModel {
        values: DesktopEntries.applications.values
            .filter(app => {
                return root.matchesPrefix(
                    app.name,
                    root.query
                )
            })
            .sort((a, b) => {
                return root.frequency(b) - root.frequency(a)
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
