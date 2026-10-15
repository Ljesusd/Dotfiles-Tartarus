import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "../services" as Services
import "../theme" as Theme

PanelWindow {
    id: root

    required property var monitorScreen
    required property var shellState

    readonly property bool belongsToMonitor:
        Services.RecorderService.recordingScreen === (root.monitorScreen
            ? root.monitorScreen.name : "")
    readonly property bool shouldShow:
        root.belongsToMonitor && Services.RecorderService.busy

    property bool expanded: true
    property bool dragging: false
    property real cardX: 0
    property real cardY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property string edge: Services.RecorderSettings.hudEdge

    screen: root.monitorScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    visible: root.shouldShow
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.aboveWindows: true
    WlrLayershell.namespace: "tartarus-recording-hud"

    // Only the card (including its tucked peek) receives pointer events. The
    // rest of the transparent overlay remains click-through for applications.
    mask: Region { item: card }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function safeLeft() { return Theme.Style.paddingLarge }
    function safeTop() { return Theme.Style.paddingLarge }
    function safeRight() { return Math.max(safeLeft(), root.width - card.width - safeLeft()) }
    function safeBottom() {
        return Math.max(
            safeTop(),
            root.height - Theme.Style.barHeight - Theme.Style.spacingLarge - card.height
        )
    }

    function placeAtSavedPosition() {
        if (root.width <= 0 || root.height <= 0)
            return

        root.edge = Services.RecorderSettings.hudEdge
        const offset = Services.RecorderSettings.hudOffset
        if (root.edge === "left") {
            root.cardX = safeLeft()
            root.cardY = safeTop() + offset * Math.max(0, safeBottom() - safeTop())
        } else if (root.edge === "right") {
            root.cardX = safeRight()
            root.cardY = safeTop() + offset * Math.max(0, safeBottom() - safeTop())
        } else if (root.edge === "top") {
            root.cardX = safeLeft() + offset * Math.max(0, safeRight() - safeLeft())
            root.cardY = safeTop()
        } else {
            root.cardX = safeLeft() + offset * Math.max(0, safeRight() - safeLeft())
            root.cardY = safeBottom()
        }
        root.clampPosition()
    }

    function clampPosition() {
        root.cardX = root.clamp(root.cardX, safeLeft(), safeRight())
        root.cardY = root.clamp(root.cardY, safeTop(), safeBottom())
    }

    function dockCard() {
        root.clampPosition()

        const distances = [
            { edge: "left", distance: Math.abs(root.cardX - safeLeft()) },
            { edge: "right", distance: Math.abs(root.cardX - safeRight()) },
            { edge: "top", distance: Math.abs(root.cardY - safeTop()) },
            { edge: "bottom", distance: Math.abs(root.cardY - safeBottom()) }
        ]
        distances.sort((a, b) => a.distance - b.distance)
        root.edge = distances[0].edge

        if (root.edge === "left") {
            root.cardX = safeLeft()
            root.cardY = root.clamp(root.cardY, safeTop(), safeBottom())
            Services.RecorderSettings.hudOffset = (root.cardY - safeTop())
                / Math.max(1, safeBottom() - safeTop())
        } else if (root.edge === "right") {
            root.cardX = safeRight()
            root.cardY = root.clamp(root.cardY, safeTop(), safeBottom())
            Services.RecorderSettings.hudOffset = (root.cardY - safeTop())
                / Math.max(1, safeBottom() - safeTop())
        } else if (root.edge === "top") {
            root.cardY = safeTop()
            root.cardX = root.clamp(root.cardX, safeLeft(), safeRight())
            Services.RecorderSettings.hudOffset = (root.cardX - safeLeft())
                / Math.max(1, safeRight() - safeLeft())
        } else {
            root.cardY = safeBottom()
            root.cardX = root.clamp(root.cardX, safeLeft(), safeRight())
            Services.RecorderSettings.hudOffset = (root.cardX - safeLeft())
                / Math.max(1, safeRight() - safeLeft())
        }

        Services.RecorderSettings.hudEdge = root.edge
        Services.RecorderSettings.save()
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.placeAtSavedPosition)
    }

    onWidthChanged: root.clampPosition()
    onHeightChanged: root.clampPosition()

    Rectangle {
        id: card
        width: root.expanded ? Math.min(344, root.width - Theme.Style.paddingLarge * 2) : 48
        height: root.expanded ? 96 : 48
        x: root.cardX
        y: root.cardY
        radius: root.expanded ? Theme.Style.cardRadius : Theme.Style.radiusFull
        color: Theme.Color.surfaceContainer
        border.width: Theme.Style.panelBorderWidth
        border.color: root.dragging
            ? Theme.Color.primary
            : Qt.alpha(Theme.Color.primary, 0.72)
        opacity: root.shouldShow ? 1 : 0
        scale: root.shouldShow ? 1 : 0.9

        Behavior on x { enabled: !root.dragging; Theme.Anim { duration: Theme.Style.motionPanel; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !root.dragging; Theme.Anim { duration: Theme.Style.motionPanel; easing.type: Easing.OutCubic } }
        Behavior on width { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }
        Behavior on height { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }
        Behavior on radius { Theme.Anim { duration: Theme.Style.motionFast; easing.type: Easing.OutCubic } }
        Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        Behavior on scale { Theme.Anim { duration: Theme.Style.motionFast; easing.type: Easing.OutCubic } }

        DragHandler {
            id: dragHandler
            onActiveChanged: {
                root.dragging = active
                if (active) {
                    root.expanded = true
                    root.dragStartX = root.cardX
                    root.dragStartY = root.cardY
                } else {
                    root.dockCard()
                }
            }
            onTranslationChanged: {
                if (!active)
                    return
                root.cardX = root.clamp(
                    root.dragStartX + translation.x,
                    root.safeLeft(), root.safeRight()
                )
                root.cardY = root.clamp(
                    root.dragStartY + translation.y,
                    root.safeTop(), root.safeBottom()
                )
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.expanded ? Theme.Style.paddingSmall : 0
            spacing: Theme.Style.spacingXs

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: root.expanded
                spacing: Theme.Style.spacingSmall

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: Theme.Style.radiusFull
                    color: Qt.alpha(Theme.Color.error, 0.16)
                    Theme.MaterialIcon {
                        anchors.centerIn: parent
                        text: Services.RecorderService.paused ? "pause_circle" : "fiber_manual_record"
                        iconSize: Theme.Style.materialIconSmall
                        iconColor: Services.RecorderService.paused ? Theme.Color.warning : Theme.Color.error
                    }
                }

                ColumnLayout {
                    visible: root.expanded
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: Services.RecorderService.finishing
                            ? "Guardando grabación"
                            : Services.RecorderService.starting
                                ? "Preparando grabación"
                                : Services.RecorderService.paused ? "Grabación pausada" : "Grabando"
                        color: Theme.Color.foreground
                        font.pixelSize: Theme.Style.fontSmall
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: Services.RecorderService.displayTime
                            + (Services.RecorderService.recordingScreen !== ""
                                ? " · " + Services.RecorderService.recordingScreen : "")
                        color: Theme.Color.foregroundMuted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillWidth: !root.expanded }

                HudButton {
                    visible: root.expanded
                    iconName: Services.RecorderService.paused ? "play_arrow" : "pause"
                    tooltip: Services.RecorderService.paused ? "Reanudar" : "Pausar"
                    enabled: Services.RecorderService.active && !Services.RecorderService.stopping
                    onClicked: Services.RecorderService.togglePause()
                }

                HudButton {
                    visible: root.expanded
                    iconName: "stop"
                    tooltip: "Detener"
                    enabled: Services.RecorderService.busy
                    onClicked: Services.RecorderService.stop()
                }

                HudButton {
                    visible: root.expanded
                    iconName: "settings"
                    tooltip: "Ajustes de grabación"
                    enabled: !Services.RecorderService.active
                    onClicked: root.shellState.openControlCenterPage(17)
                }

                HudButton {
                    iconName: root.expanded ? "expand_less" : "fiber_manual_record"
                    tooltip: root.expanded ? "Ocultar controles" : "Mostrar controles"
                    onClicked: root.expanded = !root.expanded
                }
            }
        }

        component HudButton: Rectangle {
            id: hudButton
            property string iconName: "settings"
            property string tooltip: ""
            property bool enabled: true
            signal clicked()
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: Theme.Style.radiusFull
            color: buttonHover.hovered
                ? Qt.alpha(Theme.Color.primary, 0.20)
                : Qt.alpha(Theme.Color.foreground, 0.08)
            opacity: hudButton.enabled ? 1 : 0.4

            Theme.MaterialIcon {
                anchors.centerIn: parent
                text: hudButton.iconName
                iconSize: Theme.Style.materialIconSmall
                iconColor: Theme.Color.foreground
            }

            HoverHandler { id: buttonHover }
            TapHandler {
                enabled: hudButton.enabled
                onTapped: hudButton.clicked()
            }
            Behavior on color { ColorAnimation { duration: Theme.Style.motionFast } }
        }
    }
}
