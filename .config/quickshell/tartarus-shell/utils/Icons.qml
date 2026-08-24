pragma Singleton

import QtQml
import Quickshell

QtObject {
    id: root

    readonly property var appCategoryIcons: ({
        WebBrowser: "web",

        Development: "code",
        IDE: "code",
        TextEditor: "edit_note",

        TerminalEmulator: "terminal",
        ConsoleOnly: "terminal",

        FileManager: "files",
        FileTools: "files",
        Filesystem: "files",
        FileTransfer: "files",

        Audio: "music_note",
        Music: "music_note",
        Player: "music_note",

        Video: "videocam",
        AudioVideo: "music_video",

        Game: "sports_esports",

        Graphics: "photo_library",
        RasterGraphics: "photo_library",

        Settings: "settings",
        DesktopSettings: "settings",
        HardwareSettings: "settings",

        Network: "chat",
        Security: "security",

        System: "host",
        Utility: "build",
        Office: "content_paste"
    })

    readonly property var specialWorkspaceIcons: ({
        special: "star",
        music: "music_note",
        communication: "forum",
        todo: "checklist",
        sysmon: "monitor_heart",
        steam: "sports_esports"
    })

    function desktopEntryForApp(name) {
        if (!name)
            return null

        return DesktopEntries.heuristicLookup(name)
    }

    function appCategoryIcon(name, fallback = "apps") {
        const entry = root.desktopEntryForApp(name)

        if (!entry || !entry.categories)
            return fallback

        for (const category of Object.keys(root.appCategoryIcons)) {
            if (entry.categories.includes(category))
                return root.appCategoryIcons[category]
        }

        return fallback
    }

    function matchesOverride(name, override) {
        if (!name || !override || !override.icon)
            return false

        if (override.regex) {
            const regex = new RegExp(
                override.regex,
                override.flags ?? ""
            )

            return regex.test(name)
        }

        return override.name === name
    }

    function specialWorkspaceKey(name) {
        if (!name)
            return ""

        return name.startsWith("special:")
            ? name.slice(8)
            : name
    }

    function specialWorkspaceIcon(name, fallback = "star") {
        const key = root.specialWorkspaceKey(name)

        if (!key)
            return fallback

        if (root.specialWorkspaceIcons[key])
            return root.specialWorkspaceIcons[key]

        return key.length > 0
            ? key.charAt(0).toUpperCase()
            : fallback
    }

    function windowClass(toplevel) {
        if (!toplevel || !toplevel.lastIpcObject)
            return ""

        return toplevel.lastIpcObject.class ?? ""
    }

    function iconForWindow(toplevel, fallback = "apps") {
        const className = root.windowClass(toplevel)

        if (!className)
            return fallback

        return root.appCategoryIcon(
            className,
            fallback
        )
    }
}
