import QtQuick
import Quickshell

import "../../theme" as Theme

Rectangle {
    id: root

    required property var wallpaper
    required property bool selected
    required property bool current
    readonly property bool isCurrent: root.current
    property int cardWidth: 300
    property int cardHeight: 185
    // Keep the decode size stable while the popup resizes. As in Caelestia,
    // use card-sized previews at the screen's device pixel ratio.
    readonly property real previewDpr: (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1

    readonly property real pathScale:
        PathView.onPath
            ? PathView.carouselScale
            : 0.0

    readonly property real pathOpacity:
        PathView.onPath
            ? PathView.carouselOpacity
            : 0.0

    readonly property real targetScale:
        root.selected
            ? root.pathScale
            : root.pathScale * 0.8

    readonly property real targetOpacity:
        root.pathOpacity

    readonly property int targetBorderWidth:
        root.selected ? 3 : hoverHandler.hovered ? 2 : 1

    readonly property color targetBorderColor:
        root.selected
            ? Theme.Color.primary
            : hoverHandler.hovered
                ? Theme.Color.surfaceVariant
                : Theme.Color.outline

    readonly property bool highlighted:
        root.selected || hoverHandler.hovered

    signal activated()
    signal hovered()

    width: root.cardWidth
    height: root.cardHeight

    radius: Theme.Style.radiusLarge
    clip: true
    border.width: root.targetBorderWidth
    border.color: root.targetBorderColor
    scale: root.targetScale
    opacity: root.targetOpacity
    transformOrigin: Item.Center

    color: root.selected ? Theme.Color.surfaceContainerHigh : Theme.Color.surfaceContainer

    Behavior on scale {
        NumberAnimation {
            duration: Theme.Style.launcherMotionPanel
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.Style.launcherMotionFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.width {
        NumberAnimation {
            duration: Theme.Style.launcherMotionFast
            easing.type: Easing.OutCubic
        }
    }

    Image {
        id: preview
        anchors.fill: parent
        source: root.wallpaper.path
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: !(root.PathView.view?.moving ?? false)
        sourceSize.width: Math.ceil(280 * root.previewDpr)
        sourceSize.height: Math.ceil(158 * root.previewDpr)
    }

    Rectangle {
        id: dimOverlay

        anchors.fill: parent
        color: root.selected || root.isCurrent
            ? "transparent"
            : "#000000"
        opacity: root.selected ? 0.10 : 0.18

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.Style.launcherMotionFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.selected ? 2 : 0
        border.color: Theme.Color.primary
        opacity: root.selected ? 1 : 0
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.Style.launcherMotionFast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: currentBadge
        anchors {
            right: parent.right
            top: parent.top
            margins: Theme.Style.spacingSmall
        }
        width: 12
        height: 12
        radius: Theme.Style.radiusFull
        color: root.isCurrent ? Theme.Color.primary : "transparent"
        border.width: root.isCurrent ? 2 : 0
        border.color: Theme.Color.surface
        opacity: root.isCurrent ? 0.95 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.Style.launcherMotionFast
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hovered)
                root.hovered()
        }
    }

    TapHandler {
        onTapped: root.activated()
    }
}
