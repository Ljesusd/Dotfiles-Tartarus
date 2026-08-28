import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../components"

Item {
    id: root

    required property var applications
    required property var controller
    required property bool active
    visible: root.active

    function revealSelection() {
        if (!root.active)
            return

        if (root.controller.selectedIndex < 0)
            return

        if (appList.currentIndex >= 0)
            appList.positionViewAtIndex(
                appList.currentIndex,
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
                text: "apps"
                iconSize: Style.materialIconMedium
                iconColor: Color.accent
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Style.spacingXs

                Text {
                    text: "Applications"

                    font.pixelSize: Style.fontNormal
                    font.weight: Font.DemiBold
                    color: Color.foreground
                }

                Text {
                    text: "Launch an application"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: appList

                anchors.fill: parent

                clip: true
                spacing: Style.spacingXs

                model: root.applications.applications
                currentIndex: root.active
                    ? root.controller.selectedIndex
                    : -1

                onCountChanged: {
                    if (root.active)
                        root.controller.resetSelection()
                }

                delegate: AppItem {
                    required property var modelData
                    required property int index

                    application: modelData
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
                anchors.centerIn: appList

                visible: root.active && appList.count === 0

                text: "No applications found"
                font.pixelSize: Style.fontNormal
                color: Color.foregroundMuted
            }
        }
    }
}
