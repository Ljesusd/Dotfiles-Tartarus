import QtQuick
import "../../theme"

// Caelestia's connected drawer silhouette, adapted for Tartarus's bottom bar.
// The outer curve flares into the bar; the baseline has no separating stroke.
Item {
    id: root
    property bool opened: false
    property real reveal: opened ? 1 : 0
    readonly property int shadowPadding: 14
    readonly property int joinRadius: 20
    readonly property int horizontalInset: shadowPadding + joinRadius
    property real contentWidth: Math.max(0, width - horizontalInset * 2)
    property real contentHeight: Math.max(0, height - shadowPadding)
    property color fillColor: Color.surfaceContainer
    property color outlineColor: Qt.alpha(Color.foreground, 0.14)
    property color shadowColor: Qt.rgba(0, 0, 0, Color.mode === "light" ? 0.2 : 0.35)
    readonly property alias contentItem: content
    readonly property alias maskItem: frame
    signal closed()

    clip: true
    opacity: Math.min(1, reveal * 3)
    onRevealChanged: {
        if (reveal === 0 && !opened) closed()
    }
    onFillColorChanged: background.requestPaint()
    onOutlineColorChanged: background.requestPaint()
    onShadowColorChanged: background.requestPaint()
    Behavior on reveal {
        NumberAnimation { duration: Style.launcherMotionPanel; easing.type: Easing.OutCubic }
    }

    Item {
        id: frame
        x: (root.width - width) / 2
        y: root.height - height * root.reveal
        width: root.contentWidth + root.horizontalInset * 2
        height: root.contentHeight + root.shadowPadding
        clip: true
        Behavior on width {
            enabled: root.opened && root.reveal === 1
            NumberAnimation { duration: Style.launcherMotionPanel; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: root.opened && root.reveal === 1
            NumberAnimation { duration: Style.launcherMotionPanel; easing.type: Easing.OutCubic }
        }

        Canvas {
            id: background
            // Draw once at the destination size, then transform the cached
            // texture. Neither the shadow nor the page is rerasterized/reflowed
            // for every intermediate size of the animated surface.
            width: root.contentWidth + root.horizontalInset * 2
            height: root.contentHeight + root.shadowPadding
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            transform: Scale {
                xScale: background.width > 0 ? frame.width / background.width : 1
                yScale: background.height > 0 ? frame.height / background.height : 1
            }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            const top = root.shadowPadding
            const available = Math.max(0, height - top)
            if (available < 1 || width <= root.horizontalInset * 2) return
            const left = root.horizontalInset, right = width - left
            const radius = Math.min(Style.panelRadius, (right - left) / 4, available / 3)
            const join = Math.min(root.joinRadius, available / 3)

            ctx.beginPath()
            ctx.moveTo(left - join, height)
            ctx.quadraticCurveTo(left, height, left, height - join)
            ctx.lineTo(left, top + radius)
            ctx.quadraticCurveTo(left, top, left + radius, top)
            ctx.lineTo(right - radius, top)
            ctx.quadraticCurveTo(right, top, right, top + radius)
            ctx.lineTo(right, height - join)
            ctx.quadraticCurveTo(right, height, right + join, height)
            // fill() closes the base; stroke() keeps the contour open at the bar.
            ctx.shadowColor = root.shadowColor
            ctx.shadowBlur = 12
            ctx.shadowOffsetY = -1
            ctx.fillStyle = root.fillColor
            ctx.fill()
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
            ctx.lineWidth = 1
            ctx.strokeStyle = root.outlineColor
            ctx.stroke()
        }
        }

        Item {
            id: content
            x: (frame.width - width) / 2
            y: frame.height - height
            width: root.contentWidth
            height: root.contentHeight
            enabled: root.opened
            // Final layout size even while frame width/height are animating.
            clip: true
        }
    }
}
