pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "../../theme"
import "components"

Item {
    id: root

    required property var plugin
    property var barScreen: null

    signal interacted()

    readonly property int shownWorkspaces: 5
    readonly property int maxWindowIcons: 5
    readonly property bool showOccupiedBg: false
    readonly property int activeWorkspaceId:
        root.plugin.service.activeWorkspaceIdForScreen(
            root.barScreen
        )
    readonly property bool specialOpened:
        root.plugin.service
            .hasActiveSpecialWorkspaceForScreen(
                root.barScreen
            )

    readonly property int groupStart:
        root.plugin.service.firstWorkspaceForScreen(
            root.barScreen
        )

    readonly property int activeIndex:
        root.activeWorkspaceId - root.groupStart

    readonly property Item activeWorkspaceItem: {
        if (
            root.activeIndex < 0
            || root.activeIndex >= workspaceRepeater.count
        ) {
            return null
        }

        return workspaceRepeater.itemAt(
            root.activeIndex
        )
    }

    function isOccupiedAt(index) {
        if (
            index < 0
            || index >= root.shownWorkspaces
        ) {
            return false
        }

        const workspaceId =
            root.groupStart + index

        return root.plugin.service.isOccupied(
            workspaceId
        )
    }

    function occupiedRunStart(runIndex) {
        let currentRun = 0

        for (
            let index = 0;
            index < root.shownWorkspaces;
            index++
        ) {
            const occupied =
                root.isOccupiedAt(index)

            const previousOccupied =
                index > 0
                && root.isOccupiedAt(index - 1)

            if (
                occupied
                && !previousOccupied
            ) {
                if (currentRun === runIndex)
                    return index

                currentRun++
            }
        }

        return -1
    }

    function occupiedRunEnd(runIndex) {
        const start =
            root.occupiedRunStart(runIndex)

        if (start < 0)
            return -1

        let end = start

        while (
            end + 1 < root.shownWorkspaces
            && root.isOccupiedAt(end + 1)
        ) {
            end++
        }

        return end
    }

    function handleWheel(angleDelta) {
        const delta = angleDelta?.y ?? 0

        if (delta === 0)
            return false

        if (root.specialOpened) {
            const activeSpecial =
                root.plugin.service
                    .activeSpecialWorkspaceNameForScreen(
                        root.barScreen
                    )

            if (!activeSpecial)
                return false

            root.plugin.service
                .toggleSpecialWorkspaceForScreen(
                    root.barScreen,
                    activeSpecial
                )

            return true
        }

        const direction = delta > 0
            ? -1
            : 1

        const nextWorkspaceId = Math.max(
            1,
            root.activeWorkspaceId + direction
        )

        if (nextWorkspaceId === root.activeWorkspaceId)
            return false

        root.plugin.service
            .activateWorkspaceForScreen(
                root.barScreen,
                nextWorkspaceId
            )

        return true
    }

    implicitWidth: normalLayer.implicitWidth
    implicitHeight: normalLayer.implicitHeight

    Rectangle {
        id: normalLayer

        implicitWidth:
            workspaceContent.implicitWidth
            + Style.barWorkspaceRailPaddingHorizontal * 2

        implicitHeight: Style.barInnerHeight

        width: implicitWidth
        height: implicitHeight

        radius: Style.radiusFull

        color: Color.surfaceContainer

        clip: false

        Item {
            id: workspaceContent

            anchors.centerIn: parent

            implicitWidth: workspaceRow.implicitWidth
            implicitHeight: workspaceRow.implicitHeight

            width: implicitWidth
            height: implicitHeight
            z: 0
            scale: root.specialOpened
                ? Style.barWorkspaceBackgroundScale
                : 1.0
            opacity: root.specialOpened
                ? Style.barWorkspaceBackgroundOpacity
                : 1.0
            enabled: !root.specialOpened
            transformOrigin: Item.Center
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root.specialOpened
                    ? Style.barWorkspaceSpecialBlur
                    : 0.0
                blurMax: Style.barWorkspaceSpecialBlurMax
                autoPaddingEnabled: false

                Behavior on blur {
                    NumberAnimation {
                        duration: Style.motionNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.motionFast
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                id: occupiedRunRepeater

                model: root.shownWorkspaces

                Rectangle {
                    required property int index

                    readonly property int startIndex:
                        root.occupiedRunStart(index)

                    readonly property int endIndex:
                        root.occupiedRunEnd(index)

                    readonly property Item startItem:
                        startIndex >= 0
                        ? workspaceRepeater.itemAt(startIndex)
                        : null

                    readonly property Item endItem:
                        endIndex >= 0
                        ? workspaceRepeater.itemAt(endIndex)
                        : null

                    visible:
                        root.showOccupiedBg
                        && startItem !== null
                        && endItem !== null

                    x: startItem
                        ? startItem.x
                        : 0

                    y: startItem
                        ? startItem.y
                        : 0

                    width:
                        startItem && endItem
                        ? endItem.x
                            + endItem.width
                            - startItem.x
                        : 0

                    height:
                        startItem
                        ? startItem.height
                        : 0

                    radius: Style.radiusSmall

                    color: Color.surfaceContainerHigh
                    z: 0
                }
            }

            ActiveIndicator {
                id: activeIndicator

                targetItem: root.activeWorkspaceItem
                targetIndex: root.activeIndex
                groupStart: root.groupStart

                z: 1
            }

            Rectangle {
                id: activeColourMask

                x: workspaceRow.x
                y: workspaceRow.y
                width: workspaceRow.width
                height: workspaceRow.height
                visible: false
                layer.enabled: true

                Rectangle {
                    x: activeIndicator.x - workspaceRow.x
                    y: activeIndicator.y - workspaceRow.y

                    width: activeIndicator.width
                    height: activeIndicator.height

                    radius: activeIndicator.radius
                    color: "white"
                }
            }

            MultiEffect {
                id: activeColourLayer

                x: workspaceRow.x
                y: workspaceRow.y
                width: workspaceRow.width
                height: workspaceRow.height
                z: 3

                visible: false
                source: workspaceRow
                colorization: 1.0
                colorizationColor: Color.onPrimaryContainer
                maskEnabled: true
                maskSource: activeColourMask
                autoPaddingEnabled: false
            }

            RowLayout {
                id: workspaceRow

                anchors.centerIn: parent
                spacing: Style.barWorkspaceSpacing
                z: 2

                Repeater {
                    id: workspaceRepeater

                    model: root.shownWorkspaces

                    Workspace {
                        required property int index

                        workspaceId: root.groupStart + index
                        barScreen: root.barScreen
                        service: root.plugin.service
                        maxWindowIcons: root.maxWindowIcons
                        activeWorkspaceId: root.activeWorkspaceId

                        onInteracted: {
                            root.interacted()
                        }
                    }
                }
            }

        }
    }

    Item {
        id: specialLayer

        anchors.fill: parent
        z: 1

        opacity: root.specialOpened
            ? 1.0
            : 0.0
        scale: root.specialOpened
            ? 1.0
            : Style.barWorkspaceSpecialEnterScale
        enabled: root.specialOpened
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation {
                duration: Style.motionFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Style.motionNormal
                easing.type: Easing.OutCubic
            }
        }

        SpecialWorkspaces {
            anchors {
                centerIn: parent
                horizontalCenterOffset: 8
            }

            width: parent.width
            height: parent.height

            service: root.plugin.service
            barScreen: root.barScreen

            onInteracted: {
                root.interacted()
            }
        }
    }
}
