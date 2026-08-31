pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    // ============================================================
    // Public state
    // ============================================================

    property bool available: false

    property var displays: []
    property var currentDisplay: null

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

    property int brightness: 0
    property int maxBrightness: 100

    readonly property int brightnessPercent:
        root.maxBrightness > 0
            ? Math.round(
                root.brightness
                / root.maxBrightness
                * 100
            )
            : 0


    // ============================================================
    // Internal state
    // ============================================================

    property int _stateRevision: 0
    property int _detectRevision: -1
    property int _readRevision: -1

    property int _pendingBrightness: -1
    property int _writeTarget: -1

    property var _readDisplay: null
    property var _writeDisplay: null
    property var _readQueue: []

    property string _readPurpose: ""
    property string _writeStep: ""

    property bool _readInProgress: false
    property bool _writeInFlight: false
    property bool _localOverrideActive: false

    readonly property int wheelCommitDelay: 75
    readonly property int sliderCommitDelay: 350
    readonly property int pollInterval: 3000

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


    // ============================================================
    // Discovery
    // ============================================================

    function refresh() {
        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || root._readInProgress
            || setDebounceTimer.running
        ) {
            return
        }

        root._detectRevision =
            root._stateRevision

        detectProcess.running = true
    }


    // ============================================================
    // Display helpers
    // ============================================================

    function sameDisplay(a, b) {
        if (!a || !b)
            return false

        if (a.bus > 0 && b.bus > 0)
            return a.bus === b.bus

        return a.number === b.number
    }

    function chooseCurrentDisplay(displays) {
        if (root.currentDisplay) {
            const existing =
                displays.find(display => {
                    return root.sameDisplay(
                        display,
                        root.currentDisplay
                    )
                })

            if (existing)
                return existing
        }

        return displays.length > 0
            ? displays[0]
            : null
    }

    function normalizeConnector(value) {
        if (!value)
            return ""

        return String(value)
            .trim()
            .replace(/^card\d+-/, "")
    }

    function displayForScreen(screen) {
        const monitor =
            root.monitorForScreen(screen)

        if (monitor?.ddcInfo)
            return monitor.ddcInfo

        if (!screen)
            return null

        const connector =
            root.normalizeConnector(
                screen.name ?? ""
            )

        if (!connector)
            return null

        for (const display of root.displays) {
            if (
                root.normalizeConnector(
                    display?.connector ?? ""
                ) === connector
            ) {
                return display
            }
        }

        return null
    }

    function monitorForScreen(screen) {
        if (!screen)
            return null

        return root.monitors.find(monitor => {
            return monitor?.modelData === screen
        }) ?? null
    }

    function monitorForDisplay(display) {
        if (!display)
            return null

        if (display.connector) {
            const connector =
                root.normalizeConnector(
                    display.connector
                )

            const byConnector =
                root.monitors.find(monitor => {
                    return (
                        root.normalizeConnector(
                            monitor?.screenName ?? ""
                        ) === connector
                    )
                }) ?? null

            if (byConnector)
                return byConnector
        }

        if (display.bus > 0) {
            return root.monitors.find(monitor => {
                return monitor?.bus === display.bus
            }) ?? null
        }

        return null
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

    function selectDisplay(bus) {
        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || setDebounceTimer.running
        ) {
            return
        }

        const display =
            root.displays.find(item => {
                return item.bus === bus
            })

        if (!display)
            return

        if (
            root.currentDisplay
            && root.currentDisplay.bus === display.bus
        ) {
            return
        }

        root.currentDisplay = display
        root.available =
            display.readable === true

        if (display.readable === true) {
            root.brightness =
                display.brightness

            root.maxBrightness =
                display.maxBrightness
        }

        root.startRead(
            display,
            "selection"
        )
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
                        previous.writable,

                    writeMode:
                        previous.writeMode
                }
            )
        })
    }

    function updateDisplay(display, patch) {
        if (!display)
            return

        const updatedDisplays =
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

        root.displays =
            updatedDisplays

        const updated =
            updatedDisplays.find(item => {
                return root.sameDisplay(
                    item,
                    display
                )
            }) ?? Object.assign(
                {},
                display,
                patch
            )

        root.syncCurrentDisplayState()
    }

    function syncCurrentDisplayState() {
        if (!root.currentDisplay) {
            root.available = false
            return
        }

        const updated =
            root.displays.find(item => {
                return root.sameDisplay(
                    item,
                    root.currentDisplay
                )
            }) ?? root.currentDisplay

        root.currentDisplay = updated

        if (
            root.sameDisplay(
                updated,
                root.currentDisplay
            )
        ) {
            if (updated.readable === true) {
                root.brightness =
                    updated.brightness

                root.maxBrightness =
                    updated.maxBrightness

                root.available = true
            } else {
                root.available = false
            }
        }
    }


    // ============================================================
    // Public brightness API
    // ============================================================

    function setBrightness(
        value,
        commitDelay
    ) {
        if (!root.currentDisplay)
            return

        root.setBrightnessForDisplay(
            root.currentDisplay,
            value,
            commitDelay
        )
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

    function setBrightnessForDisplay(
        display,
        value,
        commitDelay
    ) {
        if (!display)
            return

        const monitor =
            root.monitorForDisplay(display)

        if (monitor) {
            monitor.setBrightness(
                value,
                commitDelay
            )
            return
        }

        if (
            !root.sameDisplay(
                display,
                root.currentDisplay
            )
        ) {
            root.currentDisplay = display
            root.available =
                display.readable === true

            if (display.readable === true) {
                root.brightness =
                    display.brightness

                root.maxBrightness =
                    display.maxBrightness
            }
        }

        if (!root.available) {
            return
        }

        const target =
            Math.max(
                0,
                Math.min(
                    Math.round(value),
                    root.maxBrightness
                )
            )

        if (
            target === root.brightness
            && root._pendingBrightness < 0
        ) {
            return
        }

        // Optimistic UI update.
        //
        // Example:
        //
        // 70 -> scroll -> 75
        //
        // The bar immediately displays 75 even though
        // the physical DDC transaction happens later.
        root.brightness =
            target

        // Any read started before this interaction
        // is no longer authoritative.
        root._stateRevision += 1

        root._pendingBrightness =
            target

        root._localOverrideActive =
            true

        setDebounceTimer.interval =
            commitDelay
            ?? root.sliderCommitDelay

        setDebounceTimer.restart()
    }

    function changeBrightness(
        deltaPercent
    ) {
        if (!root.currentDisplay)
            return

        const monitor =
            root.monitorForDisplay(
                root.currentDisplay
            )

        if (monitor) {
            monitor.changeBrightness(
                deltaPercent
            )
            return
        }

        if (!root.available)
            return

        const rawDelta =
            Math.max(
                1,
                Math.round(
                    root.maxBrightness
                    * Math.abs(deltaPercent)
                    / 100
                )
            )
            * (
                deltaPercent >= 0
                    ? 1
                    : -1
            )

        root.setBrightness(
            root.brightness + rawDelta,
            root.wheelCommitDelay
        )
    }

    function changeBrightnessForScreen(
        screen,
        deltaPercent
    ) {
        const monitor =
            root.monitorForScreen(screen)

        if (
            !monitor
        ) {
            return
        }

        monitor.changeBrightness(
            deltaPercent
        )
    }


    // ============================================================
    // Read queue lifecycle
    // ============================================================

    function clearReadQueue() {
        root._readQueue = []
        root._readDisplay = null
        root._readPurpose = ""
        root._readInProgress = false
    }

    function refreshAllDisplays(purpose) {
        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || root._localOverrideActive
            || root._readInProgress
            || getProcess.running
        ) {
            return
        }

        root.startReadQueue(
            root.displays,
            purpose ?? "refresh"
        )
    }

    function startReadQueue(
        displays,
        purpose
    ) {
        if (
            root._writeInFlight
            || getProcess.running
        ) {
            return
        }

        const queue =
            displays.filter(display => {
                return display
                    && display.bus > 0
            }).slice()

        if (queue.length === 0) {
            root.clearReadQueue()
            return
        }

        root._readQueue = queue
        root._readPurpose = purpose
        root._readInProgress = false

        root.readNextInQueue()
    }

    function readNextInQueue() {
        if (
            root._writeInFlight
            || getProcess.running
        ) {
            return
        }

        if (root._readQueue.length === 0) {
            root.clearReadQueue()
            return
        }

        const queue =
            root._readQueue.slice()

        const display = queue.shift()

        root._readQueue = queue

        root.startRead(
            display,
            root._readPurpose
        )
    }


    // ============================================================
    // Brightness reads
    // ============================================================

    function readBrightness() {
        if (
            root.displays.length === 0
        ) {
            return
        }

        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || setDebounceTimer.running
            || root._localOverrideActive
        ) {
            return
        }

        root.refreshAllDisplays(
            "refresh"
        )
    }

    function startRead(
        display,
        purpose
    ) {
        if (
            !display
            || display.bus <= 0
        ) {
            return
        }

        root._readDisplay =
            display

        root._readPurpose =
            purpose

        root._readRevision =
            root._stateRevision

        root._readInProgress = true

        getProcess.command = [
            "ddcutil",
            "getvcp",
            "--bus",
            display.bus.toString(),
            "--terse",
            "10"
        ]

        getProcess.running = true
    }


    // ============================================================
    // Brightness writes
    // ============================================================

    function startPendingWrite() {
        if (
            !root.currentDisplay
            || root._pendingBrightness < 0
        ) {
            return
        }

        root.clearReadQueue()

        root._writeDisplay =
            root.currentDisplay

        root._writeTarget =
            root._pendingBrightness

        root._pendingBrightness = -1

        root._writeInFlight = true

        if (getProcess.running)
            getProcess.running = false

        if (
            root._writeDisplay.writeMode
            === "scs"
        ) {
            root.startScsSet()
        } else {
            root.startNormalSet()
        }
    }

    function startNormalSet() {
        root._writeStep =
            "normal-set"

        setProcess.command = [
            "ddcutil",
            "setvcp",
            "--bus",
            root._writeDisplay.bus.toString(),
            "10",
            root._writeTarget.toString()
        ]

        setProcess.running = true
    }

    function startScsSet() {
        root._writeStep =
            "scs-set"

        setProcess.command = [
            "ddcutil",
            "setvcp",
            "--noverify",
            "--bus",
            root._writeDisplay.bus.toString(),
            "10",
            root._writeTarget.toString()
        ]

        setProcess.running = true
    }

    function startScsSave() {
        root._writeStep =
            "scs-save"

        scsProcess.command = [
            "ddcutil",
            "scs",
            "--bus",
            root._writeDisplay.bus.toString()
        ]

        scsProcess.running = true
    }

    function finishWrite(
        success,
        writeMode
    ) {
        if (
            success
            && root._writeDisplay
        ) {
            root.updateDisplay(
                root._writeDisplay,
                {
                    brightness:
                        root._writeTarget,

                    maxBrightness:
                        root.maxBrightness,

                    readable: true,
                    writable: true,

                    writeMode:
                        writeMode
                }
            )
        }

        root._writeInFlight = false
        root._writeTarget = -1
        root._writeDisplay = null
        root._writeStep = ""

        // Another scroll/slider value arrived while
        // the previous DDC transaction was running.
        if (root._pendingBrightness >= 0) {
            setDebounceTimer.restart()
            return
        }

        // Local state is no longer privileged.
        // External OSD changes may update the Service again.
        root._localOverrideActive = false

        Qt.callLater(() => {
            root.refreshAllDisplays(
                "post-write"
            )
        })
    }


    // ============================================================
    // Display parser
    // ============================================================

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

            // Format used by `ddcutil detect --brief`.
            //
            // Example:
            //
            // Monitor: MSI:MSI MP275:PC3M...
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

            if (match) {
                current.serial =
                    match[1].trim()
            }
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
                writable: true,

                // Learned automatically:
                //
                // unknown
                //   -> normal
                //
                // or:
                //
                // unknown
                //   -> normal fails
                //   -> noverify + SCS works
                //   -> scs
                writeMode: "unknown"
            }
        })
    }


    // ============================================================
    // getvcp parser
    // ============================================================

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

    function applyBrightnessOutput(text) {
        if (
            root._readPurpose !== "verify"
            && root._localOverrideActive
        ) {
            return
        }

        if (
            root._readRevision
            !== root._stateRevision
        ) {
            return
        }

        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || setDebounceTimer.running
        ) {
            return
        }

        const parsed =
            root.parseBrightness(text)

        if (!parsed) {
            if (
                root.sameDisplay(
                    root._readDisplay,
                    root.currentDisplay
                )
            ) {
                root.available = false
            }

            return
        }

        root.updateDisplay(
            root._readDisplay,
            {
                brightness:
                    parsed.current,

                maxBrightness:
                    parsed.maximum,

                readable: true
            }
        )
    }


    // ============================================================
    // ddcutil detect
    // ============================================================

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
                root.available = false

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

            // Preserve properties learned during the
            // current TartarusShell session, especially
            // writeMode = normal/scs.
            const detected =
                root.mergeDetectedDisplays(
                    parsed
                )

            root.displays =
                detected

            root.currentDisplay =
                root.chooseCurrentDisplay(
                    detected
                )

            root.syncCurrentDisplayState()

            if (!root.currentDisplay) {
                root.available = false
                return
            }

            // Discovery started before a later local
            // state change, so its follow-up read would
            // now be stale.
            if (
                root._detectRevision
                !== root._stateRevision
            ) {
                return
            }

            root.syncCurrentDisplayState()
        }
    }

    readonly property Process getProcess: Process {
        stdout: StdioCollector {
            id: getCollector
        }

        stderr: StdioCollector {
            id: getErrorCollector
        }

        onExited: (
            exitCode,
            exitStatus
        ) => {
            if (exitCode !== 0) {
                // If a local write deliberately killed
                // this read, do not report it as a real
                // backend failure.
                if (
                    !root._writeInFlight
                    && root._pendingBrightness < 0
                ) {
                    console.warn(
                        "Brightness getvcp failed:",
                        exitCode,
                        exitStatus
                    )

                    if (getErrorCollector.text !== "") {
                        console.warn(
                            "Brightness getvcp stderr:",
                            getErrorCollector.text
                        )
                    }
                }

                if (root._readDisplay) {
                    root.updateDisplay(
                        root._readDisplay,
                        {
                            readable: false
                        }
                    )
                }

                root._readDisplay = null
                root.readNextInQueue()
                return
            }

            root.applyBrightnessOutput(
                getCollector.text
            )

            root._readDisplay = null
            root.readNextInQueue()
        }
    }


    // ============================================================
    // ddcutil setvcp
    // ============================================================

    readonly property Process setProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (
                    this.text !== ""
                    && !(
                        root._writeStep
                            === "normal-set"
                        && root._writeDisplay
                        && root._writeDisplay.writeMode
                            === "unknown"
                    )
                ) {
                    console.warn(
                        "Brightness setvcp stderr:",
                        this.text
                    )
                }
            }
        }

        onExited: (
            exitCode,
            exitStatus
        ) => {
            if (
                root._writeStep
                === "normal-set"
            ) {
                if (exitCode === 0) {
                    // Normal DDC implementation.
                    root.finishWrite(
                        true,
                        "normal"
                    )

                    return
                }

                // Unknown monitor:
                //
                // normal verification failed.
                // Try the SCS fallback that the MSI
                // requires.
                if (
                    root._writeDisplay
                    && root._writeDisplay.writeMode
                        === "unknown"
                ) {
                    root.startScsSet()
                    return
                }
            } else if (
                root._writeStep
                === "scs-set"
            ) {
                if (exitCode === 0) {
                    root.startScsSave()
                    return
                }
            }

            console.warn(
                "Brightness setvcp failed:",
                exitCode,
                exitStatus
            )

            root.finishWrite(
                false,
                "unknown"
            )
        }
    }


    // ============================================================
    // ddcutil SCS
    // ============================================================

    readonly property Process scsProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text !== "") {
                    console.warn(
                        "Brightness scs stderr:",
                        this.text
                    )
                }
            }
        }

        onExited: (
            exitCode,
            exitStatus
        ) => {
            if (exitCode === 0) {
                root.finishWrite(
                    true,
                    "scs"
                )

                return
            }

            console.warn(
                "Brightness scs failed:",
                exitCode,
                exitStatus
            )

            root.finishWrite(
                false,
                "unknown"
            )
        }
    }
    // ============================================================
    // Timers
    // ============================================================

    readonly property Timer setDebounceTimer: Timer {
        id: setDebounceTimer

        interval:
            root.sliderCommitDelay

        repeat: false

        onTriggered: {
            if (
                !root.currentDisplay
                || root._pendingBrightness < 0
            ) {
                return
            }

            if (root._writeInFlight)
                return

            root.startPendingWrite()
        }
    }

    readonly property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: false

        onTriggered: {
            if (
                root._writeInFlight
                || root._pendingBrightness >= 0
                || root._localOverrideActive
                || root._readInProgress
                || getProcess.running
                || detectProcess.running
                || setProcess.running
                || scsProcess.running
                || setDebounceTimer.running
            ) {
                return
            }

            root.refreshAllDisplays(
                "poll"
            )
        }
    }


    // ============================================================
    // Startup
    // ============================================================

    Component.onCompleted: {
        root.refresh()
    }
}
