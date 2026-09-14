pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
QtObject {
    id: root
    property bool available: false
    property string cpuModel: "CPU"
    property int cpuCores: 0
    property int cpuThreads: 0
    property real cpuFrequencyGHz: 0
    property real cpuUsage: 0
    property var cpuHistory: []
    property var coreUsages: []
    property var coreFrequencies: []
    property var corePhysical: []
    property real memoryUsed: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property string cpuTemperatureLabel: ""
    property real cpuTemperature: -1
    property var temperatureHistory: []
    property bool gpuAvailable: false
    property string gpuModel: "GPU"
    property string gpuVendor: ""
    property real gpuUsage: -1
    property real gpuMemoryUsedGiB: -1
    property real gpuMemoryTotalGiB: -1
    property real gpuTemperature: -1
    property real gpuPower: -1
    property real gpuPowerLimit: -1
    property real gpuFanRpm: -1
    property string gpuPowerMode: ""
    property string gpuClocks: ""
    property var gpuHistory: []
    property var powerHistory: []
    property string gpuFanText: ""
    property var disks: []
    property real diskUsed: 0
    property string diskUsedText: "N/A"
    property real diskReadMiB: -1
    property real diskWriteMiB: -1
    property string smartStatus: "No disponible"
    property int batteryPercent: -1
    property string batteryStatus: ""
    property real fanRpm: -1
    property var cpuProcesses: []
    property var gpuProcesses: []
    property bool showCpu: true
    property bool showGpu: true
    property bool showMemory: true
    property bool showStorage: true
    property bool showThermals: true
    property bool showProcesses: true
    property bool monitoringEnabled: false
    property var consumers: ({})
    readonly property string settingsPath: Quickshell.stateDir + "/hardware-sidebar.json"
    function setMetric(key, value) {
        var next=Object.assign({}, root.metricSettings); next[key]=!!value; root.metricSettings=next
        root[key]=!!value
        root.settingsWrite.command=["python3","-c","import json,sys;json.dump(json.loads(sys.argv[1]),open(sys.argv[2],'w'))",JSON.stringify(next),root.settingsPath]
        root.settingsWrite.running=true
    }
    property var metricSettings: ({})
    function setConsumerActive(name, active) {
        var next = Object.assign({}, root.consumers)
        if (active) next[name] = true; else delete next[name]
        root.consumers = next
        root.monitoringEnabled = Object.keys(next).length > 0
        if (root.monitoringEnabled) root.refresh()
    }
    function refresh() { if (!probe.running && root.monitoringEnabled) probe.running = true }
    function valid(v, fallback) { return typeof v === "number" && isFinite(v) ? v : fallback }
    function history(h, v) { if (v < 0) return h; var n=h.slice(); n.push(v); return n.slice(-60) }
    function alert(v, key, title) {
        if (v < 0 || root.alertCooldown[key] > Date.now()) return
        root.alertCooldown[key]=Date.now()+60000
        root.alertProc.command=["notify-send","-a","Tartarus Hardware","Hardware",title]
        root.alertProc.running=true
    }
    property var alertCooldown: ({})
    property Process probe: Process {
        id: probe
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/tartarus-shell/scripts/hardware-snapshot.py"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var d=JSON.parse(String(text).trim()); if (!d || !d.ok) return
                    root.available=true; var c=d.cpu || {}, m=d.memory || {}, g=d.gpu || {}
                    root.cpuModel=c.name || "CPU"; root.cpuCores=c.cores||0; root.cpuThreads=c.threads||0; root.cpuFrequencyGHz=c.frequency||0
                    root.cpuUsage=root.valid(c.usage,root.cpuUsage); root.cpuHistory=root.history(root.cpuHistory,root.cpuUsage)
                    root.coreUsages=c.coreUsage||[]; root.coreFrequencies=c.coreFrequency||[]; root.corePhysical=c.physical||[]
                    root.load1=d.load[0]||0; root.load5=d.load[1]||0; root.load15=d.load[2]||0
                    root.memoryUsedGiB=m.used||0; root.memoryTotalGiB=m.total||0; root.memoryUsed=m.percent||0
                    root.cpuTemperature=root.valid(d.thermal.cpu,-1); root.cpuTemperatureLabel=d.thermal.cpuLabel||""
                    if (root.cpuTemperature >= 0) root.temperatureHistory=root.history(root.temperatureHistory,Math.max(0,Math.min(100,(root.cpuTemperature-20)/80*100)))
                    root.gpuAvailable=!!g.detected; root.gpuModel=g.name||"GPU"; root.gpuVendor=g.vendor||""
                    root.gpuUsage=root.valid(g.usage,-1); root.gpuMemoryUsedGiB=root.valid(g.memoryUsed,-1); root.gpuMemoryTotalGiB=root.valid(g.memoryTotal,-1)
                    root.gpuTemperature=root.valid(g.temperature,-1); root.gpuPower=root.valid(g.power,-1); root.gpuPowerLimit=root.valid(g.powerLimit,-1)
                    root.gpuFanRpm=root.valid(g.fan,-1); root.gpuPowerMode=g.powerMode||""; root.gpuClocks=g.clocks||""
                    root.gpuHistory=root.history(root.gpuHistory,root.gpuUsage); root.disks=d.disks||[]
                    if (root.gpuPower >= 0 && root.gpuPowerLimit > 0) root.powerHistory=root.history(root.powerHistory,root.gpuPower/root.gpuPowerLimit*100)
                    root.gpuProcesses=g.processes||[]
                    root.diskUsed=root.disks.length?root.disks[0].percent:0; root.diskUsedText=root.disks.length?root.disks[0].percent+"%":"N/A"
                    root.diskReadMiB=root.valid(d.io.read,-1); root.diskWriteMiB=root.valid(d.io.write,-1); root.smartStatus=d.smart||"No disponible"
                    root.batteryPercent=root.valid(d.battery.percent,-1); root.batteryStatus=d.battery.status||""; root.fanRpm=root.valid(d.thermal.fan,-1); root.cpuProcesses=d.processes||[]
                    if (root.cpuUsage >= 90) root.alert(root.cpuUsage,"cpu","Carga de CPU crítica")
                    if (root.cpuTemperature >= 85) root.alert(root.cpuTemperature,"cpuTemp","Temperatura de CPU elevada")
                    if (root.gpuTemperature >= 85) root.alert(root.gpuTemperature,"gpuTemp","Temperatura de GPU elevada")
                    if (root.disks.length && root.disks[0].percent >= 90) root.alert(root.disks[0].percent,"disk","Almacenamiento casi lleno")
                } catch(e) { }
            }
        }
    }
    property Process settingsRead: Process {
        command: ["cat", root.settingsPath]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: { try { var s=JSON.parse(String(text)); root.metricSettings=s; for(var k in s) if(k.indexOf("show")===0) root[k]=!!s[k] } catch(e) {} } }
    }
    property Process settingsWrite: Process {}
    property Process alertProc: Process {}
    property Timer pollTimer: Timer { interval: 2000; repeat: true; running: root.monitoringEnabled; triggeredOnStart: true; onTriggered: root.refresh() }
    Component.onCompleted: root.settingsRead.running=true
}
