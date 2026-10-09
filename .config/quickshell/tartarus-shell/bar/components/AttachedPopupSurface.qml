import QtQuick

import "../../theme"

Canvas {
    id: root

    property color fillColor: Color.surfaceContainer
    // Caelestia's BlobInvertedRect keeps the whole lower edge attached to
    // the bar. The shoulders, rather than a small centred tab, create the
    // connected-drawer silhouette shared with the launcher.
    property real surfaceInset: 14
    property real joinRadius: 18
    property real neckHeight: Style.barPopupGap * 2
    property real cornerRadius: Style.panelRadius
    property color outlineColor: Qt.alpha(Color.foreground, 0.12)
    property color shadowColor: Qt.rgba(0, 0, 0, Color.mode === "light" ? 0.16 : 0.32)

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onSurfaceInsetChanged: requestPaint()
    onJoinRadiusChanged: requestPaint()
    onNeckHeightChanged: requestPaint()
    onOutlineColorChanged: requestPaint()
    onShadowColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const w = width
        const h = height
        const bottom = Math.max(0, h - neckHeight)
        const inset = Math.min(
            Math.max(0, surfaceInset),
            Math.max(0, (w - 2) / 2)
        )
        const left = inset
        const right = w - inset
        const r = Math.min(cornerRadius, (right - left) / 4, bottom / 3)
        const join = Math.min(
            joinRadius,
            neckHeight,
            inset,
            Math.max(1, (right - left) / 8)
        )

        ctx.beginPath()
        ctx.moveTo(left + r, 0)
        ctx.lineTo(right - r, 0)
        ctx.quadraticCurveTo(right, 0, right, r)
        ctx.lineTo(right, bottom - r)
        ctx.quadraticCurveTo(right, bottom, right - r, bottom)
        // The lower bridge is intentionally wide: this is the same shared
        // edge that Caelestia's SDF group forms against its bar.
        ctx.quadraticCurveTo(right + join, bottom, right + join, bottom + join)
        ctx.lineTo(right + join, h)
        ctx.lineTo(left - join, h)
        ctx.lineTo(left - join, bottom + join)
        ctx.quadraticCurveTo(left - join, bottom, left, bottom)
        ctx.quadraticCurveTo(left, bottom, left, bottom - r)
        ctx.lineTo(left, r)
        ctx.quadraticCurveTo(left, 0, left + r, 0)
        ctx.closePath()
        ctx.shadowColor = shadowColor
        ctx.shadowBlur = 12
        ctx.shadowOffsetY = -1
        ctx.fillStyle = fillColor
        ctx.fill()
        ctx.shadowColor = "transparent"
        ctx.shadowBlur = 0
        ctx.lineWidth = 1
        ctx.strokeStyle = outlineColor
        ctx.stroke()
    }
}
