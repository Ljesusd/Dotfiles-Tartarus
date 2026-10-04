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
        role("background", "#171925")

    readonly property color backgroundAlt:
        role("background_alt", "#12141e")

    readonly property color surface:
        role("surface", "#20243a")

    readonly property color surfaceHover:
        role("surface_hover", "#303957")

    readonly property color surfaceContainer:
        role("surface_container", root.surface)

    readonly property color surfaceContainerHigh:
        role("surface_container_high", root.surfaceHover)

    readonly property color surfaceElevated:
        role("surface_elevated", root.surfaceContainerHigh)

    readonly property color selection:
        role("selection", "#344263")

    readonly property color surfaceVariant:
        role("surface_variant", root.surfaceHover)

    readonly property color primaryContainer:
        role("primary_container", root.selection)

    readonly property color secondaryContainer:
        role("secondary_container", root.surfaceHover)

    readonly property color tertiaryContainer:
        role("tertiary_container", root.accent)

    readonly property color foreground:
        role("foreground", "#d9e1ff")

    readonly property color onSurface:
        role("on_surface", root.foreground)

    readonly property color onPrimaryContainer:
        role("on_primary_container", root.foreground)

    readonly property color onTertiaryContainer:
        role("on_tertiary_container", root.background)

    readonly property color primary:
        role("primary", root.accent)

    readonly property color onPrimary:
        role("on_primary", root.background)

    readonly property color secondary:
        role("secondary", root.info)

    readonly property color onSecondary:
        role("on_secondary", root.background)

    readonly property color tertiary:
        role("tertiary", root.accent)

    readonly property color onTertiary:
        role("on_tertiary", root.background)

    readonly property color outline:
        role("outline", root.foregroundSubtle)

    readonly property color outlineVariant:
        role("outline_variant", root.outline)

    readonly property color foregroundMuted:
        role("foreground_muted", "#9ba7ca")

    readonly property color foregroundSubtle:
        role("foreground_subtle", "#7180a7")

    readonly property color onSurfaceVariant:
        role("on_surface_variant", root.foregroundMuted)

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
