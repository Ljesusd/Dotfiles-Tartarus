// SPDX-License-Identifier: GPL-3.0-only
// From ryoku-dev/ryoku, commit 98a0368253d9628be72b853985878a5db90e1547.
// Modified for Tartarus on 2026-10-10: imports, theme and service adapters.
// See LICENSE and NOTICE.md in this directory.
import QtQuick
import Quickshell.Widgets
import "../../../theme"

// The sleeve: one square plate that crossfades to the next cover instead of
// snapping, because the daemon resolves art asynchronously and a hard swap reads
// as a glitch mid-song. Two image slots alternate; the incoming one loads behind
// the outgoing one and is revealed once it has pixels.
Item {
    id: cover

    property string source: ""
    property real radius: 10
    property color plate: "#1a1a1a"
    property color ink: "#888888"
    property real s: 1

    property string frontSrc: ""
    property string backSrc: ""
    property bool showFront: true

    readonly property bool ready: (cover.showFront ? front.status : back.status) === Image.Ready

    onSourceChanged: {
        if (cover.source === (cover.showFront ? cover.frontSrc : cover.backSrc))
            return;
        if (cover.showFront) {
            cover.backSrc = cover.source;
            cover.showFront = false;
        } else {
            cover.frontSrc = cover.source;
            cover.showFront = true;
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: cover.radius
        color: cover.plate

        MaterialIcon {
            anchors.centerIn: parent
            visible: !cover.ready
            iconSize: Math.round(parent.width * 0.26)
            text: "music_note"
            iconColor: cover.ink
            opacity: 0.55
        }

        Image {
            id: front
            anchors.fill: parent
            source: cover.frontSrc
            opacity: cover.showFront && front.status === Image.Ready ? 1 : 0
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(cover.width * 2)
            sourceSize.height: Math.round(cover.height * 2)
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Image {
            id: back
            anchors.fill: parent
            source: cover.backSrc
            opacity: !cover.showFront && back.status === Image.Ready ? 1 : 0
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.round(cover.width * 2)
            sourceSize.height: Math.round(cover.height * 2)
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
    }

    // hairline rim, so a pale sleeve still reads as a seated plate.
    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
    }
}
