import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services/WeatherModel.js" as Model

Rectangle {
    id: root
    required property var day
    required property string localNow
    readonly property real progress: {
        if (!root.day || root.day.date !== root.localNow.slice(0, 10)) return -1
        const start = Model.minutes(root.day.sunrise), end = Model.minutes(root.day.sunset)
        const now = Model.minutes(root.localNow.slice(11, 16))
        if (start === null || end === null || now === null || end <= start || now < start || now > end) return -1
        return (now - start) / (end - start)
    }
    implicitHeight: 176
    radius: Style.cardRadius
    color: Color.surfaceContainerHigh
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingMedium
        spacing: 5
        Text { text: "Sol y noche"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true }
        Canvas {
            id: arc
            Layout.fillWidth: true
            Layout.fillHeight: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (width <= 0 || height <= 0) return
                const x0 = 12, x1 = width - 12, y = height - 5
                function trace(limit) {
                    ctx.beginPath()
                    for (let i = 0; i <= 60; i++) {
                        const t = i / 60 * limit
                        const x = x0 + (x1 - x0) * t
                        const py = y - Math.sin(t * Math.PI) * (height - 16)
                        if (i === 0) ctx.moveTo(x, py); else ctx.lineTo(x, py)
                    }
                    ctx.stroke()
                }
                ctx.lineWidth = 2
                ctx.strokeStyle = Qt.alpha(Color.warning, 0.25)
                trace(1)
                if (root.progress >= 0) {
                    ctx.strokeStyle = Color.warning
                    trace(root.progress)
                    ctx.beginPath()
                    ctx.arc(x0 + (x1 - x0) * root.progress, y - Math.sin(root.progress * Math.PI) * (height - 16), 5, 0, Math.PI * 2)
                    ctx.fillStyle = Color.warning
                    ctx.fill()
                }
            }
        }
        Row {
            id: sunEvents
            Layout.fillWidth: true
            Repeater {
                model: [
                    { label: "Amanecer", time: root.day ? root.day.sunrise : "", icon: "wb_twilight" },
                    { label: "Atardecer", time: root.day ? root.day.sunset : "", icon: "sunny" },
                    { label: "Anochecer ≈", time: root.day ? root.day.dusk : "", icon: "clear_night" }
                ]
                delegate: Column {
                    required property var modelData
                    width: sunEvents.width / 3
                    spacing: 2
                    Row {
                        spacing: 4
                        MaterialIcon { text: modelData.icon; iconSize: 15; iconColor: Color.warning }
                        Text { text: modelData.time || "—"; color: Color.foreground; font.pixelSize: 15; font.bold: true }
                    }
                    Text { text: modelData.label; color: Color.foregroundMuted; font.pixelSize: 11 }
                }
            }
        }
        Text { text: "Anochecer: fin del crepúsculo civil, estimado"; color: Color.foregroundSubtle; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
    onProgressChanged: arc.requestPaint()
    Connections { target: Color; function onWarningChanged() { arc.requestPaint() } }
}
