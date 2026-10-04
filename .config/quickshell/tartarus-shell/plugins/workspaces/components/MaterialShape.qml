import QtQuick
import "../../../theme"

Item {
    id: root

    enum Shape {
        Circle,
        Square,
        Pill,
        Diamond,
        Triangle,
        SoftBurst
    }

    property int shape: MaterialShape.Circle
    property color color: "white"
    property real animationProgress: 1
    property int animationDuration: Style.motionNormal
    property real scale: 1

    implicitWidth: 20
    implicitHeight: 20

    Behavior on scale {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutBack
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        scale: root.scale
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            const cx = w / 2
            const cy = h / 2
            const r = Math.min(w, h) / 2

            ctx.reset()
            ctx.fillStyle = root.color
            ctx.beginPath()

            function roundedRect(x, y, width, height, radius) {
                const r = Math.min(radius, width / 2, height / 2)
                ctx.moveTo(x + r, y)
                ctx.lineTo(x + width - r, y)
                ctx.arcTo(x + width, y, x + width, y + r, r)
                ctx.lineTo(x + width, y + height - r)
                ctx.arcTo(x + width, y + height,
                    x + width - r, y + height, r)
                ctx.lineTo(x + r, y + height)
                ctx.arcTo(x, y + height, x, y + height - r, r)
                ctx.lineTo(x, y + r)
                ctx.arcTo(x, y, x + r, y, r)
                ctx.closePath()
            }

            if (root.shape === MaterialShape.Circle) {
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
            } else if (root.shape === MaterialShape.Square) {
                const inset = Math.min(w, h) * 0.16
                roundedRect(inset, inset, w - inset * 2,
                    h - inset * 2, inset)
            } else if (root.shape === MaterialShape.Pill) {
                roundedRect(0, h * 0.16, w, h * 0.68, h * 0.34)
            } else {
                ctx.moveTo(cx, 0)
                ctx.lineTo(w, cy)
                ctx.lineTo(cx, h)
                ctx.lineTo(0, cy)
                ctx.closePath()
            }

            ctx.fill()
        }

        Connections {
            target: root
            function onShapeChanged() { canvas.requestPaint() }
            function onColorChanged() { canvas.requestPaint() }
            function onWidthChanged() { canvas.requestPaint() }
            function onHeightChanged() { canvas.requestPaint() }
        }
    }
}
