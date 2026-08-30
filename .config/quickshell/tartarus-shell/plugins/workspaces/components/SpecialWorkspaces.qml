pragma ComponentBehavior: Bound

import QtQuick

import "../../../theme"
import "../../../utils"

Rectangle {
    id: root

    required property var service
    required property var barScreen

    signal interacted()

    readonly property string activeName:
        service.activeSpecialWorkspaceNameForScreen(barScreen)

    readonly property var specialWorkspaces:
        service.specialWorkspaces()

    readonly property int specialCount:
        specialWorkspaces.length

    readonly property int maxWindowIcons: 5
    readonly property real edgeFadeWidth:
        Style.spacingLg
    readonly property real edgeFadeRatio:
        width > 0
        ? Math.min(
            0.25,
            root.edgeFadeWidth / width
        )
        : 0
    readonly property int activeIndex: {
        for (
            let index = 0;
            index < root.specialCount;
            index++
        ) {
            const workspace =
                root.specialWorkspaces[index]

            if (
                workspace
                && workspace.name === root.activeName
            ) {
                return index
            }
        }

        return -1
    }
    readonly property real dragThreshold: 8

    property real dragStartX: 0
    property real dragStartContentX: 0
    property bool specialDragging: false

    implicitHeight: Style.barWorkspaceActiveHeight

    function maxContentX() {
        return Math.max(
            0,
            specialView.contentWidth - specialView.width
        )
    }

    function boundedContentX(value) {
        return Math.max(
            0,
            Math.min(
                root.maxContentX(),
                value
            )
        )
    }

    function ensureActiveVisible() {
        if (root.activeIndex < 0)
            return

        Qt.callLater(() => {
            specialView.positionViewAtIndex(
                root.activeIndex,
                ListView.Contain
            )
        })
    }

    onActiveIndexChanged: {
        root.ensureActiveVisible()
    }

    ListView {
        id: specialView

        anchors.fill: parent

        orientation: ListView.Horizontal
        spacing: Style.spacingSm
        clip: true
        interactive: false
        z: 1

        model: root.specialCount
        currentIndex: root.activeIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Style.motionNormal
        highlightResizeDuration: Style.motionNormal
        highlightRangeMode: ListView.NoHighlightRange
        highlight: Rectangle {
            radius: Style.radiusFull
            color: Color.tertiaryContainer
            z: 0
        }

        delegate: Rectangle {
            id: specialItem

            required property int index

            readonly property var workspace:
                root.specialWorkspaces[index]

            readonly property bool active:
                workspace
                && workspace.name === root.activeName

            readonly property var windows:
                workspace
                ? root.service.windowsForSpecialWorkspace(
                    workspace.name
                )
                : []
            readonly property color containerColor:
                "transparent"
            readonly property color contentColor:
                specialItem.active
                ? Color.onTertiaryContainer
                : Color.onSurfaceVariant
            readonly property string specialIcon:
                Icons.specialWorkspaceIcon(
                    specialItem.workspace?.name ?? ""
                )
            readonly property bool specialIconIsText:
                specialItem.specialIcon.length === 1

            radius: Style.radiusSmall
            color: specialItem.containerColor
            z: 1

            implicitWidth: Math.max(
                Style.barInnerHeight,
                itemContent.implicitWidth + Style.spacingMd
            )

            implicitHeight: Style.barWorkspaceActiveHeight

            Row {
                id: itemContent

                anchors.centerIn: parent
                spacing: Style.barWorkspaceContentSpacing

                Loader {
                    anchors.verticalCenter: parent.verticalCenter

                    sourceComponent:
                        specialItem.specialIconIsText
                        ? letterComponent
                        : materialIconComponent
                }

                Row {
                    spacing: 0

                    Repeater {
                        model: Math.min(
                            specialItem.windows.length,
                            root.maxWindowIcons
                        )

                        MaterialIcon {
                            required property int index

                            text: Icons.iconForWindow(
                                specialItem.windows[index],
                                "apps"
                            )

                            iconSize: Style.barWorkspaceIconSize
                            iconColor: specialItem.contentColor
                        }
                    }
                }
            }

            Component {
                id: materialIconComponent

                MaterialIcon {
                    text: specialItem.specialIcon

                    iconSize: Style.barWorkspaceIconSize
                    iconColor: specialItem.contentColor
                }
            }

            Component {
                id: letterComponent

                Text {
                    text: specialItem.specialIcon

                    font.pixelSize: Style.barWorkspaceIconSize
                    color: specialItem.contentColor

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    MouseArea {
        id: specialInteraction

        anchors.fill: specialView
        z: 20

        acceptedButtons: Qt.LeftButton

        onPressed: event => {
            root.dragStartX = event.x
            root.dragStartContentX = specialView.contentX
            root.specialDragging = false
        }

        onPositionChanged: event => {
            if (!(event.buttons & Qt.LeftButton))
                return

            const delta = event.x - root.dragStartX

            if (
                !root.specialDragging
                && Math.abs(delta) >= root.dragThreshold
            ) {
                root.specialDragging = true
            }

            if (!root.specialDragging)
                return

            specialView.contentX = root.boundedContentX(
                root.dragStartContentX - delta
            )
        }

        onReleased: event => {
            const wasDragging = root.specialDragging

            root.specialDragging = false

            if (wasDragging)
                return

            const contentX = event.x + specialView.contentX
            const contentY = event.y + specialView.contentY

            const index = specialView.indexAt(
                contentX,
                contentY
            )

            if (index < 0)
                return

            const workspace = root.specialWorkspaces[index]

            if (!workspace)
                return

            root.interacted()
            root.service
                .toggleSpecialWorkspaceForScreen(
                    root.barScreen,
                    workspace.name
                )
        }

        onCanceled: {
            root.specialDragging = false
        }
    }

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }

        width: root.edgeFadeWidth
        visible: !specialView.atXBeginning
        z: 10

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Color.surfaceContainer
                }

                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }

        width: root.edgeFadeWidth
        visible: !specialView.atXEnd
        z: 10

        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: 1
                color: Color.surfaceContainer
            }
        }
    }
}
