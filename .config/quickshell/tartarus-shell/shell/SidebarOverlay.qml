import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.Pipewire
import Qt.labs.folderlistmodel
import "../services" as Services
import "../theme" as Theme

// Quick settings: one window owns its layout, controls and monitor lifecycle.
PanelWindow {
    id: root

    required property var monitorScreen
    required property var pluginRegistry
    required property var monitorContext
    required property var shellState

    screen: root.monitorScreen
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    property real offsetScale: monitorContext.sidebarOpened ? 0 : 1
    Behavior on offsetScale {
        Theme.Anim {
            duration: Theme.Style.motionPanel
        }
    }
    visible: monitorContext.sidebarOpened || offsetScale < 1
    WlrLayershell.keyboardFocus: monitorContext.sidebarOpened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property var net: pluginRegistry.plugin("network")?.service
    readonly property var bt: pluginRegistry.plugin("bluetooth")?.service
    readonly property var audio: pluginRegistry.plugin("audio")?.service
    readonly property var brightness: pluginRegistry.plugin("brightness")?.service
    readonly property var mic: Pipewire.defaultAudioSource
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.visible
    }
    readonly property date today: clock.date
    property int shownMonth: today.getMonth()
    property int shownYear: today.getFullYear()

    readonly property string wifiSubtitle: {
        if (!root.net)
            return "No disponible";
        if (!root.net.wifiEnabled)
            return "Desactivado";
        return root.net.connected ? (root.net.ssid || "Conectado") : "No conectado";
    }
    readonly property string bluetoothSubtitle: {
        if (!root.bt || !root.bt.available)
            return "No disponible";
        if (!root.bt.enabled)
            return "Desactivado";
        const connected = root.bt.devices?.find(device => device.connected);
        return connected ? (connected.name || "Conectado") : "No conectado";
    }
    readonly property real volume: root.audio?.volume ?? 0
    property string quickPage: ""

    PwObjectTracker {
        objects: [root.mic]
    }

    function monthTitle() {
        return new Date(root.shownYear, root.shownMonth, 1).toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy");
    }

    function calendarCells() {
        const first = new Date(root.shownYear, root.shownMonth, 1);
        const count = new Date(root.shownYear, root.shownMonth + 1, 0).getDate();
        const offset = (first.getDay() + 6) % 7;
        const cells = [];
        for (let i = 0; i < offset; ++i)
            cells.push({
                day: "",
                current: false,
                event: false
            });
        for (let day = 1; day <= count; ++day) {
            const date = new Date(root.shownYear, root.shownMonth, day, 12);
            const key = Qt.formatDate(date, "yyyy-MM-dd");
            cells.push({
                day: String(day),
                current: key === Qt.formatDate(root.today, "yyyy-MM-dd"),
                event: Services.CalendarService.eventsForDate(key).length > 0
            });
        }
        while (cells.length % 7)
            cells.push({
                day: "",
                current: false,
                event: false
            });
        return cells;
    }

    function moveMonth(delta) {
        const next = new Date(root.shownYear, root.shownMonth + delta, 1);
        root.shownMonth = next.getMonth();
        root.shownYear = next.getFullYear();
    }

    function openAdvanced(page) {
        Services.QuickSettingsState.setPage(page)
        root.quickPage = page
        viewport.contentY = 0
    }

    function closePage() {
        root.quickPage = ""
        Services.QuickSettingsState.setPage("")
        viewport.contentY = 0
    }

    function pageTitle() {
        if (root.quickPage === "wifi") return "Wi‑Fi"
        if (root.quickPage === "bluetooth") return "Bluetooth"
        if (root.quickPage === "audio") return "Salida de audio"
        if (root.quickPage === "microphone") return "Micrófono"
        if (root.quickPage === "dnd") return "No molestar"
        if (root.quickPage === "night") return "Modo nocturno"
        if (root.quickPage === "power") return "Energía y sesión"
        return "Ajustes rápidos"
    }

    Connections {
        target: root.monitorContext
        function onSidebarOpenedChanged() {
            if (root.monitorContext.sidebarOpened)
                root.closePage()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.monitorContext.closeSidebar()
    }

    Rectangle {
        id: drawer
        width: Math.max(1, Math.min(420, parent.width - 24))
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }
        anchors.topMargin: 12
        anchors.bottomMargin: Theme.Style.barHeight + 16
        anchors.rightMargin: 12 - (width + 24) * root.offsetScale
        opacity: 1 - root.offsetScale
        color: Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant
        radius: Theme.Style.panelRadius
        clip: true
        focus: root.monitorContext.sidebarOpened
        Keys.onEscapePressed: root.monitorContext.closeSidebar()
        MouseArea {
            anchors.fill: parent
            onClicked: event => event.accepted = true
        }

        Flickable {
            id: viewport
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingLarge
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: contentColumn
                width: viewport.width
                spacing: Theme.Style.spacingMedium

                RowLayout {
                    id: panelHeader
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall

                    QuickAction {
                        visible: root.quickPage !== ""
                        iconName: "arrow_back"
                        tooltip: "Volver"
                        onClicked: root.closePage()
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.Style.radiusFull
                        color: Theme.Color.primaryContainer
                        Theme.MaterialIcon {
                            anchors.centerIn: parent
                            text: root.quickPage === "" ? "tune" : "settings_input_component"
                            iconSize: Theme.Style.materialIconMedium
                            iconColor: Theme.Color.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.pageTitle()
                            color: Theme.Color.foreground
                            font.pixelSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.quickPage === "" ? Qt.formatDate(root.today, "dddd, d MMMM") : "Controles del sistema"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    QuickAction {
                        iconName: "close"
                        tooltip: "Cerrar"
                        onClicked: root.monitorContext.closeSidebar()
                    }
                }

                Loader {
                    id: pageLoader
                    visible: root.quickPage !== ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    sourceComponent: root.quickPage === "wifi" ? wifiPage
                        : root.quickPage === "bluetooth" ? bluetoothPage
                        : root.quickPage === "audio" ? audioPage
                        : root.quickPage === "microphone" ? microphonePage
                        : root.quickPage === "dnd" ? dndPage
                        : root.quickPage === "night" ? nightPage
                        : root.quickPage === "power" ? powerPage
                        : null
                }

                RowLayout {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall
                    Item {
                        Layout.fillWidth: true
                    }
                    QuickAction {
                        iconName: "lock"
                        tooltip: "Bloquear"
                        onClicked: Services.PowerService.lock()
                    }
                    QuickAction {
                        iconName: "restart_alt"
                        tooltip: "Reiniciar"
                        onClicked: Services.PowerService.reboot()
                    }
                    QuickAction {
                        iconName: "power_settings_new"
                        tooltip: "Apagar"
                        onClicked: Services.PowerService.shutdown()
                    }
                }

                SectionLabel {
                    visible: root.quickPage === ""
                    label: "Connect"
                }

                GridLayout {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Theme.Style.spacingSmall
                    columnSpacing: Theme.Style.spacingSmall
                    QuickTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: "wifi"
                        title: "Wi‑Fi"
                        subtitle: root.wifiSubtitle
                        active: Boolean(root.net?.wifiEnabled && root.net?.connected)
                        iconOnlyToggle: true
                        showDetails: true
                        onClicked: if (root.net)
                            root.net.setWifiEnabled(!root.net.wifiEnabled)
                        onDetailsClicked: root.openAdvanced("wifi")
                    }
                    QuickTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: "bluetooth"
                        title: "Bluetooth"
                        subtitle: root.bluetoothSubtitle
                        active: Boolean(root.bt?.enabled)
                        iconOnlyToggle: true
                        showDetails: true
                        onClicked: if (root.bt)
                            root.bt.setEnabled(!root.bt.enabled)
                        onDetailsClicked: root.openAdvanced("bluetooth")
                    }
                }

                Rectangle {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 152
                    radius: Theme.Style.cardRadius
                    color: Theme.Color.primaryContainer
                    border.width: Theme.Style.panelBorderWidth
                    border.color: Theme.Color.outlineVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingXs
                        Text {
                            text: Services.WeatherService.location || "Clima"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Services.WeatherService.current ? Services.WeatherService.current.temp + "°" : "--°"
                            color: Theme.Color.foreground
                            font.pixelSize: 30
                            font.bold: true
                        }
                        Text {
                            text: Services.WeatherService.current ? Services.WeatherService.description(Services.WeatherService.current.code) : Services.WeatherService.loading ? "Consultando…" : "Sin datos"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        QsButton {
                            Layout.alignment: Qt.AlignLeft
                            text: "Actualizar"
                            enabled: !Services.WeatherService.loading
                            onClicked: Services.WeatherService.refresh(true)
                        }
                    }
                }

                SectionLabel {
                    visible: root.quickPage === ""
                    label: "Sound & display"
                }

                Repeater {
                    visible: root.quickPage === ""
                    model: root.brightness?.monitors || []
                    delegate: SliderCard {
                        required property var modelData
                        visible: root.quickPage === ""
                        title: modelData.name || "Pantalla"
                        icon: "brightness_6"
                        value: (modelData.brightnessPercent || 0) / 100
                        enabled: Boolean(modelData.available)
                        showDetails: false
                        onMoved: value => modelData.setBrightness(value * (modelData.maxBrightness || 100), 350)
                    }
                }

                SliderCard {
                    visible: root.quickPage === ""
                    title: root.audio?.outputName || "Sonido"
                    icon: root.audio?.muted ? "volume_off" : "volume_up"
                    value: root.volume
                    enabled: Boolean(root.audio?.available)
                    onMoved: value => root.audio?.setVolume(value)
                    onClicked: root.audio?.toggleMute()
                    showDetails: true
                    onDetailsClicked: root.openAdvanced("audio")
                }

                SliderCard {
                    visible: root.quickPage === ""
                    title: root.audio?.inputDisplayName(root.mic) || "Micrófono"
                    icon: root.mic?.audio?.muted ? "mic_off" : "mic"
                    value: root.mic?.audio?.volume ?? 0
                    enabled: Boolean(root.mic?.audio)
                    onMoved: value => {
                        if (root.mic?.audio)
                            root.mic.audio.volume = value
                    }
                    onClicked: {
                        if (root.mic?.audio)
                            root.mic.audio.muted = !root.mic.audio.muted
                    }
                    showDetails: true
                    onDetailsClicked: root.openAdvanced("microphone")
                }

                GridLayout {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Theme.Style.spacingSmall
                    columnSpacing: Theme.Style.spacingSmall
                    QuickTile {
                        Layout.fillWidth: true
                        title: "Mantener despierto"
                        subtitle: Services.QuickSettingsService.keepAwake ? "Activado" : "Desactivado"
                        icon: "coffee"
                        active: Services.QuickSettingsService.keepAwake
                        onClicked: Services.QuickSettingsService.toggleKeepAwake()
                    }
                    QuickTile {
                        Layout.fillWidth: true
                        title: "Modo gaming"
                        subtitle: Services.QuickSettingsService.gaming ? "Activado" : "Desactivado"
                        icon: "sports_esports"
                        active: Services.QuickSettingsService.gaming
                        onClicked: Services.QuickSettingsService.toggleGaming()
                    }
                    QuickTile {
                        Layout.fillWidth: true
                        title: "Modo nocturno"
                        subtitle: Services.QuickSettingsService.nightAvailable
                            ? Services.QuickSettingsService.night ? "Activado" : "Desactivado"
                            : "No disponible"
                        icon: "nightlight"
                        active: Services.QuickSettingsService.night
                        onClicked: Services.QuickSettingsService.toggleNight()
                    }
                    QuickTile {
                        Layout.fillWidth: true
                        title: "Modo avión"
                        subtitle: root.net?.wifiEnabled ? "Desactivado" : "Activado"
                        icon: "flight"
                        active: !root.net?.wifiEnabled
                        onClicked: {
                            if (root.net)
                                root.net.setWifiEnabled(!root.net.wifiEnabled)
                        }
                    }
                }

                SectionLabel {
                    visible: root.quickPage === ""
                    label: "Media"
                }

                Rectangle {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    implicitHeight: 94
                    radius: Theme.Style.cardRadius
                    color: Theme.Color.surfaceContainer
                    border.width: Theme.Style.panelBorderWidth
                    border.color: Theme.Color.outlineVariant

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingMedium
                        Rectangle {
                            Layout.preferredWidth: 62
                            Layout.fillHeight: true
                            radius: Theme.Style.controlRadius
                            color: Theme.Color.surfaceContainerHigh
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: Services.MediaService.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Theme.MaterialIcon {
                                anchors.centerIn: parent
                                text: "music_note"
                                iconSize: Theme.Style.materialIconLarge
                                iconColor: Theme.Color.foregroundMuted
                                visible: !Services.MediaService.artUrl
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Theme.Style.spacingXs
                            Text {
                                text: Services.MediaService.available ? Services.MediaService.title : "Sin reproducción"
                                color: Theme.Color.foreground
                                font.pixelSize: Theme.Style.fontSmall
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Services.MediaService.available ? Services.MediaService.artist : "Sung"
                                color: Theme.Color.foregroundMuted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                QuickAction {
                                    iconName: "skip_previous"
                                    enabled: Services.MediaService.canPrevious
                                    onClicked: Services.MediaService.command("previous")
                                }
                                QuickAction {
                                    iconName: Services.MediaService.playing ? "pause" : "play_arrow"
                                    enabled: Services.MediaService.canToggle
                                    onClicked: Services.MediaService.command("play-pause")
                                }
                                QuickAction {
                                    iconName: "skip_next"
                                    enabled: Services.MediaService.canNext
                                    onClicked: Services.MediaService.command("next")
                                }
                            }
                        }
                    }
                }

                CaptureCard {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    monitorName: root.monitorScreen.name
                }

                SectionLabel {
                    visible: root.quickPage === ""
                    label: "Calendar"
                }

                Rectangle {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    implicitHeight: 236
                    radius: Theme.Style.cardRadius
                    color: Theme.Color.surfaceContainer
                    border.width: Theme.Style.panelBorderWidth
                    border.color: Theme.Color.outlineVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingSmall
                        RowLayout {
                            Layout.fillWidth: true
                            QsButton {
                                text: "‹"
                                compact: true
                                onClicked: root.moveMonth(-1)
                            }
                            Text {
                                text: root.monthTitle()
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                color: Theme.Color.foreground
                                font.bold: true
                                font.pixelSize: Theme.Style.fontSmall
                            }
                            QsButton {
                                text: "›"
                                compact: true
                                onClicked: root.moveMonth(1)
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            columnSpacing: 3
                            rowSpacing: 3
                            Repeater {
                                model: ["L", "M", "X", "J", "V", "S", "D"]
                                delegate: Text {
                                    required property string modelData
                                    text: modelData
                                    color: Theme.Color.foregroundMuted
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                            }
                            Repeater {
                                model: root.calendarCells()
                                delegate: Rectangle {
                                    id: dayCell
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Theme.Style.radiusSmall
                                    color: modelData.current ? Theme.Color.primary : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.modelData.day
                                        color: dayCell.modelData.current ? Theme.Color.onPrimary : Theme.Color.foreground
                                        font.pixelSize: 11
                                    }
                                    Rectangle {
                                        visible: dayCell.modelData.event && !dayCell.modelData.current
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: Theme.Color.primary
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    visible: root.quickPage === ""
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall
                    QuickTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: "notifications"
                        title: "Notificaciones"
                        subtitle: Services.NotificationService.dnd ? "No molestar" : "Activas"
                        active: !Services.NotificationService.dnd
                        onClicked: Services.NotificationService.toggleDnd()
                    }
                    QuickTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        icon: "logout"
                        title: "Sesión"
                        subtitle: "Cerrar sesión"
                        onClicked: Services.PowerService.logout()
                    }
                }
            }
        }
    }

    component QuickAction: ToolButton {
        id: action
        property string iconName: ""
        property string tooltip: ""
        implicitWidth: 34
        implicitHeight: 34
        padding: 0
        display: AbstractButton.IconOnly
        ToolTip.visible: hovered && action.tooltip !== ""
        ToolTip.text: action.tooltip
        contentItem: Theme.MaterialIcon {
            text: action.iconName
            iconSize: Theme.Style.materialIconSmall
            iconColor: action.enabled ? Theme.Color.foreground : Theme.Color.foregroundMuted
        }
        background: Rectangle {
            radius: Theme.Style.radiusFull
            color: action.hovered ? Theme.Color.surfaceHover : "transparent"
        }
    }

    component CaptureCard: Rectangle {
        id: captureCard
        property string monitorName: ""
        readonly property bool recording: Services.RecorderService.active
        Layout.fillWidth: true
        implicitHeight: 158
        radius: Theme.Style.cardRadius
        color: Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant

        FolderListModel {
            id: recentShots
            folder: "file://" + Services.CaptureService.screenshotsDir
            nameFilters: ["*.png"]
            showDirs: false
            sortField: FolderListModel.Time
            sortReversed: true
        }

    function capture(mode) {
        root.monitorContext.closeSidebar()
        Services.CaptureService.launch(mode)
        }

        function toggleRecording() {
            root.monitorContext.closeSidebar()
            if (captureCard.recording)
                Services.RecorderService.stop()
            else
                Services.RecorderService.start(captureCard.monitorName)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingMedium
            spacing: Theme.Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Capturas"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: captureCard.recording
                        ? Services.RecorderService.displayTime
                        : Services.CaptureService.editorAvailable ? "Editor" : "Captura básica"
                    color: captureCard.recording ? Theme.Color.error : Theme.Color.foregroundMuted
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.Style.spacingSmall
                QsButton {
                    Layout.fillWidth: true
                    text: "Área"
                    enabled: !Services.CaptureService.busy && !captureCard.recording
                    onClicked: captureCard.capture("area")
                }
                QsButton {
                    Layout.fillWidth: true
                    text: "Monitor"
                    enabled: !Services.CaptureService.busy && !captureCard.recording
                    onClicked: captureCard.capture("monitor")
                }
                QsButton {
                    Layout.fillWidth: true
                    text: captureCard.recording ? "Detener" : "Grabar"
                    enabled: captureCard.recording || Services.RecorderService.available
                    onClicked: captureCard.toggleRecording()
                }
                QsButton {
                    Layout.fillWidth: true
                    text: "Ajustes"
                    enabled: !captureCard.recording
                    onClicked: {
                        root.monitorContext.closeSidebar()
                        root.shellState.openControlCenterPage(17)
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                spacing: Theme.Style.spacingSmall
                Repeater {
                    model: Math.min(recentShots.count, 4)
                    delegate: Rectangle {
                        required property int index
                        width: (captureCard.width - Theme.Style.paddingMedium * 2 - Theme.Style.spacingSmall * 3) / 4
                        height: 54
                        radius: Theme.Style.controlRadius
                        color: Theme.Color.surfaceContainerHigh
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: recentShots.get(index, "fileUrl")
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wifiPage
        ColumnLayout {
            width: pageLoader.width
            spacing: Theme.Style.spacingSmall
            PageCard {
                title: "Redes Wi‑Fi"
                icon: "wifi"
                subtitle: root.wifiSubtitle
                PageToggle {
                    label: "Wi‑Fi"
                    icon: "wifi"
                    active: Boolean(root.net?.wifiEnabled)
                    onClicked: if (root.net) root.net.setWifiEnabled(!root.net.wifiEnabled)
                }
                QsButton {
                    text: root.net?.scanning ? "Detener búsqueda" : "Buscar redes"
                    enabled: Boolean(root.net?.wifiEnabled)
                    onClicked: if (root.net) root.net.setScanning(!root.net.scanning)
                }
                Text {
                    visible: Boolean(root.net?.scanning)
                    text: "Buscando redes…"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    Layout.fillWidth: true
                }
                Repeater {
                    model: root.net?.networks || []
                    delegate: PageRow {
                        required property var modelData
                        name: modelData.ssid || "Red sin nombre"
                        detail: modelData.connected ? "Conectado · " + modelData.strength + "%" : (modelData.secured ? "Protegida · " : "Abierta · ") + modelData.strength + "%"
                        active: modelData.connected
                        onClicked: if (root.net) modelData.connected ? root.net.disconnect() : root.net.connectNetwork(modelData)
                    }
                }
                Text {
                    visible: Boolean(root.net?.wifiEnabled && !root.net?.scanning && (root.net?.networks || []).length === 0)
                    text: "No se encontraron redes"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: bluetoothPage
        ColumnLayout {
            width: pageLoader.width
            spacing: Theme.Style.spacingSmall
            PageCard {
                title: "Dispositivos Bluetooth"
                icon: "bluetooth"
                subtitle: root.bt?.enabled ? "Bluetooth activado" : "Bluetooth desactivado"
                PageToggle {
                    label: "Bluetooth"
                    icon: "bluetooth"
                    active: Boolean(root.bt?.enabled)
                    onClicked: if (root.bt) root.bt.setEnabled(!root.bt.enabled)
                }
                QsButton {
                    text: root.bt?.discovering ? "Detener búsqueda" : "Buscar dispositivos"
                    enabled: Boolean(root.bt?.enabled)
                    onClicked: if (root.bt) root.bt.discovering ? root.bt.stopScan() : root.bt.startScan()
                }
                Repeater {
                    model: root.bt?.devices || []
                    delegate: PageRow {
                        required property var modelData
                        name: modelData.name || "Dispositivo Bluetooth"
                        detail: modelData.connected ? "Conectado" : modelData.connecting ? "Conectando…" : modelData.paired ? "Emparejado" : "Disponible"
                        active: modelData.connected
                        onClicked: if (root.bt && !modelData.connecting && !modelData.disconnecting) modelData.connected ? root.bt.disconnectDevice(modelData) : root.bt.connectDevice(modelData)
                    }
                }
                Text {
                    visible: Boolean(root.bt?.enabled && !root.bt?.discovering && (root.bt?.devices || []).length === 0)
                    text: "No se encontraron dispositivos"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: audioPage
        ColumnLayout {
            width: pageLoader.width
            spacing: Theme.Style.spacingSmall
            PageCard {
                title: "Salida de audio"
                icon: "volume_up"
                subtitle: root.audio?.outputName || "Salida predeterminada"
                Repeater {
                    model: root.audio?.outputsModel || []
                    delegate: PageRow {
                        required property var modelData
                        name: root.audio.outputDisplayName(modelData)
                        detail: modelData === Pipewire.defaultAudioSink ? "Activo" : "Disponible"
                        active: modelData === Pipewire.defaultAudioSink
                        onClicked: root.audio.selectOutput(modelData)
                    }
                }
                PageSlider {
                    label: "Volumen principal"
                    icon: "volume_up"
                    value: root.audio?.volume ?? 0
                    enabled: Boolean(root.audio?.available)
                    onMoved: if (root.audio) root.audio.setVolume(value)
                }
                PageToggle {
                    label: "Silenciar salida"
                    icon: "volume_off"
                    active: Boolean(root.audio?.muted)
                    onClicked: if (root.audio) root.audio.toggleMute()
                }
            }
        }
    }

    Component {
        id: microphonePage
        ColumnLayout {
            width: pageLoader.width
            spacing: Theme.Style.spacingSmall
            PageCard {
                title: "Micrófono"
                icon: "mic"
                subtitle: root.mic?.description || root.mic?.name || "Entrada predeterminada"
                Repeater {
                    model: root.audio?.inputsModel || []
                    delegate: PageRow {
                        required property var modelData
                        name: root.audio.inputDisplayName(modelData)
                        detail: modelData === Pipewire.defaultAudioSource ? "Activo" : "Disponible"
                        active: modelData === Pipewire.defaultAudioSource
                        onClicked: root.audio.selectInput(modelData)
                    }
                }
                PageSlider {
                    label: "Volumen del micrófono"
                    icon: "mic"
                    value: root.mic?.audio?.volume ?? 0
                    enabled: Boolean(root.mic?.audio)
                    onMoved: if (root.mic?.audio) root.mic.audio.volume = value
                }
                PageToggle {
                    label: "Silenciar micrófono"
                    icon: "mic_off"
                    active: Boolean(root.mic?.audio?.muted)
                    onClicked: if (root.mic?.audio) root.mic.audio.muted = !root.mic.audio.muted
                }
            }
        }
    }

    Component {
        id: dndPage
        ColumnLayout {
            width: pageLoader.width
            PageCard {
                title: "No molestar"
                icon: "notifications_off"
                subtitle: "Silencia las notificaciones emergentes"
                PageToggle {
                    label: "No molestar"
                    icon: "notifications_off"
                    active: Services.NotificationService.dnd
                    onClicked: Services.NotificationService.toggleDnd()
                }
            }
        }
    }

    Component {
        id: nightPage
        ColumnLayout {
            width: pageLoader.width
            PageCard {
                title: "Modo nocturno"
                icon: "nightlight"
                subtitle: Services.QuickSettingsService.nightAvailable ? "Temperatura de pantalla" : "Backend no disponible"
                Text {
                    visible: !Services.QuickSettingsService.nightAvailable
                    text: "Instala hyprsunset, wlsunset o gammastep para activar este control."
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                PageSlider {
                    label: "Temperatura · " + Services.QuickSettingsState.nightTemperature + " K"
                    icon: "thermostat"
                    value: (Services.QuickSettingsState.nightTemperature - 2500) / 4000
                    enabled: Services.QuickSettingsService.nightAvailable
                    onMoved: Services.QuickSettingsState.setNightTemperature(2500 + value * 4000)
                }
                PageToggle {
                    label: "Filtro de luz azul"
                    icon: "nightlight"
                    active: Services.QuickSettingsService.night
                    onClicked: Services.QuickSettingsService.toggleNight()
                }
            }
        }
    }

    Component {
        id: powerPage
        ColumnLayout {
            width: pageLoader.width
            PageCard {
                title: "Energía y sesión"
                icon: "power_settings_new"
                subtitle: "Acciones de esta sesión"
                RowLayout {
                    Layout.fillWidth: true
                    QsButton { text: "Bloquear"; Layout.fillWidth: true; onClicked: Services.PowerService.lock() }
                    QsButton { text: "Cerrar sesión"; Layout.fillWidth: true; onClicked: Services.PowerService.logout() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    QsButton { text: "Suspender"; Layout.fillWidth: true; onClicked: Services.PowerService.suspend() }
                    QsButton { text: "Reiniciar"; Layout.fillWidth: true; onClicked: Services.PowerService.reboot() }
                    QsButton { text: "Apagar"; Layout.fillWidth: true; onClicked: Services.PowerService.shutdown() }
                }
            }
        }
    }

    component SectionLabel: Text {
        id: sectionLabel
        property string label: ""
        text: "· " + sectionLabel.label.toUpperCase()
        color: Theme.Color.foregroundMuted
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.2
        Layout.fillWidth: true
        Layout.topMargin: Theme.Style.spacingSmall
    }

    component PageCard: Rectangle {
        id: pageCard
        property string title: ""
        property string subtitle: ""
        property string icon: ""
        default property alias content: pageBody.data
        Layout.fillWidth: true
        implicitHeight: pageBody.implicitHeight + Theme.Style.paddingMedium * 2
        radius: Theme.Style.cardRadius
        color: Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant
        ColumnLayout {
            id: pageBody
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingMedium
            spacing: Theme.Style.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                Theme.MaterialIcon { text: pageCard.icon; iconSize: Theme.Style.sectionIconSize; iconColor: Theme.Color.primary }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: pageCard.title; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true; Layout.fillWidth: true }
                    Text { text: pageCard.subtitle; color: Theme.Color.foregroundMuted; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }

    component PageRow: Rectangle {
        id: pageRow
        property string name: ""
        property string detail: ""
        property bool active: false
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Theme.Style.controlRadius
        color: pageRow.active ? Theme.Color.primaryContainer : Theme.Color.surface
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingSmall
            Theme.MaterialIcon { text: pageRow.active ? "check_circle" : "radio_button_unchecked"; iconSize: Theme.Style.materialIconMedium; iconColor: pageRow.active ? Theme.Color.primary : Theme.Color.foregroundMuted }
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: pageRow.name; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                Text { text: pageRow.detail; color: Theme.Color.foregroundMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Theme.MaterialIcon { text: "chevron_right"; iconSize: Theme.Style.materialIconSmall; iconColor: Theme.Color.foregroundMuted }
        }
        TapHandler { onTapped: pageRow.clicked() }
    }

    component PageToggle: Rectangle {
        id: pageToggle
        property string label: ""
        property string icon: ""
        property bool active: false
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 42
        radius: Theme.Style.controlRadius
        color: pageToggle.active ? Theme.Color.primaryContainer : Theme.Color.surface
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingSmall
            Theme.MaterialIcon { text: pageToggle.icon; iconSize: Theme.Style.materialIconMedium; iconColor: pageToggle.active ? Theme.Color.primary : Theme.Color.foregroundMuted }
            Text { text: pageToggle.label; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
            Theme.MaterialIcon { text: pageToggle.active ? "toggle_on" : "toggle_off"; iconSize: Theme.Style.materialIconMedium; iconColor: pageToggle.active ? Theme.Color.primary : Theme.Color.foregroundMuted }
        }
        TapHandler { onTapped: pageToggle.clicked() }
    }

    component PageSlider: ColumnLayout {
        id: pageSlider
        property string label: ""
        property string icon: ""
        property real value: 0
        property bool enabled: true
        signal moved(real value)
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            Theme.MaterialIcon { text: pageSlider.icon; iconSize: Theme.Style.materialIconSmall; iconColor: Theme.Color.foregroundMuted }
            Text { text: pageSlider.label; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
            Text { text: Math.round(pageSlider.value * 100) + "%"; color: Theme.Color.foregroundMuted; font.pixelSize: Theme.Style.fontSmall }
        }
        Slider {
            id: pageSliderControl
            Layout.fillWidth: true
            enabled: pageSlider.enabled
            from: 0
            to: 1
            value: pageSlider.value
            onMoved: pageSlider.moved(value)
            background: Rectangle {
                x: pageSliderControl.leftPadding
                y: pageSliderControl.topPadding + (pageSliderControl.availableHeight - height) / 2
                width: pageSliderControl.availableWidth
                height: 6
                radius: 3
                color: Theme.Color.outlineVariant
                Rectangle { width: pageSliderControl.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.Color.primary }
            }
            handle: Rectangle {
                x: pageSliderControl.leftPadding + pageSliderControl.visualPosition * (pageSliderControl.availableWidth - width)
                y: pageSliderControl.topPadding + pageSliderControl.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: pageSliderControl.pressed ? Theme.Color.primary : Theme.Color.primaryContainer
                border.width: 2
                border.color: pageSliderControl.enabled ? Theme.Color.primary : Theme.Color.outlineVariant
            }
        }
    }

    component QsButton: Button {
        id: qsButton
        property bool compact: false
        implicitWidth: compact ? 30 : Math.max(84, contentItem.implicitWidth + Theme.Style.paddingMedium * 2)
        implicitHeight: compact ? 30 : 32
        padding: 0
        contentItem: Text {
            text: qsButton.text
            color: qsButton.enabled ? Theme.Color.foreground : Theme.Color.foregroundMuted
            font.pixelSize: Theme.Style.fontSmall
            font.bold: !qsButton.compact
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Theme.Style.radiusFull
            color: qsButton.pressed ? Theme.Color.primary : qsButton.hovered ? Theme.Color.surfaceHover : Theme.Color.surfaceContainerHigh
            border.width: 1
            border.color: qsButton.pressed ? Theme.Color.primary : Theme.Color.outlineVariant
            opacity: qsButton.enabled ? 1 : 0.55
            Behavior on color {
                ColorAnimation {
                    duration: Theme.Style.motionFast
                }
            }
        }
    }

    component QuickTile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool iconOnlyToggle: false
        property bool showDetails: false
        signal clicked
        signal detailsClicked
        implicitHeight: 64
        radius: Theme.Style.cardRadius
        color: tile.active ? Theme.Color.primaryContainer : Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: tile.active ? Theme.Color.primary : Theme.Color.outlineVariant
        Behavior on color {
            ColorAnimation {
                duration: Theme.Style.motionFast
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingSmall
            spacing: Theme.Style.spacingSmall
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Theme.Style.radiusFull
                color: tile.active ? Theme.Color.primary : Theme.Color.surfaceContainerHigh
                Theme.MaterialIcon {
                    anchors.centerIn: parent
                    text: tile.icon
                    iconSize: Theme.Style.materialIconSmall
                    iconColor: tile.active ? Theme.Color.onPrimary : Theme.Color.foregroundMuted
                }
                TapHandler {
                    enabled: tile.iconOnlyToggle
                    onTapped: tile.clicked()
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                Text {
                    text: tile.title
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: tile.subtitle
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Theme.MaterialIcon {
                visible: tile.showDetails
                text: "chevron_right"
                iconSize: Theme.Style.materialIconSmall
                iconColor: Theme.Color.foregroundMuted
            }
        }
        TapHandler {
            onTapped: point => {
                // The trailing chevron is a separate navigation target. Do
                // not let its click bubble into the tile toggle action.
                if (tile.showDetails && point.position.x >= tile.width - 46)
                    tile.detailsClicked()
                else if (!tile.iconOnlyToggle)
                    tile.clicked()
            }
        }
    }

    component SliderCard: Rectangle {
        id: sliderCard
        property string title: ""
        property string icon: ""
        property real value: 0
        property bool showDetails: false
        signal moved(real value)
        signal clicked
        signal detailsClicked
        Layout.fillWidth: true
        implicitHeight: 78
        radius: Theme.Style.cardRadius
        color: Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: Theme.Color.outlineVariant
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingMedium
            spacing: Theme.Style.spacingSmall
            QuickAction {
                iconName: sliderCard.icon
                tooltip: "Control de " + sliderCard.title
                onClicked: sliderCard.clicked()
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: sliderCard.title
                    elide: Text.ElideRight
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                    font.bold: true
                }
                Slider {
                    id: slider
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 28
                    enabled: sliderCard.enabled
                    from: 0
                    to: 1
                    value: sliderCard.value
                    onMoved: sliderCard.moved(value)
                    background: Rectangle {
                        x: slider.leftPadding
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: slider.availableWidth
                        height: 5
                        radius: 3
                        color: Theme.Color.surfaceContainerHigh
                        Rectangle {
                            width: slider.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: slider.enabled ? Theme.Color.primary : Theme.Color.outlineVariant
                        }
                    }
                    handle: Rectangle {
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: slider.pressed ? Theme.Color.primary : Theme.Color.primaryContainer
                        border.width: 2
                        border.color: slider.enabled ? Theme.Color.primary : Theme.Color.outlineVariant
                        scale: slider.pressed ? 1.12 : slider.hovered ? 1.06 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.Style.motionFast
                            }
                        }
                    }
                }
            }
            QuickAction {
                visible: sliderCard.showDetails
                iconName: "chevron_right"
                tooltip: "Más opciones"
                onClicked: sliderCard.detailsClicked()
            }
            Text {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: sliderCard.enabled ? Math.round(sliderCard.value * 100) + "%" : "—"
                color: Theme.Color.foregroundMuted
                font.pixelSize: 12
            }
        }
    }
}
