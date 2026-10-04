import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Layouts

import "../../theme"

PopupWindow {
    id: root

    required property var trayItem
    required property Item anchorSurface
    property bool menuHovered: false
    property bool popupOpen: false
    property var menuStack: []

    function materialFallback(iconName) {
        const name = String(iconName || "").split("/").pop().replace(/\.(svg|png)$/i, "")
        return ({
            "user-bookmarks-symbolic": "bookmarks",
            "audio-input-microphone-symbolic": "mic",
            "audio-speakers-symbolic": "speaker",
            "input-keyboard-symbolic": "keyboard",
            "help-contents-symbolic": "help",
            "application-exit-symbolic": "exit_to_app"
        })[name] || ""
    }

    function open() {
        menuStack = []
        popupOpen = true
    }

    function close() {
        popupOpen = false
    }

    required property Item anchorItem
    anchor.item: root.anchorSurface
    // Anchor the popup to the whole bar, while retaining the tray icon's
    // horizontal position as the attachment point.
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    anchor.rect: root.anchorSurface && root.anchorItem
        ? Qt.rect(
            root.anchorItem.mapToItem(root.anchorSurface, 0, 0).x,
            0,
            root.anchorItem.width,
            root.anchorSurface.height + Style.barPopupGap
        )
        : Qt.rect(0, 0, 1, 1)

    implicitWidth: Math.min(
        360,
        Math.max(260, (root.anchorSurface?.width ?? 1280) * 0.42)
    )
    implicitHeight: Math.min(
        520,
        menuColumn.implicitHeight + Style.paddingMedium * 2 + Style.barPopupGap * 2
    )
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
        color: "transparent"
        clip: true

        AttachedPopupSurface {
            anchors.fill: parent
            fillColor: Color.surfaceContainer
            neckHeight: Style.barPopupGap * 2
        }
        HoverHandler {
            onHoveredChanged: {
                root.menuHovered = hovered
                if (hovered) root.popupOpen = true
            }
        }
        opacity: root.popupOpen ? 1 : 0
        scale: root.popupOpen ? 1 : 0.94
        transformOrigin: Item.Bottom

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutBack } }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.leftMargin: Style.paddingLarge
            anchors.rightMargin: Style.paddingLarge
            anchors.topMargin: Style.paddingMedium
            anchors.bottomMargin: Style.paddingMedium + Style.barPopupGap * 2
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
                    implicitHeight: modelData.isSeparator ? 1 : Style.controlHeight
                    radius: Style.controlRadius
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
                            visible: modelData.icon !== "" && root.materialFallback(modelData.icon) === ""
                            implicitSize: Style.iconSmall
                            source: root.materialFallback(modelData.icon) === ""
                                ? modelData.icon
                                : ""
                        }

                        MaterialIcon {
                            visible: root.materialFallback(modelData.icon) !== ""
                            text: root.materialFallback(modelData.icon)
                            iconSize: Style.iconSmall
                            iconColor: Color.foregroundMuted
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
