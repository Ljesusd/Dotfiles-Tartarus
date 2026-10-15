import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme
import "../components"

Item {
    id: root

    required property var themes
    required property var controller
    required property bool active
    visible: root.active

    function revealSelection() {
        if (!root.active)
            return

        if (root.controller.selectedIndex < 0)
            return

        if (schemeList.currentIndex >= 0)
            schemeList.positionViewAtIndex(
                schemeList.currentIndex,
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
        anchors.leftMargin: Theme.Style.paddingXLarge
        anchors.rightMargin: Theme.Style.paddingXLarge
        anchors.topMargin: Theme.Style.paddingLarge
        anchors.bottomMargin: Theme.Style.paddingXLarge

        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true

            spacing: Theme.Style.spacingLarge

            Theme.MaterialIcon {
                text: "palette"
                iconSize: Theme.Style.materialIconMedium
                iconColor: Theme.Color.primary
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Theme.Style.spacingXs

                Text {
                    text: "Schemes"

                    font.pixelSize: Theme.Style.fontNormal
                    font.weight: Font.DemiBold
                    color: Theme.Color.foreground
                }

                Text {
                    text: "Select a color scheme"

                    font.pixelSize: Theme.Style.fontSmall
                    color: Theme.Color.foregroundMuted
                }
            }

            Text {
                text: root.themes.currentSlug

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.tertiary
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LauncherListView {
                id: schemeList
                pageActive: root.active

                anchors.fill: parent

                model: root.themes.filtered(
                    root.controller.schemeQuery
                )
                spacing: Theme.Style.spacingSmall

                currentIndex: root.active
                    ? root.controller.selectedIndex
                    : -1

                onCountChanged: {
                    if (root.active)
                        root.controller.resetSelection()
                }

                delegate: ThemeItem {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    theme: modelData
                    selected: ListView.isCurrentItem

                    current:
                        modelData.slug
                        === root.themes.currentSlug

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
                anchors.centerIn: schemeList

                visible: root.active && schemeList.count === 0

                text: "No schemes found"
                font.pixelSize: Theme.Style.fontNormal
                color: Theme.Color.foregroundMuted
            }
        }
    }
}
