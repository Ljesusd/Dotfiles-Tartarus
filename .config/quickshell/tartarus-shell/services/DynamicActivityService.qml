pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "." as Services

QtObject {
    id: root

    // Optional integrations. They stay false when the corresponding program is absent.
    property bool recordingActive: false
    property bool vpnActive: false
    property bool easyEffectsActive: false
    property bool localSendActive: false
    property bool timerActive: false

    readonly property bool mediaActive:
        Services.MediaService.available
        && (Services.MediaService.playing
            || String(Services.MediaService.identity || "").toLowerCase().includes("sung"))
    readonly property bool notificationsActive:
        Services.NotificationService.notifications.count > 0
    readonly property int notificationCount:
        Services.NotificationService.notifications.count
    readonly property string mediaTitle:
        Services.MediaService.title || Services.MediaService.identity || "Reproduciendo"

    function refresh() {
        if (!probe.running) probe.running = true
    }

    property Process probe: Process {
        command: ["sh", "-c", ""
            + "recording=0; "
            + "(pgrep -x wf-recorder >/dev/null || pgrep -x gpu-screen-recorder >/dev/null || "
            + "pgrep -x obs >/dev/null || pgrep -x kooha >/dev/null) && recording=1; "
            + "vpn=0; command -v nmcli >/dev/null && "
            + "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^vpn:connected$' && vpn=1; "
            + "effects=0; pgrep -x easyeffects >/dev/null && effects=1; "
            + "localsend=0; pgrep -f '(^|/)localsend($| )' >/dev/null && localsend=1; "
            + "printf 'recording=%s\\nvpn=%s\\neffects=%s\\nlocalsend=%s\\n' \"$recording\" \"$vpn\" \"$effects\" \"$localsend\""
        ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const values = {}
                String(text).trim().split("\n").forEach(line => {
                    const pair = line.split("=")
                    if (pair.length === 2) values[pair[0]] = pair[1] === "1"
                })
                root.recordingActive = values.recording === true
                root.vpnActive = values.vpn === true
                root.easyEffectsActive = values.effects === true
                root.localSendActive = values.localsend === true
            }
        }
    }

    property Timer poller: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
