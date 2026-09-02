pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property var displays: []

    readonly property var ddcMonitorMap: {
        const next = {}

        for (const display of root.displays) {
            const connector =
                root.normalizeConnector(
                    display?.connector ?? ""
                )

            if (!connector)
                continue

            next[connector] = display
        }

        return next
    }

    readonly property var monitors:
        monitorVariants.instances

    readonly property int wheelCommitDelay: 75
    readonly property int sliderCommitDelay: 350

    readonly property Variants monitorVariants: Variants {
        model: Quickshell.screens

        QtObject {
            id: monitor

            property var modelData: null
            property int _lastInitializedBus: -1
            property int queuedBrightness: -1
            property bool writeInFlight: false

            readonly property string screenName:
                monitor.modelData?.name ?? ""

            readonly property var ddcInfo:
                monitor.screenName.length > 0
                    ? (
                        root.ddcMonitorMap[
                            monitor.screenName
                        ] ?? null
                    )
                    : null

            readonly property int bus:
                monitor.ddcInfo?.bus ?? 0

            readonly property string name:
                monitor.ddcInfo?.name
                ?? monitor.screenName

            readonly property int brightness:
                monitor.ddcInfo?.brightness ?? 0

            readonly property int maxBrightness:
                monitor.ddcInfo?.maxBrightness
                ?? 100

            readonly property bool available:
                monitor.ddcInfo?.readable === true

            readonly property int brightnessPercent:
                monitor.available
                && monitor.maxBrightness > 0
                    ? Math.round(
                        monitor.brightness
                        / monitor.maxBrightness
                        * 100
                    )
                    : 0

            function initBrightness() {
                if (!monitor.modelData)
                    return

                if (monitor.bus <= 0)
                    return

                if (initProc.running)
                    return

                monitor._lastInitializedBus =
                    monitor.bus

                initProc.command = [
                    "ddcutil",
                    "getvcp",
                    "--bus",
                    monitor.bus.toString(),
                    "--terse",
                    "10"
                ]

                initProc.running = true
            }

            function setBrightness(
                value,
                commitDelay
            ) {
                if (!monitor.available)
                    return

                const target =
                    Math.max(
                        0,
                        Math.min(
                            Math.round(value),
                            monitor.maxBrightness
                        )
                    )

                if (
                    target === monitor.brightness
                    && monitor.queuedBrightness < 0
                ) {
                    return
                }

                root.updateDisplay(
                    monitor.ddcInfo,
                    {
                        brightness: target,
                        readable: true
                    }
                )

                monitor.queuedBrightness = target

                writeDebounceTimer.interval =
                    commitDelay
                    ?? root.sliderCommitDelay

                writeDebounceTimer.restart()
            }

            function changeBrightness(
                deltaPercent
            ) {
                if (!monitor.available)
                    return

                const rawDelta =
                    Math.max(
                        1,
                        Math.round(
                            monitor.maxBrightness
                            * Math.abs(
                                deltaPercent
                            )
                            / 100
                        )
                    )
                    * (
                        deltaPercent >= 0
                            ? 1
                            : -1
                    )

                monitor.setBrightness(
                    monitor.brightness + rawDelta,
                    root.wheelCommitDelay
                )
            }

            function startPendingWrite() {
                if (
                    !monitor.available
                    || monitor.bus <= 0
                    || monitor.queuedBrightness < 0
                    || monitor.writeInFlight
                ) {
                    return
                }

                const target =
                    monitor.queuedBrightness

                monitor.queuedBrightness = -1
                monitor.writeInFlight = true

                setProc.command = [
                    "ddcutil",
                    "setvcp",
                    "--bus",
                    monitor.bus.toString(),
                    "10",
                    target.toString()
                ]

                setProc.running = true
            }

            readonly property Process initProc: Process {
                stdout: StdioCollector {
                    id: initCollector
                }

                stderr: StdioCollector {
                    id: initErrorCollector
                }

                onExited: (
                    exitCode,
                    exitStatus
                ) => {
                    if (!monitor.ddcInfo)
                        return

                    if (exitCode !== 0) {
                        console.warn(
                            "Brightness monitor getvcp failed:",
                            monitor.screenName,
                            exitCode,
                            exitStatus
                        )

                        if (initErrorCollector.text !== "") {
                            console.warn(
                                "Brightness monitor getvcp stderr:",
                                initErrorCollector.text
                            )
                        }

                        root.updateDisplay(
                            monitor.ddcInfo,
                            {
                                readable: false
                            }
                        )

                        return
                    }

                    const parsed =
                        root.parseBrightness(
                            initCollector.text
                        )

                    if (!parsed) {
                        root.updateDisplay(
                            monitor.ddcInfo,
                            {
                                readable: false
                            }
                        )

                        return
                    }

                    root.updateDisplay(
                        monitor.ddcInfo,
                        {
                            brightness:
                                parsed.current,

                            maxBrightness:
                                parsed.maximum,

                            readable: true
                        }
                    )
                }
            }

            readonly property Process setProc: Process {
                stderr: StdioCollector {
                    id: setErrorCollector
                }

                onExited: (
                    exitCode,
                    exitStatus
                ) => {
                    monitor.writeInFlight = false

                    if (exitCode !== 0) {
                        console.warn(
                            "Brightness monitor setvcp failed:",
                            monitor.screenName,
                            exitCode,
                            exitStatus
                        )

                        if (setErrorCollector.text !== "") {
                            console.warn(
                                "Brightness monitor setvcp stderr:",
                                setErrorCollector.text
                            )
                        }

                        monitor.initBrightness()
                        return
                    }

                    if (monitor.queuedBrightness >= 0)
                        writeDebounceTimer.restart()
                }
            }

            readonly property Timer writeDebounceTimer: Timer {
                interval: root.sliderCommitDelay
                repeat: false

                onTriggered: {
                    monitor.startPendingWrite()
                }
            }

            onModelDataChanged: {
                monitor.initBrightness()
            }

            onBusChanged: {
                if (
                    monitor.bus > 0
                    && monitor.bus
                        !== monitor._lastInitializedBus
                ) {
                    monitor.initBrightness()
                }
            }

            Component.onCompleted: {
                monitor.initBrightness()
            }
        }
    }

    function refresh() {
        if (detectProcess.running)
            return

        detectProcess.running = true
    }

    function sameDisplay(a, b) {
        if (!a || !b)
            return false

        if (a.bus > 0 && b.bus > 0)
            return a.bus === b.bus

        return a.number === b.number
    }

    function normalizeConnector(value) {
        if (!value)
            return ""

        return String(value)
            .trim()
            .replace(/^card\d+-/, "")
    }

    function mergeDetectedDisplays(detected) {
        return detected.map(display => {
            const previous =
                root.displays.find(item => {
                    return root.sameDisplay(
                        item,
                        display
                    )
                })

            if (!previous)
                return display

            return Object.assign(
                {},
                display,
                {
                    brightness:
                        previous.brightness,

                    maxBrightness:
                        previous.maxBrightness,

                    readable:
                        previous.readable,

                    writable:
                        previous.writable
                }
            )
        })
    }

    function updateDisplay(display, patch) {
        if (!display)
            return

        root.displays =
            root.displays.map(item => {
                if (
                    !root.sameDisplay(
                        item,
                        display
                    )
                ) {
                    return item
                }

                return Object.assign(
                    {},
                    item,
                    patch
                )
            })
    }

    function monitorForScreen(screen) {
        if (!screen)
            return null

        return root.monitors.find(monitor => {
            return monitor?.modelData === screen
        }) ?? null
    }

    function displayForScreen(screen) {
        const monitor =
            root.monitorForScreen(screen)

        return monitor?.ddcInfo ?? null
    }

    function brightnessForScreen(screen) {
        const monitor =
            root.monitorForScreen(screen)

        return monitor?.available
            ? monitor.brightness
            : 0
    }

    function brightnessPercentForScreen(screen) {
        const monitor =
            root.monitorForScreen(screen)

        if (
            !monitor
            || !monitor.available
        ) {
            return 0
        }

        return monitor.brightnessPercent
    }

    function availableForScreen(screen) {
        const monitor =
            root.monitorForScreen(screen)

        return monitor?.available ?? false
    }

    function setBrightnessForScreen(
        screen,
        value,
        commitDelay
    ) {
        const monitor =
            root.monitorForScreen(screen)

        if (!monitor)
            return

        monitor.setBrightness(
            value,
            commitDelay
        )
    }

    function changeBrightnessForScreen(
        screen,
        deltaPercent
    ) {
        const monitor =
            root.monitorForScreen(screen)

        if (!monitor)
            return

        monitor.changeBrightness(
            deltaPercent
        )
    }

    function parseDisplays(text) {
        const lines =
            text.split(/\r?\n/)

        const displays = []
        let current = null

        for (const line of lines) {
            let match =
                line.match(
                    /^Display\s+(\d+)/
                )

            if (match) {
                if (current)
                    displays.push(current)

                current = {
                    number:
                        parseInt(match[1]),
                    bus: 0,
                    connector: "",
                    manufacturer: "",
                    model: "",
                    serial: "",
                    name: ""
                }

                continue
            }

            if (!current)
                continue

            match =
                line.match(
                    /I2C bus:\s+\/dev\/i2c-(\d+)/
                )

            if (match) {
                current.bus =
                    parseInt(match[1])
                continue
            }

            match =
                line.match(
                    /DRM connector:\s+(.+)/
                )

            if (match) {
                current.connector =
                    root.normalizeConnector(
                        match[1].trim()
                    )
                continue
            }

            match =
                line.match(
                    /Mfg id:\s+([^\s]+)/
                )

            if (match) {
                current.manufacturer =
                    match[1]
                continue
            }

            match =
                line.match(
                    /Model:\s+(.+)/
                )

            if (match) {
                current.model =
                    match[1].trim()
                continue
            }

            match =
                line.match(
                    /Monitor:\s+([^:]+):([^:]+):(.+)/
                )

            if (match) {
                current.manufacturer =
                    match[1].trim()
                current.model =
                    match[2].trim()
                current.serial =
                    match[3].trim()
                continue
            }

            match =
                line.match(
                    /Serial number:\s+(.+)/
                )

            if (match)
                current.serial = match[1].trim()
        }

        if (current)
            displays.push(current)

        return displays.map(display => {
            return {
                number:
                    display.number,
                bus:
                    display.bus,
                connector:
                    display.connector,
                manufacturer:
                    display.manufacturer,
                model:
                    display.model,
                serial:
                    display.serial,
                name:
                    display.model !== ""
                        ? display.model
                        : "Display "
                            + display.number,
                brightness: 0,
                maxBrightness: 100,
                readable: false,
                writable: true
            }
        })
    }

    function parseBrightness(text) {
        const match =
            text.match(
                /VCP\s+10\s+\S+\s+(\d+)\s+(\d+)/
            )

        if (!match)
            return null

        return {
            current:
                parseInt(match[1]),
            maximum:
                parseInt(match[2])
        }
    }

    readonly property Process detectProcess: Process {
        command: [
            "ddcutil",
            "detect",
            "--brief"
        ]

        stdout: StdioCollector {
            id: detectCollector
        }

        stderr: StdioCollector {
            id: detectErrorCollector
        }

        onExited: (
            exitCode,
            exitStatus
        ) => {
            if (exitCode !== 0) {
                if (detectErrorCollector.text !== "") {
                    console.warn(
                        "Brightness detect stderr:",
                        detectErrorCollector.text
                    )
                }

                return
            }

            const parsed =
                root.parseDisplays(
                    detectCollector.text
                )

            root.displays =
                root.mergeDetectedDisplays(
                    parsed
                )
        }
    }

    Component.onCompleted: {
        root.refresh()
    }
}
