import Quickshell.Networking
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var _lastCounters: null
    property var _samples: []
    property string detectedInterface: ""

    function formatRate(bytes) {
        if (bytes < 1024) return `${Math.round(bytes)} B/s`
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB/s`
        return `${(bytes / 1024 / 1024).toFixed(1)} MB/s`
    }

    readonly property string activeInterface:
        root.detectedInterface || "wlan0"

    readonly property var interfaceProcess: Process {
        command: ["sh", "-c", "for i in /sys/class/net/wlan* /sys/class/net/wlp* /sys/class/net/en*; do [ -e \"$i/operstate\" ] && [ \"$(cat \"$i/operstate\")\" = up ] && { basename \"$i\"; exit; }; done"]
        stdout: StdioCollector {
            onStreamFinished: root.detectedInterface = text.trim()
        }
    }

    readonly property var counterProcess: Process {
        command: ["sh", "-c", "i=\"$1\"; cat /sys/class/net/\"$i\"/statistics/rx_bytes /sys/class/net/\"$i\"/statistics/tx_bytes", "stats", root.activeInterface]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split(/\s+/).map(Number)
                if (values.length !== 2 || values.some(v => !isFinite(v))) return
                const now = Date.now()
                if (root._lastCounters) {
                    const dt = Math.max(0.1, (now - root._lastCounters.time) / 1000)
                    const down = Math.max(0, (values[0] - root._lastCounters.rx) / dt)
                    const up = Math.max(0, (values[1] - root._lastCounters.tx) / dt)
                    root._samples = root._samples.concat([{ down: down, up: up }]).slice(-8)
                    const total = root._samples.reduce((sum, sample) => ({
                        down: sum.down + sample.down,
                        up: sum.up + sample.up
                    }), { down: 0, up: 0 })
                    root.downloadSpeed = total.down / root._samples.length
                    root.uploadSpeed = total.up / root._samples.length
                }
                root._lastCounters = { rx: values[0], tx: values[1], time: now }
            }
        }
    }

    readonly property var counterTimer: Timer {
        interval: 500
        running: root.activeInterface.length > 0
        repeat: true
        onTriggered: {
            root.counterProcess.running = true
        }
    }

    Component.onCompleted: root.interfaceProcess.running = true

    readonly property var wifiDevice: {
        const devices = Networking.devices.values

        for (const device of devices) {
            if (device.type === DeviceType.Wifi)
                return device
        }

        return null
    }

    readonly property var wiredDevice: {
        return root.ethernetDevice
    }

    readonly property var wiredDevices: {
        const devices = Networking.devices.values
        const result = []

        for (const device of devices) {
            if (device.type === DeviceType.Wired)
                result.push(device)
        }

        return result
    }

    readonly property var ethernetDevice: {
        const devices = root.wiredDevices

        for (const device of devices) {
            if (device.connected)
                return device
        }

        for (const device of devices) {
            if (device.hasLink)
                return device
        }

        return devices.length > 0
            ? devices[0]
            : null
    }

    readonly property var ethernetNetwork:
        root.ethernetDevice
        ? root.ethernetDevice.network
        : null

    readonly property bool ethernetAvailable:
        root.ethernetDevice !== null

    readonly property bool ethernetConnected:
        root.ethernetDevice
        ? root.ethernetDevice.connected
        : false

    readonly property bool ethernetHasLink:
        root.ethernetDevice
        ? root.ethernetDevice.hasLink
        : false

    readonly property string ethernetInterface:
        root.ethernetDevice
        ? root.ethernetDevice.name
        : ""

    readonly property string ethernetName:
        root.ethernetNetwork
        ? root.ethernetNetwork.name
        : ""

    readonly property int ethernetLinkSpeed:
        root.ethernetDevice
        ? root.ethernetDevice.linkSpeed
        : 0

    readonly property var ethernet: ({
        available: root.ethernetAvailable,
        connected: root.ethernetConnected,
        hasLink: root.ethernetHasLink,
        interfaceName: root.ethernetInterface,
        connectionName: root.ethernetName,
        linkSpeed: root.ethernetLinkSpeed,
        rawDevice: root.ethernetDevice,
        rawNetwork: root.ethernetNetwork,
    })

    readonly property var connectedDevice: {
        const devices = Networking.devices.values

        for (const device of devices) {
            if (device.connected)
                return device
        }

        return null
    }

    readonly property var connectedNetwork: {
        if (!root.wifiDevice)
            return null

        const networks = root.wifiDevice.networks.values

        for (const network of networks) {
            if (network.connected)
                return network
        }

        return null
    }

    readonly property bool connected:
        root.connectedNetwork !== null

    readonly property bool wifiEnabled:
        Networking.wifiEnabled

    readonly property bool wifiHardwareEnabled:
        Networking.wifiHardwareEnabled

    readonly property bool scanning:
        root.wifiDevice
        ? root.wifiDevice.scannerEnabled
        : false

    readonly property bool wired:
        root.wiredDevice
        && root.wiredDevice.connected

    readonly property string ssid:
        root.connectedNetwork
        ? root.connectedNetwork.name
        : ""

    readonly property int strength:
        root.signalPercent(root.connectedNetwork)

    readonly property var networks: {
        if (!root.wifiDevice)
            return []

        const values =
            root.wifiDevice.networks.values

        const result = []

        for (const network of values)
            result.push(root.networkInfo(network))

        return result
    }

    readonly property string statusText: {
        if (root.wired)
            return "Ethernet"

        if (root.connected) {
            return root.ssid
                + " "
                + root.strength
                + "%"
        }

        if (!root.wifiEnabled)
            return "Wi-Fi off"

        return "Offline"
    }

    function scan() {
        root.setScanning(true)
    }

    function connectNetwork(network) {
        if (!network)
            return

        const target =
            network.raw ?? network

        if (target.connect)
            target.connect()
    }

    function disconnect() {
        if (root.connectedNetwork) {
            root.connectedNetwork.disconnect()
            return
        }

        if (root.connectedDevice)
            root.connectedDevice.disconnect()
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled

        if (!enabled)
            root.setScanning(false)
    }

    function setScanning(enabled) {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = enabled
    }

    function connectEthernet() {
        if (!root.ethernetNetwork)
            return

        root.ethernetNetwork.connect()
    }

    function disconnectEthernet() {
        if (!root.ethernetDevice)
            return

        root.ethernetDevice.disconnect()
    }

    function networkInfo(network) {
        return {
            ssid: network.name,
            strength: root.signalPercent(network),
            secured: network.security !== WifiSecurityType.Open,
            connected: network.connected,
            raw: network,
        }
    }

    function signalPercent(network) {
        if (!network)
            return 0

        return Math.round(
            network.signalStrength * 100
        )
    }
}
