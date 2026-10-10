pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var events: []
    property bool loading: false
    property bool configured: false
    property string errorMessage: ""
    property string syncedAt: ""
    property string timezone: "Europe/Madrid"
    property string feedUrl: ""
    property string selectedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property var localTasks: []
    property string taskSaveError: ""
    property var notifiedTaskIds: ({})
    property var reminderQueue: []
    readonly property string configPath: Quickshell.stateDir + "/calendar.json"
    readonly property string tasksPath: Quickshell.stateDir + "/calendar-tasks.json"
    readonly property var todayEvents: root.eventsForDate(root.selectedDate)
    readonly property var nextEvent: root.events.find(event => String(event.start) >= new Date().toISOString()) || null

    readonly property FileView configFile: FileView {
        path: root.configPath
        blockLoading: true
        printErrors: false
    }

    readonly property FileView tasksFile: FileView {
        path: root.tasksPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: root.loadTasks()
    }

    function loadConfig() {
        try {
            const value = JSON.parse(configFile.text() || "{}")
            root.timezone = String(value.timezone || "Europe/Madrid")
            root.configured = Array.isArray(value.feeds) && value.feeds.length > 0
            root.feedUrl = root.configured ? String(value.feeds[0].url || value.feeds[0].icalUrl || "") : String(value.icalUrl || "")
        } catch (error) {
            root.configured = false
        }
    }

    function configure(url, name) {
        const value = String(url || "").trim()
        if (!value.startsWith("https://")) {
            root.errorMessage = "La URL debe comenzar por https://"
            return false
        }
        configFile.setText(JSON.stringify({
            timezone: root.timezone,
            feeds: [{ name: String(name || "Calendario").trim() || "Calendario", url: value }]
        }))
        root.protectConfig.running = true
        root.configured = true
        root.feedUrl = value
        root.errorMessage = ""
        root.refresh()
        return true
    }

    function loadTasks() {
        try {
            const value = JSON.parse(tasksFile.text() || "[]")
            root.localTasks = Array.isArray(value) ? value.filter(task => task && task.id && task.title && task.dateKey) : []
        } catch (error) {
            root.localTasks = []
        }
    }

    function saveTasks() {
        root.taskSaveError = ""
        root.taskWriter.command = [
            "python3",
            "-c",
            "import os,sys,tempfile; path=sys.argv[1]; data=sys.argv[2]; directory=os.path.dirname(path); os.makedirs(directory, exist_ok=True); fd,tmp=tempfile.mkstemp(prefix='.calendar-tasks-', dir=directory); os.fchmod(fd,0o600); os.write(fd,data.encode()); os.fsync(fd); os.close(fd); os.replace(tmp,path)",
            root.tasksPath,
            JSON.stringify(root.localTasks, null, 2)
        ]
        root.taskWriter.running = true
    }

    function addTask(title, date) {
        return root.addTimedTask(title, date, "")
    }

    function addTimedTask(title, date, time) {
        const value = String(title || "").trim()
        const dateKey = String(date || root.selectedDate)
        const taskTime = String(time || "").trim()
        if (value === "" || !/^\d{4}-\d{2}-\d{2}$/.test(dateKey))
            return false
        if (taskTime !== "" && !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(taskTime))
            return false
        const next = root.localTasks.slice()
        next.push({
            id: "task-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7),
            title: value,
            dateKey: dateKey,
            time: taskTime,
            completed: false
        })
        root.localTasks = next
        root.saveTasks()
        return true
    }

    function toggleTask(id) {
        root.localTasks = root.localTasks.map(task => task.id === id
            ? Object.assign({}, task, { completed: !task.completed })
            : task)
        root.saveTasks()
    }

    function removeTask(id) {
        root.localTasks = root.localTasks.filter(task => task.id !== id)
        root.saveTasks()
    }

    function eventsForDate(date) {
        const external = root.events.filter(event => event.dateKey === date)
        const tasks = root.localTasks
            .filter(task => task.dateKey === date)
            .map(task => Object.assign({}, task, {
                task: true,
                allDay: !task.time,
                location: "",
                calendar: "Tartarus"
            }))
        return external.concat(tasks)
    }

    function formatEventTime(event) {
        if (event.task && event.time)
            return event.time
        if (event.allDay)
            return "Todo el día"
        return Qt.formatTime(new Date(event.start), "HH:mm") + " – " + Qt.formatTime(new Date(event.end), "HH:mm")
    }

    function checkTaskReminders() {
        const now = new Date()
        const today = Qt.formatDate(now, "yyyy-MM-dd")
        for (const task of root.localTasks) {
            if (task.completed || !task.time || task.dateKey !== today)
                continue
            const due = new Date(task.dateKey + "T" + task.time + ":00")
            const reminderKey = task.id + "@" + task.dateKey + "@" + task.time
            const age = now.getTime() - due.getTime()
            if (due <= now && age >= 0 && age <= 10 * 60 * 1000 && !root.notifiedTaskIds[reminderKey]) {
                const notified = Object.assign({}, root.notifiedTaskIds)
                notified[reminderKey] = true
                root.notifiedTaskIds = notified
                root.reminderQueue = root.reminderQueue.concat([task])
            }
        }
        root.sendNextReminder()
    }

    function sendNextReminder() {
        if (root.reminderProcess.running || root.reminderQueue.length === 0)
            return
        const task = root.reminderQueue[0]
        root.reminderQueue = root.reminderQueue.slice(1)
        root.reminderProcess.command = [
            "notify-send",
            "--app-name=Tartarus",
            "--urgency=normal",
            "Tarea programada",
            task.title + " · " + task.time
        ]
        root.reminderProcess.running = true
    }

    function refresh() {
        if (!root.fetchProcess.running)
            root.fetchProcess.running = true
    }

    property Process fetchProcess: Process {
        command: ["python3", Quickshell.shellPath("scripts/calendar-events.py"), root.configPath]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const value = JSON.parse(String(text || "{}"))
                    root.events = value.events || []
                    root.syncedAt = value.syncedAt || ""
                    root.errorMessage = value.errors?.join(" · ") || value.error || ""
                } catch (error) {
                    root.errorMessage = "No se pudo leer el calendario"
                }
                root.loading = false
            }
        }
        onStarted: root.loading = true
    }

    property Process protectConfig: Process {
        command: ["chmod", "600", root.configPath]
    }

    property Process taskWriter: Process {
        stderr: StdioCollector {
            id: taskWriterError
            waitForEnd: true
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.taskSaveError = String(taskWriterError.text || "No se pudo escribir el archivo de tareas").trim()
                console.warn("Calendar: no se pudieron guardar las tareas:", root.taskSaveError)
            }
        }
    }

    property Process reminderProcess: Process {
        onExited: root.sendNextReminder()
    }

    property Timer reminderTimer: Timer {
        interval: 15000
        repeat: true
        running: root.localTasks.length > 0
        onTriggered: root.checkTaskReminders()
    }

    property Timer refreshTimer: Timer {
        interval: 300000
        repeat: true
        running: root.configured
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.loadConfig()
        root.loadTasks()
        root.checkTaskReminders()
        root.refresh()
    }
}
