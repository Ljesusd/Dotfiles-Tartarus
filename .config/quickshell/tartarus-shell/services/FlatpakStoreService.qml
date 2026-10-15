pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

// Small Flathub client for the launcher. It deliberately uses Flatpak's
// command line interface instead of embedding a second package manager: the
// launcher only searches, installs for the current user and updates Flatpaks.
QtObject {
    id: root

    signal applicationInstalled(string applicationId)

    property string query: ""
    property var results: []
    property var installedIds: ({})
    property string status: "Escribe el nombre de una aplicación para buscar en Flathub."
    property string error: ""
    property string installingId: ""
    property string installedScope: ""
    property string updateScope: ""
    property string searchOutput: ""
    property string installError: ""
    property string pendingQuery: ""
    property string runningQuery: ""
    property string systemUpdateOutput: ""

    readonly property bool busy:
        searchProcess.running
        || installedProcess.running
        || installProcess.running
        || updateProcess.running
        || systemUpdateProcess.running
    readonly property bool updatingFlatpaks: updateProcess.running
    readonly property bool updatingSystem: systemUpdateProcess.running

    function search(value) {
        const next = String(value ?? "").trim()
        root.query = next
        root.pendingQuery = next
        root.error = ""
        root.searchOutput = ""

        if (next === "") {
            searchTimer.stop()
            root.results = []
            root.status = "Escribe el nombre de una aplicación para buscar en Flathub."
            return
        }

        root.status = "Buscando en Flathub…"
        searchTimer.restart()
    }

    function startSearch(value) {
        const next = String(value ?? "").trim()
        if (next === "" || next !== root.query || searchProcess.running)
            return

        root.runningQuery = next
        searchProcess.command = [
            "flatpak", "search", "--json",
            "--columns=application,name,description,version,branch,remotes",
            next
        ]
        searchProcess.running = true
    }

    function parseSearch(text, searchedQuery) {
        if (String(searchedQuery || "") !== root.query)
            return

        let data = []
        try {
            data = JSON.parse(String(text).trim())
        } catch (exception) {
            root.results = []
            root.error = "Flathub devolvió una respuesta no válida."
            root.status = "No se pudo completar la búsqueda."
            return
        }

        if (!Array.isArray(data))
            data = data.results || []

        const seen = ({})
        root.results = data.map(item => {
            const applicationId = String(item.application_id || item.application || "").trim()
            const remotes = String(item.remotes || "")
            if (remotes !== "" && !remotes.toLowerCase().includes("flathub"))
                return null
            if (applicationId === "" || seen[applicationId])
                return null
            seen[applicationId] = true

            return {
                applicationId: applicationId,
                name: String(item.name || applicationId),
                description: String(item.description || "Aplicación de Flathub"),
                version: String(item.version || ""),
                branch: String(item.branch || ""),
                remotes: remotes,
                installed: root.installedIds[applicationId] === true
            }
        }).filter(item => item !== null)

        if (root.results.length === 0)
            root.status = "No se encontraron aplicaciones en Flathub."
        else
            root.status = root.results.length + (root.results.length === 1 ? " resultado" : " resultados")

        root.refreshInstalled()
    }

    function decorateResults() {
        root.results = root.results.map(item => {
            return Object.assign({}, item, {
                installed: root.installedIds[item.applicationId] === true
            })
        })
    }

    function refreshInstalled() {
        if (installedProcess.running)
            installedProcess.running = false

        root.installedIds = ({})
        root.installedScope = "user"
        installedProcess.command = [
            "flatpak", "list", "--user", "--app", "--columns=application"
        ]
        installedProcess.running = true
    }

    function consumeInstalled(text) {
        const next = Object.assign({}, root.installedIds)
        String(text).split(/\r?\n/).forEach(line => {
            const id = line.trim()
            if (id !== "")
                next[id] = true
        })
        root.installedIds = next

        if (root.installedScope === "user") {
            root.installedScope = "system"
            installedProcess.command = [
                "flatpak", "list", "--system", "--app", "--columns=application"
            ]
            installedProcess.running = true
            return
        }

        root.decorateResults()
    }

    function install(item) {
        if (!item || !item.applicationId || item.installed || root.busy)
            return

        root.error = ""
        root.installError = ""
        root.installingId = item.applicationId
        root.status = "Instalando " + item.name + "…"
        installProcess.command = [
            "flatpak", "install", "--user", "--noninteractive", "--assumeyes",
            "flathub", item.applicationId
        ]
        installProcess.running = true
    }

    function updateFlatpaks() {
        if (root.busy)
            return

        root.error = ""
        root.updateScope = "user"
        root.status = "Actualizando Flatpaks del usuario…"
        updateProcess.command = [
            "flatpak", "update", "--user", "--noninteractive", "--assumeyes"
        ]
        updateProcess.running = true
    }

    function updateSystem() {
        if (root.busy)
            return

        root.error = ""
        root.systemUpdateOutput = ""
        root.status = "Actualizando Arch y AUR…"
        systemUpdateProcess.command = [
            "paru", "-Syu", "--noconfirm", "--skipreview",
            "--sudo", "pkexec"
        ]
        systemUpdateProcess.running = true
    }

    readonly property Timer searchTimer: Timer {
        id: searchTimer
        interval: 260
        repeat: false
        onTriggered: root.startSearch(root.pendingQuery)
    }

    readonly property Process searchProcess: Process {
        id: searchProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseSearch(text, root.runningQuery)
        }
        stderr: StdioCollector {
            id: searchStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            const finishedQuery = root.runningQuery
            root.runningQuery = ""

            if (finishedQuery !== root.query) {
                if (root.query !== "")
                    searchTimer.restart()
                return
            }

            if (exitCode !== 0 && root.results.length === 0) {
                root.error = String(searchStderr.text || "").trim()
                root.status = root.error !== ""
                    ? root.error.slice(-240)
                    : "No se pudo buscar en Flathub."
            }
        }
    }

    readonly property Process installedProcess: Process {
        id: installedProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.consumeInstalled(text)
        }
    }

    readonly property Process installProcess: Process {
        id: installProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector {
            id: installStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            const id = root.installingId
            const item = root.results.find(entry => entry.applicationId === id)
            if (exitCode === 0) {
                root.installingId = ""
                root.status = (item?.name || id) + " instalada para tu usuario."
                root.applicationInstalled(id)
                root.refreshInstalled()
            } else {
                root.installingId = ""
                root.installError = String(installStderr.text || "").trim()
                root.error = root.installError !== ""
                    ? root.installError.slice(-500)
                    : "La instalación terminó con código " + exitCode + "."
                root.status = "No se pudo instalar la aplicación."
            }
        }
    }

    readonly property Process updateProcess: Process {
        id: updateProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector {
            id: updateStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = String(updateStderr.text || "").trim()
                root.status = root.error !== ""
                    ? root.error.slice(-500)
                    : "La actualización de Flatpaks terminó con código " + exitCode + "."
                return
            }

            if (root.updateScope === "user") {
                root.updateScope = "system"
                root.status = "Actualizando Flatpaks del sistema…"
                updateProcess.command = [
                    "pkexec", "flatpak", "update", "--system",
                    "--noninteractive", "--assumeyes"
                ]
                updateProcess.running = true
                return
            }

            root.status = "Flatpaks actualizados."
            root.refreshInstalled()
        }
    }

    readonly property Process systemUpdateProcess: Process {
        id: systemUpdateProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.systemUpdateOutput = String(text || "").trim()
        }
        stderr: StdioCollector {
            id: systemUpdateStderr
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const detail = String(systemUpdateStderr.text || "").trim()
                root.error = detail !== ""
                    ? detail.slice(-500)
                    : "La actualización del sistema terminó con código " + exitCode + "."
                root.status = "No se pudo actualizar el sistema."
            } else {
                root.error = ""
                root.status = "Actualización del sistema terminada."
            }
        }
    }
}
