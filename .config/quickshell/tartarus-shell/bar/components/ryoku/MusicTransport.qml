// SPDX-License-Identifier: GPL-3.0-only
// From ryoku-dev/ryoku, commit 98a0368253d9628be72b853985878a5db90e1547.
// Modified for Tartarus on 2026-10-10: imports, theme and service adapters.
// See LICENSE and NOTICE.md in this directory.
pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"

// The three moves: reverse, play or pause, skip. Play/pause wears the sleeve's
// colour as the one filled tile, so the widget has a single focal control.
Row {
    id: transport

    property real s: 1
    property color accent: Color.primary
    property color ink: Color.foreground
    // ink for the one filled tile. Not named onAccent: QML would read that as a
    // change handler for `accent` and drop the assignment.
    property color inkOnAccent: Color.surface
    property bool active: true
    property bool playing: false
    property bool canPrevious: false
    property bool canNext: false
    property bool canToggle: false

    signal previous()
    signal toggle()
    signal next()

    spacing: 6 * transport.s

    component Move: Item {
        id: move
        property string glyph: ""
        property bool filled: false
        property bool live: true
        property bool pulsing: false
        signal activated()
        activeFocusOnTab: move.live
        Accessible.role: Accessible.Button
        Accessible.name: glyph === "skip_previous" ? "Anterior"
            : glyph === "skip_next" ? "Siguiente" : glyph === "pause" ? "Pausar" : "Reproducir"
        Accessible.onPressAction: if (move.live) move.activated()
        Keys.onSpacePressed: if (move.live) move.activated()
        Keys.onReturnPressed: if (move.live) move.activated()

        width: (move.filled ? 38 : 30) * transport.s
        height: move.width

        opacity: move.live ? 1 : 0.35

        // focal glow: the one filled tile sits on a soft accent seat that
        // breathes while the track plays, so the eye lands on play/pause first.
        Rectangle {
            visible: move.filled
            anchors.centerIn: parent
            width: parent.width + 12 * transport.s
            height: width
            radius: width / 2
            color: transport.accent
            opacity: 0.18
            SequentialAnimation on opacity {
                running: move.pulsing && move.visible && transport.active
                loops: Animation.Infinite
                NumberAnimation { to: 0.08; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.26; duration: 1000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: move.filled ? transport.accent
                : (hover.hovered ? Qt.rgba(transport.ink.r, transport.ink.g, transport.ink.b, 0.10)
                                 : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MaterialIcon {
            anchors.centerIn: parent
            iconSize: (move.filled ? 20 : 18) * transport.s
            text: move.glyph
            iconColor: move.filled ? transport.inkOnAccent : transport.ink
        }
        // press dip: the same physical acknowledgement the menu rows use.
        scale: tap.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tap
            enabled: move.live
            onTapped: move.activated()
        }
    }

    Move {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "skip_previous"
        live: transport.canPrevious
        onActivated: transport.previous()
    }
    Move {
        anchors.verticalCenter: parent.verticalCenter
        filled: true
        pulsing: transport.playing
        glyph: transport.playing ? "pause" : "play_arrow"
        live: transport.canToggle
        onActivated: transport.toggle()
    }
    Move {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "skip_next"
        live: transport.canNext
        onActivated: transport.next()
    }
}
