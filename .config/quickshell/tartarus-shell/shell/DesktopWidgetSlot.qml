import QtQuick
import "../services" as Services
import "../theme"

Item {
    id: root

    required property var monitorScreen
    required property string widgetId
    property real defaultX: 24
    property real defaultY: 90
    property bool active: true
    property real currentX: -1
    property real currentY: -1
    property bool dragging: false
    property real grabX: 0
    property real grabY: 0
    property real dragX: 0
    property real dragY: 0
    property real scaleFactor: config.scale
    property bool locked: config.locked
    readonly property string monitorName: monitorScreen ? monitorScreen.name : "default"
    readonly property var config: Services.DesktopWidgets.widget(root.monitorName, root.widgetId)
    readonly property real visualWidth: width * root.scaleFactor
    readonly property real visualHeight: height * root.scaleFactor
    default property alias content: holder.data

    function clampX(value) {
        const available = root.parent?.width ?? 1280
        return Math.max(12, Math.min(value, Math.max(12, available - root.visualWidth - 12)))
    }

    function clampY(value) {
        const available = root.parent?.height ?? 800
        return Math.max(12, Math.min(value, Math.max(12, available - root.visualHeight - 12)))
    }

    function syncPosition() {
        if (root.dragging)
            return
        root.currentX = root.config.x >= 0 ? root.clampX(root.config.x) : root.defaultX
        root.currentY = root.config.y >= 0 ? root.clampY(root.config.y) : root.defaultY
    }

    width: Math.max(1, holder.implicitWidth)
    height: Math.max(1, holder.implicitHeight)
    visible: root.active && root.config.enabled
    scale: root.scaleFactor
    transformOrigin: Item.TopLeft
    x: root.dragging ? root.dragX : root.currentX
    y: root.dragging ? root.dragY : root.currentY

    Component.onCompleted: root.syncPosition()
    onConfigChanged: root.syncPosition()

    Item {
        id: holder
        anchors.fill: parent
        implicitWidth: children.length > 0 && children[0].implicitWidth > 0 ? children[0].implicitWidth : 280
        implicitHeight: children.length > 0 && children[0].implicitHeight > 0 ? children[0].implicitHeight : 120
    }

    MouseArea {
        id: dragHandle
        z: 20
        width: parent.width
        height: 42
        enabled: root.visible && !root.locked
        acceptedButtons: Qt.LeftButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            root.dragging = true
            const p = root.mapToItem(root.parent, mouse.x, mouse.y)
            root.grabX = p.x - root.x
            root.grabY = p.y - root.y
            root.dragX = root.x
            root.dragY = root.y
        }
        onPositionChanged: (mouse) => {
            if (!root.dragging) return
            const p = root.mapToItem(root.parent, mouse.x, mouse.y)
            root.dragX = root.clampX(p.x - root.grabX)
            root.dragY = root.clampY(p.y - root.grabY)
        }
        onReleased: {
            if (!root.dragging) return
            root.dragging = false
            root.currentX = root.dragX
            root.currentY = root.dragY
            Services.DesktopWidgets.setWidgetPosition(root.monitorName, root.widgetId, root.currentX, root.currentY)
        }
    }

    WheelHandler {
        enabled: root.visible && !root.locked
        acceptedModifiers: Qt.ControlModifier
        onWheel: event => {
            const next = Math.max(0.7, Math.min(1.4,
                root.scaleFactor * (event.angleDelta.y > 0 ? 1.05 : 1 / 1.05)))
            root.scaleFactor = next
            Services.DesktopWidgets.setWidgetScale(root.monitorName, root.widgetId, next)
        }
    }
}
