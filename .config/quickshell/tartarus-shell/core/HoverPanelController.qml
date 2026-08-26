import QtQuick
import QtQml

QtObject {
    id: root

    required property var pluginRegistry

    property string activePanelId: ""
    property Item anchorEntry: null
    property bool entryHovered: false
    property bool panelHovered: false
    property string openReason: ""
    property int closeDelay: 160

    readonly property var activePanelPlugin:
        root.activePanelId !== ""
        && root.pluginRegistry
        && typeof root.pluginRegistry.plugin === "function"
            ? root.pluginRegistry.plugin(
                root.activePanelId
            )
            : null

    readonly property Timer closeTimer: Timer {
        interval: root.closeDelay
        repeat: false

        onTriggered: {
            if (
                !root.entryHovered
                && !root.panelHovered
                && root.openReason === "hover"
            ) {
                root.closePanel()
            }
        }
    }

    function closePanel() {
        root.entryHovered = false
        root.panelHovered = false
        root.openReason = ""
        root.closeTimer.stop()
    }

    function openPanel(
        panelId,
        anchorEntry,
        reason
    ) {
        if (!panelId)
            return

        root.activePanelId = panelId
        root.anchorEntry =
            anchorEntry ?? root.anchorEntry
        root.openReason = reason ?? "hover"
        root.closeTimer.stop()
    }

    function togglePanel(panelId, anchorEntry) {
        if (
            root.activePanelId === panelId
            && root.openReason === "click"
        ) {
            root.closePanel()
            return
        }

        root.openPanel(
            panelId,
            anchorEntry,
            "click"
        )
    }

    function scheduleClose() {
        if (
            root.openReason !== "hover"
            || root.entryHovered
            || root.panelHovered
        ) {
            return
        }

        root.closeTimer.restart()
    }

    function setEntryHovered(
        panelId,
        hovered,
        anchorEntry
    ) {
        if (hovered) {
            root.entryHovered = true
            root.anchorEntry =
                anchorEntry ?? root.anchorEntry

            if (root.activePanelId !== panelId) {
                root.panelHovered = false
                root.openPanel(
                    panelId,
                    root.anchorEntry,
                    "hover"
                )
            } else {
                root.openReason = "hover"
                root.closeTimer.stop()
            }

            return
        }

        if (
            root.activePanelId !== panelId
            || root.openReason !== "hover"
        ) {
            return
        }

        root.entryHovered = false
        root.scheduleClose()
    }

    function setPanelHovered(panelId, hovered) {
        if (
            root.activePanelId !== panelId
            || root.openReason !== "hover"
        ) {
            return
        }

        root.panelHovered = hovered

        if (hovered) {
            root.closeTimer.stop()
            return
        }

        root.scheduleClose()
    }
}
