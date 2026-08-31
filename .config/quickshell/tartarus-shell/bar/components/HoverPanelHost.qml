import Quickshell
import QtQuick

import "../../theme"

PopupWindow {
    id: root

    required property var hoverPanelController
    required property Item anchorSurface
    property var barScreen: null

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

    property int currentContentSlot: -1
    property int pendingContentSlot: -1
    property int outgoingContentSlot: -1
    property var currentContentComponent: null
    property var pendingContentComponent: null
    property bool contentTransitionRunning: false
    property real contentTransitionProgress: 1.0

    readonly property var currentContentLoader:
        root.currentContentSlot === 0
            ? contentLoaderA
            : root.currentContentSlot === 1
                ? contentLoaderB
                : null

    readonly property var previousContentLoader:
        root.currentContentSlot === 0
            ? contentLoaderB
            : root.currentContentSlot === 1
                ? contentLoaderA
                : null

    readonly property real panelImplicitWidth:
        root.currentContentLoader
        && root.currentContentLoader.item
            ? root.currentContentLoader.item.implicitWidth
            : 0

    readonly property real panelImplicitHeight:
        root.currentContentLoader
        && root.currentContentLoader.item
            ? root.currentContentLoader.item.implicitHeight
            : 0

    readonly property bool panelReady:
        root.currentContentLoader !== null
        && root.currentContentLoader.item !== null
        && root.panelImplicitWidth > 0
        && root.panelImplicitHeight > 0

    readonly property real targetWidth:
        Math.max(1, root.panelImplicitWidth)

    readonly property real targetHeight:
        Math.max(1, root.panelImplicitHeight)

    readonly property var anchorEntry:
        root.hoverPanelController.anchorEntry

    readonly property real targetCenterX: {
        const entry = root.anchorEntry

        if (!entry || !root.anchorSurface)
            return 0

        const point = entry.mapToItem(
            root.anchorSurface,
            entry.width / 2,
            entry.height
        )

        return point.x
    }

    property real currentCenterX: 0
    property real currentWidth: 1
    property real currentHeight: 1
    property real hostHeight: 1
    property bool positionInitialized: false
    property bool sizeInitialized: false
    property bool surfacePrepared: false

    function syncCenterPosition() {
        const target = root.targetCenterX

        if (!Number.isFinite(target))
            return

        if (!root.visible || !root.positionInitialized) {
            root.positionInitialized = false
            root.currentCenterX = target
            root.positionInitialized = true
            return
        }

        root.currentCenterX = target
    }

    function syncPanelSize() {
        const targetWidth = root.targetWidth
        const targetHeight = root.targetHeight

        if (
            !Number.isFinite(targetWidth)
            || !Number.isFinite(targetHeight)
        ) {
            return
        }

        if (!root.visible || !root.sizeInitialized) {
            root.sizeInitialized = false
            root.currentWidth = targetWidth
            root.currentHeight = targetHeight
            root.sizeInitialized = true
            return
        }

        root.currentWidth = targetWidth
        root.currentHeight = targetHeight
    }

    function syncHostHeight() {
        const targetHeight = root.targetHeight

        if (!Number.isFinite(targetHeight))
            return

        if (!root.visible) {
            root.hostHeight = targetHeight
            return
        }

        if (targetHeight > root.hostHeight)
            root.hostHeight = targetHeight
    }

    function prepareSurface() {
        if (!root.hoverPanelController.opened)
            return

        if (!root.panelReady)
            return

        root.positionInitialized = false
        root.sizeInitialized = false

        root.currentCenterX = root.targetCenterX
        root.currentWidth = root.targetWidth
        root.currentHeight = root.targetHeight

        root.positionInitialized = true
        root.sizeInitialized = true
        root.surfacePrepared = true
    }

    function prepareSurfaceIfPossible() {
        if (
            root.hoverPanelController.opened
            && root.panelReady
            && !root.surfacePrepared
        ) {
            root.prepareSurface()
        }
    }

    function updateAnchorIfReady() {
        if (!root.visible)
            return

        if (!root.panelReady)
            return

        if (!root.anchorEntry || !root.anchorSurface)
            return

        root.anchor.updateAnchor()
    }

    function loaderForSlot(slot) {
        if (slot === 0)
            return contentLoaderA

        if (slot === 1)
            return contentLoaderB

        return null
    }

    function setLoaderProperties(loader) {
        if (!loader || !loader.item)
            return

        if (
            root.activePlugin
            && "plugin" in loader.item
        ) {
            loader.item.plugin = root.activePlugin
        }

        if (
            "hoverPanelController" in loader.item
        ) {
            loader.item.hoverPanelController =
                root.hoverPanelController
        }

        if (
            "barScreen" in loader.item
        ) {
            loader.item.barScreen =
                root.barScreen
        }
    }

    function setPanelContentActive(loader, active) {
        if (!loader || !loader.item)
            return

        if ("active" in loader.item)
            loader.item.active = active
    }

    function refreshPanelContentActivity() {
        root.setPanelContentActive(
            contentLoaderA,
            root.visible
                && root.currentContentSlot === 0
        )

        root.setPanelContentActive(
            contentLoaderB,
            root.visible
                && root.currentContentSlot === 1
        )
    }

    function finishContentTransition() {
        root.contentTransitionProgress = 1.0
        root.contentTransitionRunning = false
        root.outgoingContentSlot = -1

        root.refreshPanelContentActivity()
    }

    function commitPanelContent(slot) {
        if (slot !== root.pendingContentSlot)
            return

        const incomingLoader = root.loaderForSlot(slot)

        if (!incomingLoader || !incomingLoader.item)
            return

        root.setLoaderProperties(incomingLoader)

        if (root.currentContentSlot < 0) {
            root.currentContentSlot = slot
            root.currentContentComponent =
                root.pendingContentComponent

            root.pendingContentSlot = -1
            root.pendingContentComponent = null

            root.outgoingContentSlot = -1
            root.contentTransitionProgress = 1.0
            root.contentTransitionRunning = false

            root.refreshPanelContentActivity()
            root.syncHostHeight()

            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })

            return
        }

        root.outgoingContentSlot =
            root.currentContentSlot

        root.setPanelContentActive(
            root.loaderForSlot(root.outgoingContentSlot),
            false
        )

        root.currentContentSlot = slot
        root.currentContentComponent =
            root.pendingContentComponent

        root.pendingContentSlot = -1
        root.pendingContentComponent = null

        root.contentTransitionProgress = 0.0
        root.contentTransitionRunning = true

        root.refreshPanelContentActivity()
        root.syncHostHeight()

        contentFadeAnimation.restart()

        Qt.callLater(function() {
            root.updateAnchorIfReady()
        })
    }

    function requestPanelContent(nextComponent) {
        if (!nextComponent)
            return

        if (root.contentTransitionRunning) {
            contentFadeAnimation.stop()
            root.finishContentTransition()
        }

        if (nextComponent === root.currentContentComponent)
            return

        if (nextComponent === root.pendingContentComponent)
            return

        const incomingSlot =
            root.currentContentSlot === 0 ? 1 : 0
        const incomingLoader =
            root.loaderForSlot(incomingSlot)

        if (!incomingLoader)
            return

        root.pendingContentSlot = incomingSlot
        root.pendingContentComponent = nextComponent

        incomingLoader.sourceComponent = nextComponent

        if (incomingLoader.status === Loader.Ready)
            root.commitPanelContent(incomingSlot)
    }

    Behavior on currentCenterX {
        enabled: root.positionInitialized && root.visible

        NumberAnimation {
            duration: Style.motionNormal
            easing.type: Easing.OutCubic
        }
    }

    Behavior on currentWidth {
        enabled: root.sizeInitialized && root.visible

        NumberAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on currentHeight {
        enabled: root.sizeInitialized && root.visible

        NumberAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: contentFadeAnimation

        target: root
        property: "contentTransitionProgress"

        from: 0.0
        to: 1.0
        duration: Style.motionFast
        easing.type: Easing.OutCubic

        onFinished: {
            root.finishContentTransition()
        }
    }

    anchor {
        item: root.anchorSurface
        edges: Edges.Bottom
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.None
    }

    visible:
        root.hoverPanelController.opened
        && root.anchorEntry !== null
        && root.panelReady
        && root.surfacePrepared

    implicitWidth:
        Math.max(1, root.anchorSurface ? root.anchorSurface.width : 1)

    implicitHeight:
        Math.max(1, root.hostHeight)

    color: "transparent"
    grabFocus: false
    mask: Region {
        item: panelSurface
    }

    Item {
        id: panelSurface

        x: Math.max(
            0,
            Math.min(
                Math.max(0, root.width - root.currentWidth),
                root.currentCenterX - root.currentWidth / 2
            )
        )
        y: 0
        width: root.currentWidth
        height: root.currentHeight
        clip: true

        Loader {
            id: contentLoaderA

            anchors.fill: parent

            visible:
                root.currentContentSlot === 0
                || root.outgoingContentSlot === 0
                || root.pendingContentSlot === 0
            opacity: {
                if (root.contentTransitionRunning) {
                    if (root.currentContentSlot === 0)
                        return root.contentTransitionProgress

                    if (root.outgoingContentSlot === 0)
                        return 1.0 - root.contentTransitionProgress
                }

                return root.currentContentSlot === 0
                    ? 1.0
                    : 0.0
            }
            enabled: root.currentContentSlot === 0
            z: root.currentContentSlot === 0 ? 1 : 0

            onLoaded: {
                root.setLoaderProperties(contentLoaderA)

                if (root.pendingContentSlot === 0)
                    root.commitPanelContent(0)

                root.refreshPanelContentActivity()
            }
        }

        Loader {
            id: contentLoaderB

            anchors.fill: parent

            visible:
                root.currentContentSlot === 1
                || root.outgoingContentSlot === 1
                || root.pendingContentSlot === 1
            opacity: {
                if (root.contentTransitionRunning) {
                    if (root.currentContentSlot === 1)
                        return root.contentTransitionProgress

                    if (root.outgoingContentSlot === 1)
                        return 1.0 - root.contentTransitionProgress
                }

                return root.currentContentSlot === 1
                    ? 1.0
                    : 0.0
            }
            enabled: root.currentContentSlot === 1
            z: root.currentContentSlot === 1 ? 1 : 0

            onLoaded: {
                root.setLoaderProperties(contentLoaderB)

                if (root.pendingContentSlot === 1)
                    root.commitPanelContent(1)

                root.refreshPanelContentActivity()
            }
        }
    }

    onVisibleChanged: {
        root.refreshPanelContentActivity()

        if (root.visible) {
            root.syncCenterPosition()
            root.syncPanelSize()
            root.syncHostHeight()
            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })
        } else {
            root.positionInitialized = false
            root.sizeInitialized = false
        }
    }

    onPanelImplicitWidthChanged: {
        root.syncPanelSize()
    }

    onPanelImplicitHeightChanged: {
        root.syncPanelSize()
        root.syncHostHeight()
    }

    onActivePluginChanged: {
        if (
            root.activePlugin
            && root.activePlugin.panelContentComponent !== undefined
            && root.activePlugin.panelContentComponent !== null
        ) {
            root.requestPanelContent(
                root.activePlugin.panelContentComponent
            )
        }
    }

    onTargetCenterXChanged: {
        root.syncCenterPosition()
    }

    onPanelReadyChanged: {
        root.syncHostHeight()
        root.prepareSurfaceIfPossible()
    }

    Connections {
        target: root.hoverPanelController

        function onOpenedChanged() {
            if (!root.hoverPanelController.opened) {
                root.surfacePrepared = false
                return
            }

            root.prepareSurfaceIfPossible()
        }

        function onAnchorEntryChanged() {
            Qt.callLater(function() {
                root.updateAnchorIfReady()
            })
        }
    }

    Connections {
        target: root.anchor

        function onAnchoring() {
            if (!root.anchorSurface)
                return

            root.anchor.rect = Qt.rect(
                0,
                0,
                Math.max(1, root.anchorSurface.width),
                Math.max(1, root.anchorSurface.height + Style.barPopupGap)
            )
        }
    }

    Component.onCompleted: {
        if (
            root.activePlugin
            && root.activePlugin.panelContentComponent !== undefined
            && root.activePlugin.panelContentComponent !== null
        ) {
            root.requestPanelContent(
                root.activePlugin.panelContentComponent
            )
        }
    }
}
