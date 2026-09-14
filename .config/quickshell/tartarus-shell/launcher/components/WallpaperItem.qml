import QtQuick

import "../../theme"

Rectangle {
    id: root

    required property var wallpaper
    required property bool selected
    required property bool current
    readonly property bool isCurrent: root.current
    property int cardWidth: 300
    property int cardHeight: 185

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
            ? Color.primary
            : hoverHandler.hovered
                ? Color.surfaceVariant
                : Color.outline

    readonly property bool highlighted:
        root.selected || hoverHandler.hovered

    signal activated()
    signal hovered()

    width: root.cardWidth
    height: root.cardHeight

    radius: Style.radiusLarge
    clip: true
    border.width: root.targetBorderWidth
    border.color: root.targetBorderColor
    scale: root.targetScale
    opacity: root.targetOpacity
    transformOrigin: Item.Center

    color: root.selected ? Color.surfaceContainerHigh : Color.surfaceContainer

    Behavior on scale {
        NumberAnimation {
            duration: Style.motionSlow
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Style.motionSlow
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.width {
        NumberAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Image {
        id: preview
        anchors.fill: parent
        source: root.wallpaper.path
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        sourceSize.width: 768
        sourceSize.height: 432
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
                duration: Style.motionFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.selected ? 2 : 0
        border.color: Color.primary
        opacity: root.selected ? 1 : 0
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: currentBadge
        anchors {
            right: parent.right
            top: parent.top
            margins: Style.spacingSmall
        }
        width: 12
        height: 12
        radius: Style.radiusFull
        color: root.isCurrent ? Color.primary : "transparent"
        border.width: root.isCurrent ? 2 : 0
        border.color: Color.surface
        opacity: root.isCurrent ? 0.95 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Style.motionFast
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
