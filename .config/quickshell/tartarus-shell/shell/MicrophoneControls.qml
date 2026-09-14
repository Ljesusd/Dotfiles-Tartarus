import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell.Services.Pipewire
import "../theme"

ColumnLayout {
    id: root
    required property string deviceName
    spacing: Style.spacingSmall

    // Require a unique capture device. Never fall back to a different default mic.
    readonly property var matchingSources: Pipewire.nodes.values.filter(node => {
        if (!node || !node.audio || node.isSink || node.isStream)
            return false
        const tokens = root.deviceName.toLowerCase().match(/[a-z0-9]+/g) || []
        const names = [node.name, node.description, node.nickname].join(" ").toLowerCase()
        const words = names.match(/[a-z0-9]+/g) || []
        return tokens.length > 0 && tokens.every(token => words.indexOf(token) !== -1)
    })
    property var source: matchingSources.length === 1 ? matchingSources[0] : null
    readonly property bool available: !!(source && source.ready && source.audio)
    readonly property real volume: available ? source.audio.volume * 100 : 0
    readonly property bool muted: available ? source.audio.muted : false

    PwObjectTracker { objects: root.matchingSources }

    function setVolume(percent) {
        if (root.available && isFinite(percent))
            root.source.audio.volume = Math.max(0, Math.min(100, percent)) / 100
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Volumen de entrada"
            color: Color.foregroundMuted
            font.pixelSize: Style.fontSmall
        }
        Text {
            objectName: "microphonePercentage"
            text: root.available ? Math.round(volumeSlider.pressed ? volumeSlider.value : root.volume) + "%" : "—"
            color: Color.foreground
            font.pixelSize: Style.fontSmall
            font.bold: true
        }
    }

    Controls.Slider {
        id: volumeSlider
        objectName: "microphoneVolumeSlider"
        Layout.fillWidth: true
        implicitHeight: 32
        from: 0
        to: 100
        stepSize: 1
        enabled: root.available
        value: root.volume
        onMoved: root.setVolume(value)
        Accessible.name: "Volumen del micrófono " + root.deviceName

        // Preserve the drag position while PipeWire publishes updates.
        Binding {
            target: volumeSlider
            property: "value"
            value: root.volume
            when: !volumeSlider.pressed
            restoreMode: Binding.RestoreBindingOrValue
        }
        background: Rectangle {
            x: volumeSlider.leftPadding
            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
            width: volumeSlider.availableWidth
            height: 6
            radius: 3
            color: Color.outlineVariant
            Rectangle {
                width: volumeSlider.position * parent.width
                height: parent.height
                radius: parent.radius
                color: volumeSlider.enabled ? Color.primary : Color.foregroundMuted
            }
        }
        handle: Rectangle {
            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
            y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
            width: 18
            height: 18
            radius: 9
            color: volumeSlider.enabled ? Color.primary : Color.foregroundMuted
            border.width: volumeSlider.activeFocus ? 2 : 0
            border.color: Color.foreground
        }
    }

    Controls.Button {
        objectName: "microphoneMuteButton"
        text: root.muted ? "Activar micrófono" : "Silenciar micrófono"
        enabled: root.available
        implicitHeight: 32
        implicitWidth: 164
        onClicked: if (root.available) root.source.audio.muted = !root.source.audio.muted
        contentItem: Text {
            text: parent.text
            color: parent.enabled ? Color.foreground : Color.foregroundMuted
            font.pixelSize: Style.fontSmall
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Style.radiusSmall
            color: root.muted ? Color.primaryContainer : Color.surfaceContainerHigh
            border.width: 1
            border.color: Color.outlineVariant
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !root.available || root.muted
        text: !root.available ? "Micrófono no disponible para controlar."
            : "Micrófono silenciado; el volumen se conserva."
        wrapMode: Text.Wrap
        font.pixelSize: Style.fontSmall
        color: Color.foregroundMuted
    }
}
