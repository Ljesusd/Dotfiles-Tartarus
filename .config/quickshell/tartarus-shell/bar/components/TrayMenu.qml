import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Layouts

import "../../theme"

PopupWindow {
    id: root

    required property var trayItem
    property bool menuHovered: false
    property bool popupOpen: false
    property var menuStack: []

    function open() {
        menuStack = []
        popupOpen = true
    }

    function close() {
        popupOpen = false
    }

    required property Item anchorItem
    anchor.item: root.anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: 300
    implicitHeight: Math.min(420, menuColumn.implicitHeight + Style.paddingMedium * 2)
    color: "transparent"
    visible: (root.popupOpen || surface.opacity > 0) && trayItem && trayItem.hasMenu

    QsMenuOpener {
        id: opener
        menu: root.menuStack.length > 0 ? root.menuStack[root.menuStack.length - 1]
            : (root.trayItem ? root.trayItem.menu : null)
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        anchors.margins: Style.barPopupGap
        radius: Style.radiusLarge
        color: Color.surfaceContainer
        border.width: Style.panelBorderWidth
        border.color: Color.outlineVariant
        clip: true
        HoverHandler {
            onHoveredChanged: {
                root.menuHovered = hovered
                if (hovered) root.popupOpen = true
            }
        }
        opacity: root.popupOpen ? 1 : 0
        scale: root.popupOpen ? 1 : 0.94

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutBack } }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingXs

            Text {
                Layout.fillWidth: true
                visible: root.menuStack.length > 0
                text: "‹ Back"
                color: Color.foreground
                font.pixelSize: Style.fontSmall
                TapHandler { onTapped: root.menuStack = root.menuStack.slice(0, -1) }
            }

            Repeater {
                model: opener.children

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 1 : 34
                    radius: Style.radiusMedium
                    color: modelData.isSeparator
                        ? Color.outlineVariant
                        : itemHover.hovered ? Color.surfaceHover : "transparent"

                    HoverHandler { id: itemHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.paddingSmall
                        anchors.rightMargin: Style.paddingSmall
                        visible: !modelData.isSeparator
                        spacing: Style.spacingSmall

                        IconImage {
                            visible: modelData.icon !== ""
                            implicitSize: Style.iconSmall
                            source: modelData.icon
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.text
                            elide: Text.ElideRight
                            font.pixelSize: Style.fontSmall
                            color: modelData.enabled ? Color.foreground : Color.foregroundMuted
                        }

                        MaterialIcon {
                            visible: modelData.hasChildren
                            text: "chevron_right"
                            iconSize: Style.materialIconSmall
                            iconColor: Color.foregroundMuted
                        }
                    }

                    TapHandler {
                        enabled: !modelData.isSeparator && modelData.enabled
                        onTapped: {
                            if (modelData.hasChildren)
                                root.menuStack = root.menuStack.concat([modelData])
                            else {
                                modelData.triggered()
                                root.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
