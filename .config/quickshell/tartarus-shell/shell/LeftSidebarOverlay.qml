import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell.Io
import "../services" as Services
import "../theme"

PanelWindow {
    id: root
    required property var monitorScreen
    required property var pluginRegistry
    required property var monitorContext
    readonly property var net: pluginRegistry.plugin("network")?.service
    readonly property var bt: pluginRegistry.plugin("bluetooth")?.service
    readonly property var audio: pluginRegistry.plugin("audio")?.service
    readonly property var brightness: pluginRegistry.plugin("brightness")?.service
    readonly property var mic: Pipewire.defaultAudioSource
    property real offsetScale: monitorContext.leftSidebarOpened ? 0 : 1
    property string detailPage: ""
    property string pendingWifiSsid: ""
    property string wifiMessage: ""
    property string pendingBluetoothAddress: ""
    property string bluetoothMessage: ""
    property bool nightBackendAvailable: false
    property string nightBackend: ""
    screen: monitorScreen
    anchors { top: true; left: true; bottom: true }
    implicitWidth: Math.min(
        420,
        Math.max(300, (root.monitorScreen?.width ?? 1280) - Style.spacingLarge * 2)
    )
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: monitorContext.leftSidebarOpened || offsetScale < 1
    PwObjectTracker { objects: [root.mic] }
    Process {
        id: nightBackendProbe
        command: ["sh", "-c", "command -v hyprsunset || command -v wlsunset || command -v gammastep"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.nightBackend = String(text).trim()
                root.nightBackendAvailable = root.nightBackend !== ""
            }
        }
    }
    Process { id: nightAction }
    Timer {
        id: wifiTimeout
        interval: 12000
        onTriggered: {
            if (root.pendingWifiSsid !== "" && !root.net?.connected) root.wifiMessage = "No se pudo confirmar la conexión. Comprueba la contraseña o la señal."
            root.pendingWifiSsid = ""
        }
    }
    Timer {
        id: bluetoothTimeout
        interval: 12000
        onTriggered: {
            if (root.pendingBluetoothAddress !== "") root.bluetoothMessage = "El dispositivo no respondió. Intenta conectarlo de nuevo."
            root.pendingBluetoothAddress = ""
        }
    }
    Connections {
        target: root.net || null
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            if (root.net?.connected) {
                root.pendingWifiSsid = ""
                root.wifiMessage = ""
                wifiTimeout.stop()
            }
        }
    }
    Connections {
        target: root.bt || null
        ignoreUnknownSignals: true
        function onDevicesChanged() {
            if (root.bt?.devices.some(device => device.address === root.pendingBluetoothAddress && device.connected)) {
                root.pendingBluetoothAddress = ""
                root.bluetoothMessage = ""
                bluetoothTimeout.stop()
            }
        }
    }
    Connections {
        target: root.monitorContext
        function onLeftSidebarOpenedChanged() {
            if (root.monitorContext.leftSidebarOpened)
                root.detailPage = Services.QuickSettingsState.lastPage
        }
    }

    function detailTitle() {
        if (root.detailPage === "wifi") return "Wi‑Fi"
        if (root.detailPage === "bluetooth") return "Bluetooth"
        if (root.detailPage === "audio") return "Audio"
        if (root.detailPage === "microphone") return "Micrófono"
        if (root.detailPage === "brightness") return "Brillo"
        if (root.detailPage === "dnd") return "No molestar"
        if (root.detailPage === "night") return "Modo nocturno"
        if (root.detailPage === "power") return "Energía y sesión"
        return "Ajustes rápidos"
    }
    function showPage(page) {
        root.detailPage = page
        Services.QuickSettingsState.setPage(page)
    }
    function connectWifi(network) {
        root.wifiMessage = ""
        root.pendingWifiSsid = network.ssid
        wifiTimeout.restart()
        root.net.connectNetwork(network)
    }
    function connectBluetooth(device) {
        root.bluetoothMessage = ""
        root.pendingBluetoothAddress = device.address
        bluetoothTimeout.restart()
        root.bt.connectDevice(device)
    }
    function toggleNight() {
        if (!root.nightBackendAvailable) return
        const enabled = !Services.QuickSettingsState.nightPreferred
        Services.QuickSettingsState.nightPreferred = enabled
        Services.QuickSettingsState.save()
        if (root.nightBackend.endsWith("hyprsunset")) {
            nightAction.command = enabled
                ? ["hyprctl", "hyprsunset", "temperature", String(Services.QuickSettingsState.nightTemperature)]
                : ["hyprctl", "hyprsunset", "identity"]
        } else if (root.nightBackend.endsWith("gammastep")) {
            nightAction.command = enabled ? [root.nightBackend, "-O", String(Services.QuickSettingsState.nightTemperature)] : [root.nightBackend, "-x"]
        } else {
            nightAction.command = enabled ? [root.nightBackend, "-t", String(Services.QuickSettingsState.nightTemperature)] : ["pkill", "-x", "wlsunset"]
        }
        nightAction.running = true
    }

    Component.onCompleted: nightBackendProbe.running = true
    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onClicked: root.monitorContext.closeLeftSidebar()
        Rectangle {
            id: drawer
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            width: Math.min(
                420,
                Math.max(300, parent.width - Style.spacingLarge)
            )
            anchors.leftMargin: -(width + Style.spacingLarge) * root.offsetScale
            opacity: 1 - root.offsetScale
            scale: 0.97 + (1 - root.offsetScale) * 0.03
            transformOrigin: Item.Left
            color: Color.surfaceContainer
            border.width: Style.panelBorderWidth
            border.color: Color.outlineVariant
            radius: Style.panelRadius
            clip: true
            Behavior on anchors.leftMargin { Anim { duration: Style.motionSlow } }
            Behavior on opacity { Anim { duration: Style.motionFast } }
            Behavior on scale { Anim { duration: Style.motionPanel; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: event => event.accepted = true }
            Flickable {
                anchors.fill: parent
                anchors.margins: Style.paddingLarge
                contentWidth: width
                contentHeight: body.implicitHeight
                clip: true
                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: Style.spacingMedium
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: Style.radiusFull
                            color: Color.primary
                            MaterialIcon { anchors.centerIn: parent; text: "tune"; iconSize: Style.materialIconMedium; iconColor: Color.onPrimary }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.spacingXs
                            Text { text: root.detailPage === "" ? "Ajustes rápidos" : root.detailTitle(); color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.detailPage === "" ? "Controles de uso frecuente" : "Configura este apartado"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        MaterialIcon { text: root.detailPage === "" ? "close" : "arrow_back"; iconSize: Style.materialIconMedium; iconColor: Color.foregroundMuted; TapHandler { onTapped: root.detailPage === "" ? root.monitorContext.closeLeftSidebar() : root.showPage("") } }
                    }

                    GridLayout {
                        id: overview
                        visible: root.detailPage === ""
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: Style.spacingSmall
                        rowSpacing: Style.spacingSmall
                        Text { text: "Controla tu entorno sin abrir el Centro de control"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.columnSpan: 2; Layout.fillWidth: true; Layout.bottomMargin: Style.spacingSmall; wrapMode: Text.WordWrap }
                        QuickCard { title: "Wi‑Fi"; icon: "wifi"; summary: root.net?.connected ? root.net.ssid : "Sin red conectada"; onClicked: root.showPage("wifi") }
                        QuickCard { title: "Bluetooth"; icon: "bluetooth"; summary: root.bt?.enabled ? (root.bt.connectedDevices.length + " conectados") : "Desactivado"; onClicked: root.showPage("bluetooth") }
                        QuickCard { title: "Audio"; icon: "volume_up"; summary: root.audio?.available ? Math.round(root.audio.volume * 100) + "% · " + (root.audio.outputName || "Salida") : "No disponible"; onClicked: root.showPage("audio") }
                        QuickCard { title: "Micrófono"; icon: "mic"; summary: root.mic?.audio ? (root.mic.audio.muted ? "Silenciado" : Math.round(root.mic.audio.volume * 100) + "%") : "No disponible"; onClicked: root.showPage("microphone") }
                        QuickCard { title: "Brillo"; icon: "brightness_6"; summary: root.brightness?.availableForScreen(root.monitorScreen) ? Math.round(root.brightness.brightnessPercentForScreen(root.monitorScreen)) + "%" : "No disponible"; onClicked: root.showPage("brightness") }
                        QuickCard { title: "No molestar"; icon: "notifications_off"; summary: Services.NotificationService.dnd ? "Activado" : "Desactivado"; onClicked: root.showPage("dnd") }
                        QuickCard { title: "Modo nocturno"; icon: "nightlight"; summary: root.nightBackendAvailable ? "Disponible" : "Backend no disponible"; onClicked: root.showPage("night") }
                        QuickCard { title: "Energía y sesión"; icon: "power_settings_new"; summary: "Bloquear, suspender o apagar"; onClicked: root.showPage("power") }
                    }

                    ColumnLayout {
                        id: details
                        visible: root.detailPage !== ""
                        Layout.fillWidth: true
                        spacing: Style.spacingMedium
                        SettingCard {
                            visible: root.detailPage === "wifi"
                            title: "Red Wi‑Fi"
                            icon: "wifi"
                            subtitle: root.net?.connected ? "Conectado a " + root.net.ssid : "Sin conexión"
                            Text {
                                Layout.fillWidth: true
                                visible: !root.net?.wifiDevice || !root.net?.wifiHardwareEnabled
                                text: !root.net?.wifiDevice ? "No se detectó un adaptador Wi‑Fi" : "Wi‑Fi desactivado por hardware"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                wrapMode: Text.WordWrap
                            }
                            Toggle {
                                label: "Wi‑Fi"
                                icon: "wifi"
                                active: Boolean(root.net?.wifiEnabled)
                                onClicked: if (root.net?.wifiHardwareEnabled) root.net.setWifiEnabled(!root.net.wifiEnabled)
                            }
                            ActionButton {
                                text: root.net?.scanning ? "Detener búsqueda" : "Buscar redes"
                                enabled: Boolean(root.net?.wifiDevice && root.net?.wifiEnabled)
                                onClicked: if (root.net) root.net.setScanning(!root.net.scanning)
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: Boolean(root.net?.scanning || root.pendingWifiSsid || root.wifiMessage)
                                text: root.wifiMessage || (root.pendingWifiSsid ? "Conectando a " + root.pendingWifiSsid + "…" : "Buscando redes…")
                                color: root.wifiMessage ? Color.warning : Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: Boolean(root.net?.wifiEnabled && !root.net?.scanning && (root.net?.networks || []).length === 0)
                                text: "No se encontraron redes"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Repeater {
                                model: root.net?.networks || []
                                delegate: RowItem {
                                    required property var modelData
                                    name: modelData.ssid
                                    detail: modelData.connected ? "Conectado · " + modelData.strength + "%" : (modelData.secured ? "Protegida · " : "Abierta · ") + modelData.strength + "%"
                                    active: modelData.connected
                                    onClicked: if (root.net) modelData.connected ? root.net.disconnect() : root.connectWifi(modelData)
                                }
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "bluetooth"
                            title: "Bluetooth"
                            icon: "bluetooth"
                            subtitle: root.bt?.enabled ? "Bluetooth activado" : "Bluetooth desactivado"
                            Text {
                                visible: !root.bt?.available
                                text: "No se detectó un adaptador Bluetooth"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Toggle {
                                label: "Bluetooth"
                                icon: "bluetooth"
                                active: Boolean(root.bt?.enabled)
                                onClicked: if (root.bt) root.bt.setEnabled(!root.bt.enabled)
                            }
                            ActionButton {
                                text: root.bt?.discovering ? "Detener búsqueda" : "Buscar dispositivos"
                                enabled: Boolean(root.bt?.enabled)
                                onClicked: if (root.bt) root.bt.discovering ? root.bt.stopScan() : root.bt.startScan()
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: Boolean(root.bt?.discovering || root.pendingBluetoothAddress || root.bluetoothMessage)
                                text: root.bluetoothMessage || (root.pendingBluetoothAddress ? "Conectando dispositivo…" : "Buscando dispositivos…")
                                color: root.bluetoothMessage ? Color.warning : Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                visible: Boolean(root.bt?.enabled && !root.bt?.discovering && (root.bt?.devices || []).length === 0)
                                text: "No se encontraron dispositivos"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Repeater {
                                model: root.bt?.devices || []
                                delegate: RowItem {
                                    required property var modelData
                                    name: modelData.name
                                    detail: (modelData.connected ? "Conectado" : modelData.connecting ? "Conectando…" : modelData.disconnecting ? "Desconectando…" : modelData.paired ? "Emparejado" : "Disponible") + (modelData.batteryAvailable ? " · " + modelData.battery + "%" : "")
                                    active: modelData.connected
                                    onClicked: if (root.bt && !modelData.connecting && !modelData.disconnecting) modelData.connected ? root.bt.disconnectDevice(modelData) : root.connectBluetooth(modelData)
                                }
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "audio"
                            title: "Salida y aplicaciones"
                            icon: "volume_up"
                            subtitle: root.audio?.outputName || "Salida predeterminada"
                            Text {
                                visible: !root.audio?.available
                                text: "No hay salida de audio disponible"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Text {
                                text: "Dispositivo de salida"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                Layout.fillWidth: true
                            }
                            Repeater {
                                model: root.audio?.outputsModel || []
                                delegate: RowItem {
                                    required property var modelData
                                    name: root.audio.outputDisplayName(modelData)
                                    detail: modelData === Pipewire.defaultAudioSink ? "Activo" : "Disponible"
                                    active: modelData === Pipewire.defaultAudioSink
                                    onClicked: root.audio.selectOutput(modelData)
                                }
                            }
                            SliderRow {
                                label: "Volumen principal"
                                icon: "volume_up"
                                value: root.audio?.volume ?? 0
                                enabled: Boolean(root.audio?.available)
                                onMoved: if (root.audio) root.audio.setVolume(value)
                            }
                            Toggle {
                                label: "Silenciar salida"
                                icon: "volume_off"
                                active: Boolean(root.audio?.muted)
                                onClicked: if (root.audio) root.audio.toggleMute()
                            }
                            Text {
                                visible: (root.audio?.applicationGroupsModel?.values || []).length === 0
                                text: "No hay aplicaciones reproduciendo audio"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Repeater {
                                model: root.audio?.applicationGroupsModel || []
                                delegate: AudioRow {
                                    required property var modelData
                                    name: modelData.name
                                    group: modelData
                                }
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "microphone"
                            title: "Micrófono"
                            icon: "mic"
                            subtitle: root.mic?.description || root.mic?.name || "Entrada predeterminada"
                            Text {
                                visible: !root.mic?.audio
                                text: "No hay micrófono disponible"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            Text {
                                text: "Dispositivo de entrada"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                Layout.fillWidth: true
                            }
                            Repeater {
                                model: root.audio?.inputsModel || []
                                delegate: RowItem {
                                    required property var modelData
                                    name: root.audio.inputDisplayName(modelData)
                                    detail: modelData === Pipewire.defaultAudioSource ? "Activo" : "Disponible"
                                    active: modelData === Pipewire.defaultAudioSource
                                    onClicked: root.audio.selectInput(modelData)
                                }
                            }
                            SliderRow {
                                label: "Volumen del micrófono"
                                icon: "mic"
                                value: root.mic?.audio?.volume ?? 0
                                enabled: Boolean(root.mic?.audio)
                                onMoved: if (root.mic?.audio) root.mic.audio.volume = value
                            }
                            Toggle {
                                label: "Silenciar micrófono"
                                icon: "mic_off"
                                active: Boolean(root.mic?.audio?.muted)
                                onClicked: if (root.mic?.audio) root.mic.audio.muted = !root.mic.audio.muted
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "brightness"
                            title: "Brillo"
                            icon: "brightness_6"
                            subtitle: "Pantalla " + (root.monitorScreen?.name ?? "no disponible")
                            SliderRow {
                                label: "Brillo"
                                icon: "brightness_6"
                                value: (root.brightness?.brightnessPercentForScreen(root.monitorScreen) || 0) / 100
                                enabled: Boolean(root.brightness?.availableForScreen(root.monitorScreen))
                                onMoved: if (root.brightness) root.brightness.setBrightnessForScreen(root.monitorScreen, value * 100, 350)
                            }
                            Text {
                                visible: !root.brightness?.availableForScreen(root.monitorScreen)
                                text: "Este monitor no admite control de brillo desde el shell"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "dnd"
                            title: "No molestar"
                            icon: "notifications_off"
                            subtitle: "Silencia las notificaciones emergentes"
                            Toggle {
                                label: "No molestar"
                                icon: "notifications_off"
                                active: Services.NotificationService.dnd
                                onClicked: Services.NotificationService.toggleDnd()
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "night"
                            title: "Modo nocturno"
                            icon: "nightlight"
                            subtitle: root.nightBackendAvailable ? "Temperatura de pantalla" : "Backend no disponible"
                            Text {
                                Layout.fillWidth: true
                                text: "No hay un controlador de temperatura compatible instalado. Instala y configura hyprsunset para activar este control."
                                visible: !root.nightBackendAvailable
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                wrapMode: Text.WordWrap
                            }
                            SliderRow {
                                label: "Temperatura · " + Services.QuickSettingsState.nightTemperature + " K"
                                icon: "thermostat"
                                value: (Services.QuickSettingsState.nightTemperature - 2500) / 4000
                                enabled: root.nightBackendAvailable
                                onMoved: Services.QuickSettingsState.setNightTemperature(2500 + value * 4000)
                            }
                            Toggle {
                                label: "Filtro de luz azul"
                                icon: "nightlight"
                                active: Services.QuickSettingsState.nightPreferred
                                onClicked: root.toggleNight()
                            }
                        }
                        SettingCard {
                            visible: root.detailPage === "power"
                            title: "Energía y sesión"
                            icon: "power_settings_new"
                            subtitle: "Acciones de esta sesión"
                            ActionButton { text: "Bloquear"; onClicked: Services.PowerService.lock() }
                            ActionButton { text: "Suspender"; onClicked: Services.SidebarService.requestPower("suspend") }
                            ActionButton { text: "Cerrar sesión"; onClicked: Services.SidebarService.requestPower("logout") }
                            ActionButton { text: "Reiniciar"; onClicked: Services.SidebarService.requestPower("reboot") }
                            ActionButton { text: "Apagar"; onClicked: Services.SidebarService.requestPower("shutdown") }
                            Text {
                                visible: Services.SidebarService.pendingPower !== ""
                                text: "¿Confirmar " + Services.SidebarService.pendingPower + "?"
                                color: Color.warning
                                font.pixelSize: Style.fontSmall
                            }
                            RowLayout {
                                visible: Services.SidebarService.pendingPower !== ""
                                ActionButton { text: "Cancelar"; onClicked: Services.SidebarService.cancelPower() }
                                ActionButton { text: "Confirmar"; onClicked: Services.SidebarService.confirmPower() }
                            }
                        }
                    }
                }
            }
        }
    }
    component QuickCard: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        property string summary: ""
        signal clicked()
        default property alias content: cardBody.data
        Layout.fillWidth: true
        implicitHeight: 78
        radius: Style.cardRadius
        color: hoverHandler.hovered ? Color.surfaceHover : Color.surface
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        scale: hoverHandler.hovered ? 1.015 : 1
        Behavior on color { ColorAnimation { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionFast; easing.type: Easing.OutCubic } }
        HoverHandler { id: hoverHandler }
        ColumnLayout {
            id: cardBody
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            spacing: Style.spacingXs
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: Style.radiusFull
                    color: Color.primaryContainer
                    MaterialIcon { anchors.centerIn: parent; text: card.icon; iconSize: Style.materialIconSmall; iconColor: Color.primary }
                }
                Text { text: card.title; color: Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                MaterialIcon { text: "chevron_right"; iconSize: Style.materialIconSmall; iconColor: Color.foregroundMuted }
            }
            Text { text: card.summary; color: Color.foregroundMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        TapHandler { onTapped: card.clicked() }
    }

    component SettingCard: Rectangle {
        id: settingCard
        property string title: ""
        property string subtitle: ""
        property string icon: ""
        default property alias content: settingBody.data
        Layout.fillWidth: true
        implicitHeight: settingBody.implicitHeight + Style.paddingMedium * 2
        radius: Style.cardRadius
        color: Color.surfaceContainer
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        ColumnLayout {
            id: settingBody
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: settingCard.icon; iconSize: Style.sectionIconSize; iconColor: Color.primary }
                ColumnLayout { Layout.fillWidth: true; Text { text: settingCard.title; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true } Text { text: settingCard.subtitle; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight } }
            }
        }
    }

    component RowItem: Rectangle {
        id: rowItem
        property string name: ""
        property string detail: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 50
        radius: Style.controlRadius
        color: active ? Color.primaryContainer : Color.surface
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        RowLayout { anchors.fill: parent; anchors.margins: Style.paddingSmall; MaterialIcon { text: rowItem.active ? "check_circle" : "radio_button_unchecked"; iconSize: Style.materialIconMedium; iconColor: rowItem.active ? Color.primary : Color.foregroundMuted } ColumnLayout { Layout.fillWidth: true; Text { text: rowItem.name; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: rowItem.detail; color: Color.foregroundMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight } } MaterialIcon { text: "chevron_right"; iconSize: Style.materialIconSmall; iconColor: Color.foregroundMuted } }
        TapHandler { onTapped: rowItem.clicked() }
    }

    component ActionButton: Button {
        id: actionButton
        implicitHeight: 34
        implicitWidth: Math.max(110, contentItem.implicitWidth + 22)
        contentItem: Text { text: actionButton.text; color: Color.foreground; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Style.radiusFull; color: actionButton.hovered ? Color.surfaceHover : Color.surface; border.width: Style.panelBorderWidth; border.color: Color.outlineVariant }
    }

    component AudioRow: ColumnLayout {
        id: audioRow
        property string name: ""
        property var node: null
        property var group: null
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: audioRow.name
                color: Color.foreground
                font.pixelSize: Style.fontSmall
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: audioRow.group ? Math.round(root.audio.groupVolume(audioRow.group) * 100) + "%" : audioRow.node?.audio ? Math.round(audioRow.node.audio.volume * 100) + "%" : "—"
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
            }
        }
        SliderRow { label: "Volumen"; icon: audioRow.group ? root.audio.applicationIcon(audioRow.group) : "volume_up"; value: audioRow.group ? root.audio.groupVolume(audioRow.group) : audioRow.node?.audio?.volume ?? 0; enabled: Boolean(audioRow.group || (audioRow.node?.ready && audioRow.node?.audio)); onMoved: if (root.audio) audioRow.group ? root.audio.setGroupVolume(audioRow.group, value) : root.audio.setStreamVolume(audioRow.node, value) }
        Toggle { label: "Silenciar aplicación"; icon: "volume_off"; active: audioRow.group ? root.audio.groupMuted(audioRow.group) : Boolean(audioRow.node?.audio?.muted); onClicked: if (root.audio) audioRow.group ? root.audio.toggleGroupMute(audioRow.group) : root.audio.toggleStreamMute(audioRow.node) }
    }
    component Toggle: Rectangle {
        id: toggle
        property string label: ""
        property string icon: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 42
        radius: Style.controlRadius
        color: active ? Color.primaryContainer : Color.surface
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        RowLayout { anchors.fill: parent; anchors.margins: Style.paddingSmall; MaterialIcon { text: toggle.icon; iconSize: Style.materialIconMedium; iconColor: toggle.active ? Color.primary : Color.foregroundMuted } Text { text: toggle.label; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.fillWidth: true } MaterialIcon { text: toggle.active ? "toggle_on" : "toggle_off"; iconSize: Style.materialIconMedium; iconColor: toggle.active ? Color.primary : Color.foregroundMuted } }
        TapHandler { onTapped: toggle.clicked() }
    }
    component SliderRow: ColumnLayout {
        id: sliderRow
        property string label: ""
        property string icon: ""
        property real value: 0
        property bool enabled: true
        signal moved(real value)
        Layout.fillWidth: true
        RowLayout { Layout.fillWidth: true; MaterialIcon { text: sliderRow.icon; iconSize: Style.materialIconSmall; iconColor: Color.foregroundMuted } Text { text: sliderRow.label; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.fillWidth: true } Text { text: Math.round(sliderRow.value * 100) + "%"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall } }
        Slider { Layout.fillWidth: true; enabled: sliderRow.enabled; from: 0; to: 1; value: sliderRow.value; onMoved: sliderRow.moved(value); background: Rectangle { x: parent.leftPadding; y: parent.topPadding + (parent.availableHeight - height) / 2; width: parent.availableWidth; height: 6; radius: 3; color: Color.outlineVariant; Rectangle { width: parent.parent.position * parent.width; height: parent.height; radius: 3; color: Color.primary } } handle: Rectangle { x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width); y: parent.topPadding + (parent.availableHeight - height) / 2; width: parent.pressed ? 20 : 16; height: width; radius: width / 2; color: Color.primary } }
    }
}
