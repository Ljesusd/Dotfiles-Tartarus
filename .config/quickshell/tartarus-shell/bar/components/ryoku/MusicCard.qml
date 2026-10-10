// SPDX-License-Identifier: GPL-3.0-only
// From ryoku-dev/ryoku, commit 98a0368253d9628be72b853985878a5db90e1547.
// Modified for Tartarus on 2026-10-10: imports, theme and service adapters.
// See LICENSE and NOTICE.md in this directory.
import QtQuick
import Quickshell.Widgets
import "../../../theme"

// The record's own card: the sleeve bled across the plate and washed out until
// only its colour is left, so the widget wears whatever is playing. The bleed is
// a heavily downscaled copy of the cover rather than a blur pass, which costs one
// small texture instead of an offscreen effect on a layer that must idle.
ClippingRectangle {
    id: card

    property string art: ""
    property color accent: Color.primary
    property real s: 1
    property bool hovered: false
    property bool showArtwork: true

    property color plate: Color.surface

    radius: Style.panelRadius * card.s
    color: card.plate
    contentUnderBorder: true
    border.width: 1
    border.color: card.hovered ? Qt.alpha(card.accent, 0.35) : Qt.alpha(card.accent, 0.18)

    Behavior on border.color { ColorAnimation { duration: 120 } }

    Image {
        anchors.fill: parent
        source: card.art
        visible: card.showArtwork && card.art.length > 0
        asynchronous: true
        cache: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
        // 64 px of sleeve stretched over the card: the colour survives, the
        // detail does not.
        sourceSize.width: 64
        sourceSize.height: 64
        opacity: 0.55
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // the wash: the plate again over the bleed, then a fade to the right so the
    // lyric column sits on a calm field instead of on album detail.
    Rectangle {
        anchors.fill: parent
        color: card.plate
        opacity: 0.80
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(card.plate.r, card.plate.g, card.plate.b, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(card.plate.r, card.plate.g, card.plate.b, 0.55) }
        }
    }
    // top sheen: a faint lit edge so the plate reads as lit glass rather than a
    // flat fill.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
}
