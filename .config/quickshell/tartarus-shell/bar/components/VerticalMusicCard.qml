// SPDX-License-Identifier: GPL-3.0-only
// Vertical artwork-first composition inspired by ryoku-dev/ryotunes MiniPlayer.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell.Widgets
import "../../services" as Services
import "../../theme"
import "ryoku" as Ryoku
import "ryoku/ArtColor.js" as ArtColor

ClippingRectangle {
    id: root
    required property bool active
    property var service: Services.MediaService
    readonly property var player: service.activePlayer
    readonly property bool wanted: active && visible
    readonly property real duration: player?.lengthSupported && Number.isFinite(player.length)
        ? Math.max(0, player.length) : 0
    readonly property real position: duration > 0 && (player?.positionSupported ?? false)
        ? Math.max(0, Math.min(duration, player.position)) : 0
    readonly property bool seekable: wanted && duration > 0
        && (player?.canSeek ?? false) && (player?.positionSupported ?? false)
    readonly property color accent: ArtColor.accentOf(palette.colors, Color.primary)
    property var gesturePlayer: null
    property int gestureTrack: -1
    implicitWidth: 320
    implicitHeight: 540
    radius: 30
    color: "transparent"
    contentUnderBorder: true
    border.width: 2
    border.color: Qt.alpha(root.accent, 0.55)

    MusicPalette {
        id: palette
        source: root.wanted ? root.service.artUrl : ""
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.wanted && root.duration > 0 && root.service.playing
        onTriggered: root.service.refreshPosition()
    }

    Ryoku.MusicCard {
        anchors.fill: parent
        art: root.service.artUrl
        accent: root.accent
        plate: Color.surface
        hovered: false
        showArtwork: false
    }

    Image {
        id: cover
        anchors.fill: parent
        source: root.service.artUrl
        sourceSize: Qt.size(640, 1080)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: status === Image.Ready ? 0.93 : 0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: "music_note"
        iconSize: 56
        iconColor: Color.foregroundMuted
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.08) }
            GradientStop { position: 0.42; color: Qt.rgba(0, 0, 0, 0.08) }
            GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.68) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.92) }
        }
    }

    ColumnLayout {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 18 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.service.title || "Sin reproducción"
                color: "white"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                visible: root.duration > 0
                text: root.service.formatTime(root.position) + " / " + root.service.formatTime(root.duration)
                color: Qt.rgba(1, 1, 1, 0.72)
                font.pixelSize: 10
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.service.artist || root.service.identity || ""
            color: Qt.rgba(1, 1, 1, 0.72)
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        SungSeekBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            position: root.position
            duration: root.duration
            accent: root.accent
            restColor: Qt.rgba(1, 1, 1, 0.34)
            playing: root.service.playing
            seekable: root.seekable
            onSeekStarted: {
                root.gesturePlayer = root.player
                root.gestureTrack = root.player?.uniqueId ?? -1
            }
            onSeekRequested: seconds => root.service.seekTo(seconds, root.gesturePlayer, root.gestureTrack)
            onSeekFinished: { root.gesturePlayer = null; root.gestureTrack = -1 }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            MediaButton { symbol: "skip_previous"; enabled: root.service.canPrevious; onClicked: root.service.command("previous") }
            MediaButton {
                symbol: root.service.playing ? "pause" : "play_arrow"
                primary: true
                enabled: root.service.canToggle
                onClicked: root.service.command("play-pause")
            }
            MediaButton { symbol: "skip_next"; enabled: root.service.canNext; onClicked: root.service.command("next") }
        }
    }

    // A quiet inner highlight gives the card a defined edge over bright
    // wallpapers without adding a blur or shadow pass.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: root.radius - 3
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        enabled: false
    }

    component MediaButton: Controls.Button {
        id: button
        property string symbol: ""
        property bool primary: false
        implicitWidth: primary ? 48 : 36
        implicitHeight: implicitWidth
        opacity: enabled ? 1 : 0.42
        contentItem: MaterialIcon {
            text: button.symbol
            iconSize: button.primary ? 25 : 21
            iconColor: button.primary ? Color.onPrimary : "white"
        }
        background: Rectangle {
            radius: height / 2
            color: button.primary ? root.accent : Qt.rgba(0, 0, 0, 0.36)
            border.width: 1
            border.color: button.primary ? Qt.alpha(root.accent, 0.8) : Qt.rgba(1, 1, 1, 0.22)
        }
    }
}
