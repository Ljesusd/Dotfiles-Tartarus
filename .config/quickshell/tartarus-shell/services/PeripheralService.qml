pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
QtObject {
 id:root
 property bool ready:false
 property var devices:[]
 function refresh(){if(!probe.running)probe.running=true}
 property Process probe:Process{id:probe;command:["python3",Quickshell.env("HOME")+"/.config/quickshell/tartarus-shell/scripts/peripherals-snapshot.py"];stdout:StdioCollector{waitForEnd:true;onStreamFinished:{try{var d=JSON.parse(String(text).trim());if(d.ok){root.devices=d.devices||[];root.ready=true}}catch(e){}}}}
 property Timer poll:Timer{interval:5000;running:true;repeat:true;triggeredOnStart:true;onTriggered:root.refresh()}
}

