import QtQuick
import QtQuick.Layouts

import "../../theme"
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
        anchors.leftMargin: Style.paddingXLarge
        anchors.rightMargin: Style.paddingXLarge
        anchors.topMargin: Style.paddingLarge
        anchors.bottomMargin: Style.paddingXLarge

        spacing: Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true

            spacing: Style.spacingMedium

            MaterialIcon {
                text: "palette"
                iconSize: Style.materialIconMedium
                iconColor: Color.accent
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Style.spacingXs

                Text {
                    text: "Schemes"

                    font.pixelSize: Style.fontNormal
                    font.weight: Font.DemiBold
                    color: Color.foreground
                }

                Text {
                    text: "Select a color scheme"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }
            }

            Text {
                text: root.themes.currentSlug

                font.pixelSize: Style.fontSmall
                color: Color.accent
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: schemeList

                anchors.fill: parent

                clip: true

                model: root.themes.filtered(
                    root.controller.schemeQuery
                )
                spacing: Style.spacingSmall

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
                font.pixelSize: Style.fontNormal
                color: Color.foregroundMuted
            }
        }
    }
}
