import Quickshell.Hyprland
import QtQml
import "." as Services

QtObject {
    id: root

    property var monitorContexts: []
    property bool launcherFocusCloseSuppressed: false

    readonly property Connections osdConnections: Connections {
        target: Services.OsdService
        function onActiveChanged() { root.syncOsdState() }
        function onSerialChanged() { root.syncOsdState() }
    }

    readonly property Connections notificationConnections: Connections {
        target: Services.NotificationService.notifications
        function onCountChanged() { root.syncNotificationState() }
        function onDataChanged() { root.syncNotificationState() }
    }

    readonly property Connections clipboardConnections: Connections {
        target: Services.ClipboardService
        function onOpenChanged() { root.syncClipboardState() }
    }

    readonly property Connections imageViewerConnections: Connections {
        target: Services.ImageViewerService
        function onVisibleChanged() { root.syncImageViewerState() }
        function onTargetScreenNameChanged() { root.syncImageViewerState() }
        function onCurrentPathChanged() { root.syncImageViewerState() }
    }

    readonly property Connections wallpaperConnections: Connections {
        target: Services.Wallpapers
        function onCurrentPathChanged() { root.syncWallpaperState() }
        function onPathsByMonitorChanged() { root.syncWallpaperState() }
    }

    function syncOsdState() {
        const screenName = Services.OsdService.screenName
        for (const context of root.monitorContexts) {
            const active = Services.OsdService.active
                && context.name === screenName
            context.osdActive = active
            if (active) {
                context.osdKind = Services.OsdService.kind
                context.osdValue = Services.OsdService.value
                context.osdMuted = Services.OsdService.muted
            }
        }
    }

    function syncNotificationState() {
        const model = Services.NotificationService.notifications
        for (const context of root.monitorContexts) {
            let count = 0
            const visibleIds = []
            for (let i = 0; i < model.count; i++) {
                const notification = model.get(i)
                if (notification
                    && Services.NotificationService.popupVisible(
                        notification.notificationId,
                        context.name,
                        3
                )) {
                    count++
                    visibleIds.push(notification.notificationId)
                }
            }
            context.notificationPopupCount = count
            context.notificationPopupIds = visibleIds
        }
    }

    function syncClipboardState() {
        const screenName = Hyprland.focusedMonitor
            ? Hyprland.focusedMonitor.name
            : ""
        for (const context of root.monitorContexts)
            context.clipboardOpen = Services.ClipboardService.open
                && context.name === screenName
    }

    function syncImageViewerState() {
        const target = Services.ImageViewerService.targetScreenName
        for (const context of root.monitorContexts) {
            context.imageViewerOpen = Services.ImageViewerService.visible
                && context.name === target
            if (context.imageViewerOpen)
                context.imageViewerPath = Services.ImageViewerService.currentPath
        }
    }

    function syncWallpaperState() {
        const paths = Services.Wallpapers.pathsByMonitor || {}
        for (const context of root.monitorContexts) {
            context.wallpaperPath = paths[context.name]
                || Services.Wallpapers.currentPath
                || ""
        }
    }

    function registerContext(context) {
        if (
            !context
            || root.monitorContexts.indexOf(context) !== -1
        ) {
            return
        }

        const next = root.monitorContexts.slice()
        next.push(context)
        root.monitorContexts = next
        root.syncOsdState()
        root.syncNotificationState()
        root.syncImageViewerState()
        root.syncWallpaperState()
    }

    function unregisterContext(context) {
        root.monitorContexts =
            root.monitorContexts.filter(candidate => {
                return candidate !== context
            })
    }

    function closeLaunchers() {
        for (const context of root.monitorContexts)
            context.closeLauncher()
    }

    function closeSidebars() {
        for (const context of root.monitorContexts)
            context.closeSidebar()
    }

    function closePanels() {
        root.closeLaunchers()
        root.closeSidebars()
    }

    function toggleNotificationCenter() {
        const context = root.contextForFocusedMonitor()
        if (!context)
            return

        const shouldOpen = !context.notificationCenterOpen
        for (const candidate of root.monitorContexts)
            candidate.closeNotificationCenter()

        if (shouldOpen) {
            context.openNotificationCenter()
            Services.NotificationService.centerScreenName = context.name
            Services.NotificationService.centerOpen = true
        } else {
            Services.NotificationService.closeCenter()
        }
    }

    function closeNotificationCenter() {
        for (const context of root.monitorContexts)
            context.closeNotificationCenter()
        Services.NotificationService.closeCenter()
    }

    function closeLauncher(context) {
        if (!context)
            return

        context.closeLauncher()
    }

    function setLauncherFocusCloseSuppressed(suppressed) {
        root.launcherFocusCloseSuppressed = suppressed
    }

    function openLauncher(context) {
        if (!context)
            return

        for (const candidate of root.monitorContexts) {
            candidate.closeSidebar()
            if (candidate === context)
                candidate.openLauncher()
            else
                candidate.closeLauncher()
        }
    }

    function toggleLauncher(context) {
        if (!context)
            return

        const shouldOpen =
            !context.launcherOpened

        for (const candidate of root.monitorContexts) {
            if (candidate === context && shouldOpen)
                candidate.openLauncher()
            else
                candidate.closeLauncher()
        }
    }

    function openSidebar(context) {
        if (!context)
            return

        context.openSidebar()
    }

    function toggleSidebar(context) {
        if (!context)
            return

        context.toggleSidebar()
    }

    function closeSidebar(context) {
        if (context)
            context.closeSidebar()
    }

    function contextForFocusedMonitor() {
        const focused = Hyprland.focusedMonitor

        if (!focused)
            return null

        for (const context of root.monitorContexts) {
            const monitor = Hyprland.monitorFor(
                context.screen
            )

            if (monitor === focused)
                return context
        }

        return null
    }
}
