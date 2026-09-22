pragma Singleton

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property bool open: false
    property string query: ""
    property string viewMode: "recent"
    property int selectedIndex: 0
    property string lastImageHash: ""
    property string lastImageMime: ""
    property string lastImageCapturePath: ""
    property string lastImageCaptureMime: ""
    property var pendingHistoryEntries: []
    property int pendingHistoryIndex: 0
    readonly property int historyLimit: 100
    readonly property var entries: historyModel

    readonly property ListModel historyModel: ListModel {}

    readonly property FileView historyFile: FileView {
        path: Quickshell.stateDir + "/clipboard-history.json"
        blockLoading: true
        printErrors: false
    }

    readonly property Process typeProcess: Process {
        command: [
            "wl-paste",
            "--list-types"
        ]

        stdout: StdioCollector {
            id: typeOutput
            onStreamFinished: root.receiveTypes(typeOutput.text)
        }

        onExited: (exitCode, exitStatus) => pollTimer.restart()
    }

    readonly property Process readProcess: Process {
        command: [
            "wl-paste",
            "--no-newline",
            "--type",
            "text"
        ]

        stdout: StdioCollector {
            id: readOutput

            onStreamFinished: root.receive(readOutput.text)
        }

        onExited: (exitCode, exitStatus) => pollTimer.restart()
    }

    readonly property Process imageHashProcess: Process {
        stdout: StdioCollector {
            id: imageHashOutput

            onStreamFinished: {
                root.receiveImageHash(imageHashOutput.text)
            }
        }
    }

    readonly property Process imageCaptureProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.addCapturedImage()

            root.pollTimer.restart()
        }
    }

    readonly property Process imageValidationProcess: Process {
        onExited: (exitCode, exitStatus) => {
            const value = root.pendingHistoryEntries[
                root.pendingHistoryIndex
            ]

            if (exitCode === 0 && value)
                root.appendHistoryValue(value)

            root.pendingHistoryIndex += 1
            root.loadNextHistoryEntry()
        }
    }

    readonly property Process copyProcess: Process {}
    readonly property Process copyImageProcess: Process {}
    readonly property Process openProcess: Process {}

    readonly property Timer pollTimer: Timer {
        // Clipboard history does not need sub-second polling. Keeping this at
        // 2s greatly reduces wl-paste processes while remaining responsive.
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.poll()
    }

    function load() {
        const text = historyFile.text()

        if (!text || text.trim() === "")
            return

        try {
            const values = JSON.parse(text)

            if (!Array.isArray(values))
                return

            root.pendingHistoryEntries = values
            root.pendingHistoryIndex = 0
            root.loadNextHistoryEntry()
        } catch (error) {
            console.warn("Could not read clipboard-history.json:", error)
        }
    }

    function loadNextHistoryEntry() {
        if (
            root.pendingHistoryIndex
            >= root.pendingHistoryEntries.length
        ) {
            root.trim()
            root.save()
            return
        }

        const value = root.pendingHistoryEntries[
            root.pendingHistoryIndex
        ]

        if (
            !value
            || (
                (value.text === undefined || value.text === "")
                && !value.imagePath
            )
        ) {
            root.pendingHistoryIndex += 1
            root.loadNextHistoryEntry()
            return
        }

        if (value.imagePath) {
            imageValidationProcess.command = [
                "sh",
                "-c",
                "test -s \"$1\" && file --brief --mime-type \"$1\" | grep -q '^image/'",
                "clipboard-image-validate",
                value.imagePath
            ]
            imageValidationProcess.running = true
            return
        }

        root.appendHistoryValue(value)
        root.pendingHistoryIndex += 1
        root.loadNextHistoryEntry()
    }

    function appendHistoryValue(value) {
        const textValue = value.text || ""
        const entry = value.imagePath
            ? root.entryFromImage(
                value.imagePath,
                value.mime || "image/png",
                Number(value.timestamp) || Date.now(),
                value.hash || ""
            )
            : root.entryFromText(
                `${textValue}`,
                Number(value.timestamp) || Date.now()
            )

        historyModel.append({
            text: entry.text || "",
            timestamp: entry.timestamp || Date.now(),
            type: entry.type || "text",
            icon: entry.icon || "content_paste",
            label: entry.label || "Text",
            preview: entry.preview || entry.text || "",
            imagePath: entry.imagePath || "",
            mime: entry.mime || "",
            hash: entry.hash || "",
            pinned: Boolean(value.pinned),
        })

        if (entry.hash)
            root.lastImageHash = entry.hash
    }

    function save() {
        const values = []

        for (let i = 0; i < historyModel.count; ++i) {
            const entry = historyModel.get(i)
            const text = entry.text || ""
            const imagePath = entry.imagePath || ""

            if (text === "" && imagePath === "")
                continue

            const type = imagePath
                ? "image"
                : entry.type || root.entryType(text)

            values.push({
                text,
                timestamp: Number(entry.timestamp) || Date.now(),
                type,
                icon: entry.icon || root.entryIcon(type),
                label: entry.label || root.entryLabel(type),
                preview: entry.preview || (
                    imagePath ? "Clipboard image" : root.normalizedText(text)
                ),
                imagePath,
                mime: entry.mime || "",
                hash: entry.hash || "",
                pinned: Boolean(entry.pinned),
            })
        }

        historyFile.setText(JSON.stringify(values, null, 2))
    }

    function trim() {
        while (historyModel.count > root.historyLimit)
            historyModel.remove(historyModel.count - 1)
    }

    function poll() {
        if (!typeProcess.running)
            typeProcess.running = true
    }

    function receiveTypes(value) {
        const types = `${value}`
            .split(/\r?\n/)
            .map(item => item.trim())
            .filter(item => item.length > 0)

        const imageType = types.find(item => {
            return [
                "image/png",
                "image/jpeg",
                "image/webp",
                "image/gif"
            ].includes(item)
        })

        if (imageType) {
            root.lastImageMime = imageType
            imageHashProcess.command = [
                "sh",
                "-c",
                "wl-paste --type \"$1\" | sha256sum",
                "clipboard-image-hash",
                imageType
            ]
            imageHashProcess.running = true
            return
        }

        if (!readProcess.running)
            readProcess.running = true
    }

    function receiveImageHash(value) {
        const hash = `${value}`.trim().split(/\s+/)[0]

        if (!hash || hash === root.lastImageHash)
            return

        const mime = root.lastImageMime || "image/png"

        root.lastImageHash = hash
        root.lastImageCaptureMime = mime
        root.lastImageCapturePath =
            Quickshell.stateDir
            + "/clipboard-images/"
            + Date.now()
            + root.imageExtension(mime)

        imageCaptureProcess.command = [
            "sh",
            "-c",
            "set -eu; mkdir -p \"$1\"; tmp=\"$(mktemp \"$1/.clipboard-image.XXXXXX\")\"; trap 'rm -f \"$tmp\"' EXIT; wl-paste --type \"$2\" > \"$tmp\"; test -s \"$tmp\"; mv \"$tmp\" \"$3\"; trap - EXIT",
            "clipboard-image-capture",
            Quickshell.stateDir + "/clipboard-images",
            mime,
            root.lastImageCapturePath
        ]
        imageCaptureProcess.running = true
    }

    function imageExtension(mime) {
        switch (mime) {
        case "image/jpeg":
            return ".jpg"
        case "image/webp":
            return ".webp"
        case "image/gif":
            return ".gif"
        default:
            return ".png"
        }
    }

    function entryFromImage(path, mime, timestamp, hash) {
        return {
            text: "",
            timestamp,
            type: "image",
            icon: "image",
            label: "Image",
            preview: "Clipboard image",
            imagePath: path,
            mime,
            hash: hash || "",
            pinned: false,
        }
    }

    function addCapturedImage() {
        const path = root.lastImageCapturePath
        const mime = root.lastImageCaptureMime || "image/png"

        if (!path)
            return

        for (let i = 0; i < historyModel.count; ++i) {
            if (historyModel.get(i).imagePath === path)
                return
        }

        historyModel.insert(0, root.entryFromImage(
            path,
            mime,
            Date.now(),
            root.lastImageHash
        ))
        root.trim()
        root.save()
    }

    function receive(value) {
        if (!value || value.length === 0)
            return

        for (let i = 0; i < historyModel.count; ++i) {
            if (historyModel.get(i).text === value) {
                if (i > 0) {
                    const pinned = Boolean(historyModel.get(i).pinned)
                    historyModel.remove(i)
                    const entry = root.entryFromText(value, Date.now())
                    entry.pinned = pinned
                    historyModel.insert(0, entry)
                    root.save()
                }
                return
            }
        }

        const entry = root.entryFromText(value, Date.now())

        historyModel.insert(0, {
            text: entry.text || value,
            timestamp: entry.timestamp || Date.now(),
            type: entry.type || "text",
            icon: entry.icon || "content_paste",
            label: entry.label || "Text",
            preview: entry.preview || value,
            imagePath: "",
            mime: "",
            hash: "",
            pinned: false,
        })
        root.trim()
        root.save()
    }

    function normalizedText(value) {
        return value
            .replace(/\s+/g, " ")
            .trim()
    }

    function entryType(text) {
        const trimmed = text.trim()

        if (/^https?:\/\/\S+$/i.test(trimmed))
            return "url"

        if (/^(file:\/\/|\/|~\/|\.\.?\/)[^\n]+$/.test(trimmed))
            return "path"

        if (
            trimmed.includes("\n")
            && /[{};=<>]|^\s*(function|const|let|var|class|import|export|def|return)\b/m.test(trimmed)
        ) {
            return "code"
        }

        if (trimmed.includes("\n"))
            return "multiline"

        return "text"
    }

    function entryIcon(type) {
        switch (type) {
        case "url":
            return "link"
        case "path":
            return "folder"
        case "code":
            return "code"
        case "multiline":
            return "notes"
        default:
            return "content_paste"
        }
    }

    function entryLabel(type) {
        switch (type) {
        case "url":
            return "Link"
        case "path":
            return "Path"
        case "code":
            return "Code"
        case "multiline":
            return "Text"
        default:
            return "Text"
        }
    }

    function entryFromText(text, timestamp) {
        const type = root.entryType(text)
        const preview = root.normalizedText(text)

        return {
            text,
            timestamp,
            type,
            icon: root.entryIcon(type),
            label: root.entryLabel(type),
            preview,
            imagePath: "",
            mime: "",
            hash: "",
            pinned: false,
        }
    }

    function filteredValues() {
        const normalized = root.query.trim().toLowerCase()
        const values = []

        for (let i = 0; i < historyModel.count; ++i) {
            const entry = historyModel.get(i)
            const entryText = entry.text || ""
            const entryPreview = entry.preview || entryText
            const entryLabel = entry.label || "Text"
            const pinned = Boolean(entry.pinned)

            if (
                (root.viewMode === "pinned" && !pinned)
                || (root.viewMode === "recent" && pinned)
            )
                continue

            if (
                normalized === ""
                || entryText.toLowerCase().includes(normalized)
                || entryPreview.toLowerCase().includes(normalized)
                || entryLabel.toLowerCase().includes(normalized)
            ) {
                values.push({
                    text: entryText,
                    timestamp: entry.timestamp || Date.now(),
                    type: entry.type || "text",
                    icon: entry.icon || "content_paste",
                    label: entryLabel,
                    preview: entryPreview,
                    filteredIndex: values.length,
                    imagePath: entry.imagePath || "",
                    mime: entry.mime || "",
                    hash: entry.hash || "",
                    pinned,
                    sourceIndex: i,
                })
            }
        }

        return values
    }

    function columnValues(column, columns) {
        const count = columns || 3

        return root.filteredValues().filter((entry, index) => {
            return index % count === column
        })
    }

    function togglePin(index) {
        if (index < 0 || index >= historyModel.count)
            return

        const entry = historyModel.get(index)
        historyModel.setProperty(index, "pinned", !Boolean(entry.pinned))
        root.save()
    }

    function copy(text) {
        if (!text)
            return

        copyProcess.command = [
            "sh",
            "-c",
            "printf '%s' \"$1\" | wl-copy",
            "clipboard-copy",
            text
        ]
        copyProcess.running = true
        root.close()
    }

    function copyEntry(entry) {
        if (!entry)
            return

        if (entry.type === "image" && entry.imagePath) {
            copyImageProcess.command = [
                "sh",
                "-c",
                "wl-copy --type \"$1\" < \"$2\"",
                "clipboard-image-copy",
                entry.mime || "image/png",
                entry.imagePath
            ]
            copyImageProcess.running = true
            root.close()
            return
        }

        root.copy(entry.text)
    }

    function canOpenEntry(entry) {
        if (!entry)
            return false

        return (
            (entry.type === "image" && entry.imagePath)
            || entry.type === "url"
            || entry.type === "path"
        )
    }

    function expandedPath(path) {
        const value = `${path || ""}`.trim()

        if (value.startsWith("file://"))
            return decodeURIComponent(value.slice("file://".length))

        return value
    }

    function openEntry(entry, screenName) {
        if (!entry)
            return

        if (entry.type === "image" && entry.imagePath) {
            ImageViewerService.open(entry.imagePath, screenName || "")
            root.close()
            return
        }

        if (entry.type === "url" && entry.text) {
            openProcess.command = [
                "xdg-open",
                entry.text.trim()
            ]
            openProcess.running = true
            root.close()
            return
        }

        if (entry.type === "path" && entry.text) {
            openProcess.command = [
                "sh",
                "-c",
                "value=\"$1\"; case \"$value\" in ~/*) value=\"$HOME/${value#~/}\";; esac; xdg-open \"$value\"",
                "clipboard-open-path",
                root.expandedPath(entry.text)
            ]
            openProcess.running = true
            root.close()
        }
    }

    function remove(index) {
        if (index < 0 || index >= historyModel.count)
            return

        historyModel.remove(index)
        root.save()
    }

    function clear() {
        for (let i = historyModel.count - 1; i >= 0; --i) {
            if (!Boolean(historyModel.get(i).pinned))
                historyModel.remove(i)
        }

        root.lastImageHash = ""
        root.save()
    }

    function toggle() {
        root.open = !root.open

        if (root.open) {
            root.query = ""
            root.viewMode = "recent"
            root.selectedIndex = 0
            root.poll()
        }
    }

    function close() {
        root.open = false
        root.query = ""
        root.viewMode = "recent"
        root.selectedIndex = 0
    }

    Component.onCompleted: {
        root.load()
        root.poll()
    }
}
