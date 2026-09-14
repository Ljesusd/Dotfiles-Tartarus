pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var toasts: []
    property int _nextId: 0
    property int defaultTimeoutMs: 2500
    property int exitDurationMs: 260

    Component {
        id: toastComponent

        QtObject {
            property int toastId: -1
            property string screenName: ""
            property string icon: ""
            property string title: ""
            property string body: ""
            property string imagePath: ""
            property var actions: []
            property double expiresAt: 0
            property double remainingMs: 0
            property bool closing: false
            property double removeAt: 0
        }
    }

    function push(
        screenName,
        icon,
        title,
        body,
        timeoutMs,
        imagePath,
        actions
    ) {
        const lifetime =
            timeoutMs === undefined
                ? root.defaultTimeoutMs
                : Math.max(0, timeoutMs)
        const now = Date.now()
        const toast = toastComponent.createObject(root, {
            toastId: root._nextId++,
            screenName: screenName ?? "",
            icon: icon ?? "",
            title: title ?? "",
            body: body ?? "",
            imagePath: imagePath ?? "",
            actions: actions ?? [],
            expiresAt:
                lifetime > 0
                    ? now + lifetime
                    : 0,
            closing: false,
            remainingMs: lifetime,
            removeAt: 0
        })

        if (toast === null)
            return

        root.toasts = [toast].concat(root.toasts)
        root.scheduleExpiry()
    }

    function clear() {
        const oldToasts = root.toasts

        root.toasts = []
        expiryTimer.stop()

        for (const toast of oldToasts)
            toast.destroy()
    }

    function dismiss(id) {
        for (const toast of root.toasts) {
            if (toast.toastId !== id)
                continue

            if (toast.closing)
                return

            toast.closing = true
            toast.expiresAt = 0
            toast.removeAt =
                Date.now() + root.exitDurationMs

            root.scheduleExpiry()
            return
        }
    }

    function setHovered(id, hovered) {
        for (const toast of root.toasts) {
            if (toast.toastId !== id || toast.closing)
                continue

            if (hovered) {
                if (toast.expiresAt > 0) {
                    toast.remainingMs = Math.max(
                        0,
                        toast.expiresAt - Date.now()
                    )
                    toast.expiresAt = 0
                    root.scheduleExpiry()
                }

                return
            }

            if (toast.remainingMs > 0) {
                toast.expiresAt =
                    Date.now() + toast.remainingMs
                toast.remainingMs = 0
                root.scheduleExpiry()
            }

            return
        }
    }

    function triggerAction(toastId, actionId) {
        for (const toast of root.toasts) {
            if (toast.toastId !== toastId || toast.closing)
                continue

            const action = toast.actions.find(
                item => item.actionId === actionId
            )

            if (action === undefined)
                return

            if (action.actionId === "open-image") {
                if (toast.imagePath.length === 0)
                    return

                ImageViewerService.open(
                    toast.imagePath,
                    toast.screenName
                )
                root.dismiss(toastId)
            }

            return
        }
    }

    function removeToasts(removed) {
        const removedIds = removed.map(
            toast => toast.toastId
        )

        root.toasts = root.toasts.filter(
            toast => !removedIds.includes(toast.toastId)
        )

        for (const toast of removed)
            toast.destroy()
    }

    function processExpirations() {
        const now = Date.now()
        const removed = []

        for (const toast of root.toasts) {
            if (toast.closing) {
                if (toast.removeAt > 0 && toast.removeAt <= now)
                    removed.push(toast)

                continue
            }

            if (
                toast.expiresAt > 0
                && toast.expiresAt <= now
            ) {
                toast.closing = true
                toast.expiresAt = 0
                toast.removeAt =
                    now + root.exitDurationMs
            }
        }

        if (removed.length > 0)
            root.removeToasts(removed)
    }

    function scheduleExpiry() {
        expiryTimer.stop()

        let nextExpiry = 0

        for (const toast of root.toasts) {
            const candidate =
                toast.closing
                    ? toast.removeAt
                    : toast.expiresAt

            if (candidate === 0)
                continue

            if (
                nextExpiry === 0
                || candidate < nextExpiry
            ) {
                nextExpiry = candidate
            }
        }

        if (nextExpiry === 0)
            return

        expiryTimer.interval = Math.max(
            1,
            nextExpiry - Date.now()
        )

        expiryTimer.start()
    }

    Timer {
        id: expiryTimer

        repeat: false

        onTriggered: {
            root.processExpirations()
            root.scheduleExpiry()
        }
    }

    IpcHandler {
        target: "toast"

        function push(
            screenName: string,
            icon: string,
            title: string,
            body: string
        ): void {
            root.push(screenName, icon, title, body)
        }

        function pushImage(
            screenName: string,
            icon: string,
            title: string,
            body: string,
            imagePath: string
        ): void {
            root.push(
                screenName,
                icon,
                title,
                body,
                undefined,
                imagePath,
                [
                    {
                        actionId: "open-image",
                        label: "Open",
                        icon: "open_in_new"
                    }
                ]
            )
        }
    }
}
