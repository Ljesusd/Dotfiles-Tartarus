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

    implicitHeight: Style.barWorkspaceActiveHeight

    function displayName(name) {
        if (!name)
            return ""

        return name.startsWith("special:")
            ? name.slice(8)
            : name
    }

    ListView {
        id: specialView

        anchors.fill: parent

        orientation: ListView.Horizontal
        spacing: Style.spacingSm
        clip: true
        z: 1

        model: root.specialCount
        currentIndex: root.activeIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Style.motionNormal
        highlightResizeDuration: Style.motionNormal
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width * 0.25
        preferredHighlightEnd: width * 0.75
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

            MouseArea {
                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.interacted()

                    root.service.toggleSpecialWorkspace(
                        specialItem.workspace.name
                    )
                }
            }

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
