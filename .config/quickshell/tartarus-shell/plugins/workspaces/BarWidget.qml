pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "../../theme"
import "../../utils"
import "components"

Item {
    id: root

    required property var plugin
    property var barScreen: null

    signal interacted()

    readonly property int shownWorkspaces:
        root.barScreen && root.barScreen.width < 1000 ? 3 : 5
    readonly property int maxWindowIcons:
        root.barScreen && root.barScreen.width < 1000 ? 3 : 5
    readonly property bool showOccupiedBg: true
    readonly property bool showUnoccupied: false
    readonly property bool showWindowIcons: true
    readonly property var workspaceIds: root.plugin.service.workspaceIdsForScreen(
        root.barScreen, root.shownWorkspaces, root.showUnoccupied)
    readonly property int workspaceCount: root.workspaceIds.length
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
        root.workspaceIds.indexOf(root.activeWorkspaceId)

    property Item activeWorkspaceItem: null

    function syncActiveWorkspaceItem() {
        root.activeWorkspaceItem = root.activeIndex >= 0
            && root.activeIndex < workspaceRepeater.count
            ? workspaceRepeater.itemAt(root.activeIndex) : null
    }

    onActiveIndexChanged: Qt.callLater(root.syncActiveWorkspaceItem)

    function isOccupiedAt(index) {
        if (
            index < 0
            || index >= root.workspaceCount
        ) {
            return false
        }

        const workspaceId =
            root.workspaceIds[index]

        return root.plugin.service.isOccupied(
            workspaceId
        )
    }

    function occupiedRunStart(runIndex) {
        let currentRun = 0

        for (
            let index = 0;
            index < root.workspaceCount;
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
            end + 1 < root.workspaceCount
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

    implicitWidth: root.hasActiveSpecial
        ? Math.max(normalLayer.implicitWidth,
            specialList.contentWidth + Style.barWorkspaceRailPaddingHorizontal * 2)
        : normalLayer.implicitWidth
    implicitHeight: normalLayer.implicitHeight

    Behavior on implicitWidth { Anim { duration: Style.motionNormal } }

    Rectangle {
        id: normalLayer

        implicitWidth:
            workspaceContent.implicitWidth
            + Style.barWorkspaceRailPaddingHorizontal * 2

        implicitHeight: Style.barInnerHeight

        width: root.width
        height: implicitHeight

        radius: Style.radiusFull

        // Keep a compact rail behind the workspace states, as in Caelestia.
        color: Color.surfaceContainerHigh
        border.width: 0

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

                model: root.workspaceCount

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

                    color: Color.surfaceHover
                    opacity: 0.72
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
                colorizationColor: Color.onPrimary
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

                    model: root.workspaceIds
                    onItemAdded: Qt.callLater(root.syncActiveWorkspaceItem)
                    onItemRemoved: Qt.callLater(root.syncActiveWorkspaceItem)

                    Workspace {
                        required property int index
                        required property int modelData

                        workspaceId: modelData
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

            LazyListView {
                id: specialList

                x: (normalLayer.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(contentWidth,
                    normalLayer.width - Style.barWorkspaceRailPaddingHorizontal * 2)
                height: Style.barInnerHeight

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
                    width: specialList.currentItem
                        ? specialList.currentItem.width
                        : Style.barWorkspaceBaseSize
                    height: specialList.height

                    MaterialShape {
                        anchors.centerIn: parent
                        width: parent.width
                        height: Style.barWorkspaceActiveHeight
                        shape: MaterialShape.Pill
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
                    readonly property var windows:
                        modelData?.toplevels?.values ?? []
                    readonly property int windowCount:
                        Math.min(windows.length, root.maxWindowIcons)

                    width: Math.max(Style.barWorkspaceBaseSize,
                        specialContent.implicitWidth + Style.spacingSm)
                    height: specialList.height
                    opacity: specialItem.active ? 1.0 : 0.72
                    scale: specialItem.active ? 1.0 : 0.86
                    transformOrigin: Item.Center

                    Behavior on opacity { Anim { duration: Style.motionFast } }
                    Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutBack } }

                    Row {
                        id: specialContent
                        anchors.centerIn: parent
                        spacing: Style.barWorkspaceContentSpacing

                        Item {
                            width: Style.barIconNormal
                            height: Style.barIconNormal

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.plugin.service.specialWorkspaceIcon(
                                    specialItem.specialKey
                                )
                                iconSize: Style.barIconNormal
                                iconColor: specialItem.active
                                    ? Color.onPrimary
                                    : Color.onSurfaceVariant
                            }
                        }

                        Repeater {
                            model: specialItem.windowCount

                            Item {
                                required property int index
                                width: Style.barIconNormal
                                height: Style.barIconNormal

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: Icons.iconForWindow(
                                        specialItem.windows[index], "apps"
                                    )
                                    iconSize: Style.barIconNormal
                                    iconColor: specialItem.active
                                        ? Color.onPrimary
                                        : Color.onSurfaceVariant
                                    fill: 0
                                    grade: 0
                                }
                            }
                        }
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
