pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string currentPath: ""
    property string targetScreenName: ""
    property bool visible: false

    function open(path, screenName) {
        root.currentPath = path ?? ""
        root.targetScreenName = screenName ?? ""
        root.visible = root.currentPath.length > 0
    }

    function close() {
        root.visible = false
    }

    function fileNameFor(path) {
        if (!path || path.length === 0)
            return "Image Viewer"

        const parts = path.split("/")
        return parts[parts.length - 1]
    }

    IpcHandler {
        target: "imageviewer"

        function open(
            path: string,
            screenName: string
        ): void {
            root.open(path, screenName)
        }

        function close(): void {
            root.close()
        }
    }
}
