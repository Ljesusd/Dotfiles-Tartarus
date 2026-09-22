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
        }
    ].concat(DockerService.installed ? [{
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

        return root.actions.filter(action => {
            return root.matchesPrefix(
                action.name,
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
}
