import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

import "../../theme"

Item {
    id: root

    implicitWidth: Style.barControlHeight
    implicitHeight: Style.barControlHeight
    property string avatarPath: ""

    Process {
        id: avatarFinder

        command: [
            "sh",
            "-c",
            "find \"" + Quickshell.env("HOME") + "/.face\" -type f "
                + "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' "
                + "-o -iname '*.webp' \\) -print -quit"
        ]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                root.avatarPath = String(text).trim()
            }
        }
    }

    Component.onCompleted: avatarFinder.running = true

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusFull
        clip: true
        color: hoverHandler.hovered
            ? Color.surfaceHover
            : Color.surfaceContainerHigh

        Behavior on color {
            ColorAnimation { duration: Style.motionFast }
        }

        Image {
            id: avatar

            anchors.fill: parent
            anchors.margins: 4
            source: root.avatarPath ? "file://" + root.avatarPath : ""
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: false
        }

        Rectangle {
            id: avatarMask

            anchors.fill: avatar
            radius: width / 2
            color: "white"
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: avatar
            source: avatar
            visible: avatar.status === Image.Ready
            maskEnabled: true
            maskSource: avatarMask
            autoPaddingEnabled: false
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "person"
            iconSize: Style.barIconSmall
            iconColor: Color.foreground
            visible: avatar.status !== Image.Ready
        }
    }

    HoverHandler { id: hoverHandler }
}
