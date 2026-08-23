pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtQml

QtObject {
    id: root

    readonly property string name: themeData.name ?? "Fallback"
    readonly property string slug: themeData.slug ?? "fallback"
    readonly property string mode: themeData.mode ?? "dark"

    readonly property color background:
        role("background", "#202020")

    readonly property color backgroundAlt:
        role("background_alt", "#181818")

    readonly property color surface:
        role("surface", "#2a2a2a")

    readonly property color surfaceHover:
        role("surface_hover", "#444444")

    readonly property color selection:
        role("selection", "#555555")

    readonly property color foreground:
        role("foreground", "#ffffff")

    readonly property color foregroundMuted:
        role("foreground_muted", "#999999")

    readonly property color foregroundSubtle:
        role("foreground_subtle", "#777777")

    readonly property color accent:
        role("accent", "#89b4fa")

    readonly property color error:
        role("error", "#f38ba8")

    readonly property color warning:
        role("warning", "#f9e2af")

    readonly property color success:
        role("success", "#a6e3a1")

    readonly property color info:
        role("info", "#89b4fa")

    property var themeData: ({})

    readonly property FileView themeFile: FileView {
        path: Quickshell.stateDir
            + "/active-theme.json"

        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: {
            reload()
        }

        onTextChanged: {
            root.loadTheme()
        }
    }

    Component.onCompleted: {
        root.loadTheme()
    }

    function role(name, fallback) {
        const roles = root.themeData.roles

        if (!roles)
            return fallback

        return roles[name] ?? fallback
    }

    function loadTheme() {
        const text = themeFile.text()

        if (text.trim() === "")
            return

        try {
            const data = JSON.parse(text)

            if (!data.roles) {
                console.warn(
                    "Color: active-theme.json no contiene roles"
                )

                return
            }

            root.themeData = data

        } catch (error) {
            console.warn(
                "Color: no se pudo leer active-theme.json:",
                error
            )
        }
    }
}
