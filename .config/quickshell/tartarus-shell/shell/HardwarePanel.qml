import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services" as Services
import "../theme"

Item {
    id: root
    required property var monitorContext
    property var hw: Services.HardwareService
    property color muted: Color.foregroundMuted
    property color line: Color.outlineVariant
    property color accent: Color.primary
    property string na: "No disponible"

    function activeChanged() {
        hw.setConsumerActive("sidebar-" + (monitorContext.name || "main"), monitorContext.sidebarOpened && monitorContext.sidebarTab === 1)
    }
    onMonitorContextChanged: activeChanged()
    Component.onCompleted: activeChanged()
    Component.onDestruction: hw.setConsumerActive("sidebar-" + (monitorContext.name || "main"), false)
    Connections {
        target: root.monitorContext
        function onSidebarOpenedChanged() { root.activeChanged() }
        function onSidebarTabChanged() { root.activeChanged() }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Column {
            id: body
            width: parent.width
            spacing: Style.spacingMedium
            Text { text: "Monitor de hardware"; color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true }
            Text { text: hw.available ? "Lecturas en directo · cada 2 s" : "Preparando lecturas…"; color: muted; font.pixelSize: Style.fontSmall }
            Card {
                visible: hw.showCpu
                alert: hw.cpuUsage >= 90 ? "ALTA" : hw.cpuUsage >= 75 ? "ELEVADA" : ""
                title: "PROCESADOR"
                icon: "memory"
                value: Math.round(hw.cpuUsage) + "%"
                subtitle: hw.cpuModel + "  ·  " + hw.cpuCores + " núcleos · " + hw.cpuThreads + " hilos"
                Meter { value: hw.cpuUsage }
                Sparkline { values: hw.cpuHistory; color: accent }
                Text { text: "Carga  " + hw.load1.toFixed(2) + "   " + hw.load5.toFixed(2) + "   " + hw.load15.toFixed(2); color: muted; font.pixelSize: Style.fontSmall }
                Text { text: "NÚCLEOS · " + hw.coreUsages.length; color: accent; font.bold: true; font.pixelSize: Style.fontSmall }
                GridLayout {
                    columns: 2
                    columnSpacing: Style.spacingMedium
                    rowSpacing: Style.spacingSmall
                    Repeater {
                        model: hw.coreUsages
                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Text { text: "C" + (index < hw.corePhysical.length ? hw.corePhysical[index] : "?") + " · T" + index; color: muted; font.pixelSize: 10; Layout.preferredWidth: 52 }
                            Meter { value: modelData; Layout.fillWidth: true }
                            Text { text: Math.round(modelData) + "%"; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight }
                            Text { text: index < hw.coreFrequencies.length && hw.coreFrequencies[index] > 0 ? hw.coreFrequencies[index].toFixed(2) + " GHz" : ""; color: muted; font.pixelSize: 10; Layout.preferredWidth: 54 }
                        }
                    }
                }
            }
            Card {
                visible: hw.showGpu
                alert: hw.gpuTemperature >= 85 ? "CALIENTE" : hw.gpuUsage >= 90 ? "ALTA" : ""
                title: "GRÁFICOS"
                icon: "videogame_asset"
                value: hw.gpuUsage >= 0 ? Math.round(hw.gpuUsage) + "%" : "—"
                subtitle: hw.gpuAvailable ? hw.gpuModel : "GPU detectada, telemetría no disponible"
                Meter { value: hw.gpuUsage }
                Sparkline { values: hw.gpuHistory; color: accent }
                Stat { label: "VRAM"; value: hw.gpuMemoryTotalGiB >= 0 ? hw.gpuMemoryUsedGiB.toFixed(1) + " / " + hw.gpuMemoryTotalGiB.toFixed(1) + " GiB" : na }
                Stat { label: "Temperatura"; value: hw.gpuTemperature >= 0 ? Math.round(hw.gpuTemperature) + " °C" : na }
                Stat { label: "Consumo"; value: hw.gpuPower >= 0 ? Math.round(hw.gpuPower) + " W" : na }
                Stat { label: "Ventilador / energía"; value: hw.gpuFanRpm >= 0 ? Math.round(hw.gpuFanRpm) + " RPM · " + hw.gpuPowerMode : (hw.gpuPowerMode || na) }
                Stat { label: "Frecuencias"; value: hw.gpuClocks || na }
                Sparkline { values: hw.powerHistory; color: accent }
                Text { visible: hw.gpuProcesses.length > 0; text: "PROCESOS USANDO GPU"; color: accent; font.bold: true; font.pixelSize: 10 }
                Repeater { model: hw.gpuProcesses; delegate: Stat { required property var modelData; label: modelData.name; value: "PID " + modelData.pid } }
            }
            Card {
                visible: hw.showMemory
                title: "MEMORIA"
                icon: "memory_alt"
                value: Math.round(hw.memoryUsed) + "%"
                subtitle: hw.memoryUsedGiB.toFixed(1) + " / " + hw.memoryTotalGiB.toFixed(1) + " GiB"
                Meter { value: hw.memoryUsed }
            }
            Card {
                visible: hw.showStorage
                alert: hw.disks.length && hw.disks[0].percent >= 90 ? "CASI LLENO" : ""
                title: "ALMACENAMIENTO"
                icon: "hard_drive"
                value: hw.diskUsedText
                subtitle: hw.diskReadMiB >= 0 ? "↑ " + hw.diskReadMiB.toFixed(1) + " MiB/s   ↓ " + hw.diskWriteMiB.toFixed(1) + " MiB/s" : "Actividad de disco no disponible"
                Repeater { model: hw.disks; delegate: Stat { required property var modelData; label: modelData.mount + " · SMART " + (modelData.smart || "N/A"); value: modelData.used + " / " + modelData.total + " GiB · " + modelData.percent + "%" } }
                Stat { label: "Salud SMART"; value: hw.smartStatus }
            }
            Card {
                visible: hw.showThermals
                title: "SENSORES"
                icon: "thermostat"
                Stat { label: hw.cpuTemperatureLabel || "CPU"; value: hw.cpuTemperature >= 0 ? Math.round(hw.cpuTemperature) + " °C" : na }
                Sparkline { values: hw.temperatureHistory; color: hw.cpuTemperature >= 85 ? Color.error : accent }
                Stat { label: "Ventilador"; value: hw.fanRpm >= 0 ? Math.round(hw.fanRpm) + " RPM" : na }
                Stat { label: "Batería"; value: hw.batteryPercent >= 0 ? hw.batteryPercent + "% " + hw.batteryStatus : na }
            }
            Card {
                visible: hw.showProcesses
                title: "PROCESOS PRINCIPALES"
                icon: "bolt"
                Repeater { model: hw.cpuProcesses; delegate: Stat { required property var modelData; label: modelData.name + "  ·  PID " + modelData.pid; value: Number(modelData.cpu).toFixed(1) + "% CPU" } }
            }
            Card {
                title: "MOSTRAR"
                Flow {
                    width: parent.width
                    spacing: Style.spacingSmall
                    Repeater {
                        model: [{l:"CPU",k:"showCpu"},{l:"GPU",k:"showGpu"},{l:"RAM",k:"showMemory"},{l:"Disco",k:"showStorage"},{l:"Sensores",k:"showThermals"},{l:"Procesos",k:"showProcesses"}]
                        delegate: Rectangle {
                            required property var modelData
                            width: 86; height: 30; radius: Style.radiusSmall
                            color: hw[modelData.k] ? Color.primaryContainer : Color.surfaceContainerHigh
                            border.color: line
                            Text { anchors.centerIn: parent; text: (hw[modelData.k] ? "✓  " : "＋  ") + modelData.l; color: Color.foreground; font.pixelSize: Style.fontSmall }
                            TapHandler { onTapped: hw.setMetric(modelData.k, !hw[modelData.k]) }
                        }
                    }
                }
            }
        }
    }
    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        property string value: ""
        property string subtitle: ""
        property string alert: ""
        default property alias content: inside.data
        width: body.width
        radius: Style.radiusMedium
        color: Color.surfaceContainerHigh
        border.width: 1
        border.color: card.alert !== "" ? Color.error : Qt.rgba(line.r,line.g,line.b,0.35)
        implicitHeight: inside.implicitHeight + Style.paddingMedium * 2
        Column {
            id: inside
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.paddingMedium }
            spacing: Style.spacingSmall
            Row {
                width: parent.width
                Text { text: card.icon; color: accent; font.family: Style.materialIconFont; font.pixelSize: Style.materialIconMedium; width: 30 }
                Text { text: card.title; color: accent; font.bold: true; font.pixelSize: Style.fontSmall; verticalAlignment: Text.AlignVCenter; width: parent.width - (card.value !== "" ? valueText.width + 40 : 30) }
                Text { id: valueText; text: card.value; color: Color.foreground; font.bold: true; font.pixelSize: Style.fontLarge; verticalAlignment: Text.AlignVCenter }
                Text { visible: card.alert !== ""; text: card.alert; color: Color.error; font.bold: true; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }
            Text { visible: card.subtitle !== ""; text: card.subtitle; color: muted; font.pixelSize: Style.fontSmall; width: parent.width; elide: Text.ElideRight }
        }
    }
    component Meter: Item {
        property real value: -1
        implicitHeight: 6
        Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(Color.foreground.r,Color.foreground.g,Color.foreground.b,0.12) }
        Rectangle { width: value >= 0 ? Math.max(4,parent.width * Math.min(100,value)/100) : 0; height: parent.height; radius: 3; color: accent; Behavior on width { NumberAnimation { duration: 180 } } }
    }
    component Stat: RowLayout {
        property string label: ""
        property string value: ""
        width: body.width
        Text { text: parent.label; color: muted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: parent.value; color: Color.foreground; font.pixelSize: Style.fontSmall; Layout.maximumWidth: root.width * 0.58; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight }
    }
    component Sparkline: Canvas {
        property var values: []
        property color color: accent
        width: body.width; height: 42
        onPaint: {
            var c=getContext("2d"); c.clearRect(0,0,width,height); c.strokeStyle=Qt.rgba(Color.foreground.r,Color.foreground.g,Color.foreground.b,.12); c.lineWidth=1
            c.beginPath(); c.moveTo(0,height-1); c.lineTo(width,height-1); c.stroke()
            if (!values || values.length<2) return
            c.strokeStyle=color; c.lineWidth=2; c.beginPath()
            for(var i=0;i<values.length;i++){var x=i*(width-2)/(values.length-1)+1;var y=height-2-(Math.max(0,Math.min(100,values[i]))/100)*(height-5);if(i)c.lineTo(x,y);else c.moveTo(x,y)} c.stroke()
        }
        onValuesChanged: requestPaint()
    }
}
