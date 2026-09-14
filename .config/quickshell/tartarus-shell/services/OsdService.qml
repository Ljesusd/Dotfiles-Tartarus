pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQml

Singleton {
    id: root
    property string kind: ""
    property real value: 0
    property bool muted: false
    property int serial: 0
    property bool active: false
    property string screenName: ""
    readonly property Timer expiry: Timer {
        interval: 1800
        onTriggered: root.active = false
    }

    function show(type, amount, isMuted) {
        kind = type
        value = Number(amount) || 0
        muted = Boolean(isMuted)
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        active = screenName.length > 0
        serial++
        expiry.restart()
    }

    function showCurrentVolume(): void {
        const sink = Pipewire.defaultAudioSink
        if (sink && sink.audio)
            root.show("volume", Math.round(sink.audio.volume * 100), sink.audio.muted)
    }
}
