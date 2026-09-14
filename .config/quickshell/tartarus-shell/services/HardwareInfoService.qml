pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
QtObject {
    id: root
    property bool ready: false
    property var data: ({})
    function refresh() { if (!probe.running) probe.running = true }
    property Process probe: Process {
        id: probe
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/tartarus-shell/scripts/hardware-info.py"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try { var d=JSON.parse(String(text).trim()); if(d){root.data=d;root.ready=true} } catch(e) { console.warn("Hardware info:",e) }
            }
        }
    }
    property Timer refreshTimer: Timer { interval: 60000; repeat:true; running:root.ready; onTriggered:root.refresh() }
    Component.onCompleted: root.refresh()
}
