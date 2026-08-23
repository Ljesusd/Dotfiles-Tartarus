import QtQml

QtObject {
    id: root

    readonly property var actions: [
        {
            name: "Scheme",
            command: "scheme",
            description: "Change the current colour scheme"
        }
    ]

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
