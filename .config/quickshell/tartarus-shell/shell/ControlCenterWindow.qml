import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Quickshell.Io
import "../services" as Services
import "../theme"
import "../launcher/components" as LauncherComponents

FloatingWindow {
    id: root
    required property var shellState
    required property var pluginRegistry
    readonly property var net: pluginRegistry.plugin("network")?.service
    readonly property var bt: pluginRegistry.plugin("bluetooth")?.service
    readonly property var audio: pluginRegistry.plugin("audio")?.service
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property var hardware: Services.HardwareInfoService
    readonly property var settingsThemes: Services.Themes
    readonly property var effects: Services.EasyEffectsService
    readonly property var effectsSource: {
        const inputs = root.audio?.inputsModel?.values || []
        return inputs.find(input => {
            const text = [input.description, input.nickname, input.name, input.properties?.["node.description"]]
                .filter(Boolean).join(" ").toLowerCase()
            return text.includes("easy effects") || text.includes("easyeffects")
        }) || null
    }
    property int page: 0
    onPageChanged: root.syncHardwareMonitoring()
    property string settingsQuery: ""
    property var pageHistory: []
    property int pageHistoryIndex: -1
    property int appearanceSchemeIndex: 0
    property string fastfetchPackageCount: "—"
    property string profileImageSource: ""
    property string speedTestPhase: "idle"
    property string speedTestError: ""
    property bool speedTestResultReady: false
    property real speedTestDownload: -1
    property real speedTestUpload: -1
    property real speedTestPing: -1
    readonly property color lyneBackground: "#171925"
    readonly property color lyneSurface: "#20243a"
    readonly property color lyneSurfaceHigh: "#282e48"
    readonly property color lyneSurfaceHover: "#303957"
    readonly property color lyneAccent: "#83aef7"
    readonly property color lyneText: "#d9e1ff"
    readonly property color lyneMuted: "#9ba7ca"
    readonly property var navigationItems: [
        { header: "OVERVIEW" },
        { label: "Inicio", icon: "home", page: 0 },
        { header: "CONNECTIVITY" },
        { label: "Wi‑Fi", icon: "wifi", page: 1 },
        { label: "Bluetooth", icon: "bluetooth", page: 2 },
        { label: "Output", icon: "volume_up", page: 3 },
        { label: "Input", icon: "mic", page: 4 },
        { header: "APPEARANCE & SHELL" },
        { label: "Apariencia", icon: "palette", page: 5 },
        { label: "Atajos", icon: "keyboard", page: 7 },
        { header: "SYSTEM" },
        { label: "Hardware", icon: "memory", page: 6 },
        { label: "Monitores", icon: "monitor", page: 9 },
        { label: "Calendario", icon: "calendar_month", page: 10 },
        { label: "Sesión", icon: "power_settings_new", page: 8 }
    ]
    property real presentationOpacity: shellState.controlCenterOpen ? 1 : 0
    visible: shellState.controlCenterOpen || presentationOpacity > 0
    title: "Tartarus — Configuración"
    implicitWidth: Math.min(1100, Math.max(640, (root.screen?.width ?? 1200) - 32))
    implicitHeight: Math.min(750, Math.max(520, (root.screen?.height ?? 800) - 32))
    minimumSize: Qt.size(640, 520)
    color: "transparent"
    PwObjectTracker { objects: [root.mic] }
    onVisibleChanged: if (visible) shellState.closeSidebars()

    function syncHardwareMonitoring() {
        Services.HardwareService.setConsumerActive("control-center-hardware",
            Boolean(root.shellState?.controlCenterOpen && root.page === 6))
        Services.MonitorService.active = Boolean(root.shellState?.controlCenterOpen && root.page === 9)
    }

    function startSpeedTest() {
        if (root.speedTestProcess.running)
            return
        root.speedTestDownload = -1
        root.speedTestUpload = -1
        root.speedTestPing = -1
        root.speedTestPhase = "starting"
        root.speedTestError = ""
        root.speedTestProcess.command = [Quickshell.env("HOME") + "/.local/bin/fast", "--json"]
        root.speedTestProcess.running = true
    }

    Component.onDestruction: {
        Services.HardwareService.setConsumerActive("control-center-hardware", false)
        Services.MonitorService.active = false
    }

    readonly property Process fastfetchPackagesProcess: Process {
        command: ["sh", "-c", "pacman -Qq 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.fastfetchPackageCount = this.text.trim() || "—"
        }
    }
    readonly property Process speedTestProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    const value = JSON.parse(String(text || "{}"))
                    root.speedTestDownload = Number(value.download_mbps)
                    root.speedTestUpload = Number(value.upload_mbps)
                    root.speedTestPing = Number(value.ping_ms)
                    if ([root.speedTestDownload, root.speedTestUpload, root.speedTestPing].every(value => isFinite(value))) {
                        root.speedTestResultReady = true
                        root.speedTestPhase = "done"
                        root.speedTestError = ""
                    }
                } catch (error) {
                    root.speedTestError = "La salida del test no era válida"
                }
            }
        }
        stderr: StdioCollector {
            id: speedTestStderr
            waitForEnd: true
        }
        onStarted: {
            root.speedTestPhase = "running"
            root.speedTestResultReady = false
            root.speedTestError = ""
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root.speedTestResultReady) {
                root.speedTestPhase = "error"
                root.speedTestError = String(speedTestStderr.text || "No se pudo ejecutar Fast CLI").trim()
            }
        }
    }

    readonly property FileView fastfetchLogoFile: FileView {
        path: Quickshell.shellPath("shell/assets/fastfetch-logo.txt")
        blockLoading: true
    }

    readonly property Process profileImageProcess: Process {
        command: ["sh", "-c", "find \"$HOME/.face\" -maxdepth 2 -type f 2>/dev/null | sort | head -n 1"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const path = this.text.trim()
                if (path !== "")
                    root.profileImageSource = "file://" + path
            }
        }
    }

    Component.onCompleted: {
        root.fastfetchPackagesProcess.running = true
        root.profileImageProcess.running = true
    }

    Connections {
        target: root.shellState
        function onControlCenterOpenChanged() {
            if (root.shellState.controlCenterOpen) {
                root.page = 0
                root.settingsQuery = ""
                root.pageHistory = [0]
                root.pageHistoryIndex = 0
            }
            root.syncHardwareMonitoring()
        }
        function onControlCenterPageRequestChanged() {
            const requestedPage = Number(root.shellState.controlCenterPageRequest)
            if (requestedPage < 0 || !root.shellState.controlCenterOpen)
                return
            root.page = requestedPage
            root.pageHistory = [0, requestedPage]
            root.pageHistoryIndex = 1
            root.shellState.controlCenterPageRequest = -1
        }
    }

    function navigate(targetPage) {
        if (targetPage === root.page)
            return

        const history = root.pageHistory.slice(0, root.pageHistoryIndex + 1)
        history.push(targetPage)
        root.pageHistory = history
        root.pageHistoryIndex = history.length - 1
        root.page = targetPage
    }

    function goBack() {
        if (root.pageHistoryIndex <= 0)
            return
        root.pageHistoryIndex--
        root.page = root.pageHistory[root.pageHistoryIndex]
    }

    function goForward() {
        if (root.pageHistoryIndex >= root.pageHistory.length - 1)
            return
        root.pageHistoryIndex++
        root.page = root.pageHistory[root.pageHistoryIndex]
    }

    function matchesNavigation(label) {
        const query = root.settingsQuery.trim().toLowerCase()
        return query === "" || label.toLowerCase().includes(query)
    }

    function fastfetchHomeMount() {
        const mounts = root.hardware?.data?.storage?.mounts || []
        return mounts.find(mount => mount.mountpoint === "/home")
            || mounts.find(mount => mount.mountpoint === "/")
            || null
    }

    function syncAppearanceSchemeIndex() {
        const themes = root.settingsThemes.themes || []
        const current = themes.findIndex(theme => theme.slug === root.settingsThemes.currentSlug)
        if (current >= 0)
            root.appearanceSchemeIndex = current
        else if (themes.length > 0)
            root.appearanceSchemeIndex = Math.min(root.appearanceSchemeIndex, themes.length - 1)
    }

    Connections {
        target: root.settingsThemes
        function onThemesChanged() { root.syncAppearanceSchemeIndex() }
        function onCurrentSlugChanged() { root.syncAppearanceSchemeIndex() }
    }

    Rectangle {
        id: panelSurface
        anchors.fill: parent
        radius: Style.panelRadius + 4
        color: root.lyneBackground
        border.width: Style.panelBorderWidth
        border.color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.75)

        ToolButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Style.paddingSmall
            anchors.rightMargin: Style.paddingSmall
            z: 3
            display: AbstractButton.IconOnly
            contentItem: MaterialIcon {
                text: "close"
                iconSize: Style.materialIconSmall
                iconColor: root.lyneMuted
            }
            background: Rectangle {
                radius: Style.radiusFull
                color: parent.hovered ? root.lyneSurfaceHover : "transparent"
            }
            onClicked: root.shellState.closeControlCenter()
        }

    }

    RowLayout {
        anchors.fill: panelSurface
        anchors.margins: Style.paddingMedium
        spacing: Style.spacingMedium
        z: 1
        opacity: root.presentationOpacity
        scale: root.presentationOpacity > 0 ? 1 : 0.985
        transformOrigin: Item.Center
        Behavior on opacity { Anim { duration: Motion.fast } }
        Behavior on scale {
            Anim {
                duration: Motion.popupOpen
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.popupOpenCurve
            }
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 236
            color: root.lyneSurface
            radius: Style.cardRadius
            border.width: 0
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingMedium
                spacing: Style.spacingSmall
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Style.spacingMedium
                    Rectangle { Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: Style.radiusMedium; color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.16); MaterialIcon { anchors.centerIn: parent; text: "settings"; iconSize: Style.sectionIconSize; iconColor: root.lyneAccent } }
                    Text { text: "Configuración"; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
                }
                TextField {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    placeholderText: "Buscar ajustes"
                    text: root.settingsQuery
                    color: root.lyneText
                    placeholderTextColor: root.lyneMuted
                    onTextChanged: root.settingsQuery = text
                    selectByMouse: true
                    leftPadding: 34
                    background: Rectangle {
                        radius: Style.radiusFull
                        color: root.lyneSurfaceHigh
                        border.width: 0
                    }
                    MaterialIcon { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "search"; iconSize: Style.materialIconSmall; iconColor: root.lyneMuted }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacingXs
                    MaterialIcon { text: "arrow_back"; iconSize: Style.materialIconSmall; iconColor: root.pageHistoryIndex > 0 ? root.lyneText : root.lyneMuted; opacity: root.pageHistoryIndex > 0 ? 1 : .45; TapHandler { onTapped: root.goBack() } }
                    MaterialIcon { text: "arrow_forward"; iconSize: Style.materialIconSmall; iconColor: root.pageHistoryIndex < root.pageHistory.length - 1 ? root.lyneText : root.lyneMuted; opacity: root.pageHistoryIndex < root.pageHistory.length - 1 ? 1 : .45; TapHandler { onTapped: root.goForward() } }
                    Item { Layout.fillWidth: true }
                }
                Text { text: "OVERVIEW"; color: root.lyneAccent; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
                Nav { label: "Inicio"; icon: "home"; visible: root.matchesNavigation(label); selected: root.page === 0; onClicked: root.navigate(0) }
                Text { text: "CONNECTIVITY"; color: root.lyneAccent; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1; Layout.topMargin: Style.spacingSmall }
                Nav { label: "Wi‑Fi"; icon: "wifi"; visible: root.matchesNavigation(label); selected: root.page === 1; onClicked: root.navigate(1) }
                Nav { label: "Bluetooth"; icon: "bluetooth"; visible: root.matchesNavigation(label); selected: root.page === 2; onClicked: root.navigate(2) }
                Nav { label: "Output"; icon: "volume_up"; visible: root.matchesNavigation(label); selected: root.page === 3; onClicked: root.navigate(3) }
                Nav { label: "Input"; icon: "mic"; visible: root.matchesNavigation(label); selected: root.page === 4; onClicked: root.navigate(4) }
                Text { text: "APPEARANCE & SHELL"; color: root.lyneAccent; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1; Layout.topMargin: Style.spacingSmall }
                Nav { label: "Apariencia"; icon: "palette"; visible: root.matchesNavigation(label); selected: root.page === 5; onClicked: root.navigate(5) }
                Nav { label: "Atajos"; icon: "keyboard"; visible: root.matchesNavigation(label); selected: root.page === 7; onClicked: root.navigate(7) }
                Text { text: "SYSTEM"; color: root.lyneAccent; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1; Layout.topMargin: Style.spacingSmall }
                Nav { label: "Hardware"; icon: "memory"; visible: root.matchesNavigation(label); selected: root.page === 6; onClicked: root.navigate(6) }
                Nav { label: "Monitores"; icon: "monitor"; visible: root.matchesNavigation(label); selected: root.page === 9; onClicked: root.navigate(9) }
                Nav { label: "Calendario"; icon: "calendar_month"; visible: root.matchesNavigation(label); selected: root.page === 10; onClicked: root.navigate(10) }
                Nav { label: "Sesión"; icon: "power_settings_new"; visible: root.matchesNavigation(label); selected: root.page === 8; onClicked: root.navigate(8) }
                Item { Layout.fillHeight: true }
                Nav { label: "Cerrar"; icon: "close"; onClicked: root.shellState.closeControlCenter() }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.page
            Page {
                icon: "home"
                title: "Centro de control"
                subtitle: "Configuración rápida y estado del entorno"
                ProfileHeader {}
                SettingCard {
                    title: "Ubicación y hora"
                    icon: "location_on"
                    subtitle: "Se usa para el clima y el reloj de la Dynamic Island"
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Ubicación del PC"; color: root.lyneText; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Services.QuickSettingsState.weatherAutoLocation
                            onToggled: Services.QuickSettingsState.setWeatherAutoLocation(checked)
                        }
                    }
                    Text {
                        text: Services.QuickSettingsState.weatherAutoLocation
                            ? "Ciudad aproximada por IP: " + (Services.WeatherService.location || "Detectando…")
                            : "Ciudad fijada: " + (Services.QuickSettingsState.weatherPlace?.label || Services.WeatherService.location || Services.QuickSettingsState.weatherLocation)
                        color: root.lyneMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Lugar"; color: root.lyneText; font.pixelSize: Style.fontSmall; Layout.preferredWidth: 120; Layout.alignment: Qt.AlignTop; topPadding: 10 }
                        LauncherComponents.WeatherLocationPicker {
                            id: locationField
                            enabled: !Services.QuickSettingsState.weatherAutoLocation
                            active: root.visible && root.page === 0 && !Services.QuickSettingsState.weatherAutoLocation
                            Layout.fillWidth: true
                            text: Services.QuickSettingsState.weatherPlace?.label || Services.QuickSettingsState.weatherLocation
                            textColor: root.lyneText
                            mutedColor: root.lyneMuted
                            surfaceColor: root.lyneSurfaceHigh
                            accentColor: root.lyneAccent
                            onLocationSelected: place => Services.QuickSettingsState.setWeatherPlace(place)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Zona horaria"; color: root.lyneText; font.pixelSize: Style.fontSmall; Layout.preferredWidth: 120 }
                        TextField {
                            id: timezoneField
                            Layout.fillWidth: true
                            text: Services.QuickSettingsState.timeZone
                            placeholderText: "Europe/Madrid"
                            color: root.lyneText
                            placeholderTextColor: root.lyneMuted
                            selectByMouse: true
                            leftPadding: 12
                            rightPadding: 12
                            background: Rectangle {
                                radius: Style.controlRadius
                                color: root.lyneSurfaceHigh
                                border.width: timezoneField.activeFocus ? 1 : 0
                                border.color: root.lyneAccent
                            }
                            onEditingFinished: Services.QuickSettingsState.setTimeZone(text)
                        }
                    }
                    Text { text: "Ejemplo: Europe/Madrid, America/Argentina/Buenos_Aires o America/New_York"; color: root.lyneMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
                SettingCard {
                    title: "Fastfetch"
                    icon: "terminal"
                    subtitle: root.hardware.ready
                        ? (root.hardware.data?.os?.distro || "Información del sistema")
                        : "Recopilando información del sistema…"
                    headerInfo: root.hardware.ready ? "Activo" : "Cargando…"

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(188, fastfetchContent.implicitHeight + Style.paddingMedium * 2)
                        radius: Style.controlRadius
                        color: root.lyneBackground
                        border.width: 1
                        border.color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.16)

                        GridLayout {
                            id: fastfetchContent
                            anchors.fill: parent
                            anchors.margins: Style.paddingMedium
                            columns: width >= 560 ? 2 : 1
                            columnSpacing: Style.paddingLarge
                            rowSpacing: Style.spacingMedium

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredHeight: 164
                                Layout.preferredWidth: fastfetchContent.columns === 2
                                    ? fastfetchContent.width * 0.52 : fastfetchContent.width
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                clip: true
                                text: root.fastfetchLogoFile.text()
                                textFormat: Text.PlainText
                                color: root.lyneAccent
                                font.family: "monospace"
                                font.pixelSize: 8
                                font.letterSpacing: 0
                                lineHeight: 0.94
                                lineHeightMode: Text.ProportionalHeight
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                scale: Math.min(
                                    1,
                                    158 / Math.max(1, implicitHeight),
                                    (fastfetchContent.width * 0.48) / Math.max(1, implicitWidth)
                                )
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1
                                FastfetchBoxLine { lineText: "╭───────────────────────────────────╮"; accent: root.lyneAccent }
                                FastfetchLine { label: "kernel"; value: root.hardware.data?.os?.kernel || "—"; accent: root.lyneAccent }
                                FastfetchLine { label: "uptime"; value: root.hardware.data?.os?.uptime || "—"; accent: "#f5b86b" }
                                FastfetchLine { label: "shell"; value: "fish"; accent: root.lyneAccent }
                                FastfetchLine {
                                    label: "mem"
                                    value: root.hardware.data?.memory
                                        ? root.hardware.data.memory.used_gb.toFixed(1) + " / " + root.hardware.data.memory.total_gb.toFixed(1) + " GiB"
                                        : "—"
                                    accent: "#f26d78"
                                }
                                FastfetchLine {
                                    label: "user"
                                    value: Quickshell.env("USER") || "—"
                                    accent: root.lyneAccent
                                }
                                FastfetchLine { label: "pkgs"; value: root.fastfetchPackageCount; accent: "#a8dba8" }
                                FastfetchLine { label: "hname"; value: root.hardware.data?.os?.hostname || "—"; accent: "#f5b86b" }
                                FastfetchLine { label: "distro"; value: root.hardware.data?.os?.distro || "—"; accent: "#b89cf5" }
                                FastfetchBoxLine { lineText: "╰───────────────────────────────────╯"; accent: root.lyneAccent }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ActionButton { text: "Actualizar"; onClicked: root.hardware.refresh() }
                        ActionButton { text: "Abrir hardware"; onClicked: root.navigate(6) }
                    }
                }
            }
            Page {
                icon: "wifi"
                title: "Wi‑Fi"
                subtitle: root.net?.connected ? "Conectado a " + root.net.ssid : root.net?.wifiEnabled ? "Redes inalámbricas cercanas" : "Wi‑Fi desactivado"
                SettingCard {
                    title: "Red Wi‑Fi"; icon: "wifi"; subtitle: root.net?.connected ? root.net.ssid : root.net?.wifiEnabled ? "Sin red conectada" : "Wi‑Fi desactivado"
                    Flow { Layout.fillWidth: true; spacing: Style.spacingSmall; ActionButton { text: root.net?.wifiEnabled ? "Desactivar Wi‑Fi" : "Activar Wi‑Fi"; enabled: Boolean(root.net?.wifiHardwareEnabled); onClicked: if (root.net) root.net.setWifiEnabled(!root.net.wifiEnabled) } ActionButton { text: root.net?.scanning ? "Detener búsqueda" : "Buscar redes"; enabled: Boolean(root.net?.wifiDevice && root.net?.wifiEnabled); onClicked: if (root.net) root.net.setScanning(!root.net.scanning) } }
                    Repeater { model: root.net?.networks || []; delegate: RowItem { required property var modelData; name: modelData.ssid; detail: modelData.connected ? "Conectado" : "Señal " + modelData.strength + "%"; active: modelData.connected; onClicked: if (root.net) modelData.connected ? root.net.disconnect() : root.net.connectNetwork(modelData) } }
                }
                SettingCard {
                    visible: Boolean(root.net?.connected)
                    title: "Actividad de red"
                    icon: "swap_vert"
                    subtitle: "Velocidad actual · " + (root.net?.activeInterface || "Wi‑Fi")
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacingMedium
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 112
                            radius: Style.controlRadius
                            color: root.lyneSurfaceHigh
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.paddingMedium
                                RowLayout {
                                    Layout.fillWidth: true
                                    MaterialIcon { text: "download"; iconSize: Style.materialIconMedium; iconColor: "#f26d78" }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Descarga"; color: root.lyneMuted; font.pixelSize: Style.fontSmall }
                                        Text { text: root.net?.formatRate(root.net.downloadSpeed) || "0 B/s"; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true }
                                    }
                                }
                                NetworkWave { Layout.fillWidth: true; Layout.fillHeight: true; values: root.net?.downloadHistory || []; accent: "#f26d78" }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 112
                            radius: Style.controlRadius
                            color: root.lyneSurfaceHigh
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.paddingMedium
                                RowLayout {
                                    Layout.fillWidth: true
                                    MaterialIcon { text: "upload"; iconSize: Style.materialIconMedium; iconColor: root.lyneAccent }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Subida"; color: root.lyneMuted; font.pixelSize: Style.fontSmall }
                                        Text { text: root.net?.formatRate(root.net.uploadSpeed) || "0 B/s"; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true }
                                    }
                                }
                                NetworkWave { Layout.fillWidth: true; Layout.fillHeight: true; values: root.net?.uploadHistory || []; accent: root.lyneAccent }
                            }
                        }
                    }
                }
                SettingCard {
                    visible: Boolean(root.net?.connected || root.net?.wired)
                    title: "Test de velocidad"
                    icon: "speed"
                    subtitle: "Fast CLI · descarga, subida y ping"
                    Text {
                        text: root.speedTestPhase === "running" || root.speedTestPhase === "starting"
                            ? "Midiendo conexión… puede tardar unos segundos"
                            : "Mide tu conexión usando Fast.com sin salir del centro de control."
                        color: root.lyneMuted
                        font.pixelSize: Style.fontSmall
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        SpeedTestMetric { label: "↓ Download"; value: root.speedTestDownload >= 0 ? root.speedTestDownload.toFixed(1) + " Mbps" : "—"; accent: "#f26d78" }
                        SpeedTestMetric { label: "↑ Upload"; value: root.speedTestUpload >= 0 ? root.speedTestUpload.toFixed(1) + " Mbps" : "—"; accent: root.lyneAccent }
                        SpeedTestMetric { label: "Ping"; value: root.speedTestPing >= 0 ? Math.round(root.speedTestPing) + " ms" : "—"; accent: "#f2b36d" }
                    }
                    Text {
                        visible: root.speedTestPhase === "error" && root.speedTestError !== ""
                        text: root.speedTestError
                        color: Color.error
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    ActionButton {
                        text: root.speedTestProcess.running ? "Midiendo…" : root.speedTestResultReady ? "Repetir test" : "Ejecutar test"
                        enabled: !root.speedTestProcess.running
                        onClicked: root.startSpeedTest()
                    }
                }
                SettingCard { visible: !root.net?.wifiDevice; title: "Adaptador Wi‑Fi"; icon: "error_outline"; subtitle: "No se detectó un adaptador inalámbrico" }
            }
            Page {
                icon: "bluetooth"
                title: "Bluetooth"
                subtitle: root.bt?.enabled ? (root.bt.connectedDevices?.length || 0) + " dispositivos conectados" : "Bluetooth desactivado"
                SettingCard {
                    title: "Bluetooth"; icon: "bluetooth"; subtitle: root.bt?.enabled ? "Disponible para conectar dispositivos" : "Bluetooth desactivado"
                    Flow { Layout.fillWidth: true; spacing: Style.spacingSmall; ActionButton { text: root.bt?.enabled ? "Desactivar Bluetooth" : "Activar Bluetooth"; enabled: Boolean(root.bt?.available); onClicked: if (root.bt) root.bt.setEnabled(!root.bt.enabled) } ActionButton { text: root.bt?.discovering ? "Detener búsqueda" : "Buscar dispositivos"; enabled: Boolean(root.bt?.enabled); onClicked: if (root.bt) root.bt.discovering ? root.bt.stopScan() : root.bt.startScan() } }
                    Repeater { model: root.bt?.devices || []; delegate: RowItem { required property var modelData; name: modelData.name; detail: modelData.connected ? "Conectado" : modelData.paired ? "Emparejado" : "Disponible"; active: modelData.connected; onClicked: if (root.bt) modelData.connected ? root.bt.disconnectDevice(modelData) : root.bt.connectDevice(modelData) } }
                }
            }
            Page {
                icon: "volume_up"
                title: "Output"
                subtitle: "Salida principal y volumen por aplicación"
                SettingCard { title: "Salida de audio"; icon: "speaker"; subtitle: root.audio?.outputName || "Salida predeterminada"; Repeater { model: root.audio?.outputsModel || []; delegate: RowItem { required property var modelData; name: root.audio.outputDisplayName(modelData); detail: modelData === Pipewire.defaultAudioSink ? "Activo" : "Disponible"; active: modelData === Pipewire.defaultAudioSink; onClicked: root.audio.selectOutput(modelData) } } AudioRow { name: "Volumen principal"; node: root.audio?.sink } }
                SettingCard { title: "Aplicaciones"; icon: "apps"; subtitle: "Volumen independiente por aplicación"; Repeater { model: root.audio?.applicationGroupsModel || []; delegate: AudioRow { required property var modelData; name: modelData.name; group: modelData } } Text { visible: (root.audio?.applicationGroupsModel?.values || []).length === 0; text: "No hay aplicaciones reproduciendo audio"; color: root.lyneMuted; font.pixelSize: Style.fontSmall } }
            }
            Page {
                icon: "mic"
                title: "Input"
                subtitle: "Micrófonos, entrada predeterminada y filtros"
                SettingCard { title: "Entrada de audio"; icon: "mic"; subtitle: root.audio?.inputDisplayName(root.mic) || "Entrada predeterminada"; Repeater { model: root.audio?.inputsModel || []; delegate: RowItem { required property var modelData; name: root.audio.inputDisplayName(modelData); detail: modelData === Pipewire.defaultAudioSource ? "Activo" : "Disponible"; active: modelData === Pipewire.defaultAudioSource; onClicked: root.audio.selectInput(modelData) } } AudioRow { name: "Volumen del micrófono"; node: root.mic } }
                SettingCard {
                    title: "Filtros del micrófono"
                    icon: "graphic_eq"
                    subtitle: root.effects.available ? (root.effects.running ? "EasyEffects activo" : "EasyEffects instalado") : "EasyEffects no disponible"
                    Text { Layout.fillWidth: true; text: root.effects.running ? "Los efectos pueden salir por una fuente virtual Easy Effects Source." : "Abre EasyEffects, activa los efectos de entrada y selecciona su fuente virtual en la llamada."; color: root.lyneMuted; font.pixelSize: Style.fontSmall; wrapMode: Text.WordWrap }
                    Flow { Layout.fillWidth: true; spacing: Style.spacingSmall; ActionButton { text: root.effects.running ? "EasyEffects abierto" : "Abrir EasyEffects"; enabled: root.effects.available && !root.effects.running; onClicked: root.effects.open() } ActionButton { text: "Usar fuente procesada"; enabled: root.effectsSource !== null; onClicked: root.audio.selectInput(root.effectsSource) } ActionButton { text: "Actualizar estado"; onClicked: root.effects.refresh() } }
                }
            }
            Page {
                icon: "palette"
                title: "Apariencia"
                subtitle: "Temas, fondos y presentación del shell"
                SettingCard {
                    title: "Schemes"; icon: "palette"; subtitle: root.settingsThemes.currentSlug || "Selecciona un scheme"
                    Text {
                        visible: root.settingsThemes.themes.length === 0
                        text: "No se encontraron schemes"
                        color: root.lyneMuted
                        font.pixelSize: Style.fontSmall
                    }
                    Item {
                        id: schemesCarouselViewport
                        Layout.fillWidth: true
                        Layout.preferredHeight: 136
                        Layout.minimumHeight: 136

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onWheel: event => {
                                if (!root.settingsThemes.themes || root.settingsThemes.themes.length === 0)
                                    return
                                if (event.angleDelta.y > 0 || event.angleDelta.x < 0)
                                    schemeCarousel.currentIndex = Math.max(0, schemeCarousel.currentIndex - 1)
                                else if (event.angleDelta.y < 0 || event.angleDelta.x > 0)
                                    schemeCarousel.currentIndex = Math.min(schemeCarousel.count - 1, schemeCarousel.currentIndex + 1)
                                event.accepted = true
                            }
                        }

                        PathView {
                            id: schemeCarousel
                            anchors.fill: parent
                            anchors.leftMargin: 38
                            anchors.rightMargin: 38
                            clip: true
                            model: root.settingsThemes.themes || []
                            currentIndex: root.appearanceSchemeIndex
                            pathItemCount: 3
                            cacheItemCount: 4
                            snapMode: PathView.SnapToItem
                            highlightRangeMode: PathView.StrictlyEnforceRange
                            preferredHighlightBegin: 0.5
                            preferredHighlightEnd: 0.5
                            highlightMoveDuration: Style.motionSlow
                            interactive: false

                            onCurrentIndexChanged: root.appearanceSchemeIndex = currentIndex

                            delegate: ThemeChoice {
                                required property var modelData
                                required property int index
                                theme: modelData
                                implicitWidth: Math.min(210, schemeCarousel.width * 0.34)
                                implicitHeight: 104
                                scale: PathView.carouselScale
                                opacity: PathView.carouselOpacity
                                z: PathView.carouselZ
                                onClicked: {
                                    schemeCarousel.currentIndex = index
                                    root.settingsThemes.setTheme(theme.slug)
                                }
                            }

                            path: Path {
                                startX: 0
                                startY: schemeCarousel.height / 2
                                PathAttribute { name: "carouselScale"; value: 0.82 }
                                PathAttribute { name: "carouselOpacity"; value: 0.58 }
                                PathAttribute { name: "carouselZ"; value: 1 }
                                PathLine { x: schemeCarousel.width / 2; y: schemeCarousel.height / 2 }
                                PathAttribute { name: "carouselScale"; value: 1.0 }
                                PathAttribute { name: "carouselOpacity"; value: 1.0 }
                                PathAttribute { name: "carouselZ"; value: 3 }
                                PathLine { x: schemeCarousel.width; y: schemeCarousel.height / 2 }
                                PathAttribute { name: "carouselScale"; value: 0.82 }
                                PathAttribute { name: "carouselOpacity"; value: 0.58 }
                                PathAttribute { name: "carouselZ"; value: 1 }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: Style.radiusFull
                            color: root.lyneSurfaceHover
                            z: 4
                            MaterialIcon { anchors.centerIn: parent; text: "chevron_left"; iconSize: Style.materialIconSmall; iconColor: root.lyneText }
                            TapHandler {
                                enabled: schemeCarousel.count > 0
                                onTapped: schemeCarousel.currentIndex = Math.max(0, schemeCarousel.currentIndex - 1)
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: Style.radiusFull
                            color: root.lyneSurfaceHover
                            z: 4
                            MaterialIcon { anchors.centerIn: parent; text: "chevron_right"; iconSize: Style.materialIconSmall; iconColor: root.lyneText }
                            TapHandler {
                                enabled: schemeCarousel.count > 0
                                onTapped: schemeCarousel.currentIndex = Math.min(schemeCarousel.count - 1, schemeCarousel.currentIndex + 1)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.settingsThemes.themes.length + " schemes disponibles"; color: root.lyneMuted; font.pixelSize: 12; Layout.fillWidth: true }
                        ActionButton { text: "Actualizar schemes"; onClicked: root.settingsThemes.listProcess.running = true }
                    }
                }
                SettingCard {
                    title: "Wallpapers"; icon: "wallpaper"; subtitle: Services.Wallpapers.currentPath || "Selecciona un wallpaper"
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: Style.spacingSmall
                        Repeater { model: Services.Wallpapers.wallpapers || []; delegate: WallpaperChoice { required property var modelData; wallpaper: modelData; current: modelData.path === Services.Wallpapers.currentPath; onClicked: Services.Wallpapers.setWallpaper(wallpaper.path, "") } }
                    }
                    Flow { Layout.fillWidth: true; spacing: Style.spacingSmall; ActionButton { text: "Actualizar lista"; onClicked: Services.Wallpapers.refresh() } ActionButton { text: "Reaplicar guardados"; onClicked: Services.Wallpapers.applySaved() } Text { text: Services.Wallpapers.currentCount + " wallpapers disponibles"; color: root.lyneMuted; font.pixelSize: Style.fontSmall; Layout.alignment: Qt.AlignVCenter } }
                }
            }
            Page {
                icon: "memory"
                title: "Hardware"
                subtitle: Services.HardwareService.available ? "Recursos del sistema · actualización cada 2 s" : "Recopilando información…"
                GridLayout {
                    id: hardwareGrid
                    Layout.fillWidth: true
                    // Keep cards readable after the sidebar has consumed its
                    // space. On compact monitors, stack them instead of
                    // squeezing labels and gauges into narrow columns.
                    columns: width >= 860 ? 2 : 1
                    columnSpacing: Style.spacingMedium
                    rowSpacing: Style.spacingMedium
                    HardwareHero {
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        label: "CPU"
                        icon: "memory"
                        description: Services.HardwareService.cpuModel
                            + " · " + Services.HardwareService.cpuCores
                            + " núcleos · " + Services.HardwareService.cpuThreads
                            + " hilos"
                        usage: Services.HardwareService.cpuUsage
                        history: Services.HardwareService.cpuHistory
                        detail: Services.HardwareService.cpuTemperature >= 0 ? Services.HardwareService.cpuTemperature.toFixed(0) + " °C" : "Sin sensor"
                        extra: Services.HardwareService.cpuFrequencyGHz > 0 ? Services.HardwareService.cpuFrequencyGHz.toFixed(2) + " GHz" : ""
                        showCoreUsage: true
                    }
                    HardwareHero {
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        label: "GPU"
                        icon: "developer_board"
                        description: Services.HardwareService.gpuAvailable ? Services.HardwareService.gpuModel : "No detectada"
                        usage: Services.HardwareService.gpuUsage
                        history: Services.HardwareService.gpuHistory
                        detail: Services.HardwareService.gpuTemperature >= 0 ? Services.HardwareService.gpuTemperature.toFixed(0) + " °C" : "Sin sensor"
                        extra: Services.HardwareService.gpuMemoryTotalGiB > 0 ? Services.HardwareService.gpuMemoryUsedGiB.toFixed(1) + " / " + Services.HardwareService.gpuMemoryTotalGiB.toFixed(1) + " GiB" : ""
                    }
                    HardwareGaugeCard {
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        label: "Memoria"
                        icon: "memory_alt"
                        value: Services.HardwareService.memoryUsed
                        detail: Services.HardwareService.memoryUsedGiB.toFixed(1) + " / " + Services.HardwareService.memoryTotalGiB.toFixed(1) + " GiB"
                    }
                    HardwareGaugeCard {
                        Layout.fillWidth: true
                        Layout.columnSpan: 1
                        label: Services.HardwareService.diskUsed >= 90 ? "Almacenamiento · Casi lleno" : "Almacenamiento"
                        icon: "hard_drive"
                        value: Services.HardwareService.diskUsed
                        detail: Services.HardwareService.primaryDisk ? Services.HardwareService.primaryDisk.used.toFixed(1) + " / " + Services.HardwareService.primaryDisk.total.toFixed(1) + " GiB · " + Services.HardwareService.primaryDisk.mount : "Sin discos detectados"
                    }
                }
                ActionButton { text: "Actualizar datos del equipo"; onClicked: root.hardware.refresh() }
            }
            Page {
                icon: "keyboard"
                title: "Atajos"
                subtitle: "Acciones principales de Tartarus"
                SettingCard { title: "Centro de control"; icon: "settings"; subtitle: "SUPER + I" }
                SettingCard { title: "Barra lateral"; icon: "view_sidebar"; subtitle: "SUPER + SHIFT + I" }
                SettingCard { title: "Launcher"; icon: "apps"; subtitle: "SUPER + SPACE" }
                SettingCard { title: "Portapapeles"; icon: "content_paste"; subtitle: "SUPER + CTRL + V" }
                SettingCard { title: "Modo gaming"; icon: "sports_esports"; subtitle: "SUPER + G" }
            }
            Page {
                icon: "power_settings_new"
                title: "Sesión"
                subtitle: "Notificaciones y acciones de energía"
                SettingCard { title: "No molestar"; icon: "notifications_off"; subtitle: Services.NotificationService.dnd ? "Activo" : "Desactivado"; ActionButton { text: Services.NotificationService.dnd ? "Desactivar" : "Activar"; onClicked: Services.NotificationService.toggleDnd() } }
                SettingCard { title: "Modo nocturno"; icon: "nightlight"; subtitle: "Se controla desde la sidebar rápida"; Text { text: "El control aparece en la sidebar cuando hay un backend compatible disponible."; color: root.lyneMuted; font.pixelSize: Style.fontSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true } }
                    SettingCard { title: "Energía y sesión"; icon: "power_settings_new"; subtitle: "Las acciones destructivas requieren confirmación"; Flow { Layout.fillWidth: true; spacing: Style.spacingSmall; ActionButton { text: "Bloquear"; onClicked: Services.PowerService.lock() } ActionButton { text: "Suspender"; onClicked: Services.SidebarService.requestPower("suspend") } ActionButton { text: "Cerrar sesión"; onClicked: Services.SidebarService.requestPower("logout") } ActionButton { text: "Reiniciar"; onClicked: Services.SidebarService.requestPower("reboot") } ActionButton { text: "Apagar"; onClicked: Services.SidebarService.requestPower("shutdown") } } RowLayout { visible: Services.SidebarService.pendingPower !== ""; Text { text: "¿Confirmar " + Services.SidebarService.pendingPower + "?"; color: Color.warning; Layout.fillWidth: true } ActionButton { text: "Cancelar"; onClicked: Services.SidebarService.cancelPower() } ActionButton { text: "Confirmar"; onClicked: Services.SidebarService.confirmPower() } } }
            }
            Page {
                icon: "monitor"
                title: "Monitores"
                subtitle: "Organiza las pantallas y ajusta su configuración"
                MonitorPanel {
                    service: Services.MonitorService
                    backgroundColor: root.lyneBackground
                    surfaceColor: root.lyneSurface
                    surfaceHighColor: root.lyneSurfaceHigh
                    surfaceHoverColor: root.lyneSurfaceHover
                    accentColor: root.lyneAccent
                    textColor: root.lyneText
                    mutedColor: root.lyneMuted
                }
            }
            Page {
                icon: "calendar_month"
                title: "Calendario"
                subtitle: "Agenda privada mediante un feed iCalendar"
                SettingCard {
                    title: "Feed iCalendar"
                    icon: "event"
                    subtitle: Services.CalendarService.configured ? "Configurado · se actualiza cada 5 minutos" : "No configurado"
                    Text { text: "Usa la dirección privada HTTPS de tu calendario. Se guarda localmente y no se muestra en la barra."; color: root.lyneMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: calendarUrlField
                            Layout.fillWidth: true
                            text: Services.CalendarService.feedUrl
                            placeholderText: "https://…/basic.ics"
                            echoMode: TextInput.Password
                            color: root.lyneText
                            placeholderTextColor: root.lyneMuted
                            leftPadding: 12
                            rightPadding: 12
                            background: Rectangle { radius: Style.controlRadius; color: root.lyneSurfaceHigh; border.width: calendarUrlField.activeFocus ? 1 : 0; border.color: root.lyneAccent }
                        }
                        ActionButton { text: "Guardar"; onClicked: Services.CalendarService.configure(calendarUrlField.text, "Calendario") }
                    }
                    Text { visible: Services.CalendarService.errorMessage !== ""; text: Services.CalendarService.errorMessage; color: "#ffb4ab"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: Services.CalendarService.events.length + " eventos cargados"; color: root.lyneMuted; font.pixelSize: 12; Layout.fillWidth: true }
                        ActionButton { text: "Actualizar"; onClicked: Services.CalendarService.refresh() }
                    }
                }
            }
        }
    }

    component Nav: Rectangle {
        id: nav
        property string label: ""
        property string icon: ""
        property bool selected: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: Style.radiusFull
        color: selected ? Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.18) : navHover.hovered ? root.lyneSurfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Style.motionFast } }
        HoverHandler { id: navHover }
        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            spacing: Style.spacingSmall
            Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: Style.radiusMedium; color: nav.selected ? root.lyneAccent : root.lyneSurfaceHigh; MaterialIcon { anchors.centerIn: parent; text: nav.icon; iconSize: Style.iconButtonIconSize - 2; iconColor: nav.selected ? root.lyneBackground : root.lyneMuted } }
            Text { text: nav.label; color: nav.selected ? root.lyneAccent : root.lyneText; font.pixelSize: Style.fontSmall; font.bold: nav.selected; Layout.fillWidth: true }
        }
        TapHandler { onTapped: nav.clicked() }
    }

    component Page: Flickable {
        id: page
        property string title: ""
        property string subtitle: ""
        property string icon: "settings"
        default property alias content: body.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: body
            x: Style.paddingLarge
            y: Style.paddingLarge
            width: page.width - Style.paddingLarge * 2
            spacing: Style.spacingMedium
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingMedium
                Rectangle { Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: Style.radiusLarge; color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.16); MaterialIcon { anchors.centerIn: parent; text: page.icon; iconSize: Style.materialIconLarge; iconColor: root.lyneAccent } }
                ColumnLayout { Layout.fillWidth: true; Text { text: page.title; color: root.lyneText; font.pixelSize: 28; font.bold: true } Text { text: page.subtitle; color: root.lyneMuted; font.pixelSize: Style.fontSmall; wrapMode: Text.WordWrap; Layout.fillWidth: true } }
            }
        }
    }

    component ProfileHeader: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 104
        radius: Style.cardRadius
        color: root.lyneSurfaceHigh
        border.width: 1
        border.color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.12)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.paddingLarge
            anchors.rightMargin: Style.paddingLarge
            anchors.topMargin: Style.paddingMedium
            anchors.bottomMargin: Style.paddingMedium
            spacing: Style.spacingMedium
            Rectangle {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 68
                radius: Style.radiusFull
                color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.18)
                border.width: 2
                border.color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.42)
                clip: true
                Image {
                    id: profileImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.profileImageSource
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: false
                }
                Rectangle {
                    id: profileImageMask
                    anchors.fill: profileImage
                    radius: width / 2
                    color: "white"
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: profileImage
                    source: profileImage
                    visible: profileImage.status === Image.Ready
                    maskEnabled: true
                    maskSource: profileImageMask
                    autoPaddingEnabled: false
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "person"
                    iconSize: Style.materialIconLarge
                    iconColor: root.lyneAccent
                    visible: profileImage.status !== Image.Ready
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: "Leandro"; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true }
                Text { text: "Tartarus · Arch Linux · Quickshell"; color: root.lyneMuted; font.pixelSize: Style.fontSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: "Sesión activa"; color: root.lyneAccent; font.pixelSize: 12; font.bold: true }
            }
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Style.radiusFull
                color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.14)
                MaterialIcon { anchors.centerIn: parent; text: "check"; iconSize: Style.materialIconSmall; iconColor: root.lyneAccent }
            }
        }
    }

    component StyledSwitch: Switch {
        id: styledSwitch
        implicitWidth: 48
        implicitHeight: 28
        indicator: Rectangle {
            x: styledSwitch.leftPadding
            y: styledSwitch.topPadding + (styledSwitch.availableHeight - height) / 2
            implicitWidth: 48
            implicitHeight: 28
            radius: height / 2
            color: styledSwitch.checked ? root.lyneAccent : root.lyneSurfaceHigh
            border.width: 1
            border.color: styledSwitch.checked
                ? Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.9)
                : Qt.rgba(root.lyneMuted.r, root.lyneMuted.g, root.lyneMuted.b, 0.42)
            Behavior on color { ColorAnimation { duration: Style.motionFast } }
            Rectangle {
                width: 20
                height: 20
                y: 3
                x: styledSwitch.checked ? parent.width - width - 3 : 3
                radius: Style.radiusFull
                color: styledSwitch.checked ? root.lyneBackground : root.lyneMuted
                Behavior on x { NumberAnimation { duration: Style.motionFast; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Style.motionFast } }
            }
        }
    }

    component SpeedTestMetric: Rectangle {
        id: speedMetric
        property string label: ""
        property string value: "—"
        property color accent: root.lyneAccent
        Layout.fillWidth: true
        implicitHeight: 70
        radius: Style.controlRadius
        color: root.lyneSurfaceHigh
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            spacing: 2
            Text { text: speedMetric.label; color: root.lyneMuted; font.pixelSize: 12; Layout.fillWidth: true }
            Text { text: speedMetric.value; color: speedMetric.accent; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
        }
    }

    component SettingCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string icon: "settings"
        property string headerInfo: ""
        default property alias content: cardBody.data
        Layout.fillWidth: true
        implicitHeight: cardBody.implicitHeight + Style.paddingMedium * 2
        radius: Style.cardRadius
        color: root.lyneSurface
        border.width: 1
        border.color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.08)
        ColumnLayout {
            id: cardBody
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: Style.radiusMedium; color: Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.14); MaterialIcon { anchors.centerIn: parent; text: card.icon; iconSize: Style.sectionIconSize; iconColor: root.lyneAccent } }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: card.title; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { visible: card.subtitle !== ""; text: card.subtitle; color: root.lyneMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                Text { visible: card.headerInfo !== ""; text: card.headerInfo; color: root.lyneAccent; font.pixelSize: Style.fontSmall; font.bold: true; Layout.alignment: Qt.AlignTop }
            }
        }
    }

    component RowItem: Rectangle {
        id: item
        property string name: ""
        property string detail: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Style.controlRadius
        color: active ? Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.18) : root.lyneSurfaceHigh
        border.width: 0
        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            MaterialIcon { text: item.active ? "check_circle" : "radio_button_unchecked"; iconSize: Style.materialIconMedium; iconColor: item.active ? root.lyneAccent : root.lyneMuted }
            ColumnLayout { Layout.fillWidth: true; Text { text: item.name; color: root.lyneText; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight } Text { text: item.detail; color: root.lyneMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight } }
            MaterialIcon { text: "chevron_right"; iconSize: Style.materialIconSmall; iconColor: root.lyneMuted }
        }
        TapHandler { onTapped: item.clicked() }
    }

    component AudioRow: ColumnLayout {
        id: audioRow
        property string name: ""
        property var node: null
        property var group: null
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: audioRow.group ? root.audio.applicationIcon(audioRow.group) : "volume_up"; iconSize: Style.materialIconSmall; iconColor: root.lyneAccent }
            Text { text: audioRow.name; color: root.lyneText; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: audioRow.group ? Math.round(root.audio.groupVolume(audioRow.group) * 100) + "%" : audioRow.node?.audio ? Math.round(audioRow.node.audio.volume * 100) + "%" : "—"; color: root.lyneMuted; font.pixelSize: Style.fontSmall }
            ActionButton { text: audioRow.group ? (root.audio.groupMuted(audioRow.group) ? "Activar" : "Silenciar") : (audioRow.node?.audio?.muted ? "Activar" : "Silenciar"); enabled: Boolean(audioRow.group || (audioRow.node?.ready && audioRow.node?.audio)); onClicked: audioRow.group ? root.audio.toggleGroupMute(audioRow.group) : audioRow.node.audio.muted = !audioRow.node.audio.muted }
        }
        StyledSlider { Layout.fillWidth: true; enabled: Boolean(audioRow.group || (audioRow.node?.ready && audioRow.node?.audio)); from: 0; to: 1; value: audioRow.group ? root.audio.groupVolume(audioRow.group) : audioRow.node?.audio?.volume ?? 0; onMoved: audioRow.group ? root.audio.setGroupVolume(audioRow.group, value) : audioRow.node.audio.volume = value }
    }

    component ActionButton: Button {
        id: button
        implicitHeight: 38
        implicitWidth: Math.max(104, contentItem.implicitWidth + 22)
        contentItem: Text { text: button.text; color: button.enabled ? root.lyneText : root.lyneMuted; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { radius: Style.radiusFull; color: button.down ? root.lyneAccent : button.hovered ? root.lyneSurfaceHover : root.lyneSurfaceHigh; border.width: 0; opacity: button.enabled ? 1 : 0.55 }
    }

    component FastfetchLine: RowLayout {
        id: fastfetchLine
        required property string label
        required property string value
        property color accent: root.lyneAccent
        Layout.fillWidth: true
        spacing: 2
        Text {
            text: fastfetchLine.label + ":"
            color: fastfetchLine.accent
            font.pixelSize: 12
            font.family: "monospace"
            font.bold: true
            Layout.preferredWidth: 66
        }
        Text {
            text: fastfetchLine.value
            color: root.lyneText
            font.pixelSize: 12
            font.family: "monospace"
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component FastfetchBoxLine: Text {
        id: fastfetchBoxLine
        required property string lineText
        property color accent: root.lyneAccent
        text: fastfetchBoxLine.lineText
        color: fastfetchBoxLine.accent
        font.pixelSize: 12
        font.family: "monospace"
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    component HardwareRing: Canvas {
        id: ring
        property real value: 0
        property color accent: root.lyneAccent
        implicitWidth: 62
        implicitHeight: 62
        onValueChanged: requestPaint()
        onAccentChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const radius = Math.max(1, Math.min(width, height) / 2 - 5)
            const centerX = width / 2
            const centerY = height / 2
            ctx.lineWidth = 5
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.strokeStyle = root.lyneSurfaceHover.toString()
            ctx.arc(centerX, centerY, radius, -Math.PI / 2, Math.PI * 1.5)
            ctx.stroke()
            if (ring.value > 0) {
                ctx.beginPath()
                ctx.strokeStyle = ring.accent.toString()
                ctx.arc(centerX, centerY, radius, -Math.PI / 2,
                    -Math.PI / 2 + Math.PI * 2 * Math.min(100, ring.value) / 100)
                ctx.stroke()
            }
        }
    }

    component HardwareHero: Rectangle {
        id: hero
        property string label: ""
        property string icon: "memory"
        property string description: ""
        property real usage: -1
        property var history: []
        property string detail: ""
        property string extra: ""
        property bool showCoreUsage: false
        readonly property color accent: usage < 0 ? root.lyneMuted : usage >= 90 ? "#f26d78" : usage >= 70 ? "#f2b36d" : root.lyneAccent
        implicitHeight: hero.showCoreUsage ? 246 : 172
        radius: Style.cardRadius
        color: root.lyneSurface
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.spacingMedium
                HardwareRing { value: hero.usage; accent: hero.accent; MaterialIcon { anchors.centerIn: parent; text: hero.icon; iconSize: Style.materialIconMedium; iconColor: hero.accent } }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: hero.label; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true }
                    Text { text: hero.description; color: root.lyneMuted; font.pixelSize: Style.fontSmall; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Text { text: hero.usage >= 0 ? Math.round(hero.usage) + "%" : "—"; color: hero.accent; font.pixelSize: 27; font.bold: true }
            }
            NetworkWave { Layout.fillWidth: true; Layout.preferredHeight: 38; values: hero.history; accent: hero.accent; maximumFloor: 100 }
            RowLayout {
                Layout.fillWidth: true
                Text { text: hero.detail; color: root.lyneMuted; font.pixelSize: Style.fontSmall }
                Item { Layout.fillWidth: true }
                Text { text: hero.extra; color: root.lyneMuted; font.pixelSize: Style.fontSmall; elide: Text.ElideRight; Layout.maximumWidth: hero.width * 0.48 }
            }
            Text {
                visible: hero.showCoreUsage
                text: "Uso por núcleo"
                color: root.lyneMuted
                font.pixelSize: 12
                Layout.topMargin: 2
            }
            Flow {
                visible: hero.showCoreUsage
                Layout.fillWidth: true
                Layout.preferredHeight: hero.showCoreUsage ? 42 : 0
                spacing: 6
                Repeater {
                    model: hero.showCoreUsage ? Services.HardwareService.coreUsages : []
                    delegate: ColumnLayout {
                        id: coreUsage
                        required property var modelData
                        required property int index
                        width: 42
                        spacing: 3
                        Accessible.name: "Núcleo " + (index + 1) + ": " + Math.round(Number(modelData)) + "%"
                        Text {
                            Layout.fillWidth: true
                            text: Math.round(Number(coreUsage.modelData)) + "%"
                            color: root.lyneText
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 5
                            radius: 3
                            color: root.lyneSurfaceHigh
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(100, Number(coreUsage.modelData))) / 100
                                height: parent.height
                                radius: parent.radius
                                color: Number(coreUsage.modelData) >= 90 ? "#f26d78" : Number(coreUsage.modelData) >= 70 ? "#f2b36d" : root.lyneAccent
                            }
                        }
                    }
                }
            }
        }
    }

    component HardwareGaugeCard: Rectangle {
        id: gaugeCard
        property string label: ""
        property string icon: "memory"
        property real value: 0
        property string detail: ""
        readonly property color accent: value >= 90 ? "#f26d78" : value >= 70 ? "#f2b36d" : root.lyneAccent
        implicitHeight: 172
        radius: Style.cardRadius
        color: root.lyneSurface
        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingMedium
            HardwareRing { implicitWidth: 76; implicitHeight: 76; value: gaugeCard.value; accent: gaugeCard.accent; Text { anchors.centerIn: parent; text: Math.round(gaugeCard.value) + "%"; color: gaugeCard.accent; font.pixelSize: Style.fontNormal; font.bold: true } }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout { MaterialIcon { text: gaugeCard.icon; iconSize: Style.materialIconSmall; iconColor: gaugeCard.accent } Text { text: gaugeCard.label; color: root.lyneText; font.pixelSize: Style.fontNormal; font.bold: true } }
                Text { text: gaugeCard.detail; color: root.lyneMuted; font.pixelSize: Style.fontSmall; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    component HardwareRate: Rectangle {
        id: rateCard
        property string label: ""
        property string icon: "download"
        property real rate: 0
        property color accent: root.lyneAccent
        property var history: []
        implicitHeight: 94
        radius: Style.controlRadius
        color: root.lyneSurfaceHigh
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: rateCard.icon; iconSize: Style.materialIconSmall; iconColor: rateCard.accent }
                Text { text: rateCard.label; color: root.lyneMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
                Text { text: root.net?.formatRate(rateCard.rate) || "0 B/s"; color: rateCard.accent; font.pixelSize: Style.fontSmall; font.bold: true }
            }
            NetworkWave { Layout.fillWidth: true; Layout.fillHeight: true; values: rateCard.history; accent: rateCard.accent }
        }
    }

    component NetworkWave: Item {
        id: wave
        property var values: []
        property color accent: root.lyneAccent
        property real maximumFloor: 1024
        property real maximum: {
            let result = wave.maximumFloor
            for (const value of wave.values || [])
                result = Math.max(result, Number(value) || 0)
            return result
        }
        implicitHeight: 30
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(wave.accent.r, wave.accent.g, wave.accent.b, 0.22)
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            height: Math.max(4, parent.height - 1)
            spacing: 3

            Repeater {
                model: wave.values || []
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(2, (wave.width - (Math.max(0, (wave.values || []).length - 1) * 3)) / Math.max(1, (wave.values || []).length))
                    height: Math.max(3, Math.min(parent.height, (Number(modelData) || 0) / wave.maximum * parent.height))
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    color: wave.accent
                    opacity: 0.35 + (height / Math.max(1, parent.height)) * 0.65
                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    component ThemeChoice: Rectangle {
        id: themeChoice
        required property var theme
        signal clicked()
        implicitWidth: 190
        implicitHeight: 82
        radius: Style.controlRadius
        color: themeChoice.theme.slug === root.settingsThemes.currentSlug ? Qt.rgba(root.lyneAccent.r, root.lyneAccent.g, root.lyneAccent.b, 0.22) : root.lyneSurfaceHigh
        border.width: themeChoice.theme.slug === root.settingsThemes.currentSlug ? 1 : 0
        border.color: root.lyneAccent
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingSmall
            spacing: Style.spacingXs
            RowLayout {
                Layout.fillWidth: true
                Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: Style.radiusFull; color: root.lyneAccent; MaterialIcon { anchors.centerIn: parent; text: "palette"; iconSize: Style.materialIconSmall; iconColor: root.lyneBackground } }
                ColumnLayout { Layout.fillWidth: true; Text { text: themeChoice.theme.name; color: root.lyneText; font.pixelSize: Style.fontSmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true } Text { text: themeChoice.theme.slug === root.settingsThemes.currentSlug ? "Activo" : "Disponible"; color: root.lyneMuted; font.pixelSize: 12 } }
            }
            Row {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: themeChoice.theme.preview || []
                    delegate: Rectangle { required property var modelData; width: 24; height: 7; radius: 4; color: modelData }
                }
            }
        }
        TapHandler { onTapped: themeChoice.clicked() }
    }

    component WallpaperChoice: Rectangle {
        id: wallpaperChoice
        required property var wallpaper
        required property bool current
        signal clicked()
        implicitWidth: 190
        implicitHeight: 126
        radius: Style.controlRadius
        clip: true
        color: root.lyneSurfaceHigh
        border.width: wallpaperChoice.current ? 2 : 0
        border.color: root.lyneAccent
        Image { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 92; source: wallpaperChoice.wallpaper.path; sourceSize.width: 480; sourceSize.height: 270; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 36; color: root.lyneSurfaceHigh }
        Text { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Style.paddingSmall; text: wallpaperChoice.wallpaper.name; color: root.lyneText; font.pixelSize: 12; elide: Text.ElideRight }
        TapHandler { onTapped: wallpaperChoice.clicked() }
    }

    component StyledSlider: Slider {
        id: slider
        implicitHeight: 30
        padding: 8
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: root.lyneSurfaceHigh
            Rectangle { width: slider.position * parent.width; height: parent.height; radius: parent.radius; color: slider.enabled ? root.lyneAccent : root.lyneMuted }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.pressed ? 20 : 16
            height: width
            radius: width / 2
            color: slider.enabled ? root.lyneAccent : root.lyneMuted
            border.width: slider.activeFocus ? 2 : 0
            border.color: root.lyneText
        }
    }
}
