import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Io
import "../theme"

ColumnLayout {
    id: root
    spacing: Style.spacingSmall

    readonly property string daemon: Quickshell.env("HOME")
        + "/Repositorios/oma-logitech-g-mouse/bin/logitech-g-daemon"
    property bool connected: false
    property int dpi: 0
    property int dpiMin: 100
    property int dpiMax: 32000
    property int reportRate: 1000
    property int battery: -1
    property string errorText: ""
    property bool busy: false
    readonly property bool protocolError: root.errorText.indexOf("no response") >= 0
    readonly property string connectionLabel: root.connected
        ? "Conectado"
        : (root.protocolError ? "Receptor accesible · control limitado" : "No detectado")

    function parseStatus(raw) {
        try {
            const data = JSON.parse(String(raw).trim())
            root.connected = data.connected === true
            root.dpi = data.dpi ? Number(data.dpi.dpiX || 0) : 0
            root.dpiMin = Number(data.dpiMin || 100)
            root.dpiMax = Number(data.dpiMax || 32000)
            root.reportRate = Number(data.reportRate || 1000)
            // The Logitech daemon returns battery as an object, not a flat
            // batteryPercentage field.
            root.battery = data.battery && data.battery.percentage !== undefined
                ? Number(data.battery.percentage) : -1
            root.errorText = String(data.error || "")
        } catch (e) {
            root.connected = false
            root.errorText = "No se pudo leer el controlador del mouse."
        }
    }

    function poll() {
        if (!probe.running)
            probe.running = true
    }

    function write(args) {
        if (!root.connected || command.running)
            return
        command.command = [root.daemon].concat(args)
        command.running = true
    }

    function setDpi(value) {
        const next = Math.max(root.dpiMin, Math.min(root.dpiMax, Math.round(value / 50) * 50))
        dpiSlider.value = next
        root.write(["--set-dpi", String(next)])
    }

    function setRate(value) {
        root.reportRate = value
        root.write(["--set-rate", String(value)])
    }

    Process {
        id: probe
        command: [root.daemon, "--once"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseStatus(text)
        }
        onRunningChanged: if (!running) root.busy = false
    }

    Process {
        id: command
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseStatus(text)
        }
        onRunningChanged: root.busy = running
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    RowLayout {
        Layout.fillWidth: true
        Rectangle {
            width: 8; height: 8; radius: 4
            color: root.connected ? Color.primary : (root.protocolError ? Color.tertiary : Color.outline)
            Layout.alignment: Qt.AlignVCenter
        }
        Text { Layout.fillWidth: true; text: "Estado del mouse"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall }
        Text { text: root.connectionLabel; color: root.connected ? Color.primary : (root.protocolError ? Color.tertiary : Color.foregroundMuted); font.pixelSize: Style.fontSmall; font.bold: true; elide: Text.ElideRight }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Sensibilidad (DPI)"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; font.bold: true }
        Text { text: root.connected ? Math.round(dpiSlider.value) : "—"; color: Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true }
    }

    Controls.Slider {
        id: dpiSlider
        objectName: "mouseDpiSlider"
        Layout.fillWidth: true
        from: root.dpiMin
        to: root.dpiMax
        stepSize: 50
        enabled: root.connected && !root.busy
        value: root.dpi > 0 ? root.dpi : 800
        // HID++ writes are synchronous. Sending one request per pointer
        // movement races the daemon and can make the receiver look offline.
        // Apply only after the user releases the slider.
        onPressedChanged: if (!pressed) root.setDpi(value)
    }

    Text {
        Layout.fillWidth: true
        text: "Cambios rápidos"
        color: Color.foregroundMuted
        font.pixelSize: Style.fontSmall
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [800, 1200, 1600, 2400, 3200]
            delegate: Rectangle {
                required property int modelData
                width: 54
                height: 28
                radius: Style.radiusSmall
                color: root.dpi === modelData ? Color.primaryContainer : Color.surfaceContainerHigh
                border.width: root.dpi === modelData ? 2 : 1
                border.color: root.dpi === modelData ? Color.primary : Color.outlineVariant
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: Color.foreground
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.connected && !root.busy
                    onClicked: root.setDpi(parent.modelData)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Frecuencia de sondeo"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; font.bold: true }
        Repeater {
            model: [125, 250, 500, 1000, 2000, 4000]
            delegate: Rectangle {
                required property int modelData
                width: 42
                height: 26
                radius: Style.radiusSmall
                color: root.reportRate === modelData ? Color.primaryContainer : Color.surfaceContainerHigh
                border.width: 1
                border.color: Color.outlineVariant
                Text { anchors.centerIn: parent; text: modelData >= 1000 ? (modelData / 1000) + "k" : modelData; color: Color.foreground; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; enabled: root.connected && !root.busy; onClicked: root.setRate(modelData) }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: root.connected
            ? (root.battery >= 0 ? "Batería: " + root.battery + "%" : "Batería no disponible")
            : (root.protocolError
                ? "El receptor responde, pero este controlador no puede leer el perfil DPI de este G305."
                : (root.errorText !== "" ? root.errorText : "Conecta y enciende el G305 para configurarlo."))
        color: Color.foregroundMuted
        font.pixelSize: Style.fontSmall
        wrapMode: Text.Wrap
    }
}
