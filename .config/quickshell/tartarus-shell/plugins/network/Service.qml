import Quickshell.Networking
import QtQml

QtObject {
    id: root

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
