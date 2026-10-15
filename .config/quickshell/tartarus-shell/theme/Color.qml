pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtQml

QtObject {
    id: root

    readonly property string name: textValue("name", "Fallback")
    readonly property string slug: textValue("slug", "fallback")
    readonly property string mode: textValue("mode", "dark")

    readonly property color background:
        role("background", "#171925")

    readonly property color backgroundAlt:
        role("background_alt", "#12141e")

    readonly property color surface:
        role("surface", "#20243a")

    readonly property color surfaceHover:
        role("surface_hover", "#303957")

    readonly property color surfaceContainer:
        role("surface_container", "#20243a")

    readonly property color surfaceContainerHigh:
        role("surface_container_high", "#303957")

    readonly property color surfaceElevated:
        role("surface_elevated", "#303957")

    readonly property color selection:
        role("selection", "#344263")

    readonly property color surfaceVariant:
        role("surface_variant", "#303957")

    readonly property color primaryContainer:
        role("primary_container", "#344263")

    readonly property color secondaryContainer:
        role("secondary_container", "#303957")

    readonly property color tertiaryContainer:
        role("tertiary_container", "#83aef7")

    readonly property color foreground:
        role("foreground", "#d9e1ff")

    readonly property color onSurface:
        role("on_surface", "#d9e1ff")

    readonly property color onPrimaryContainer:
        role("on_primary_container", "#d9e1ff")

    readonly property color onTertiaryContainer:
        role("on_tertiary_container", "#171925")

    readonly property color primary:
        role("primary", "#83aef7")

    readonly property color onPrimary:
        role("on_primary", "#171925")

    readonly property color secondary:
        role("secondary", "#89b4fa")

    readonly property color onSecondary:
        role("on_secondary", "#171925")

    readonly property color tertiary:
        role("tertiary", "#83aef7")

    readonly property color onTertiary:
        role("on_tertiary", "#171925")

    readonly property color outline:
        role("outline", "#7180a7")

    readonly property color outlineVariant:
        role("outline_variant", "#7180a7")

    readonly property color foregroundMuted:
        role("foreground_muted", "#9ba7ca")

    readonly property color foregroundSubtle:
        role("foreground_subtle", "#7180a7")

    readonly property color onSurfaceVariant:
        role("on_surface_variant", "#9ba7ca")

    readonly property color accent:
        role("accent", "#83aef7")

    readonly property color error:
        role("error", "#f38ba8")

    readonly property color warning:
        role("warning", "#f9e2af")

    readonly property color success:
        role("success", "#a6e3a1")

    readonly property color info:
        role("info", "#89b4fa")

    property var themeData: ({
        name: "Fallback",
        slug: "fallback",
        mode: "dark",
        roles: ({})
    })

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
        const data = root.themeData
        const roles = data && data.roles

        if (!roles || typeof roles !== "object")
            return fallback

        const value = roles[name]
        return typeof value === "string" && value.trim() !== ""
            ? value
            : fallback
    }

    function textValue(name, fallback) {
        const data = root.themeData
        const value = data && data[name]
        return typeof value === "string" && value.trim() !== ""
            ? value
            : fallback
    }

    function loadTheme() {
        const text = themeFile.text()

        if (text.trim() === "")
            return

        try {
            const data = JSON.parse(text)

            if (!data || typeof data !== "object"
                    || !data.roles || typeof data.roles !== "object") {
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
