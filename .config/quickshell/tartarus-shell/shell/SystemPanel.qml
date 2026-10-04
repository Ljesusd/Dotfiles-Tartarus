import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../services" as Services
import "../theme"

Item {
    id: root
    required property var monitorScreen
    required property var pluginRegistry
    property color muted: Color.foregroundMuted
    property color accent: Color.primary
    property bool showHeading: true

    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: content
            width: Math.max(0, scroll.width - 12)
            spacing: Style.spacingMedium
            Text { visible: root.showHeading; text: "Centro de sistema"; color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true }
            Text { visible: root.showHeading; width: parent.width; wrapMode: Text.WordWrap; text: "Controles rápidos y estado del entorno"; color: muted; font.pixelSize: Style.fontSmall }

            Card { title: "CONEXIONES"; icon: "tune"
                Flow { width: parent.width; spacing: Style.spacingSmall
                    Repeater { model: [{l:"Wi-Fi",i:"wifi",k:"network"},{l:"Bluetooth",i:"bluetooth",k:"bluetooth"},{l:"No molestar",i:"notifications_off",k:"dnd"}]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var ns: root.pluginRegistry.plugin("network")?.service
                            readonly property var bs: root.pluginRegistry.plugin("bluetooth")?.service
                            readonly property bool active: modelData.k==="network" ? Boolean(ns?.wifiEnabled) : modelData.k==="bluetooth" ? Boolean(bs?.enabled) : Services.NotificationService.dnd
                            width: parent.width < 420
                                ? (parent.width - Style.spacingSmall) / 2
                                : (parent.width - Style.spacingSmall * 2) / 3
                            height: 72; radius: Style.cardRadius
                            color: active ? Color.primaryContainer : Color.surface
                            border.width: Style.panelBorderWidth
                            border.color: Color.outlineVariant
                            Column { anchors.centerIn: parent; spacing: 4
                                MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; text:modelData.i; iconSize:Style.materialIconMedium; iconColor:active?Color.onPrimaryContainer:muted }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text:modelData.l; color:active?Color.onPrimaryContainer:Color.foreground; font.pixelSize:Style.fontSmall }
                            }
                            TapHandler { onTapped: { if(modelData.k==="network"&&ns) ns.setWifiEnabled(!ns.wifiEnabled); else if(modelData.k==="bluetooth"&&bs) bs.setEnabled(!bs.enabled); else Services.NotificationService.toggleDnd() } }
                        }
                    }
                }
            }
            Card { title: "SONIDO Y PANTALLA"; icon: "tune"
                ControlRow { icon:"volume_up"; label:"Volumen"; value:Math.round((root.pluginRegistry.plugin("audio")?.service.volume??0)*100)+"%"
                    StyledSlider { Layout.fillWidth:true; from:0; to:1; value:root.pluginRegistry.plugin("audio")?.service.volume??0; onMoved:root.pluginRegistry.plugin("audio")?.service.setVolume(value) }
                }
                Text { text:"Aplicaciones"; color:muted; font.pixelSize:Style.fontSmall }
                Repeater {
                    model: root.audioService ? root.audioService.applicationGroupsModel : []
                    delegate: ColumnLayout {
                        id: streamRow
                        required property var modelData
                        width: parent.width
                        spacing:Style.spacingSmall
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth:true; Layout.minimumWidth:0; text:streamRow.modelData.name; color:Color.foreground; font.pixelSize:Style.fontSmall; elide:Text.ElideRight }
                            Text { text:Math.round(root.audioService.groupVolume(streamRow.modelData)*100)+"%"; color:muted; font.pixelSize:Style.fontSmall }
                            ActionButton { enabled:streamRow.modelData.nodes.length > 0; text:root.audioService.groupMuted(streamRow.modelData) ? "Activar" : "Silenciar"; onClicked:root.audioService.toggleGroupMute(streamRow.modelData) }
                        }
                        StyledSlider { Layout.fillWidth:true; enabled:streamRow.modelData.nodes.length > 0; from:0; to:1; value:root.audioService.groupVolume(streamRow.modelData); onMoved:root.audioService.setGroupVolume(streamRow.modelData,value) }
                    }
                }
                ControlRow { icon:"brightness_6"; label:"Brillo"; value:(root.pluginRegistry.plugin("brightness")?.service.brightnessPercentForScreen(root.monitorScreen)??0)+"%"
                    StyledSlider { Layout.fillWidth:true; from:0; to:100; value:root.pluginRegistry.plugin("brightness")?.service.brightnessPercentForScreen(root.monitorScreen)??0; onMoved:{var s=root.pluginRegistry.plugin("brightness")?.service;if(s&&s.availableForScreen(root.monitorScreen)){var m=s.monitorForScreen(root.monitorScreen)?.maxBrightness??100;s.setBrightnessForScreen(root.monitorScreen,value*m/100,350)}}}
                }
            }
            Card { title:"RED"; icon:"wifi"
                Stat { label:"Estado"; value: networkService?.connected ? "Conectado" : networkService?.wifiEnabled ? "Sin conexión" : "Wi-Fi apagado" }
                Stat { label:"Red"; value: networkService?.ssid || "No disponible" }
                Stat { label:"Tráfico"; value: networkService ? "↑ "+networkService.formatRate(networkService.uploadSpeed)+"   ↓ "+networkService.formatRate(networkService.downloadSpeed) : "No disponible" }
            }
            Card { title:"BLUETOOTH"; icon:"bluetooth"
                Stat { label:"Dispositivos"; value: bluetoothService ? bluetoothService.connectedDevices.length+" conectados" : "No disponible" }
                ActionButton { text: bluetoothService?.discovering ? "Detener búsqueda" : "Buscar dispositivos"; onClicked: bluetoothService?.discovering ? bluetoothService.stopScan() : bluetoothService?.startScan() }
            }
            Card { title:"REPRODUCCIÓN"; icon:"music_note"
                Stat { label:"Ahora"; value: Services.MediaService.available ? Services.MediaService.title : "Sin reproductor activo" }
                Stat { label:"Artista"; value: Services.MediaService.available ? Services.MediaService.artist : "—" }
                RowLayout { Layout.alignment:Qt.AlignHCenter; spacing:Style.spacingLarge
                    ActionButton { enabled:Services.MediaService.available; text:"‹"; onClicked:Services.MediaService.command("previous") }
                    ActionButton { enabled:Services.MediaService.available; text:Services.MediaService.playing?"Ⅱ":"▶"; onClicked:Services.MediaService.command("play-pause") }
                    ActionButton { enabled:Services.MediaService.available; text:"›"; onClicked:Services.MediaService.command("next") }
                }
            }
            Card { title:"ENERGÍA Y SESIÓN"; icon:"power_settings_new"
                Flow { width:parent.width; spacing:Style.spacingSmall
                    Repeater { model:[["lock","Bloquear"],["sleep","Suspender"],["logout","Cerrar sesión"],["restart_alt","Reiniciar"],["power_settings_new","Apagar"]]
                        delegate: ActionButton { required property var modelData; text:modelData[1]; onClicked: Services.SidebarService.requestPower(modelData[0]) }
                    }
                }
                RowLayout {
                    visible: Services.SidebarService.pendingPower.length > 0
                    Text { text: "¿Confirmar " + Services.SidebarService.pendingPower + "?"; color: muted; Layout.fillWidth: true }
                    ActionButton { text: "Cancelar"; onClicked: Services.SidebarService.cancelPower() }
                    ActionButton { text: "Confirmar"; onClicked: Services.SidebarService.confirmPower() }
                }
            }
        }
    }
    readonly property var networkService: pluginRegistry.plugin("network")?.service
    readonly property var bluetoothService: pluginRegistry.plugin("bluetooth")?.service
    readonly property var audioService: pluginRegistry.plugin("audio")?.service
    component Card: Rectangle {
        default property alias content: inside.data
        property string title: ""
        property string icon: ""
        width: parent.width
        radius: Style.cardRadius
        color: Color.surfaceContainer
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        implicitHeight: inside.implicitHeight + Style.paddingMedium * 2
        Column {
            id: inside
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.paddingMedium }
            spacing: Style.spacingSmall
            Row {
                width: parent.width
                MaterialIcon { text: card.icon; iconColor: accent; iconSize: Style.sectionIconSize; width: 30 }
                Text { id: cardTitle; text: card.title; color: accent; font.bold: true; font.pixelSize: Style.fontSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        id:card
    }
    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        width: parent.width
        Text { text: parent.label; color: muted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
        Text { text: parent.value; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.maximumWidth: parent.width * 0.65; wrapMode: Text.WrapAnywhere; horizontalAlignment: Text.AlignRight }
    }
    component ControlRow: ColumnLayout {
        property string icon: ""
        property string label: ""
        property string value: ""
        width: parent.width
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: parent.parent.icon; iconSize: Style.materialIconSmall; iconColor: accent }
            Text { text: parent.parent.label; color: Color.foreground; Layout.fillWidth: true }
            Text { text: parent.parent.value; color: muted }
        }
    }
    component ActionButton: Button {
        implicitHeight: 34
        implicitWidth: Math.max(78, contentItem.implicitWidth + 24)
        contentItem: Text { text: parent.text; color: parent.enabled ? Color.foreground : muted; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { radius: Style.radiusFull; color: parent.down ? Color.primary : parent.hovered ? Color.surfaceHover : Color.surface; border.width: Style.panelBorderWidth; border.color: parent.down ? Color.primary : Color.outlineVariant; opacity: parent.enabled ? 1 : .55 }
    }
    component StyledSlider: Slider {
        id: slider
        implicitHeight: 30
        implicitWidth: 120
        Layout.minimumWidth: 0
        padding: 8
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.availableWidth
            height: 6
            radius: 3
            color: Color.outlineVariant
            Rectangle {
                width: slider.position * parent.width
                height: parent.height
                radius: parent.radius
                color: slider.enabled ? Color.primary : Color.foregroundMuted
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.pressed ? 20 : 16
            height: width
            radius: width / 2
            color: slider.enabled ? Color.primary : Color.foregroundMuted
            border.width: slider.activeFocus ? 2 : 0
            border.color: Color.foreground
        }
    }
}
