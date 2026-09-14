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

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Column {
            id: content
            width: parent.width
            spacing: Style.spacingMedium
            Text { text: "Centro de sistema"; color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true }
            Text { text: "Controles rápidos y estado del entorno"; color: muted; font.pixelSize: Style.fontSmall }

            Card { title: "CONEXIONES"; icon: "tune"
                Flow { width: parent.width; spacing: Style.spacingSmall
                    Repeater { model: [{l:"Wi-Fi",i:"wifi",k:"network"},{l:"Bluetooth",i:"bluetooth",k:"bluetooth"},{l:"No molestar",i:"notifications_off",k:"dnd"}]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var ns: root.pluginRegistry.plugin("network")?.service
                            readonly property var bs: root.pluginRegistry.plugin("bluetooth")?.service
                            readonly property bool active: modelData.k==="network" ? Boolean(ns?.wifiEnabled) : modelData.k==="bluetooth" ? Boolean(bs?.enabled) : Services.NotificationService.dnd
                            width: (parent.width-Style.spacingSmall*2)/3; height: 72; radius: Style.radiusMedium
                            color: active ? Color.primaryContainer : Color.surfaceContainer
                            Column { anchors.centerIn: parent; spacing: 4
                                MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; text:modelData.i; iconSize:Style.materialIconMedium; iconColor:active?accent:muted }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text:modelData.l; color:active?Color.onPrimaryContainer:Color.foreground; font.pixelSize:Style.fontSmall }
                            }
                            TapHandler { onTapped: { if(modelData.k==="network"&&ns) ns.setWifiEnabled(!ns.wifiEnabled); else if(modelData.k==="bluetooth"&&bs) bs.setEnabled(!bs.enabled); else Services.NotificationService.toggleDnd() } }
                        }
                    }
                }
            }
            Card { title: "SONIDO Y PANTALLA"; icon: "tune"
                ControlRow { icon:"volume_up"; label:"Volumen"; value:Math.round((root.pluginRegistry.plugin("audio")?.service.volume??0)*100)+"%"
                    Slider { Layout.fillWidth:true; from:0; to:1; value:root.pluginRegistry.plugin("audio")?.service.volume??0; onMoved:root.pluginRegistry.plugin("audio")?.service.setVolume(value) }
                }
                ControlRow { icon:"brightness_6"; label:"Brillo"; value:(root.pluginRegistry.plugin("brightness")?.service.brightnessPercentForScreen(root.monitorScreen)??0)+"%"
                    Slider { Layout.fillWidth:true; from:0; to:100; value:root.pluginRegistry.plugin("brightness")?.service.brightnessPercentForScreen(root.monitorScreen)??0; onMoved:{var s=root.pluginRegistry.plugin("brightness")?.service;if(s&&s.availableForScreen(root.monitorScreen)){var m=s.monitorForScreen(root.monitorScreen)?.maxBrightness??100;s.setBrightnessForScreen(root.monitorScreen,value*m/100,350)}}}
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
    component Card: Rectangle {
        default property alias content: inside.data
        property string title: ""
        property string icon: ""
        width: root.width
        radius: Style.radiusMedium
        color: Color.surfaceContainerHigh
        border.width: 1
        border.color: Color.outlineVariant
        implicitHeight: inside.implicitHeight + Style.paddingMedium * 2
        Column {
            id: inside
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.paddingMedium }
            spacing: Style.spacingSmall
            Row {
                width: parent.width
                Text { text: card.icon; color: accent; font.family: Style.materialIconFont; font.pixelSize: Style.materialIconMedium; width: 30 }
                Text { id: cardTitle; text: card.title; color: accent; font.bold: true; font.pixelSize: Style.fontSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        id:card
    }
    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        width: root.width
        Text { text: parent.label; color: muted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
        Text { text: parent.value; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.maximumWidth: root.width * 0.58; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight }
    }
    component ControlRow: ColumnLayout {
        property string icon: ""
        property string label: ""
        property string value: ""
        width: root.width
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
        background: Rectangle { radius: Style.radiusSmall; color: parent.down ? Color.primary : parent.hovered ? Color.surfaceHover : Color.surfaceContainer; border.width: 1; border.color: parent.down ? Color.primary : Color.outlineVariant; opacity: parent.enabled ? 1 : .55 }
    }
}
