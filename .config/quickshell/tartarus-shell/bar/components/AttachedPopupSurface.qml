import QtQuick

import "../../theme"

Canvas {
    id: root

    property color fillColor: Color.surfaceContainer
    property real neckCenter: width / 2
    property real neckWidth: width
    property real neckHeight: 10
    property real cornerRadius: Style.panelRadius

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onNeckCenterChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const w = width
        const h = height
        const bottom = h - neckHeight
        const r = Math.min(cornerRadius, w / 4, bottom / 4)
        const join = Math.min(10, neckHeight)
        const fullWidthBase = neckWidth >= w - 2 * r
        const left = Math.max(r + join, Math.min(w - r - join - neckWidth, neckCenter - neckWidth / 2))
        const right = left + neckWidth

        ctx.beginPath()
        ctx.moveTo(r, 0)
        ctx.lineTo(w - r, 0)
        ctx.quadraticCurveTo(w, 0, w, r)
        if (fullWidthBase) {
            ctx.lineTo(w, bottom)
            ctx.lineTo(w, h)
            ctx.lineTo(0, h)
            ctx.lineTo(0, bottom)
        } else {
            ctx.lineTo(w, bottom - r)
            ctx.quadraticCurveTo(w, bottom, w - r, bottom)
            ctx.lineTo(right + join, bottom)
            ctx.quadraticCurveTo(right, bottom, right, bottom + join)
            ctx.lineTo(right, h)
            ctx.lineTo(left, h)
            ctx.lineTo(left, bottom + join)
            ctx.quadraticCurveTo(left, bottom, left - join, bottom)
            ctx.lineTo(r, bottom)
            ctx.quadraticCurveTo(0, bottom, 0, bottom - r)
        }
        ctx.lineTo(0, r)
        ctx.quadraticCurveTo(0, 0, r, 0)
        ctx.closePath()
        ctx.fillStyle = fillColor
        ctx.fill()
    }
}
