import QtQuick

import "../../theme"

Item {
    id: root

    property real progress: 1
    property color accent: Color.warning

    implicitWidth: Style.barIconSmall + Style.spacingXs
    implicitHeight: implicitWidth

    Behavior on progress {
        NumberAnimation { duration: 800; easing.type: Easing.Linear }
    }

    Canvas {
        id: dial
        anchors.fill: parent
        onAvailableChanged: requestPaint()
        onPaint: {
            const context = getContext("2d")
            const cx = width / 2
            const cy = height / 2
            const radius = Math.min(width, height) / 2 - 2.5
            const remaining = Math.max(0, Math.min(1, root.progress))
            const start = -Math.PI / 2
            const end = start + remaining * Math.PI * 2

            context.clearRect(0, 0, width, height)
            context.lineWidth = 2.4
            context.lineCap = "round"
            context.strokeStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
            context.beginPath()
            context.arc(cx, cy, radius, 0, Math.PI * 2)
            context.stroke()

            if (remaining > 0) {
                context.strokeStyle = root.accent
                context.beginPath()
                context.arc(cx, cy, radius, start, end)
                context.stroke()
            }

            context.fillStyle = root.accent
            context.beginPath()
            context.arc(cx + Math.cos(end) * radius,
                        cy + Math.sin(end) * radius, 2.5, 0, Math.PI * 2)
            context.fill()
        }
    }

    onProgressChanged: dial.requestPaint()
    onAccentChanged: dial.requestPaint()
}
