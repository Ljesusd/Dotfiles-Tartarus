import Quickshell
import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell.Wayland
import "../bar/components"
import "../services" as Services
import "../theme"

Item {
    id: root

    required property var monitorScreen
    readonly property string monitorName: monitorScreen ? monitorScreen.name : "default"
    readonly property var config: Services.DesktopWidgets.music(root.monitorName)
    readonly property bool mediaVisible: Services.MediaService.available
        && Services.MediaService.title.length > 0
    property real currentX: -1
    property real currentY: -1
    property bool dragging: false
    property real grabX: 0
    property real grabY: 0
    property real dragX: 0
    property real dragY: 0
    property bool locked: root.config.locked
    property real scaleFactor: root.config.scale

    readonly property real baseWidth: 320
    readonly property real visualWidth: baseWidth * root.scaleFactor
    readonly property real visualHeight: card.implicitHeight * root.scaleFactor

    width: baseWidth
    height: card.implicitHeight
    visible: root.mediaVisible && root.config.enabled
    scale: root.scaleFactor
    transformOrigin: Item.TopLeft

    function defaultX() {
        return Math.max(24, (root.parent?.width ?? 1280) - root.visualWidth - 40)
    }

    function defaultY() {
        return 90
    }

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
        root.currentX = root.config.x >= 0 ? root.clampX(root.config.x) : root.defaultX()
        root.currentY = root.config.y >= 0 ? root.clampY(root.config.y) : root.defaultY()
    }

    x: root.dragging ? root.dragX : root.currentX
    y: root.dragging ? root.dragY : root.currentY

    Component.onCompleted: root.syncPosition()
    onConfigChanged: root.syncPosition()

    Rectangle {
        anchors.fill: parent
        radius: Style.panelRadius
        color: "transparent"
        visible: root.mediaVisible
        border.width: root.dragging ? 1 : 0
        border.color: Color.primary
    }

    VerticalMusicCard {
        id: card
        anchors.fill: parent
        active: root.visible
    }

    // The header is deliberately the drag handle. Controls and the seek rail
    // remain fully interactive, while the widget still feels like a movable
    // desktop tile.
    MouseArea {
        id: dragHandle
        z: 5
        x: 0
        y: 0
        width: parent.width
        height: 48
        enabled: root.mediaVisible && !root.locked
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
            if (!root.dragging)
                return
            const p = root.mapToItem(root.parent, mouse.x, mouse.y)
            root.dragX = root.clampX(p.x - root.grabX)
            root.dragY = root.clampY(p.y - root.grabY)
        }
        onReleased: {
            if (!root.dragging)
                return
            root.dragging = false
            root.currentX = root.dragX
            root.currentY = root.dragY
            Services.DesktopWidgets.setMusicPosition(root.monitorName, root.currentX, root.currentY)
        }
    }

    WheelHandler {
        enabled: root.mediaVisible && !root.locked
        acceptedModifiers: Qt.ControlModifier
        onWheel: event => {
            const next = Math.max(0.7, Math.min(1.4,
                root.scaleFactor * (event.angleDelta.y > 0 ? 1.05 : 1 / 1.05)))
            root.scaleFactor = next
            Services.DesktopWidgets.setMusicScale(root.monitorName, next)
        }
    }
}
