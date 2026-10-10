import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../services" as Services
import "../../theme"
import "../../launcher/components" as LauncherComponents

PopupWindow {
    id: root
    required property Item anchorItem
    required property var barWindow
    required property var monitorContext
    property bool popupOpen: false

    function toggle() { popupOpen = !popupOpen && Services.MediaService.available }
    function close() { popupOpen = false }

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: Math.min(360 + surface.horizontalInset * 2, Math.max(1, (root.barWindow.screen?.width ?? 1280) - 32))
    implicitHeight: Math.min(540, Math.max(1, (root.barWindow.screen?.height ?? 800) - Style.barHeight - 32))
    visible: root.popupOpen || surface.reveal > 0
    color: "transparent"
    mask: Region { item: surface.maskItem }

    HyprlandFocusGrab {
        windows: [root.barWindow, root]
        active: root.popupOpen
        onCleared: root.close()
    }
    Connections {
        target: root.monitorContext
        function onLauncherOpenedChanged() { if (root.monitorContext.launcherOpened) root.close() }
    }
    Connections {
        target: Services.MediaService
        function onAvailableChanged() { if (!Services.MediaService.available) root.close() }
    }
    Shortcut { sequence: "Escape"; enabled: root.popupOpen; onActivated: root.close() }
    LauncherComponents.LauncherSurface {
        id: surface
        anchors.fill: parent
        opened: root.popupOpen
        contentWidth: Math.max(1, root.width - horizontalInset * 2)
        contentHeight: Math.min(root.height - shadowPadding, card.item?.implicitHeight ?? 460)
    }
    Flickable {
        parent: surface.contentItem
        anchors.fill: parent
        contentHeight: card.item?.implicitHeight ?? 0
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: card
            width: parent.width
            active: root.popupOpen || surface.reveal > 0
            sourceComponent: MusicCard {
                active: root.popupOpen
                onCloseRequested: root.close()
            }
        }
    }
}
