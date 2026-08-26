import Quickshell
import QtQuick

import "../../theme"

PopupWindow {
    id: root

    required property var hoverPanelController

    readonly property var activePlugin:
        root.hoverPanelController.activePanelPlugin

    readonly property bool supportsSharedHover:
        root.activePlugin
        && root.activePlugin.panelContentComponent !== undefined
        && root.activePlugin.panelContentComponent !== null

    readonly property bool hoverAllowed:
        root.hoverPanelController.opened
        && root.hoverPanelController.anchorEntry !== null
        && root.supportsSharedHover

    readonly property real panelImplicitWidth:
        panelLoader.item
            ? panelLoader.item.implicitWidth
            : 0

    readonly property real panelImplicitHeight:
        panelLoader.item
            ? panelLoader.item.implicitHeight
            : 0

    readonly property bool panelReady:
        panelLoader.item !== null
        && root.panelImplicitWidth > 0
        && root.panelImplicitHeight > 0

    readonly property var anchorEntry:
        root.hoverPanelController.anchorEntry

    function debugState(label) {
        console.log(
            "HOVER HOST", label,
            "opened:", root.hoverPanelController.opened,
            "reason:", root.hoverPanelController.openReason,
            "panel:", root.hoverPanelController.activePanelId,
            "entry:", root.anchorEntry,
            "ready:", root.panelReady,
            "visible:", root.visible
        )
    }

    function updateAnchorIfReady() {
        if (!root.visible)
            return

        if (!root.panelReady)
            return

        if (!root.anchorEntry)
            return

        root.anchor.updateAnchor()
    }

    anchor {
        item: root.anchorEntry
        edges: Edges.Bottom
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.None
    }

    visible:
        root.hoverPanelController.opened
        && root.anchorEntry !== null
        && root.panelReady

    implicitWidth:
        Math.max(1, root.panelImplicitWidth)

    implicitHeight:
        Math.max(1, root.panelImplicitHeight)

    color: "transparent"
    grabFocus: false

    Loader {
        id: panelLoader

        anchors.fill: parent

        active:
            root.activePlugin
            && root.activePlugin.panelContentComponent !== undefined
            && root.activePlugin.panelContentComponent !== null

        sourceComponent:
            root.activePlugin
            && root.activePlugin.panelContentComponent !== undefined
            && root.activePlugin.panelContentComponent !== null
                ? root.activePlugin.panelContentComponent
                : null

        onLoaded: {
            if (
                item
                && "plugin" in item
            ) {
                item.plugin = root.activePlugin
            }

            if (
                item
                && "hoverPanelController" in item
            ) {
                item.hoverPanelController =
                    root.hoverPanelController
            }

            if (
                item
                && "active" in item
            ) {
                item.active = root.visible
            }

            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })
        }
    }

    onVisibleChanged: {
        root.debugState("visible")

        if (
            panelLoader.item
            && "active" in panelLoader.item
        ) {
            panelLoader.item.active = root.visible
        }

        if (root.visible) {
            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })
        }
    }

    onPanelImplicitWidthChanged: {
        Qt.callLater(function() {
            root.updateAnchorIfReady()
        })
    }

    onPanelImplicitHeightChanged: {
        Qt.callLater(function() {
            root.updateAnchorIfReady()
        })
    }

    onHoverAllowedChanged: {
        root.debugState("hoverAllowed")
    }

    onAnchorEntryChanged: {
        root.debugState("anchorEntry")
    }

    onPanelReadyChanged: {
        root.debugState("panelReady")
    }

    Connections {
        target: root.hoverPanelController

        function onAnchorEntryChanged() {
            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })
        }
    }

    Connections {
        target: root.anchor

        function onAnchoring() {
            const entry = root.anchorEntry

            if (!entry)
                return

            root.anchor.rect = Qt.rect(
                0,
                0,
                Math.max(1, entry.width),
                Math.max(
                    1,
                    entry.height + Style.barPopupGap
                )
            )
        }
    }
}
