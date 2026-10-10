// SPDX-License-Identifier: GPL-3.0-only
// Layout adapted from ryoku-dev/ryoku MusicWidget.qml, 2026-10-10.
// See ryoku/NOTICE.md and ryoku/LICENSE.
import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../services" as Services
import "../../theme"
import "ryoku" as Ryoku
import "ryoku/ArtColor.js" as ArtColor

Item {
    id: root
    required property bool active
    property var service: Services.MediaService
    property bool showClose: true
    readonly property var player: service.activePlayer
    readonly property bool wanted: active && visible
    readonly property real duration: player?.lengthSupported && Number.isFinite(player.length)
        ? Math.max(0, player.length) : 0
    readonly property bool hasProgress: duration > 0 && (player?.positionSupported ?? false)
    readonly property real position: hasProgress && Number.isFinite(player.position)
        ? Math.max(0, Math.min(duration, player.position)) : 0
    readonly property real coverSize: Math.min(168, (width - 32) * 0.43)
    property var gesturePlayer: null
    property int gestureTrack: -1
    signal closeRequested()
    implicitWidth: 560
    implicitHeight: body.implicitHeight + 32

    MusicPalette {
        id: palette
        source: root.wanted ? root.service.artUrl : ""
    }
    readonly property color sleeveAccent: ArtColor.accentOf(palette.colors, Color.primary)

    HoverHandler { id: hover }
    Ryoku.MusicCard {
        anchors.fill: parent
        art: root.service.artUrl
        accent: root.sleeveAccent
        plate: ArtColor.plateOf(root.sleeveAccent, Color.surface)
        hovered: hover.hovered
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.wanted && root.hasProgress && root.service.playing
        onTriggered: root.service.refreshPosition()
    }

    ColumnLayout {
        id: body
        x: 16; y: 16
        width: parent.width - 32
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            MaterialIcon { text: "music_note"; iconSize: 18; iconColor: root.sleeveAccent }
            Text {
                Layout.fillWidth: true
                text: root.service.identity || "Música"
                textFormat: Text.PlainText
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
                elide: Text.ElideRight
            }
            Controls.Button {
                id: closeButton
                visible: root.showClose
                implicitWidth: 24; implicitHeight: 24
                Accessible.name: "Cerrar tarjeta"
                onClicked: root.closeRequested()
                contentItem: MaterialIcon { text: "close"; iconSize: 18; iconColor: Color.foreground }
                background: Rectangle { radius: 12; color: closeButton.hovered ? Color.surfaceHover : "transparent" }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.coverSize
            spacing: 14
            Ryoku.MusicCover {
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                source: root.service.artUrl
                plate: Color.surfaceContainerHigh
                ink: Color.foregroundMuted
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: root.service.title || "Sin reproducción"
                    textFormat: Text.PlainText
                    color: Color.foreground
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.service.artist
                    textFormat: Text.PlainText
                    color: Color.foregroundMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            Text {
                Layout.alignment: Qt.AlignBottom
                visible: root.hasProgress
                text: root.service.formatTime(root.position) + " / " + root.service.formatTime(root.duration)
                color: Color.foregroundMuted
                font.family: "monospace"
                font.pixelSize: 10
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 14
            Ryoku.MusicSeek {
                Layout.fillWidth: true
                frac: root.duration > 0 ? root.position / root.duration : 0
                opacity: root.hasProgress ? 1 : 0.35
                live: root.wanted && root.service.playing
                accent: root.sleeveAccent
                track: Qt.alpha(Color.foreground, 0.16)
                seekable: root.wanted && root.hasProgress && (root.player?.canSeek ?? false)
                onSeekStarted: {
                    root.gesturePlayer = root.player
                    root.gestureTrack = root.player?.uniqueId ?? -1
                }
                onSeekRequested: fraction => root.service.seekTo(
                    fraction * root.duration, root.gesturePlayer, root.gestureTrack)
                onSeekFinished: root.gesturePlayer = null
            }
            Ryoku.MusicTransport {
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 38
                active: root.wanted
                accent: root.sleeveAccent
                ink: Color.foreground
                inkOnAccent: Color.surface
                playing: root.service.playing
                canPrevious: root.wanted && root.service.canPrevious
                canNext: root.wanted && root.service.canNext
                canToggle: root.wanted && root.service.canToggle
                onPrevious: root.service.command("previous")
                onNext: root.service.command("next")
                onToggle: root.service.command("play-pause")
            }
        }
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: root.service.players.length > 1
            contentWidth: playersRow.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: playersRow
                spacing: 6
                Repeater {
                    model: root.service.players
                    delegate: Controls.Button {
                        id: choice
                        required property var modelData
                        height: 30
                        text: modelData.identity || "Reproductor"
                        Accessible.name: "Seleccionar " + text
                        onClicked: root.service.selectPlayer(modelData)
                        contentItem: Text { text: choice.text; textFormat: Text.PlainText; color: Color.foreground; font.pixelSize: 12 }
                        background: Rectangle {
                            radius: Style.controlRadius
                            color: choice.modelData === root.player ? Color.primaryContainer : Color.surfaceContainerHigh
                            border.width: choice.modelData === root.player || choice.activeFocus ? 1 : 0
                            border.color: Color.primary
                        }
                    }
                }
            }
        }
    }

}
