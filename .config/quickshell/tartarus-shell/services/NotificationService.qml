pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import Quickshell.Io
import QtQml
import QtQml.Models

QtObject {
    id: root

    property bool dnd: false
    property bool centerOpen: false
    property string centerScreenName: ""
    readonly property string sessionId: String(Date.now())
    readonly property var notifications: notificationModel

    property var notificationObjects: ({})
    property var notificationActionObjects: ({})

    readonly property var notificationModel: ListModel {}
    readonly property var history: historyModel
    readonly property int historyLimit: 100

    readonly property FileView historyFile: FileView {
        path: Quickshell.stateDir + "/notifications.json"
        blockLoading: true
        printErrors: false
    }

    readonly property FileView settingsFile: FileView {
        path: Quickshell.stateDir + "/notification-settings.json"
        blockLoading: true
        printErrors: false
    }

    readonly property var historyModel: ListModel {}

    function loadSettings() {
        const text = settingsFile.text()

        if (!text || text.trim() === "")
            return

        try {
            const settings = JSON.parse(text)

            if (settings && settings.dnd !== undefined)
                root.dnd = Boolean(settings.dnd)
        } catch (error) {
            console.warn("Could not read notification-settings.json:", error)
        }
    }

    function saveSettings() {
        settingsFile.setText(JSON.stringify({
            dnd: root.dnd,
        }, null, 2))
    }

    function loadHistory() {
        const text = historyFile.text()

        if (!text || text.trim() === "")
            return

        try {
            const entries = JSON.parse(text)

            if (!Array.isArray(entries))
                return

            const ordered = entries
                .filter(entry => entry && entry.notificationId !== undefined)
                .sort((a, b) => (Number(b.timestamp) || 0) - (Number(a.timestamp) || 0))
            historyModel.clear()
            for (const entry of ordered) {

                historyModel.append({
                    notificationId: root.toNotificationId(entry.notificationId),
                    sessionId: "",
                    appName: entry.appName || "",
                    summary: entry.summary || "",
                    body: entry.body || "",
                    image: String(entry.image || "").startsWith("image://") ? "" : (entry.image || ""),
                    timestamp: Number(entry.timestamp) || 0,
                })
            }

            root.trimHistory()
        } catch (error) {
            console.warn("Could not read notifications.json:", error)
        }
    }

    function saveHistory() {
        const entries = []

        for (let i = 0; i < historyModel.count; ++i)
            entries.push(historyModel.get(i))

        historyFile.setText(JSON.stringify(entries, null, 2))
    }

    function trimHistory() {
        while (historyModel.count > root.historyLimit)
            historyModel.remove(historyModel.count - 1)
    }

    function historyImage(notification) {
        if (!notification || notification.image === undefined)
            return ""

        if (typeof notification.image !== "string")
            return ""

        // image:// is owned by the current Quickshell process and cannot be
        // restored after a reload. Keep stable file/data URLs only.
        return notification.image.startsWith("image://")
            ? ""
            : notification.image
    }

    function recordHistory(notification) {
        if (!notification)
            return

        const notificationId = root.toNotificationId(notification.id)
        const entry = {
            notificationId,
            sessionId: root.sessionId,
            appName: notification.appName || "",
            summary: notification.summary || "",
            body: notification.body || "",
            image: root.historyImage(notification),
            timestamp: Date.now(),
        }

        for (let i = 0; i < historyModel.count; ++i) {
            if (
                root.isSameNotificationId(
                    historyModel.get(i).notificationId,
                    notificationId
                ) && historyModel.get(i).sessionId === root.sessionId
            ) {
                historyModel.set(i, entry)
                // Updates are recent activity too: keep the same entity,
                // but move it to the newest-first position.
                if (i > 0) historyModel.move(i, 0, 1)
                root.saveHistory()
                return
            }
        }

        historyModel.insert(0, entry)
        root.trimHistory()
        root.saveHistory()
    }

    function clearHistory() {
        historyModel.clear()
        root.saveHistory()
    }

    function removeHistory(index) {
        if (index < 0 || index >= historyModel.count)
            return

        const entry = historyModel.get(index)
        if (entry.sessionId === root.sessionId) root.close(entry.notificationId)
        historyModel.remove(index)
        root.saveHistory()
    }

    function toggleCenter() {
        const screen = Hyprland.focusedMonitor?.name ?? ""
        if (root.centerOpen && root.centerScreenName === screen) root.closeCenter()
        else {
            root.centerScreenName = screen
            root.centerOpen = true
        }
    }

    function closeCenter() {
        root.centerOpen = false
    }

    Component.onCompleted: {
        root.loadSettings()
        root.loadHistory()
    }

    function toggleDnd(screenName) {
        root.dnd = !root.dnd
        root.saveSettings()

        const targetScreen = screenName !== undefined
            ? screenName
            : Hyprland.focusedMonitor
                ? Hyprland.focusedMonitor.name
                : ""

        ToastService.push(
            targetScreen,
            root.dnd ? "notifications_off" : "notifications",
            root.dnd ? "Do Not Disturb enabled" : "Do Not Disturb disabled",
            root.dnd
                ? "New notifications will be received without popups."
                : "New notifications will show popups again."
        )
    }

    function toNotificationId(value) {
        if (value === undefined || value === null)
            return ""

        return `${value}`
    }

    function addAction(actionList, actionMap, action) {
        if (!action)
            return

        const identifier = action.identifier !== undefined
            ? action.identifier
            : ""
        const text = action.text !== undefined
            ? action.text
            : identifier

        if (!identifier)
            return

        actionList.push({
            identifier,
            text,
        })
        actionMap[identifier] = action
    }

    function extractActions(notification) {
        const actionList = []
        const actionMap = ({})

        if (!notification || !notification.actions)
            return { actions: actionList, actionMap }

        const rawActions = notification.actions

        try {
            for (const action of rawActions)
                root.addAction(actionList, actionMap, action)
        } catch (error) {
        }

        if (actionList.length === 0) {
            const count = rawActions.count !== undefined
                ? rawActions.count
                : rawActions.length

            const limit = count !== undefined ? count : 32

            for (let i = 0; i < limit; ++i) {
                let action = rawActions.get
                    ? rawActions.get(i)
                    : rawActions[i]

                if (!action)
                    break

                root.addAction(actionList, actionMap, action)
            }
        }

        return { actions: actionList, actionMap }
    }

    function isSameNotificationId(a, b) {
        return `${a}` === `${b}`
    }

    function upsert(notification) {
        if (!notification)
            return false

        const extracted = root.extractActions(notification)
        const currentScreen = Hyprland.focusedMonitor
            ? Hyprland.focusedMonitor.name
            : ""

        for (let i = 0; i < notificationModel.count; ++i) {
            const existing = notificationModel.get(i)
            const existingId = existing.notificationId
            const oldKey = root.toNotificationId(existingId)
            const newKey = root.toNotificationId(notification.id)

            if (
                root.isSameNotificationId(existingId, notification.id)
            ) {
                notificationModel.set(i, {
                    notification: notification,
                    notificationId: notification.id,
                    screenName: existing.screenName
                        ? existing.screenName
                        : currentScreen,
                    appName: notification.appName,
                    summary: notification.summary,
                    body: notification.body,
                    image: notification.image,
                    actions: extracted.actions,
                    notificationActions: notification.actions,
                    receivedAt: Date.now(),
                    popupAllowed: !root.dnd,
                })

                if (oldKey && oldKey !== newKey) {
                    delete notificationObjects[oldKey]
                    delete notificationActionObjects[oldKey]
                }

                notificationObjects[newKey] = notification
                notificationActionObjects[newKey] = extracted.actionMap
                return true
            }

        }

        return false
    }

    function add(notification) {
        if (!notification)
            return

        notification.tracked = true
        root.recordHistory(notification)

        if (root.upsert(notification))
            return

        const extracted = root.extractActions(notification)
        const screenName = Hyprland.focusedMonitor
            ? Hyprland.focusedMonitor.name
            : ""

        // Keep one entry per active notification id. This also handles
        // applications that update an existing notification.
        notificationModel.insert(0, {
            notification: notification,
            notificationId: notification.id,
            screenName,
            appName: notification.appName,
            summary: notification.summary,
            body: notification.body,
            image: notification.image,
            actions: extracted.actions,
            notificationActions: notification.actions,
            receivedAt: Date.now(),
            popupAllowed: !root.dnd,
        })

        const key = root.toNotificationId(notification.id)
        notificationObjects[key] = notification
        notificationActionObjects[key] = extracted.actionMap
    }

    function remove(notificationId) {
        const key = root.toNotificationId(notificationId)

        for (let i = notificationModel.count - 1; i >= 0; --i) {
            if (
                root.isSameNotificationId(
                    notificationModel.get(i).notificationId,
                    notificationId
                )
            ) {
                notificationModel.remove(i)
                break
            }
        }

        delete notificationObjects[key]
        delete notificationActionObjects[key]
    }

    function close(notificationId) {
        const key = root.toNotificationId(notificationId)
        const notification = notificationObjects[key]

        if (
            notification
            && typeof notification.dismiss === "function"
        ) {
            notification.dismiss()
        }

        root.remove(key)
    }

    function dismiss(notification) {
        if (!notification)
            return

        const notificationId = notification.id !== undefined
            ? notification.id
            : notification

        root.close(notificationId)
    }

    function invokeAction(notificationId, actionId) {
        const notification = notificationObjects[root.toNotificationId(notificationId)]
        if (!notification || !notification.actions)
            return

        const invokeIfMatching = action => {
            if (
                action
                && action.identifier === actionId
                && typeof action.invoke === "function"
            ) {
                action.invoke()
                return true
            }

            return false
        }

        try {
            for (const action of notification.actions) {
                if (invokeIfMatching(action))
                    return
            }
        } catch (error) {
        }

        const rawActions = notification.actions
        const count = rawActions.count !== undefined
            ? rawActions.count
            : rawActions.length

        for (let i = 0; count !== undefined && i < count; ++i) {
            const action = rawActions.get
                ? rawActions.get(i)
                : rawActions[i]

            if (invokeIfMatching(action))
                return
        }
    }

    // Lifecycle belongs to the service, not to one timer per monitor delegate.
    function popupVisible(id, screen, limit) {
        let rank = 0
        for (let i = 0; i < notificationModel.count; ++i) {
            const row = notificationModel.get(i)
            if (row.screenName !== screen || !row.popupAllowed) continue
            if (root.isSameNotificationId(row.notificationId, id)) return rank < limit
            rank++
        }
        return false
    }

    readonly property Timer expiry: Timer {
        interval: 250
        repeat: true
        running: notificationModel.count > 0
        onTriggered: {
            const now = Date.now()
            for (let i = notificationModel.count - 1; i >= 0; --i) {
                const row = notificationModel.get(i)
                const timeout = Number(row.notification?.expireTimeout ?? -1)
                const duration = timeout < 0 ? 8000 : timeout
                if (duration > 0 && now - row.receivedAt >= duration) {
                    const object = row.notification
                    const id = row.notificationId
                    if (object && typeof object.expire === "function") object.expire()
                    root.remove(id)
                }
            }
        }
    }

    readonly property Instantiator lifecycles: Instantiator {
        model: notificationModel
        delegate: QtObject {
            id: lifecycle
            required property var notification
            required property int notificationId
            function refresh() {
                if (!notification) return
                root.recordHistory(notification)
                root.upsert(notification)
            }
            readonly property Connections changes: Connections {
                target: lifecycle.notification
                function onClosed() { root.remove(lifecycle.notificationId) }
                function onSummaryChanged() { lifecycle.refresh() }
                function onBodyChanged() { lifecycle.refresh() }
                function onImageChanged() { lifecycle.refresh() }
            }
        }
    }

    readonly property var server: NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onNotification: notification => root.add(notification)
    }

}
