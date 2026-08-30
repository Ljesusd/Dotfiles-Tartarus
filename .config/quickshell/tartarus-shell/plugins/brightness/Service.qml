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

    property string _readPurpose: ""
    property string _writeStep: ""

    property bool _writeInFlight: false
    property bool _localOverrideActive: false

    // Whether the Service wants the watcher to stay alive.
    property bool _watchWanted: false

    // I2C bus currently watched by ddcutil.
    property int _watchBus: -1

    readonly property int wheelCommitDelay: 75
    readonly property int sliderCommitDelay: 350


    // ============================================================
    // Discovery
    // ============================================================

    function refresh() {
        if (
            root._writeInFlight
            || root._pendingBrightness >= 0
            || setDebounceTimer.running
        ) {
            return
        }

        root.stopWatch()

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

        root.stopWatch()

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

        if (
            root.sameDisplay(
                root.currentDisplay,
                display
            )
        ) {
            root.currentDisplay =
                updated

            if (updated.readable === true) {
                root.brightness =
                    updated.brightness

                root.maxBrightness =
                    updated.maxBrightness

                root.available = true
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
        if (
            !root.available
            || !root.currentDisplay
        ) {
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


    // ============================================================
    // Watch lifecycle
    // ============================================================

    function startWatch() {
        if (!root.available)
            return

        if (!root.currentDisplay)
            return

        if (root.currentDisplay.bus <= 0)
            return

        if (root._writeInFlight)
            return

        if (getProcess.running)
            return

        if (setProcess.running)
            return

        if (scsProcess.running)
            return

        if (detectProcess.running)
            return

        if (watchProcess.running)
            return

        root._watchWanted = true

        root._watchBus =
            root.currentDisplay.bus

        watchProcess.command = [
            "ddcutil",
            "watch",
            "--x52-no-fifo",
            "--bus",
            root._watchBus.toString()
        ]

        watchProcess.running = true
    }

    function stopWatch() {
        root._watchWanted = false

        watchRestartTimer.stop()

        if (watchProcess.running)
            watchProcess.running = false

        root._watchBus = -1
    }


    // ============================================================
    // Brightness reads
    // ============================================================

    function readBrightness() {
        if (
            !root.available
            || !root.currentDisplay
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

        root.startRead(
            root.currentDisplay,
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

        root.stopWatch()

        root._readDisplay =
            display

        root._readPurpose =
            purpose

        root._readRevision =
            root._stateRevision

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

        // watch and write should not operate on the
        // same DDC bus at the same time.
        root.stopWatch()

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
            root.startWatch()
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
    // watch parser
    // ============================================================

    function parseWatchBrightness(line) {
        // Actual output observed on the MSI:
        //
        // VCP code 0x10 (Brightness):
        // current value = 60, max value = 100
        //
        // SplitParser delivers it as one textual line.

        const match =
            line.match(
                /VCP code 0x10\b.*current value\s*=\s*(\d+),\s*max value\s*=\s*(\d+)/
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

    function applyWatchBrightness(line) {
        const parsed =
            root.parseWatchBrightness(
                line
            )

        // Ignore lines such as:
        //
        // Watching for VCP...
        // Type ^C to exit...
        // MAX_CHANGES...
        // other VCP features.
        if (!parsed)
            return

        if (!root.currentDisplay)
            return

        if (root._watchBus <= 0)
            return

        // Ensure this watcher still corresponds to
        // the currently selected monitor.
        if (
            root.currentDisplay.bus
            !== root._watchBus
        ) {
            return
        }

        // Normally our own write path stops watch,
        // but keep this as a defensive guard.
        if (
            root._writeInFlight
            || root._localOverrideActive
        ) {
            return
        }

        // The MSI repeats the same VCP 0x10 event
        // multiple times.
        //
        // Only the first actual state change matters.
        if (
            root.brightness
                === parsed.current
            && root.maxBrightness
                === parsed.maximum
        ) {
            return
        }

        // This value already came from the physical
        // monitor.
        //
        // Do NOT call setBrightness(), because that
        // would write it back through DDC.
        root.updateDisplay(
            root.currentDisplay,
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

            root.startRead(
                root.currentDisplay,
                "initial"
            )
        }
    }


    // ============================================================
    // ddcutil getvcp
    // ============================================================

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

                return
            }

            root.applyBrightnessOutput(
                getCollector.text
            )

            if (
                root.available
                && !root._writeInFlight
                && root._pendingBrightness < 0
                && !root._localOverrideActive
            ) {
                Qt.callLater(() => {
                    root.startWatch()
                })
            }
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
    // ddcutil watch
    // ============================================================

    readonly property Process watchProcess: Process {
        stdout: SplitParser {
            onRead: line => {
                if (line.length === 0)
                    return

                root.applyWatchBrightness(
                    line
                )
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.length === 0)
                    return

                console.warn(
                    "Brightness watch stderr:",
                    line
                )
            }
        }

        onExited: (
            exitCode,
            exitStatus
        ) => {
            // stopWatch() intentionally terminating
            // ddcutil is not a failure.
            if (!root._watchWanted)
                return

            console.warn(
                "Brightness: watch exited:",
                exitCode,
                exitStatus
            )

            watchRestartTimer.restart()
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

    readonly property Timer watchRestartTimer: Timer {
        id: watchRestartTimer

        interval: 500
        repeat: false

        onTriggered: {
            if (root._watchWanted)
                root.startWatch()
        }
    }


    // ============================================================
    // Startup
    // ============================================================

    Component.onCompleted: {
        root.refresh()
    }
}
