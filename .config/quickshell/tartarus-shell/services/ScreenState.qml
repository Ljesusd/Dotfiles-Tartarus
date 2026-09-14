import Quickshell
import QtQml

QtObject {
    id: root

    required property var screen
    readonly property string name: root.screen ? root.screen.name : ""
    readonly property real x: root.screen ? root.screen.x : 0
    readonly property real y: root.screen ? root.screen.y : 0
    readonly property real width: root.screen ? root.screen.width : 0
    readonly property real height: root.screen ? root.screen.height : 0
    readonly property real scale:
        root.screen ? root.screen.devicePixelRatio : 1.0
    readonly property rect geometry: Qt.rect(
        root.x, root.y, root.width, root.height
    )

    property bool launcherOpened: false
    property bool sidebarOpened: false
    property int sidebarTab: 0
    property bool osdActive: false
    property string osdKind: ""
    property real osdValue: 0
    property bool osdMuted: false
    property bool notificationCenterOpen: false
    property int notificationPopupCount: 0
    property var notificationPopupIds: []
    property string wallpaperPath: ""
    property bool clipboardOpen: false
    property bool imageViewerOpen: false
    property string imageViewerPath: ""

    function openClipboard() { root.clipboardOpen = true }
    function closeClipboard() { root.clipboardOpen = false }
    function toggleClipboard() {
        if (root.clipboardOpen)
            root.closeClipboard()
        else
            root.openClipboard()
    }

    function openNotificationCenter() {
        root.notificationCenterOpen = true
    }

    function closeNotificationCenter() {
        root.notificationCenterOpen = false
    }

    function openLauncher() {
        root.launcherOpened = true
        root.sidebarOpened = false
    }

    function closeLauncher() {
        root.launcherOpened = false
    }

    function toggleLauncher() {
        if (root.launcherOpened)
            root.closeLauncher()
        else
            root.openLauncher()
    }

    function openSidebar() {
        root.sidebarOpened = true
        root.launcherOpened = false
    }

    function closeSidebar() {
        root.sidebarOpened = false
    }

    function toggleSidebar() {
        if (root.sidebarOpened)
            root.closeSidebar()
        else
            root.openSidebar()
    }
}
