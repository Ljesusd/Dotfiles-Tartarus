import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../components"

Item {
    id: root

    required property var actions
    required property var controller
    required property bool active
    visible: root.active

    function revealSelection() {
        if (!root.active)
            return

        if (root.controller.selectedIndex < 0)
            return

        if (actionList.currentIndex >= 0)
            actionList.positionViewAtIndex(
                actionList.currentIndex,
                ListView.Contain
            )
    }

    onActiveChanged: {
        if (root.active)
            root.revealSelection()
    }

    Connections {
        target: root.controller

        function onSelectedIndexChanged() {
            root.revealSelection()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.paddingXLarge
        anchors.rightMargin: Style.paddingXLarge
        anchors.topMargin: Style.paddingLarge
        anchors.bottomMargin: Style.paddingXLarge

        spacing: Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true

            spacing: Style.spacingMedium

            MaterialIcon {
                text: "chevron_right"
                iconSize: Style.materialIconMedium
                iconColor: Color.accent
            }

            Text {
                text: "Actions"

                font.pixelSize: Style.fontNormal
                font.weight: Font.DemiBold
                color: Color.foreground
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: actionList

                anchors.fill: parent

                clip: true
                spacing: Style.spacingXs

                model: root.actions.filtered(
                    root.controller.actionQuery
                )

                currentIndex: root.active
                    ? root.controller.selectedIndex
                    : -1

                onCountChanged: {
                    if (root.active)
                        root.controller.resetSelection()
                }

                delegate: ActionItem {
                    required property var modelData
                    required property int index

                    action: modelData
                    selected: ListView.isCurrentItem

                    onHovered: {
                        root.controller.select(index)
                    }

                    onActivated: {
                        root.controller.select(index)
                        root.controller.accept()
                    }
                }
            }

            Text {
                anchors.centerIn: actionList

                visible: root.active && actionList.count === 0

                text: "No actions found"
                font.pixelSize: Style.fontNormal
                color: Color.foregroundMuted
            }
        }
    }
}
