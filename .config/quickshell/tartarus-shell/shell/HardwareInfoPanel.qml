import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../services" as Services
import "../theme"
Item {
    id: root
    property var info: Services.HardwareInfoService
    property color muted: Color.foregroundMuted
    property color accent: Color.primary
    property var d: info.data
    Flickable { anchors.fill:parent; contentWidth:width; contentHeight:body.implicitHeight; clip:true; boundsBehavior:Flickable.StopAtBounds; flickableDirection:Flickable.VerticalFlick
        Column { id:body; width:parent.width; spacing:Style.spacingMedium
            Text { text:"Información del equipo"; color:Color.foreground; font.pixelSize:Style.fontLarge; font.bold:true }
            Text { text:info.ready ? "Datos del sistema · actualización cada 60 s" : "Recopilando información…"; color:muted; font.pixelSize:Style.fontSmall }
            Card { title:"SISTEMA Y PLACA"; icon:"computer"
                Stat {label:"Fabricante";value:d.dmi?.board_vendor||"—"} Stat {label:"Placa";value:d.dmi?.board_name||"—"} Stat {label:"BIOS";value:(d.dmi?.bios_vendor||"—")+" · "+(d.dmi?.bios_version||"—")} Stat {label:"Fecha BIOS";value:d.dmi?.bios_date||"—"} Stat {label:"Sistema";value:d.os?.distro||"—"} Stat {label:"Kernel";value:d.os?.kernel||"—"} Stat {label:"Hostname";value:d.os?.hostname||"—"} Stat {label:"Uptime";value:d.os?.uptime||"—"}
            }
            Card { title:"PROCESADOR Y CACHÉ"; icon:"memory"
                Stat {label:"Modelo";value:d.cpu?.model||"—"} Stat {label:"Arquitectura";value:d.cpu?.arch||"—"} Stat {label:"Topología";value:(d.cpu?.cores||"—")+" núcleos · "+(d.cpu?.threads||"—")+" hilos · "+(d.cpu?.sockets||"—")+" socket(s)"} Stat {label:"Frecuencia";value:(d.cpu?.base_mhz||"—")+"–"+(d.cpu?.max_mhz||"—")+" MHz"} Stat {label:"Governor";value:d.cpu?.governor||"—"} Stat {label:"Driver";value:d.cpu?.driver||"—"} Stat {label:"Caché";value:"L1d "+(d.cpu?.caches?.l1d||"—")+" · L1i "+(d.cpu?.caches?.l1i||"—")+" · L2 "+(d.cpu?.caches?.l2||"—")+" · L3 "+(d.cpu?.caches?.l3||"—")}
            }
            Card { title:"MEMORIA Y SWAP"; icon:"memory_alt"
                Stat {label:"RAM";value:(d.memory?.used_gb||"—")+" / "+(d.memory?.total_gb||"—")+" GiB · "+(d.memory?.used_pct||0)+"%"} Stat {label:"Disponible";value:(d.memory?.avail_gb||"—")+" GiB"} Stat {label:"Caché / buffers";value:(d.memory?.cached_gb||"—")+" GiB / "+(d.memory?.buffers_mb||"—")+" MiB"} Stat {label:"Swap";value:(d.memory?.swap_used_gb||"—")+" / "+(d.memory?.swap_total_gb||"—")+" GiB"}
                Repeater {model:d.memory?.modules||[]; delegate:Stat{required property var modelData;label:modelData.slot+" · "+modelData.type;value:modelData.size+" · "+modelData.speed}}
            }
            Card { title:"DISCOS Y MONTajes"; icon:"hard_drive"
                Repeater {model:d.storage?.disks||[]; delegate:Stat{required property var modelData;label:modelData.model;value:modelData.tran+" · "+modelData.size+" · "+modelData.serial}}
                Repeater {model:d.storage?.mounts||[]; delegate:Stat{required property var modelData;label:modelData.mountpoint+" · "+modelData.fstype;value:modelData.used+" / "+modelData.size+" · "+modelData.use_pct}}
            }
            Card { title:"DISPOSITIVOS"; icon:"devices"
                Text{ text:"GRÁFICOS";color:accent;font.bold:true;font.pixelSize:Style.fontSmall } Repeater{model:d.devices?.gpus||[];delegate:Stat{required property var modelData;label:modelData.slot;value:modelData.name}}
                Text{ text:"RED";color:accent;font.bold:true;font.pixelSize:Style.fontSmall } Repeater{model:d.devices?.network||[];delegate:Stat{required property var modelData;label:modelData.slot;value:modelData.name}}
                Text{ text:"AUDIO";color:accent;font.bold:true;font.pixelSize:Style.fontSmall } Repeater{model:d.devices?.audio||[];delegate:Stat{required property var modelData;label:modelData.slot;value:modelData.name}}
            }
            Card { title:"CAPACIDADES Y SEGURIDAD"; icon:"security"
                FeatureGroup {title:"SIMD";items:d.cpu?.capabilities?.simd||[]} FeatureGroup{title:"Criptografía";items:d.cpu?.capabilities?.crypto||[]} FeatureGroup{title:"Virtualización";items:d.cpu?.capabilities?.virtualization||[]} FeatureGroup{title:"Mitigaciones del kernel";items:d.cpu?.vulnerabilities||[]}
            }
        }
    }
    component Card: Rectangle {
        id: card
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
                Text { text: card.title; color: accent; font.bold: true; font.pixelSize: Style.fontSmall }
            }
        }
    }
    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        width: root.width
        Text { text: parent.label; color: muted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: parent.value; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.maximumWidth: root.width * 0.58; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight }
    }
    component FeatureGroup: Column {
        property string title: ""
        property var items: []
        width: root.width
        Text { text: title; color: accent; font.bold: true; font.pixelSize: Style.fontSmall }
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: parent.parent.items
                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(70, featureLabel.implicitWidth + 18)
                    height: 24
                    radius: 5
                    color: modelData.supported || modelData.is_mitigated ? Color.primaryContainer : Color.surfaceContainer
                    border.color: Color.outlineVariant
                    Text { id: featureLabel; anchors.centerIn: parent; text: modelData.name || modelData.status; color: Color.foreground; font.pixelSize: 10; elide: Text.ElideRight }
                }
            }
        }
    }
}
