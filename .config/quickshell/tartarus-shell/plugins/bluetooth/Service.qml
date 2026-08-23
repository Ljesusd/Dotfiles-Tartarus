import Quickshell.Bluetooth
import QtQml

QtObject {
    id: root

    readonly property var adapter:
        Bluetooth.defaultAdapter

    readonly property bool available:
        root.adapter !== null

    readonly property bool enabled:
        root.available
        ? root.adapter.enabled
        : false

    readonly property bool discovering:
        root.available
        ? root.adapter.discovering
        : false

    readonly property var devices: {
        const values =
            Bluetooth.devices.values

        const result = []

        for (const device of values)
            result.push(root.deviceInfo(device))

        return result
    }

    readonly property var connectedDevices:
        root.devices.filter(device => {
            return device.connected
        })

    function setEnabled(enabled) {
        if (!root.available)
            return

        root.adapter.enabled = enabled

        if (!enabled)
            root.stopScan()
    }

    function startScan() {
        if (!root.available || !root.enabled)
            return

        root.adapter.discovering = true
    }

    function stopScan() {
        if (!root.available)
            return

        root.adapter.discovering = false
    }

    function connectDevice(device) {
        const target = root.rawDevice(device)

        if (!target || !target.connect)
            return

        if (target.connected)
            return

        if (
            target.state
            === BluetoothDeviceState.Connecting
        ) {
            return
        }

        if (
            target.state
            === BluetoothDeviceState.Disconnecting
        ) {
            return
        }

        if (
            target.paired
            && target.trusted !== undefined
            && !target.trusted
        ) {
            target.trusted = true
        }

        target.connect()
    }

    function disconnectDevice(device) {
        const target = root.rawDevice(device)

        if (target && target.disconnect)
            target.disconnect()
    }

    function pairDevice(device) {
        const target = root.rawDevice(device)

        if (target && target.pair)
            target.pair()
    }

    function forgetDevice(device) {
        const target = root.rawDevice(device)

        if (target && target.forget)
            target.forget()
    }

    function cancelPairing(device) {
        const target = root.rawDevice(device)

        if (target && target.cancelPair)
            target.cancelPair()
    }

    function rawDevice(device) {
        if (!device)
            return null

        return device.raw ?? device
    }

    function deviceInfo(device) {
        return {
            address: device.address,
            name: root.deviceDisplayName(device),
            deviceName: device.deviceName,
            icon: device.icon,
            state: device.state,
            connected: device.connected,
            connecting:
                device.state
                === BluetoothDeviceState.Connecting,
            disconnecting:
                device.state
                === BluetoothDeviceState.Disconnecting,
            paired: device.paired,
            bonded: device.bonded,
            pairing: device.pairing,
            trusted: device.trusted,
            blocked: device.blocked,
            batteryAvailable: device.batteryAvailable,
            battery: root.batteryPercent(device),
            raw: device,
        }
    }

    function deviceDisplayName(device) {
        if (!device)
            return ""

        if (device.name !== "")
            return device.name

        if (device.deviceName !== "")
            return device.deviceName

        return device.address
    }

    function batteryPercent(device) {
        if (!device || !device.batteryAvailable)
            return 0

        return Math.round(
            device.battery * 100
        )
    }
}
