// Slider adapted from Sung/qml/SeekBar.qml.
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property real position
    required property real duration
    property color accent: "#ffffff"
    property color restColor: Qt.rgba(1, 1, 1, 0.30)
    property bool playing: false
    property bool seekable: false
    signal seekRequested(real seconds)
    signal seekStarted()
    signal seekFinished()

    readonly property real fraction: duration > 0
        ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property real handleWidth: 4
    implicitHeight: 26

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 2
        radius: 1
        color: root.restColor
    }

    Item {
        id: played
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: root.width * root.fraction
        clip: true

        Shape {
            id: wave
            width: root.width + 28
            height: root.height
            anchors.verticalCenter: parent.verticalCenter
            preferredRendererType: Shape.CurveRenderer
            property real amplitude: root.playing ? 3 : 1

            ShapePath {
                strokeColor: root.accent
                strokeWidth: 2.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathPolyline {
                    path: {
                        const points = []
                        const mid = wave.height / 2
                        for (let x = 0; x <= wave.width + 3; x += 3)
                            points.push(Qt.point(x, mid + wave.amplitude * Math.sin(x * Math.PI / 14)))
                        return points
                    }
                }
            }
            XAnimator {
                from: 0; to: -28; duration: 1000; loops: Animation.Infinite
                running: root.playing && root.visible && played.width > 0
            }
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(root.width - width, root.width * root.fraction - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: 18
        radius: width / 2
        color: root.accent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.seekable
        cursorShape: Qt.PointingHandCursor
        function fractionAt(x) { return Math.max(0, Math.min(1, x / Math.max(1, root.width))) }
        function seekAt(x) { root.seekRequested(fractionAt(x) * root.duration) }
        onPressed: event => { root.seekStarted(); seekAt(event.x) }
        onPositionChanged: event => { if (pressed) seekAt(event.x) }
        onReleased: root.seekFinished()
        onCanceled: root.seekFinished()
    }
}
