import QtQuick

import "../../theme"

Item {
    id: root

    required property string imagePath

    property real userScale: 1.0
    property real offsetX: 0
    property real offsetY: 0
    property real maxUserScale: 8.0
    property bool drawing: false
    property color drawingColor: "#ff5555"
    property int drawingWidth: 4
    property var strokes: []

    readonly property string source:
        root.imagePath.length > 0
            ? "file://" + root.imagePath
            : ""

    readonly property real sourceWidth:
        image.implicitWidth

    readonly property real sourceHeight:
        image.implicitHeight

    readonly property real fitScale:
        root.computeFitScale()

    readonly property real effectiveScale:
        root.fitScale * root.userScale

    Rectangle {
        anchors.fill: parent
        color: Color.backgroundAlt
    }

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        Image {
            id: image

            source: root.source
            asynchronous: true
            cache: false
            smooth: true
            visible: root.source.length > 0

            width: implicitWidth * root.effectiveScale
            height: implicitHeight * root.effectiveScale

            x: (root.width - width) / 2 + root.offsetX
            y: (root.height - height) / 2 + root.offsetY
        }

        Canvas {
            id: drawingCanvas
            anchors.fill: parent
            visible: root.drawing
            z: 2

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = root.drawingColor
                ctx.lineWidth = root.drawingWidth
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                for (const stroke of root.strokes) {
                    if (stroke.length < 2) continue
                    ctx.beginPath()
                    ctx.moveTo(stroke[0].x, stroke[0].y)
                    for (let i = 1; i < stroke.length; ++i)
                        ctx.lineTo(stroke[i].x, stroke[i].y)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: root.drawing
            z: 3
            acceptedButtons: Qt.LeftButton
            property var currentStroke: []

            onPressed: function(mouse) {
                currentStroke = [{ x: mouse.x, y: mouse.y }]
                root.strokes = root.strokes.concat([currentStroke])
            }
            onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.LeftButton)) return
                currentStroke.push({ x: mouse.x, y: mouse.y })
                drawingCanvas.requestPaint()
            }
            onReleased: drawingCanvas.requestPaint()
        }

        MouseArea {
            id: interactionArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true

            property real lastX: 0
            property real lastY: 0

            onPressed: function(mouse) {
                interactionArea.lastX = mouse.x
                interactionArea.lastY = mouse.y
            }

            onPositionChanged: function(mouse) {
                if (!(mouse.buttons & Qt.LeftButton))
                    return

                const dx =
                    mouse.x - interactionArea.lastX
                const dy =
                    mouse.y - interactionArea.lastY

                root.offsetX += dx
                root.offsetY += dy

                interactionArea.lastX = mouse.x
                interactionArea.lastY = mouse.y

                root.clampOffsets()
            }

            onWheel: function(wheel) {
                const factor =
                    wheel.angleDelta.y > 0
                        ? 1.12
                        : 1 / 1.12

                root.zoomAt(
                    wheel.x,
                    wheel.y,
                    factor
                )

                wheel.accepted = true
            }
        }
    }

    function computeFitScale() {
        if (
            root.sourceWidth <= 0
            || root.sourceHeight <= 0
            || root.width <= 0
            || root.height <= 0
        )
            return 1.0

        return Math.min(
            root.width / root.sourceWidth,
            root.height / root.sourceHeight
        )
    }

    function resetView() {
        root.userScale = 1.0
        root.offsetX = 0
        root.offsetY = 0
    }

    function clearDrawing() {
        root.strokes = []
        drawingCanvas.requestPaint()
    }

    function zoomIn() {
        root.zoomAt(
            root.width / 2,
            root.height / 2,
            1.12
        )
    }

    function zoomOut() {
        root.zoomAt(
            root.width / 2,
            root.height / 2,
            1 / 1.12
        )
    }

    function clampOffsets() {
        if (
            root.sourceWidth <= 0
            || root.sourceHeight <= 0
        ) {
            root.offsetX = 0
            root.offsetY = 0
            return
        }

        const scaledWidth =
            root.sourceWidth * root.effectiveScale
        const scaledHeight =
            root.sourceHeight * root.effectiveScale
        const maxOffsetX =
            Math.max(0, (scaledWidth - root.width) / 2)
        const maxOffsetY =
            Math.max(0, (scaledHeight - root.height) / 2)

        root.offsetX = Math.max(
            -maxOffsetX,
            Math.min(maxOffsetX, root.offsetX)
        )
        root.offsetY = Math.max(
            -maxOffsetY,
            Math.min(maxOffsetY, root.offsetY)
        )
    }

    function zoomAt(mouseX, mouseY, factor) {
        if (
            root.sourceWidth <= 0
            || root.sourceHeight <= 0
        )
            return

        const oldScale = root.effectiveScale
        const oldLeft =
            (root.width - root.sourceWidth * oldScale) / 2
            + root.offsetX
        const oldTop =
            (root.height - root.sourceHeight * oldScale) / 2
            + root.offsetY

        const imageX =
            (mouseX - oldLeft) / oldScale
        const imageY =
            (mouseY - oldTop) / oldScale

        root.userScale = Math.max(
            1.0,
            Math.min(
                root.maxUserScale,
                root.userScale * factor
            )
        )

        const newScale = root.effectiveScale
        const centeredLeft =
            (root.width - root.sourceWidth * newScale) / 2
        const centeredTop =
            (root.height - root.sourceHeight * newScale) / 2

        root.offsetX =
            mouseX - imageX * newScale - centeredLeft
        root.offsetY =
            mouseY - imageY * newScale - centeredTop

        root.clampOffsets()
    }

    onImagePathChanged: {
        root.resetView()
    }

    onWidthChanged: {
        root.clampOffsets()
    }

    onHeightChanged: {
        root.clampOffsets()
    }
}
