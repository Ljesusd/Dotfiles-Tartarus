pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    readonly property string defaultEndpoint: "http://127.0.0.1:8081/v1"
    readonly property string defaultModel: "gemma-4-E4B-it-qat-UD-Q4_K_XL"
    readonly property string defaultVaultPath: Quickshell.env("HOME") + "/.local/share/tartarus/rashin"
    readonly property string statePath: Quickshell.stateDir + "/rashin.json"
    readonly property string historyPath: Quickshell.stateDir + "/rashin-asks.jsonl"
    readonly property string indexScript: Quickshell.shellPath("scripts/rashin-index.py")
    readonly property string askScript: Quickshell.shellPath("scripts/rashin-ask.py")
    readonly property string controlScript: Quickshell.shellPath("scripts/rashin-control.sh")
    readonly property string daemonUrl: "http://127.0.0.1:3610"

    property bool enabled: false
    readonly property bool serviceTransition: root.serviceControlProcess.running
    property bool serviceTargetEnabled: false
    property int startupProbeAttempts: 0
    property string endpoint: root.defaultEndpoint
    property string model: root.defaultModel
    property string vaultPath: root.defaultVaultPath
    property bool backendAvailable: false
    property bool daemonAvailable: false
    property bool indexed: false
    property bool busy: false
    property string modelLabel: "Modelo local"
    property string statusText: "Desactivado"
    property string answer: ""
    property string lastQuestion: ""
    property string errorText: ""
    property string lastIndexedAt: ""
    property string pendingQuestion: ""
    property string permissionRequestId: ""
    property string permissionTitle: ""
    property var permissionOptions: []
    property bool askOutputReceived: false
    property bool daemonAskOutputReceived: false
    property bool indexOutputReceived: false
    property var historyItems: []
    property bool turnVisible: false
    readonly property string connectionText: root.serviceTransition
        ? (root.enabled ? "Encendiendo…" : "Apagando…")
        : !root.enabled ? "Desconectado"
        : root.backendAvailable ? "Conectado"
        : root.daemonProbeProcess.running || root.probeProcess.running
            || root.startupProbeTimer.running || (root.busy && root.turnVisible) ? "Conectando"
        : "Desconectado"

    readonly property FileView settingsFile: FileView {
        path: root.statePath
        blockLoading: true
        printErrors: false
    }

    readonly property FileView historyFile: FileView {
        path: root.historyPath
        blockLoading: true
        printErrors: false
        onLoaded: if (!root.busy) root.loadHistory()
    }

    property Process probeProcess: Process {
        id: probeProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleProbe(text)
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code, status) => {
            if (code !== 0 && !root.backendAvailable) {
                root.backendAvailable = false
                root.statusText = root.enabled
                    ? "No se encontró un modelo local"
                    : "Desactivado"
            }
        }
    }

    property Process daemonProbeProcess: Process {
        id: daemonProbeProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleDaemonProbe(text)
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (code, status) => {
            if (code !== 0 && !root.daemonAvailable)
                root.startDirectProbe()
        }
    }

    property Process indexProcess: Process {
        id: indexProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleIndex(text)
        }
        stderr: StdioCollector { id: indexStderr; waitForEnd: true }
        onExited: (code, status) => {
            if (!root.indexOutputReceived) {
                root.busy = false
                root.indexed = false
                root.errorText = String(indexStderr.text || "No se pudo crear la bóveda local.").trim()
                root.statusText = "Error al indexar"
                root.pendingQuestion = ""
            }
        }
    }

    property Process askProcess: Process {
        id: askProcess
        stdout: SplitParser {
            onRead: data => root.handleAskEvent(data)
        }
        stderr: StdioCollector { id: askStderr; waitForEnd: true }
        onExited: (code, status) => {
            // Even a successful exit without a terminal event must unlock input.
            if (!root.askOutputReceived)
                root.failAsk(String(askStderr.text || "La respuesta terminó antes de completarse.").trim())
        }
    }

    property Process daemonAskProcess: Process {
        id: daemonAskProcess
        stdout: SplitParser {
            onRead: data => root.handleDaemonEvent(data)
        }
        stderr: StdioCollector { id: daemonAskStderr; waitForEnd: true }
        onExited: (code, status) => {
            if (!root.daemonAskOutputReceived)
                root.failAsk(String(daemonAskStderr.text || "El daemon de Rashin terminó antes de completar la respuesta.").trim())
        }
    }

    property Process openVaultProcess: Process {}
    property Process openDashboardProcess: Process {}
    property Process setupHermesProcess: Process {}
    property Process permissionProcess: Process {}

    property Process serviceControlProcess: Process {
        stderr: StdioCollector { id: serviceControlStderr; waitForEnd: true }
        onExited: (code, status) => root.finishServiceChange(code, serviceControlStderr.text)
    }

    property Timer startupProbeTimer: Timer {
        interval: 2000
        repeat: true
        onTriggered: {
            if (!root.enabled || root.backendAvailable || ++root.startupProbeAttempts >= 90) {
                stop()
                return
            }
            root.probe()
        }
    }

    function defaults() {
        return {
            enabled: false,
            endpoint: root.defaultEndpoint,
            model: root.defaultModel,
            vaultPath: root.defaultVaultPath
        }
    }

    function save() {
        root.settingsFile.setText(JSON.stringify({
            enabled: root.enabled,
            endpoint: root.endpoint,
            model: root.model,
            vaultPath: root.vaultPath
        }))
    }

    function load() {
        const text = root.settingsFile.text()
        if (!text || !text.trim())
            return
        try {
            const value = JSON.parse(text)
            root.enabled = value.enabled === true
            if (typeof value.endpoint === "string" && value.endpoint.trim() !== "")
                root.endpoint = value.endpoint.trim()
            if (typeof value.model === "string" && value.model.trim() !== "")
                root.model = value.model.trim()
            root.modelLabel = root.formatModelLabel(root.model, {})
            if (typeof value.vaultPath === "string" && value.vaultPath.trim() !== "")
                root.vaultPath = value.vaultPath.trim()
        } catch (error) {
            root.errorText = "La configuración de Rashin no es válida."
        }
    }

    function normalizedEndpoint() {
        let value = String(root.endpoint || "").trim()
        if (value === "")
            value = root.defaultEndpoint
        if (!value.includes("://"))
            value = "http://" + value
        return value
    }

    function formatModelLabel(identifier, metadata) {
        const value = String(identifier || "Modelo local").trim()
        const lower = value.toLowerCase()
        let label = value

        if (lower.includes("gemma-4-e4b"))
            label = lower.includes("qat") ? "Gemma 4 E4B QAT" : "Gemma 4 E4B"
        else if (lower.includes("qwen3.5") && lower.includes("9b"))
            label = "Qwen 3.5 9B"
        else if (lower.includes("qwen") && lower.includes("14b"))
            label = "Qwen 2.5 14B"
        else if (lower.includes("gpt-oss") && lower.includes("20b"))
            label = "GPT-OSS 20B"

        const details = metadata || {}
        const quantization = String(
            details.quantization_level || details.ftype || ""
        ).trim().replace(/\s*-\s*/g, " ")
        if (quantization !== "" && !label.toLowerCase().includes(quantization.toLowerCase()))
            label += " · " + quantization
        return label
    }

    function loadHistory() {
        const raw = root.historyFile.text()
        if (!raw || !raw.trim()) {
            root.historyItems = []
            return
        }

        const entries = []
        raw.split(/\r?\n/).forEach(line => {
            if (!line.trim())
                return
            try {
                const entry = JSON.parse(line)
                if (entry && entry.question && entry.answer)
                    entries.push(entry)
            } catch (error) {
                // Ignore an incomplete final line while the history is being written.
            }
        })
        root.historyItems = entries.slice(-30)
    }

    function refresh() {
        if (!root.busy)
            root.historyFile.reload()
        root.probe()
    }

    function saveAndProbe() {
        if (root.busy)
            return
        root.endpoint = root.normalizedEndpoint()
        root.model = String(root.model || root.defaultModel).trim() || root.defaultModel
        root.vaultPath = String(root.vaultPath || root.defaultVaultPath).trim() || root.defaultVaultPath
        root.save()
        root.backendAvailable = false
        root.probe()
    }

    function setEnabled(value) {
        root.enabled = value === true
        root.errorText = ""
        root.save()
        root.startupProbeTimer.stop()
        root.statusText = root.enabled ? "Encendiendo Rashin y el modelo…" : "Apagando Rashin y el modelo…"
        if (!root.enabled) {
            // Ignore trailing output/exit signals from the cancelled clients.
            root.askOutputReceived = true
            root.daemonAskOutputReceived = true
            root.indexOutputReceived = true
            root.pendingQuestion = ""
            root.clearPermission()
            root.askProcess.running = false
            root.daemonAskProcess.running = false
            root.probeProcess.running = false
            root.daemonProbeProcess.running = false
            root.indexProcess.running = false
            root.permissionProcess.running = false
            root.openDashboardProcess.running = false
            root.setupHermesProcess.running = false
            root.busy = false
            root.turnVisible = false
            root.backendAvailable = false
            root.daemonAvailable = false
        }
        // Serialize transitions: an off request arriving during startup wins
        // as soon as systemctl finishes, instead of launching racing commands.
        if (!root.serviceTransition)
            root.applyServiceState()
    }

    function applyServiceState() {
        root.serviceTargetEnabled = root.enabled
        root.serviceControlProcess.command = [
            "bash", root.controlScript, root.enabled ? "enable" : "disable"
        ]
        root.serviceControlProcess.running = true
    }

    function finishServiceChange(code, details) {
        if (root.serviceTargetEnabled !== root.enabled) {
            root.applyServiceState()
            return
        }
        if (code !== 0) {
            root.errorText = "No se pudo " + (root.enabled ? "encender" : "apagar")
                + " Rashin: " + String(details || "comprueba los servicios de usuario").trim()
            root.statusText = "Error al cambiar los servicios"
            return
        }
        root.errorText = ""
        root.statusText = root.enabled ? "Cargando el modelo local…" : "Desactivado · modelo detenido"
        if (root.enabled) {
            root.startupProbeAttempts = 0
            root.startupProbeTimer.start()
            root.probe()
            root.index()
        }
    }

    function handleProbe(value) {
        if (!root.enabled)
            return
        try {
            const result = JSON.parse(String(value || "{}"))
            root.backendAvailable = result.available === true
            if (typeof result.model === "string" && result.model.trim() !== "")
                root.modelLabel = root.formatModelLabel(result.model, result.metadata)
            if (root.backendAvailable && root.endpoint.endsWith("/v1")
                    && typeof result.model === "string" && result.model.trim() !== "") {
                const discoveredModel = result.model.trim()
                if (root.model !== discoveredModel) {
                    root.model = discoveredModel
                    root.save()
                }
            }
            root.statusText = root.enabled
                ? (root.backendAvailable ? "Modelo local disponible" : "Modelo local no disponible")
                : (root.backendAvailable ? "Disponible; Rashin está desactivado" : "Desactivado")
            if (root.backendAvailable)
                root.errorText = ""
        } catch (error) {
            root.backendAvailable = false
            root.statusText = root.enabled ? "No se pudo comprobar el modelo" : "Desactivado"
        }
    }

    function handleDaemonProbe(value) {
        if (!root.enabled)
            return
        try {
            const result = JSON.parse(String(value || "{}"))
            root.daemonAvailable = result.running === true && result.providerAvailable === true
            root.backendAvailable = root.daemonAvailable
            if (typeof result.model === "string" && result.model.trim() !== "") {
                root.model = result.model.trim()
                root.modelLabel = String(result.modelLabel || root.formatModelLabel(result.model, {}))
            }
            root.statusText = root.backendAvailable
                ? "Modelo local disponible"
                : root.enabled ? "Daemon activo · modelo local apagado" : "Desactivado"
            if (root.backendAvailable)
                root.errorText = ""
        } catch (error) {
            root.daemonAvailable = false
            root.startDirectProbe()
        }
    }

    function handleAnswer(value) {
        root.askOutputReceived = true
        root.clearPermission()
        try {
            const result = JSON.parse(String(value || "{}"))
            if ((result.ok === true || result.type === "done") && String(result.answer || "").trim() !== "") {
                root.answer = String(result.answer || "").trim()
                root.backendAvailable = true
                root.errorText = String(result.warning || "")
                root.statusText = "Respuesta local lista"
                // Append only the completed turn, once. Do not rebuild history
                // for every token or rely on FileView's cached pre-request text.
                const entry = result.entry || {
                    question: root.lastQuestion,
                    answer: root.answer,
                    model: root.model,
                    at: new Date().toISOString()
                }
                root.historyItems = root.historyItems.concat([entry]).slice(-30)
                root.turnVisible = false
                root.busy = false
                if (!result.warning)
                    root.historyFile.reload()
            } else {
                root.failAsk(String(result.error || "El modelo local no devolvió una respuesta."),
                             result.available !== undefined ? result.available === true : true)
            }
        } catch (error) {
            root.failAsk("La salida del asistente local no era válida.", root.backendAvailable)
        }
    }

    function failAsk(message, available) {
        root.askOutputReceived = true
        root.clearPermission()
        root.busy = false
        root.backendAvailable = available === true
        root.errorText = message
        root.statusText = "Consulta fallida"
        // Keep any partial answer visible; never save it as a completed reply.
    }

    function handleAskEvent(value) {
        if (root.askOutputReceived || !String(value || "").trim())
            return
        try {
            const event = JSON.parse(value)
            if (event.type === "connected") {
                root.backendAvailable = true
            } else if (event.type === "delta" && typeof event.text === "string") {
                root.backendAvailable = true
                root.answer += event.text
            } else if (event.type === "done" || event.type === "error") {
                root.handleAnswer(value)
            }
        } catch (error) {
            root.askProcess.running = false
            root.failAsk("Se recibió un fragmento no válido del modelo local.", root.backendAvailable)
        }
    }

    function handleDaemonEvent(value) {
        if (root.daemonAskOutputReceived || !String(value || "").trim())
            return
        try {
            const event = JSON.parse(value)
            if (event.type === "connected") {
                root.backendAvailable = true
                root.statusText = "Conectado"
            } else if (event.type === "delta" && typeof event.text === "string") {
                root.backendAvailable = true
                root.answer += event.text
            } else if (event.type === "working" || event.type === "state") {
                root.statusText = String(event.text || event.state || "Trabajando")
            } else if (event.type === "tool") {
                root.statusText = String(event.title || "Consultando sistema")
            } else if (event.type === "permission") {
                root.permissionRequestId = String(event.requestId || "")
                root.permissionTitle = String(event.title || "acción avanzada")
                root.permissionOptions = event.options || []
                root.errorText = ""
                root.statusText = "Esperando aprobación"
            } else if (event.type === "done" || event.type === "error") {
                root.daemonAskOutputReceived = true
                root.handleAnswer(value)
            }
        } catch (error) {
            root.daemonAskProcess.running = false
            root.failAsk("Se recibió un fragmento no válido del daemon local.", root.backendAvailable)
        }
    }

    function probe() {
        if (!root.enabled || root.serviceTransition || root.probeProcess.running || root.daemonProbeProcess.running || root.busy)
            return
        root.endpoint = root.normalizedEndpoint()
        root.daemonProbeProcess.command = [
            "curl", "-fsS", "--max-time", "2", root.daemonUrl + "/api/status"
        ]
        root.daemonProbeProcess.running = true
    }

    function clearPermission() {
        root.permissionRequestId = ""
        root.permissionTitle = ""
        root.permissionOptions = []
    }

    function resolvePermission(allow) {
        const requestId = root.permissionRequestId
        if (requestId === "")
            return
        root.clearPermission()
        root.statusText = allow ? "Ejecutando acción…" : "Acción denegada"
        root.permissionProcess.command = [
            "curl", "-fsS", "--max-time", "5", "-X", "POST",
            root.daemonUrl + "/api/perm?id=" + encodeURIComponent(requestId)
                + "&action=" + (allow ? "allow" : "deny")
        ]
        root.permissionProcess.running = true
    }

    function startDirectProbe() {
        if (!root.enabled || root.serviceTransition || root.probeProcess.running || root.busy)
            return
        root.probeProcess.command = [
            "python3", root.askScript,
            "--endpoint", root.endpoint,
            "--probe"
        ]
        root.probeProcess.running = true
    }

    function handleIndex(value) {
        if (root.indexOutputReceived)
            return
        root.indexOutputReceived = true
        try {
            const result = JSON.parse(String(value || "{}"))
            root.busy = false
            root.indexed = result.ok === true
            if (root.indexed) {
                root.lastIndexedAt = String(result.updated || new Date().toISOString())
                root.errorText = ""
                root.statusText = root.backendAvailable
                    ? "Contexto local actualizado"
                    : "Contexto local actualizado · falta el modelo"
            } else {
                root.errorText = String(result.error || "No se pudo indexar la bóveda local.")
                root.statusText = "Error al indexar"
            }
        } catch (error) {
            root.busy = false
            root.indexed = false
            root.errorText = "La salida del indexador no era válida."
            root.statusText = "Error al indexar"
        }

        if (root.pendingQuestion !== "") {
            const question = root.pendingQuestion
            root.pendingQuestion = ""
            if (root.indexed) {
                if (root.daemonAvailable)
                    root.startDaemonAsk(question)
                else
                    root.startAsk(question)
            }
        }
    }

    function index() {
        if (root.busy || root.indexProcess.running)
            return
        root.indexOutputReceived = false
        root.errorText = ""
        root.statusText = "Indexando contexto local…"
        root.busy = true
        root.indexProcess.command = [
            "python3", root.indexScript,
            "--vault", root.vaultPath,
            "--config-root", Quickshell.env("HOME") + "/.config/quickshell/tartarus-shell"
        ]
        root.indexProcess.running = true
    }

    function startAsk(question) {
        if (!root.enabled || root.serviceTransition || root.askProcess.running || root.daemonAskProcess.running)
            return
        root.askOutputReceived = false
        root.lastQuestion = question
        root.answer = ""
        root.errorText = ""
        root.statusText = "Conectando"
        root.busy = true
        root.askProcess.command = [
            "python3", "-u", root.askScript, "--stream",
            "--endpoint", root.normalizedEndpoint(),
            "--model", root.model,
            "--question", question,
            "--vault", root.vaultPath,
            "--history", root.historyPath
        ]
        root.askProcess.running = true
    }

    function startDaemonAsk(question) {
        if (!root.enabled || root.serviceTransition || root.daemonAskProcess.running)
            return
        root.daemonAskOutputReceived = false
        root.lastQuestion = question
        root.answer = ""
        root.errorText = ""
        root.statusText = "Conectando"
        root.busy = true
        root.daemonAskProcess.command = [
            "curl", "-N", "-sS", "--max-time", "300", "-X", "POST",
            root.daemonUrl + "/api/ask?q=" + encodeURIComponent(question)
        ]
        root.daemonAskProcess.running = true
    }

    function ask(question) {
        const value = String(question || "").trim()
        if (value === "") {
            root.errorText = "Escribe una pregunta para Rashin."
            return false
        }
        if (!root.enabled) {
            root.errorText = "Activa Rashin local desde Configuración → Rashin."
            return false
        }
        if (root.serviceTransition || root.busy || root.askProcess.running || root.daemonAskProcess.running)
            return false
        root.lastQuestion = value
        root.answer = ""
        root.errorText = ""
        root.clearPermission()
        root.turnVisible = true
        if (!root.indexed) {
            root.pendingQuestion = value
            root.index()
            return true
        }
        if (root.daemonAvailable)
            root.startDaemonAsk(value)
        else
            root.startAsk(value)
        return true
    }

    function clearAnswer() {
        if (root.busy)
            return
        root.answer = ""
        root.lastQuestion = ""
        root.errorText = ""
        root.turnVisible = false
    }

    function openVault() {
        root.openVaultProcess.command = ["xdg-open", root.vaultPath]
        root.openVaultProcess.running = true
    }

    function openDashboard() {
        if (!root.enabled || root.serviceTransition) {
            root.errorText = "Activa Rashin desde Configuración → Rashin y espera a que se inicie."
            return
        }
        root.openDashboardProcess.command = ["xdg-open", root.daemonUrl]
        root.openDashboardProcess.running = true
    }

    function setupHermes() {
        root.setupHermesProcess.command = [
            "curl", "-fsS", "--max-time", "8", "-X", "POST", root.daemonUrl + "/api/setup"
        ]
        root.setupHermesProcess.running = true
    }

    Component.onCompleted: {
        root.load()
        root.loadHistory()
        root.probe()
    }
}
