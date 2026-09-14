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
    readonly property bool showOccupiedBg: true
    readonly property bool showUnoccupied: false
    readonly property bool showWindowIcons: true
    readonly property int activeWorkspaceId:
        root.plugin.service.activeWorkspaceIdForScreen(
            root.barScreen
        )
    readonly property string activeSpecialName:
        root.plugin.service
            .activeSpecialWorkspaceNameForScreen(
                root.barScreen
            )
    readonly property bool hasActiveSpecial:
        root.activeSpecialName !== ""
    readonly property var specialWorkspaces:
        root.plugin.service.specialWorkspacesForScreen(
            root.barScreen
        )
    readonly property int specialCount:
        root.specialWorkspaces.length
    readonly property string activeSpecialKey:
        root.specialKey(root.activeSpecialName)
    readonly property int activeSpecialIndex: {
        for (let i = 0; i < root.specialCount; ++i) {
            const workspace = root.specialWorkspaces[i]
            const specialName = workspace?.name ?? ""

            if (root.specialKey(specialName) === root.activeSpecialKey)
                return i
        }

        return -1
    }
    property int displayedSpecialIndex: -1

    function specialKey(name) {
        if (!name)
            return ""

        return name.startsWith("special:")
            ? name.slice(8)
            : name
    }

    function workspaceSlotWidth(index) {
        const workspace = workspaceRepeater.itemAt(index)

        return workspace
            ? workspace.width
            : Style.barWorkspaceBaseSize
    }

    onActiveSpecialIndexChanged: {
        if (activeSpecialIndex >= 0)
            displayedSpecialIndex = activeSpecialIndex
    }

    Component.onCompleted: {
        if (activeSpecialIndex >= 0)
            displayedSpecialIndex = activeSpecialIndex
    }

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

        if (root.hasActiveSpecial) {
            root.plugin.service
                .toggleSpecialWorkspaceForScreen(
                    root.barScreen,
                    root.activeSpecialName
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

        color: Color.surfaceContainerHigh
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant

        clip: true

        Item {
            id: workspaceContent

            anchors.centerIn: parent

            implicitWidth: workspaceRow.implicitWidth
            implicitHeight: workspaceRow.implicitHeight

            width: implicitWidth
            height: implicitHeight
            z: 0
            scale: root.hasActiveSpecial
                ? Style.barWorkspaceBackgroundScale
                : 1.0
            opacity: root.hasActiveSpecial
                ? Style.barWorkspaceSpecialDimOpacity
                : 1.0
            enabled: !root.hasActiveSpecial
            transformOrigin: Item.Center

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

            Behavior on enabled {
                PropertyAnimation {
                    duration: Style.motionFast
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
                visible: !root.hasActiveSpecial

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

                visible: !root.hasActiveSpecial
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
                        showUnoccupied: root.showUnoccupied
                        showWindowIcons: root.showWindowIcons

                        onInteracted: {
                            root.interacted()
                        }
                    }
                }
            }

        }

        Item {
            id: specialLayer

            anchors.fill: parent
            z: 4

            opacity: root.hasActiveSpecial ? 1.0 : 0.0
            scale: root.hasActiveSpecial ? 1.0 : 0.8
            enabled: root.hasActiveSpecial
            transformOrigin: Item.Left

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }

            ListView {
                id: specialList

                x: workspaceContent.x + workspaceRow.x
                y: workspaceContent.y + workspaceRow.y
                width: workspaceRow.width
                height: workspaceRow.height

                clip: true
                interactive: false
                orientation: ListView.Horizontal
                spacing: workspaceRow.spacing

                model: root.specialWorkspaces
                currentIndex: root.displayedSpecialIndex
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Style.motionNormal
                highlightResizeDuration: Style.motionNormal

                highlight: Item {
                    width: Style.barWorkspaceBaseSize
                        + Style.barWorkspaceActivePaddingHorizontal * 2
                    height: specialList.height

                    Rectangle {
                        x: -Style.barWorkspaceActivePaddingHorizontal
                        anchors.verticalCenter: parent.verticalCenter

                        width: parent.width
                            + Style.barWorkspaceActivePaddingHorizontal * 2
                        height: Style.barWorkspaceActiveHeight
                        radius: Style.radiusFull
                        color: Color.primary
                    }
                }

                delegate: Item {
                    id: specialItem

                    required property int index
                    required property var modelData

                    readonly property string specialName:
                        modelData?.name ?? ""
                    readonly property string specialKey:
                        root.specialKey(specialName)
                    readonly property bool active:
                        index === root.activeSpecialIndex

                    width: Style.barWorkspaceBaseSize
                    height: specialList.height
                    opacity: specialItem.active ? 1.0 : 0.72
                    scale: specialItem.active ? 1.0 : 0.86
                    transformOrigin: Item.Center

                    Behavior on opacity { Anim { duration: Style.motionFast } }
                    Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutBack } }

                    MaterialIcon {
                        anchors.centerIn: parent

                        text: root.plugin.service.specialWorkspaceIcon(
                            specialItem.specialKey
                        )
                        iconSize: Style.barWorkspaceIconSize
                        iconColor:
                            specialItem.active
                                ? Color.onPrimary
                                : Color.onSurfaceVariant
                        opacity: 1.0
                    }

                    TapHandler {
                        onTapped: {
                            root.plugin.service
                                .toggleSpecialWorkspaceForScreen(root.barScreen, specialItem.specialKey)
                        }
                    }
                }
            }
        }
    }
}
