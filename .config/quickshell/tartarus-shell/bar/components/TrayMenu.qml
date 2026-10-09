import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Layouts

import "../../theme"
import "../../launcher/components" as LauncherComponents

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
    // Same geometry as the launcher: the native popup starts at the roof of
    // the bar and its surface grows upward, leaving the bar uncovered.
    anchor.item: root.anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.Slide

    readonly property real maxMenuHeight: Math.max(
        220,
        Math.min(
            560,
            (root.anchorSurface?.screen?.height ?? 800)
                - (root.anchorSurface?.height ?? Style.barHeight)
                - Style.paddingLarge * 2
        )
    )
    readonly property real menuWidth: Math.min(
        340,
        Math.max(240, (root.anchorSurface?.width ?? 1280) * 0.24)
    )
    readonly property real menuHeight: Math.min(
        root.maxMenuHeight,
        Math.max(96, menuColumn.implicitHeight + Style.paddingMedium * 2 + Style.barPopupGap * 2)
    )
    // As in the launcher, only the inner surface animates. Reserve space for
    // the curves/shadow and avoid native-window resizing for every submenu.
    implicitWidth: Math.min(root.menuWidth + surface.horizontalInset * 2,
        Math.max(1, root.anchorSurface?.width ?? 1280))
    implicitHeight: root.maxMenuHeight + surface.shadowPadding
    color: "transparent"
    visible: (root.popupOpen || surface.reveal > 0) && trayItem && trayItem.hasMenu
    mask: Region { item: surface.maskItem }

    QsMenuOpener {
        id: opener
        menu: root.menuStack.length > 0 ? root.menuStack[root.menuStack.length - 1]
            : (root.trayItem ? root.trayItem.menu : null)
    }

    LauncherComponents.LauncherSurface {
        id: surface
        anchors.fill: parent
        opened: root.popupOpen
        contentWidth: Math.max(1, root.width - horizontalInset * 2)
        contentHeight: root.menuHeight

        HoverHandler {
            parent: surface.contentItem
            onHoveredChanged: {
                root.menuHovered = hovered
                if (hovered) root.popupOpen = true
            }
        }
        Flickable {
            id: menuViewport
            parent: surface.contentItem
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Style.paddingMedium
            anchors.rightMargin: Style.paddingMedium
            anchors.topMargin: Style.paddingSmall
            anchors.bottomMargin: Style.paddingMedium + Style.barPopupGap * 2
            clip: true
            contentWidth: width
            contentHeight: menuColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: menuColumn
            width: menuViewport.width
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
                    implicitHeight: modelData.isSeparator ? 1 : 36
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
}
