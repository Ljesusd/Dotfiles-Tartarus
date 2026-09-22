pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property string script: Qt.resolvedUrl("../scripts/docker-control.py").toString().replace(/^file:\/\//, "")
    property bool installed: false
    property bool ready: false
    property bool available: false
    property var containers: []
    property var consumers: ({})
    property string error: ""
    property string warning: ""
    property string actionMessage: ""
    property string logId: ""
    property string logs: ""
    readonly property bool busy: probe.running || operation.running
    readonly property bool monitoring: Object.keys(consumers).length > 0
    property string operationKind: ""

    function parse(text) {
        try { return JSON.parse(text) }
        catch (e) { return {ok: false, error: "Respuesta Docker no válida."} }
    }
    function setConsumer(key, active) {
        const next = Object.assign({}, root.consumers)
        if (active) next[key] = true
        else delete next[key]
        root.consumers = next
    }
    function refresh() {
        if (!root.busy) probe.running = true
    }
    function filtered(query) {
        const tokens = query.trim().toLowerCase().split(/\s+/).filter(Boolean)
        return root.containers.filter(c => tokens.every(t => {
            if (t === "activos") return c.state === "running"
            if (t === "detenidos") return c.state === "exited" || c.state === "created"
            return [c.name, c.image, c.project, c.id].join(" ").toLowerCase().includes(t)
        }))
    }
    function grouped(query) {
        const groups = []
        const byProject = ({})
        filtered(query).forEach(c => {
            const name = c.project || "Sin proyecto"
            if (byProject[name] === undefined) {
                byProject[name] = groups.length
                groups.push({project: name, containers: []})
            }
            groups[byProject[name]].containers.push(c)
        })
        return groups
    }
    function readLogs(id) {
        if (root.busy) return
        root.logId = id
        root.logs = ""
        root.operationKind = "logs"
        operation.command = ["python3", root.script, "logs", id]
        operation.running = true
    }
    function execute(verb, id) {
        if (root.busy || !root.available) return
        root.actionMessage = ""
        root.operationKind = "action"
        operation.command = ["python3", root.script, "action", verb, id]
        operation.running = true
    }
    onMonitoringChanged: if (monitoring) root.refresh()
    property Timer poller: Timer {
        interval: 10000
        repeat: true
        running: root.monitoring
        onTriggered: root.refresh()
    }
    property Process detection: Process {
        command: ["python3", root.script, "available"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.installed = root.parse(text).installed === true }
    }
    property Process probe: Process {
        id: probe
        command: ["python3", root.script, "snapshot"]
        stdout: StdioCollector {
            onStreamFinished: {
                const data = root.parse(text)
                root.ready = true
                root.installed = data.installed === true
                root.available = data.ok === true
                root.error = data.error || ""
                root.warning = data.warning || ""
                root.containers = data.ok ? (data.containers || []) : []
            }
        }
    }
    property Process operation: Process {
        id: operation
        stdout: StdioCollector {
            onStreamFinished: {
                const data = root.parse(text)
                if (root.operationKind === "logs")
                    root.logs = data.ok ? (data.logs || "Sin logs recientes.") : data.error
                else
                    root.actionMessage = data.ok ? "Acción completada." : data.error
            }
        }
        onRunningChanged: if (!running && root.operationKind === "action") Qt.callLater(root.refresh)
    }
}
