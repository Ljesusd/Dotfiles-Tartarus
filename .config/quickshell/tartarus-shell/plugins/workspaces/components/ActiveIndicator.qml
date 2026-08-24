import QtQuick

import "../../../theme"

Rectangle {
    id: root

    property Item targetItem: null
    property int targetIndex: -1
    property int groupStart: -1
    readonly property real pillHeight:
        Style.barWorkspaceActiveHeight

    property real leftEdge: 0
    property real rightEdge: 0

    property int previousIndex: -1
    property int previousGroupStart: -1
    property bool initialized: false

    visible: targetItem !== null

    x: root.leftEdge
    y: parent
        ? (parent.height - root.pillHeight) / 2
        : 0

    width: Math.max(
        0,
        root.rightEdge - root.leftEdge
    )
    height: root.pillHeight

    radius: Style.radiusFull
    color: Color.primaryContainer

    function movementDuration(distance) {
        return Math.min(
            Style.barWorkspaceTrailMaxDuration,
            Style.barWorkspaceTrailBaseDuration
                + distance
                * Style.barWorkspaceTrailDistanceFactor
        )
    }

    function syncToTarget() {
        if (!root.targetItem)
            return

        const nextLeft =
            root.targetItem.x
            - Style.barWorkspaceActivePaddingHorizontal

        const nextRight =
            root.targetItem.x
            + root.targetItem.width
            + Style.barWorkspaceActivePaddingHorizontal

        const nextCenter =
            (nextLeft + nextRight) / 2

        const currentCenter =
            (root.leftEdge + root.rightEdge) / 2

        const groupChanged =
            root.previousGroupStart !== root.groupStart

        if (
            !root.initialized
            || groupChanged
        ) {
            leftAnimation.stop()
            rightAnimation.stop()

            root.leftEdge = nextLeft
            root.rightEdge = nextRight

            root.initialized = true
            root.previousIndex = root.targetIndex
            root.previousGroupStart = root.groupStart

            return
        }

        const direction =
            root.targetIndex > root.previousIndex
            ? 1
            : root.targetIndex < root.previousIndex
            ? -1
            : 0

        const distance =
            Math.abs(nextCenter - currentCenter)

        const leadingDuration =
            root.movementDuration(distance)

        const trailingDuration =
            leadingDuration
            + Style.barWorkspaceTrailLag

        leftAnimation.stop()
        rightAnimation.stop()

        leftAnimation.from = root.leftEdge
        leftAnimation.to = nextLeft

        rightAnimation.from = root.rightEdge
        rightAnimation.to = nextRight

        if (direction > 0) {
            leftAnimation.duration = trailingDuration
            rightAnimation.duration = leadingDuration
            leftAnimation.easing.type = Easing.InOutCubic
            rightAnimation.easing.type = Easing.OutCubic
        } else if (direction < 0) {
            leftAnimation.duration = leadingDuration
            rightAnimation.duration = trailingDuration
            leftAnimation.easing.type = Easing.OutCubic
            rightAnimation.easing.type = Easing.InOutCubic
        } else {
            leftAnimation.duration = leadingDuration
            rightAnimation.duration = leadingDuration
            leftAnimation.easing.type = Easing.OutCubic
            rightAnimation.easing.type = Easing.OutCubic
        }

        leftAnimation.start()
        rightAnimation.start()

        root.previousIndex = root.targetIndex
        root.previousGroupStart = root.groupStart
    }

    function scheduleSync() {
        Qt.callLater(root.syncToTarget)
    }

    onTargetItemChanged: {
        root.scheduleSync()
    }

    onTargetIndexChanged: {
        root.scheduleSync()
    }

    onGroupStartChanged: {
        root.scheduleSync()
    }

    NumberAnimation {
        id: leftAnimation

        target: root
        property: "leftEdge"
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: rightAnimation

        target: root
        property: "rightEdge"
        easing.type: Easing.OutCubic
    }

    Connections {
        target: root.targetItem

        ignoreUnknownSignals: true

        function onXChanged() {
            root.scheduleSync()
        }

        function onWidthChanged() {
            root.scheduleSync()
        }
    }
}
