import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property var themes: []
    property string currentSlug: ""

    function filtered(query) {
        const normalized =
            query.trim().toLowerCase()

        if (normalized === "")
            return root.themes

        return root.themes.filter(theme => {
            return root.matchesPrefix(
                theme.name,
                normalized
            )
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

    function setTheme(slug) {
        if (!slug || slug === root.currentSlug)
            return

        setProcess.command = [
            "python",
            Quickshell.shellPath("scripts/theme.py"),
            "set",
            slug
        ]

        setProcess.running = true
    }

    readonly property Process listProcess: Process {
        command: [
            "python",
            Quickshell.shellPath("scripts/theme.py"),
            "list",
            "--json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text === "")
                    return

                try {
                    root.themes = JSON.parse(text)

                } catch (error) {
                    console.warn(
                        "Themes: no se pudo interpretar la lista:",
                        error
                    )
                }
            }
        }
    }

    readonly property Process currentProcess: Process {
        command: [
            "python",
            Quickshell.shellPath("scripts/theme.py"),
            "current",
            "--json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text === "")
                    return

                try {
                    const current = JSON.parse(text)

                    root.currentSlug =
                        current.slug ?? ""

                } catch (error) {
                    console.warn(
                        "Themes: no se pudo leer el tema actual:",
                        error
                    )
                }
            }
        }
    }

    readonly property Process setProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                root.currentProcess.running = true
            }
        }
    }

    Component.onCompleted: {
        listProcess.running = true
        currentProcess.running = true
    }
}
