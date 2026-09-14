import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../theme"

Item {
    id: root
    property var service: Services.PeripheralService
    readonly property color muted: Color.foregroundMuted
    readonly property color accent: Color.primary
    readonly property var devices: service.devices || []
    readonly property var audioDevices: devices.filter(x => ["Audio", "Micrófono"].indexOf(x.kind) !== -1)
    readonly property var keyboards: devices.filter(x => x.kind === "Teclado")
    readonly property var mice: devices.filter(x => x.kind === "Mouse" || x.kind === "Logitech")
    readonly property var controllers: devices.filter(x => x.kind === "Control")
    readonly property var inputDevices: devices.filter(x => x.kind === "Entrada")
    readonly property var cameras: devices.filter(x => x.kind === "Webcam")
    readonly property var usbDevices: devices.filter(x => ["Audio", "Micrófono", "Teclado", "Mouse", "Logitech", "Control", "Entrada", "Webcam"].indexOf(x.kind) === -1)
    property string openConfig: ""
    property string filterKind: "Todos"

    function filtered(list) {
        var out = list.slice()
        if (root.filterKind !== "Todos")
            out = out.filter(function (d) { return d.kind === root.filterKind })
        out.sort(function (a, b) {
            var ac = a.controller || a.kind === "Micrófono"
            var bc = b.controller || b.kind === "Micrófono"
            return ac === bc ? String(a.name).localeCompare(String(b.name)) : (bc ? 1 : -1)
        })
        return out
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: body
            width: parent.width
            height: {
                var total = 0
                var visibleCount = 0
                for (var i = 0; i < children.length; i++) {
                    var child = children[i]
                    if (!child.visible)
                        continue
                    total += child.height
                    visibleCount++
                }
                return total + Math.max(0, visibleCount - 1) * spacing
            }
            spacing: Style.spacingMedium

            Text {
                width: parent.width
                text: "Periféricos"
                color: Color.foreground
                font.pixelSize: Style.fontLarge
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Caption {
                text: root.service.ready ? root.devices.length + " dispositivos detectados" : "Buscando dispositivos…"
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: ["Todos", "Micrófono", "Teclado", "Mouse", "Iluminación", "Control"]
                    delegate: Rectangle {
                        required property string modelData
                        width: filterText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: root.filterKind === modelData ? root.accent : Color.surfaceContainerHigh
                        border.width: 1
                        border.color: Color.outlineVariant
                        Text {
                            id: filterText
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: root.filterKind === parent.modelData ? Color.background : root.muted
                            font.pixelSize: 10
                            font.bold: root.filterKind === parent.modelData
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.filterKind = parent.modelData }
                    }
                }
            }
            Card {
                title: "AUDIO"
                icon: "mic"
                devices: root.filtered(root.audioDevices)
                emptyText: "No hay dispositivos de audio detectados"
            }
            Card {
                title: "TECLADOS"
                icon: "keyboard"
                devices: root.filtered(root.keyboards)
                emptyText: "No hay teclados detectados"
            }
            Card {
                title: "RATONES"
                icon: "mouse"
                devices: root.filtered(root.mice)
                emptyText: "No hay ratones detectados"
            }
            Card {
                title: "CÁMARAS"
                icon: "videocam"
                devices: root.filtered(root.cameras)
                emptyText: "No hay webcam detectada"
            }
            Card {
                title: "USB Y DISPOSITIVOS ESPECIALES"
                icon: "usb"
                devices: root.filtered(root.usbDevices.concat(root.controllers))
                emptyText: "No hay dispositivos USB detectados"
            }
        }
    }

    component Caption: Text {
        width: parent ? parent.width : 0
        color: root.muted
        font.pixelSize: Style.fontSmall
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }

    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        property var devices: []
        property string emptyText: ""
        width: parent ? parent.width : 0
        height: inside.childrenRect.height + Style.paddingMedium * 2
        implicitHeight: height
        radius: Style.radiusMedium
        color: Color.surfaceContainerHigh
        border.width: 1
        border.color: Color.outlineVariant

        Column {
            id: inside
            x: Style.paddingMedium
            y: Style.paddingMedium
            width: Math.max(0, card.width - Style.paddingMedium * 2)
            spacing: Style.spacingSmall
            height: childrenRect.height

            RowLayout {
                width: parent.width
                MaterialIcon {
                    text: card.icon
                    iconSize: Style.materialIconMedium
                    iconColor: root.accent
                }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: card.title
                    textFormat: Text.PlainText
                    color: root.accent
                    font.bold: true
                    font.pixelSize: Style.fontSmall
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 24
                    height: 22
                    radius: 11
                    color: card.devices.length > 0 ? Color.primary : Color.surfaceContainer
                    border.width: 1
                    border.color: Color.outlineVariant
                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: card.devices.length
                        color: card.devices.length > 0 ? Color.background : root.muted
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Repeater {
                model: card.devices
                delegate: DeviceRow {}
            }

            Caption {
                visible: card.devices.length === 0
                text: card.emptyText
            }
        }
    }

    component Stat: RowLayout {
        id: stat
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        spacing: Style.spacingSmall

        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: stat.width * 0.6
            text: stat.label
            textFormat: Text.PlainText
            color: root.muted
            font.pixelSize: Style.fontSmall
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: stat.width * 0.4
            text: stat.value
            textFormat: Text.PlainText
            color: Color.foreground
            font.pixelSize: Style.fontSmall
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignRight
        }
    }

    component DeviceRow: Rectangle {
        id: device
        required property var modelData
        width: parent ? parent.width : 0
        implicitHeight: details.implicitHeight + Style.paddingSmall * 2
        radius: Style.radiusSmall
        color: Color.surfaceContainer

        RowLayout {
            id: details
            x: Style.paddingSmall
            y: Style.paddingSmall
            width: Math.max(0, device.width - Style.paddingSmall * 2)
            spacing: Style.spacingSmall

            MaterialIcon {
                text: device.modelData.kind === "Iluminación" ? "lightbulb"
                    : device.modelData.kind === "iPhone" ? "phone_iphone"
                    : device.modelData.kind === "Micrófono" ? "mic"
                    : device.modelData.kind === "Teclado" ? "keyboard"
                    : device.modelData.kind === "Mouse" ? "mouse"
                    : device.modelData.kind === "Control" ? "gamepad"
                    : device.modelData.kind === "Webcam" ? "videocam"
                    : "usb"
                iconSize: Style.materialIconMedium
                iconColor: root.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Text {
                    Layout.fillWidth: true
                    text: device.modelData.name || "Dispositivo USB"
                    textFormat: Text.PlainText
                    color: Color.foreground
                    font.pixelSize: Style.fontSmall + 1
                    font.bold: true
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: [device.modelData.kind, device.modelData.vendor, device.modelData.id].filter(Boolean).join(" · ")
                    textFormat: Text.PlainText
                    color: root.muted
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
                Text {
                    text: "Conectado"
                    color: root.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.alignment: Qt.AlignLeft
                    Layout.preferredWidth: 116
                    Layout.preferredHeight: 28
                    radius: 14
                    color: root.openConfig === device.modelData.name ? Color.primary : Color.surfaceContainerHigh
                    border.width: 1
                    border.color: Color.outlineVariant
                    Text {
                        anchors.centerIn: parent
                        text: root.openConfig === device.modelData.name ? "Cerrar" : "Configuración"
                        color: root.openConfig === device.modelData.name ? Color.background : Color.foreground
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openConfig = root.openConfig === device.modelData.name ? "" : device.modelData.name
                    }
                }
                Text {
                    visible: root.openConfig === device.modelData.name
                        && device.modelData.kind !== "Micrófono"
                        && device.modelData.kind !== "Mouse"
                    Layout.fillWidth: true
                    text: device.modelData.kind === "Micrófono"
                        ? "Volumen y muteo del sistema estarán disponibles aquí."
                        : device.modelData.kind === "Teclado"
                        ? "RGB y distribución del teclado estarán disponibles aquí."
                        : device.modelData.kind === "Mouse"
                        ? (device.modelData.controller === "logitech-g"
                            ? "DPI y polling rate disponibles."
                            : "Mouse detectado; este modelo no tiene controlador configurado todavía.")
                        : "Este dispositivo no tiene controles configurables todavía."
                    color: root.muted
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
                Loader {
                    Layout.fillWidth: true
                    active: root.openConfig === device.modelData.name
                        && device.modelData.kind === "Micrófono"
                    visible: active
                    opacity: active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    sourceComponent: Component {
                        MicrophoneControls { deviceName: device.modelData.name || "" }
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    active: root.openConfig === device.modelData.name
                        && device.modelData.kind === "Mouse"
                        && device.modelData.controller === "logitech-g"
                    visible: active
                    opacity: active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    sourceComponent: Component {
                        MouseControls { }
                    }
                }
            }
        }
    }

}
