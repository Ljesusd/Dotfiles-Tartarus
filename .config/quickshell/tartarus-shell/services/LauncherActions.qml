import QtQml

QtObject {
    id: root

    readonly property var actions: [
        {
            name: "Scheme",
            icon: "palette",
            command: "scheme",
            description: "Change the current colour scheme"
        },
        {
            name: "Wallpaper",
            icon: "photo",
            command: "wallpaper",
            description: "Open wallpaper selector"
        },
        {
            name: "Reapply wallpapers",
            icon: "sync",
            command: "reapply-wallpapers",
            description: "Apply saved wallpapers on every monitor"
        },
        {
            name: "Clipboard",
            icon: "content_paste",
            command: "clipboard",
            description: "Open clipboard history"
        },
        {
            name: "Calculator",
            icon: "calculate",
            command: "calc",
            description: "Scientific calculator with Qalculate and LaTeX"
        },
        {
            name: "Timer",
            icon: "timer",
            command: "timer",
            description: "Start a countdown, for example >timer 10m"
        },
        {
            name: "Pomodoro",
            icon: "schedule",
            command: "pomodoro",
            description: "Start Pomodoro: >pomodoro 25m 5m 4"
        },
        {
            name: "Whisp",
            icon: "edit_note",
            command: "whisp",
            description: "Open the Whisp scratchpad"
        },
        {
            name: "Weather",
            icon: "partly_cloudy_day",
            command: "weather",
            description: "Clima actual, hoy, mañana y calidad del aire"
        },
        {
            name: "Export Whisp note",
            icon: "upload_file",
            command: "whisp-export",
            description: "Export the active note to the Obsidian Inbox"
        }
    ].concat([{
        name: "Record screen",
        icon: "fiber_manual_record",
        command: "record",
        aliases: ["grabador", "grabar", "grabacion", "grabación"],
        description: "Grabar este monitor a 60 FPS, sin audio"
    }]).concat(DockerService.installed ? [{
        name: "Docker",
        icon: "deployed_code",
        command: "docker",
        description: "Contenedores, recursos y logs"
    }] : [])

    function filtered(query) {
        const normalized =
            query.trim().toLowerCase()

        if (normalized === "")
            return root.actions

        const commandQuery = normalized.split(/\s+/)[0]
        return root.actions.filter(action => {
            return root.matchesPrefix(action.name, commandQuery)
                || action.command.startsWith(commandQuery)
                || (action.aliases || []).some(alias => alias.startsWith(commandQuery))
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
}
