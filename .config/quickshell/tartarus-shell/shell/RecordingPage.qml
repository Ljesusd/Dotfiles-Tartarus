import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../services" as Services
import "../theme" as Theme

Flickable {
    id: root

    required property var settings
    required property var recorder
    property bool active: false
    property color backgroundColor: Theme.Color.background
    property color surfaceColor: Theme.Color.surfaceContainer
    property color surfaceHighColor: Theme.Color.surfaceContainerHigh
    property color hoverColor: Theme.Color.surfaceHover
    property color accentColor: Theme.Color.primary
    property color textColor: Theme.Color.foreground
    property color mutedColor: Theme.Color.foregroundMuted

    property var draft: ({})
    property bool dirty: false
    property string message: ""
    property bool messageError: false

    contentWidth: width
    contentHeight: body.implicitHeight + Theme.Style.paddingLarge * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    readonly property var screenNames: {
        return Quickshell.screens
            .filter(screen => screen && screen.name && screen.name !== "FALLBACK"
                && screen.width > 0 && screen.height > 0)
            .map(screen => screen.name)
    }
    readonly property var screenOptions: root.screenNames.length > 0
        ? root.screenNames : ["Sin monitor"]
    readonly property var fpsOptions: [24, 30, 60, 120]
    readonly property var modeOptions: [
        { value: "cfr", label: "CFR · constante" },
        { value: "vfr", label: "VFR · variable" },
        { value: "content", label: "Contenido" }
    ]
    readonly property var qualityOptions: [
        { value: "very_high", label: "Muy alta" },
        { value: "high", label: "Alta" },
        { value: "medium", label: "Media" },
        { value: "ultra", label: "Ultra" }
    ]
    readonly property var codecOptions: [
        { value: "h264", label: "H.264 · compatible" },
        { value: "hevc", label: "HEVC" },
        { value: "av1", label: "AV1" },
        { value: "vp8", label: "VP8" },
        { value: "vp9", label: "VP9" }
    ]
    readonly property var encoderOptions: [
        { value: "gpu", label: "GPU · recomendado" },
        { value: "cpu", label: "CPU" }
    ]

    function resetDraft() {
        root.draft = root.settings.snapshot()
        root.dirty = false
        root.message = ""
        root.messageError = false
    }

    function setDraft(key, value) {
        const next = Object.assign({}, root.draft)
        next[key] = value
        root.draft = next
        root.dirty = true
        root.message = ""
    }

    function optionIndex(options, value) {
        const index = options.findIndex(option => option.value === value)
        return index >= 0 ? index : 0
    }

    function audioDevices(kind) {
        const fallback = kind === "output"
            ? { id: "default_output", label: "Salida predeterminada" }
            : { id: "default_input", label: "Micrófono predeterminado" }
        const values = (root.recorder.audioDevices || []).filter(device => {
            if (kind === "output")
                return device.id.startsWith("default_output") || device.id.startsWith("alsa_output")
            return device.id.startsWith("default_input") || device.id.startsWith("alsa_input")
        })
        const result = values.length > 0 ? values.slice() : [fallback]
        if (!result.some(device => device.id === fallback.id))
            result.unshift(fallback)
        return result
    }

    function audioLabels(kind) {
        return root.audioDevices(kind).map(device => device.label)
    }

    function audioIndex(kind, value) {
        const devices = root.audioDevices(kind)
        const index = devices.findIndex(device => device.id === value)
        return index >= 0 ? index : 0
    }

    function saveDraft() {
        root.settings.apply(root.draft)
        root.draft = root.settings.snapshot()
        root.dirty = false
        root.message = "Configuración guardada para la próxima grabación."
        root.messageError = false
    }

    function resetFactoryDraft() {
        root.draft = root.settings.defaults()
        root.dirty = true
        root.message = "Valores iniciales preparados; pulsa Guardar para aplicarlos."
        root.messageError = false
    }

    function selectRegion() {
        const selected = root.draft.monitorName || root.screenOptions[0]
        root.recorder.requestRegionSelection(selected)
    }

    function regionText() {
        const region = root.draft.region || {}
        if (Number(region.width) > 0 && Number(region.height) > 0)
            return Math.round(region.width) + " × " + Math.round(region.height)
                + " · " + (region.screen || "monitor")
        return "No hay una región guardada"
    }

    onVisibleChanged: {
        if (visible && !root.dirty)
            root.resetDraft()
    }

    onActiveChanged: {
        if (active && !root.dirty)
            root.resetDraft()
    }

    Component.onCompleted: root.resetDraft()

    Connections {
        target: root.recorder
        function onRegionSelected(screenName, x, y, width, height) {
            root.draft = Object.assign({}, root.draft, {
                captureMode: "region",
                monitorName: screenName,
                region: {
                    screen: screenName,
                    x: x,
                    y: y,
                    width: width,
                    height: height
                }
            })
            root.dirty = true
            root.message = "Región seleccionada. Guarda para usarla al iniciar."
            root.messageError = false
        }
        function onRegionSelectionCancelled() {
            root.message = "Selección cancelada."
            root.messageError = false
        }
    }

    ColumnLayout {
        id: body
        x: Theme.Style.paddingLarge
        y: Theme.Style.paddingLarge
        width: root.width - Theme.Style.paddingLarge * 2
        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: Theme.Style.spacingMedium
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.Style.radiusSmall
                color: Qt.alpha(root.accentColor, 0.18)
                border.width: 1
                border.color: Qt.alpha(root.accentColor, 0.55)
                Theme.MaterialIcon {
                    anchors.centerIn: parent
                    text: "fiber_manual_record"
                    iconSize: Theme.Style.materialIconLarge
                    iconColor: root.accentColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Grabación"; color: root.textColor; font.pixelSize: 27; font.bold: true }
                Text {
                    text: root.recorder.busy
                        ? "Hay una grabación activa · los cambios se aplican después"
                        : "Ajustes locales de vídeo, audio y salida"
                    color: root.mutedColor
                    font.pixelSize: Theme.Style.fontSmall
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        SettingCard {
            title: "Captura"
            icon: "crop_free"
            subtitle: root.draft.captureMode === "region"
                ? "Región personalizada"
                : "Monitor enfocado al iniciar"

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Fuente"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: captureModeBox
                    Layout.preferredWidth: 190
                    model: ["Monitor", "Región"]
                    currentIndex: root.draft.captureMode === "region" ? 1 : 0
                    onActivated: root.setDraft("captureMode", currentIndex === 1 ? "region" : "monitor")
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: captureModeBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: captureModeBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Monitor"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: monitorBox
                    Layout.preferredWidth: 190
                    model: root.screenOptions
                    currentIndex: Math.max(0, root.screenOptions.indexOf(root.draft.monitorName))
                    onActivated: root.setDraft("monitorName", root.screenOptions[currentIndex])
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: monitorBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: monitorBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                visible: root.draft.captureMode === "region"
                Layout.fillWidth: true
                Text { text: root.regionText(); color: root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                ActionButton { text: "Seleccionar región"; onClicked: root.selectRegion() }
            }

            Text {
                visible: root.draft.captureMode === "region"
                text: "El selector se abre sobre el monitor elegido. Esc cancela sin modificar la configuración."
                color: root.mutedColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        SettingCard {
            title: "Vídeo"
            icon: "movie"
            subtitle: "Calidad y codificación de gpu-screen-recorder"

            RowLayout {
                Layout.fillWidth: true
                Text { text: "FPS"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: fpsBox
                    Layout.preferredWidth: 190
                    model: root.fpsOptions.map(value => String(value))
                    currentIndex: Math.max(0, root.fpsOptions.indexOf(Number(root.draft.fps)))
                    onActivated: root.setDraft("fps", root.fpsOptions[currentIndex])
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: fpsBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: fpsBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Framerate"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: modeBox
                    Layout.preferredWidth: 190
                    model: root.modeOptions.map(option => option.label)
                    currentIndex: root.optionIndex(root.modeOptions, root.draft.framerateMode)
                    onActivated: root.setDraft("framerateMode", root.modeOptions[currentIndex].value)
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: modeBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: modeBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Calidad"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: qualityBox
                    Layout.preferredWidth: 190
                    model: root.qualityOptions.map(option => option.label)
                    currentIndex: root.optionIndex(root.qualityOptions, root.draft.quality)
                    onActivated: root.setDraft("quality", root.qualityOptions[currentIndex].value)
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: qualityBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: qualityBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Códec"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: codecBox
                    Layout.preferredWidth: 190
                    model: root.codecOptions.map(option => option.label)
                    currentIndex: root.optionIndex(root.codecOptions, root.draft.codec)
                    onActivated: root.setDraft("codec", root.codecOptions[currentIndex].value)
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: codecBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: codecBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Encoder"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true }
                ComboBox {
                    id: encoderBox
                    Layout.preferredWidth: 190
                    model: root.encoderOptions.map(option => option.label)
                    currentIndex: root.optionIndex(root.encoderOptions, root.draft.encoder)
                    onActivated: root.setDraft("encoder", root.encoderOptions[currentIndex].value)
                    contentItem: Text { leftPadding: 12; rightPadding: 28; text: encoderBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: encoderBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }
            }

            ToggleRow {
                label: "Mostrar cursor"
                detail: root.draft.cursor ? "El puntero se incluye en el vídeo" : "El puntero queda oculto"
                checked: root.draft.cursor === true
                onToggled: root.setDraft("cursor", checked)
            }
        }

        SettingCard {
            title: "Audio"
            icon: "graphic_eq"
            subtitle: "Desactivado por defecto para evitar capturas accidentales"

            ToggleRow {
                label: "Audio del sistema"
                detail: root.draft.desktopAudio ? "Se incluirá la salida seleccionada" : "No se grabará la salida"
                checked: root.draft.desktopAudio === true
                onToggled: root.setDraft("desktopAudio", checked)
            }

            ComboBox {
                id: outputAudioBox
                Layout.fillWidth: true
                enabled: root.draft.desktopAudio === true
                model: root.audioLabels("output")
                currentIndex: root.audioIndex("output", root.draft.desktopAudioDevice)
                onActivated: root.setDraft("desktopAudioDevice", root.audioDevices("output")[currentIndex].id)
                contentItem: Text { leftPadding: 12; rightPadding: 28; text: outputAudioBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: outputAudioBox.activeFocus ? 1 : 0; border.color: root.accentColor; opacity: outputAudioBox.enabled ? 1 : 0.5 }
            }

            ToggleRow {
                label: "Micrófono"
                detail: root.draft.microphone ? "Se incluirá la entrada seleccionada" : "No se grabará el micrófono"
                checked: root.draft.microphone === true
                onToggled: root.setDraft("microphone", checked)
            }

            ComboBox {
                id: inputAudioBox
                Layout.fillWidth: true
                enabled: root.draft.microphone === true
                model: root.audioLabels("input")
                currentIndex: root.audioIndex("input", root.draft.microphoneDevice)
                onActivated: root.setDraft("microphoneDevice", root.audioDevices("input")[currentIndex].id)
                contentItem: Text { leftPadding: 12; rightPadding: 28; text: inputAudioBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                background: Rectangle { radius: Theme.Style.controlRadius; color: root.surfaceHighColor; border.width: inputAudioBox.activeFocus ? 1 : 0; border.color: root.accentColor; opacity: inputAudioBox.enabled ? 1 : 0.5 }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: (root.recorder.audioDevices || []).length + " dispositivos detectados"; color: root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true }
                ActionButton { text: "Actualizar dispositivos"; onClicked: root.recorder.refreshAudioDevices() }
            }
        }

        SettingCard {
            title: "Salida"
            icon: "folder_open"
            subtitle: "Los vídeos se guardan localmente"

            TextField {
                id: outputField
                Layout.fillWidth: true
                text: root.draft.outputDirectory || ""
                placeholderText: "~/Videos/Recordings"
                color: root.textColor
                placeholderTextColor: root.mutedColor
                selectByMouse: true
                leftPadding: 12
                rightPadding: 12
                onTextEdited: root.setDraft("outputDirectory", text)
                background: Rectangle {
                    radius: Theme.Style.controlRadius
                    color: root.surfaceHighColor
                    border.width: outputField.activeFocus ? 1 : 0
                    border.color: root.accentColor
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.recorder.active ? "La grabación actual no cambiará de carpeta" : "Se creará automáticamente si no existe"; color: root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                ActionButton { text: "Usar carpeta de vídeos"; onClicked: root.setDraft("outputDirectory", root.settings.defaultOutputDirectory) }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Theme.Style.cardRadius
            color: root.dirty ? Qt.alpha(root.accentColor, 0.10) : root.surfaceColor
            border.width: 1
            border.color: root.dirty ? Qt.alpha(root.accentColor, 0.55) : Qt.alpha(root.accentColor, 0.18)
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingMedium
                spacing: Theme.Style.spacingSmall
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { text: root.dirty ? "Hay cambios sin guardar" : "Configuración guardada"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; font.bold: true }
                    Text { visible: root.message !== ""; text: root.message; color: root.messageError ? Theme.Color.error : root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                ActionButton { text: "Restablecer"; onClicked: root.resetFactoryDraft() }
                ActionButton { text: "Descartar"; enabled: root.dirty; onClicked: root.resetDraft() }
                ActionButton { text: "Guardar"; enabled: root.dirty; onClicked: root.saveDraft() }
            }
        }
    }

    component SettingCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string icon: "settings"
        default property alias content: cardBody.data
        Layout.fillWidth: true
        implicitHeight: cardBody.implicitHeight + Theme.Style.paddingMedium * 2
        radius: Theme.Style.cardRadius
        color: root.surfaceColor
        border.width: 1
        border.color: Qt.alpha(root.accentColor, 0.18)
        ColumnLayout {
            id: cardBody
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingLarge
            spacing: Theme.Style.spacingMedium
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.Style.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(root.accentColor, 0.42)
                    Theme.MaterialIcon { anchors.centerIn: parent; text: card.icon; iconSize: Theme.Style.sectionIconSize - 2; iconColor: root.accentColor }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: card.title; color: root.textColor; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { visible: card.subtitle !== ""; text: card.subtitle; color: root.mutedColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow
        property string label: ""
        property string detail: ""
        property bool checked: false
        signal toggled(bool value)
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: toggleRow.label; color: root.textColor; font.pixelSize: Theme.Style.fontSmall }
            Text { text: toggleRow.detail; color: root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Switch {
            id: toggle
            checked: toggleRow.checked
            onToggled: toggleRow.toggled(checked)
            indicator: Rectangle {
                x: toggle.leftPadding
                y: toggle.topPadding + (toggle.availableHeight - height) / 2
                implicitWidth: 44
                implicitHeight: 24
                radius: height / 2
                color: toggle.checked ? root.accentColor : root.surfaceHighColor
                border.width: 1
                border.color: toggle.checked ? root.accentColor : root.mutedColor
                Rectangle {
                    width: 18
                    height: 18
                    y: 2
                    x: toggle.checked ? parent.width - width - 3 : 3
                    radius: Theme.Style.radiusFull
                    color: toggle.checked ? root.backgroundColor : root.mutedColor
                }
            }
        }
    }

    component ActionButton: Button {
        id: button
        implicitHeight: 34
        implicitWidth: Math.max(96, contentItem.implicitWidth + 24)
        contentItem: Text {
            text: button.text
            color: button.down ? root.backgroundColor : button.enabled ? root.textColor : root.mutedColor
            font.pixelSize: Theme.Style.fontSmall
            font.bold: button.down
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.Style.radiusSmall
            color: button.down ? root.accentColor : button.hovered ? root.hoverColor : "transparent"
            border.width: 1
            border.color: button.down || button.hovered ? root.accentColor : Qt.alpha(root.accentColor, 0.42)
            opacity: button.enabled ? 1 : 0.5
            Behavior on color { ColorAnimation { duration: Theme.Style.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.Style.motionFast } }
        }
    }
}
