import QtQuick
import "../theme"

Rectangle {
    id: root
    property string imageSource: ""
    property int maxHeight: 160
    readonly property bool ready: preview.status === Image.Ready
    visible: root.ready
    implicitHeight: root.ready && preview.implicitWidth > 0
        ? Math.min(root.maxHeight, Math.max(0, width - 8) * preview.implicitHeight / preview.implicitWidth + 8) : 0
    height: implicitHeight
    radius: Style.controlRadius
    color: Color.surfaceContainerHigh
    clip: true
    Image {
        id: preview
        objectName: "notificationPreviewImage"
        anchors.fill: parent
        anchors.margins: 4
        source: root.imageSource
        asynchronous: true
        sourceSize.width: 768
        fillMode: Image.PreserveAspectFit
    }
}
