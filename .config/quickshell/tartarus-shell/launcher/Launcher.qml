pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../theme"
import "components"

Scope {
    id: root

    required property var launcherState

    GlobalShortcut {
        name: "launcher"
        description: "Toggle application launcher"

        onPressed: {
            root.launcherState.toggle()
        }
    }

    HyprlandFocusGrab {
        id: launcherFocusGrab

        windows: [
            root.launcherState.barWindow,
            launcherWindow
        ]

        active: root.launcherState.opened

        onCleared: {
            if (
                root.launcherState.opened
                && launcherWindow.outsideClickArmed
            ) {
                root.launcherState.close()
            }
        }
    }

    PopupWindow {
        id: launcherWindow

        property bool contentOpened: false
        property bool outsideClickArmed: false

        readonly property string mode: {
            const query = root.launcherState.query
                .trim()
                .toLowerCase()

            if (query.startsWith(">scheme"))
                return "schemes"

            if (query.startsWith(">"))
                return "actions"

            return "applications"
        }

        readonly property string actionQuery: {
            if (launcherWindow.mode !== "actions")
                return ""

            return root.launcherState.query
                .slice(1)
                .trim()
        }

        readonly property string schemeQuery: {
            if (launcherWindow.mode !== "schemes")
                return ""

            const prefix = ">scheme"

            return root.launcherState.query
                .slice(prefix.length)
                .trim()
        }

        anchor.item:
            root.launcherState.anchorItem

        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom

        implicitWidth: Style.launcherWidth
        implicitHeight: Style.launcherHeight

        color: "transparent"

        visible: false
        grabFocus: false

        Applications {
            id: applications
        }

        Themes {
            id: themes
        }

        LauncherActions {
            id: launcherActions
        }

        Timer {
            id: closeTimer

            interval: Style.animationNormal
            repeat: false

            onTriggered: {
                launcherWindow.visible = false
            }
        }

        Timer {
            id: outsideClickArmTimer

            interval: 120
            repeat: false

            onTriggered: {
                launcherWindow.outsideClickArmed = true
            }
        }

        Connections {
            target: root.launcherState

            function onOpenedChanged() {
                if (root.launcherState.opened) {
                    launcherWindow.outsideClickArmed = false
                    outsideClickArmTimer.restart()
                    launcherWindow.openLauncher()
                } else {
                    outsideClickArmTimer.stop()
                    launcherWindow.outsideClickArmed = false
                    launcherWindow.closeLauncher()
                }
            }

            function onQueryChanged() {
                if (launcherWindow.mode === "applications") {
                    applications.query =
                        root.launcherState.query
                }

                launcherWindow.selectFirstVisibleItem()
            }

            function onMoveDownRequested() {
                launcherWindow.moveDown()
            }

            function onMoveUpRequested() {
                launcherWindow.moveUp()
            }

            function onAcceptRequested() {
                launcherWindow.acceptCurrent()
            }

            function onEscapeRequested() {
                if (!root.launcherState.opened)
                    return

                launcherWindow.goBack()
            }
        }

        function activateAction(action) {
            if (!action)
                return

            root.launcherState.query =
                ">" + action.command

            root.launcherState.focusSearch()

            launcherWindow.selectFirstVisibleItem()
        }

        function selectFirstVisibleItem() {
            Qt.callLater(() => {
                if (
                    launcherWindow.mode === "applications"
                    && appList.count > 0
                ) {
                    appList.currentIndex = 0
                } else if (
                    launcherWindow.mode === "actions"
                    && actionList.count > 0
                ) {
                    actionList.currentIndex = 0
                } else if (
                    launcherWindow.mode === "schemes"
                    && schemeList.count > 0
                ) {
                    schemeList.currentIndex = 0
                }
            })
        }

        function currentScheme() {
            if (
                schemeList.currentIndex < 0
                || schemeList.currentIndex >= schemeList.count
            ) {
                return null
            }

            return schemeList.model[
                schemeList.currentIndex
            ]
        }

        function goBack() {
            if (launcherWindow.mode === "schemes") {
                root.launcherState.query = ">"
                root.launcherState.focusSearch()
                return
            }

            if (launcherWindow.mode === "actions") {
                root.launcherState.query = ""
                root.launcherState.focusSearch()
                return
            }

            root.launcherState.close()
        }

        function moveDown() {
            if (launcherWindow.mode === "applications") {
                if (appList.currentIndex < appList.count - 1)
                    appList.currentIndex++
            } else if (launcherWindow.mode === "actions") {
                if (actionList.currentIndex < actionList.count - 1)
                    actionList.currentIndex++
            } else if (launcherWindow.mode === "schemes") {
                if (schemeList.currentIndex < schemeList.count - 1)
                    schemeList.currentIndex++
            }
        }

        function moveUp() {
            if (launcherWindow.mode === "applications") {
                if (appList.currentIndex > 0)
                    appList.currentIndex--
            } else if (launcherWindow.mode === "actions") {
                if (actionList.currentIndex > 0)
                    actionList.currentIndex--
            } else if (launcherWindow.mode === "schemes") {
                if (schemeList.currentIndex > 0)
                    schemeList.currentIndex--
            }
        }

        function acceptCurrent() {
            if (
                launcherWindow.mode === "applications"
                && appList.count > 0
                && appList.currentIndex >= 0
            ) {
                applications.launch(
                    applications.applications.values[appList.currentIndex]
                )

                root.launcherState.close()
            } else if (
                launcherWindow.mode === "actions"
                && actionList.count > 0
                && actionList.currentIndex >= 0
            ) {
                const action =
                    actionList.model[actionList.currentIndex]

                launcherWindow.activateAction(action)
            } else if (
                launcherWindow.mode === "schemes"
                && schemeList.count > 0
                && schemeList.currentIndex >= 0
            ) {
                const theme =
                    launcherWindow.currentScheme()

                if (theme)
                    themes.setTheme(theme.slug)
            }
        }

        function openLauncher() {
            closeTimer.stop()

            launcherWindow.visible = true
            launcherWindow.contentOpened = false

            Qt.callLater(() => {
                launcherWindow.contentOpened = true

                if (launcherWindow.mode === "applications") {
                    applications.query =
                        root.launcherState.query
                }

                launcherWindow.selectFirstVisibleItem()
                root.launcherState.focusSearch()
            })
        }

        function closeLauncher() {
            launcherWindow.contentOpened = false
            closeTimer.restart()
        }

        function toggleLauncher() {
            root.launcherState.toggle()
        }

        Rectangle {
            id: launcherContent

            clip: true

            width: launcherWindow.contentOpened
                ? Style.launcherWidth
                : Style.launcherSearchWidth

            height: launcherWindow.contentOpened
                ? Style.launcherHeight
                : 0

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            opacity: launcherWindow.contentOpened
                ? 1
                : 0

            radius: Style.radiusLarge
            color: Color.background

            Behavior on width {
                NumberAnimation {
                    duration: Style.animationNormal
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Style.animationNormal
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animationFast
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: Style.radiusLarge

                color: launcherContent.color
            }

            ListView {
                id: appList

                visible: launcherWindow.mode === "applications"

                clip: true

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    topMargin: Style.paddingLarge
                    leftMargin: Style.paddingXLarge
                    rightMargin: Style.paddingXLarge
                    bottomMargin: Style.paddingXLarge
                }

                model: applications.applications
                currentIndex: 0

                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                }

                delegate: AppItem {
                    required property var modelData
                    required property int index

                    application: modelData
                    selected: ListView.isCurrentItem

                    onHovered: {
                    }

                    onActivated: {
                        applications.launch(application)
                        root.launcherState.close()
                    }
                }
            }

            Text {
                anchors.centerIn: appList

                visible: launcherWindow.mode === "applications"
                    && appList.count === 0

                text: "No applications found"

                font.pixelSize: Style.fontNormal
                color: Color.foregroundMuted
            }

            ListView {
                id: actionList

                visible: launcherWindow.mode === "actions"

                clip: true

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    topMargin: Style.paddingLarge
                    leftMargin: Style.paddingXLarge
                    rightMargin: Style.paddingXLarge
                    bottomMargin: Style.paddingXLarge
                }

                model: launcherActions.filtered(
                    launcherWindow.actionQuery
                )

                currentIndex: 0

                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                }

                delegate: ActionItem {
                    required property var modelData
                    required property int index

                    action: modelData
                    selected: ListView.isCurrentItem

                    onHovered: {
                    }

                    onActivated: {
                        launcherWindow.activateAction(action)
                    }
                }
            }

            ListView {
                id: schemeList

                visible: launcherWindow.mode === "schemes"

                clip: true

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom

                    topMargin: Style.paddingLarge
                    leftMargin: Style.paddingXLarge
                    rightMargin: Style.paddingXLarge
                    bottomMargin: Style.paddingXLarge
                }

                model: themes.filtered(
                    launcherWindow.schemeQuery
                )
                spacing: Style.spacingSmall

                currentIndex: 0

                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain)
                }

                delegate: ThemeItem {
                    required property var modelData
                    required property int index

                    width: ListView.view.width

                    theme: modelData

                    selected: ListView.isCurrentItem

                    active:
                        modelData.slug
                        === themes.currentSlug

                    onHovered: {
                    }

                    onActivated: {
                        themes.setTheme(theme.slug)
                    }
                }
            }

            Text {
                anchors.centerIn: schemeList

                visible: launcherWindow.mode === "schemes"
                    && schemeList.count === 0

                text: "No schemes found"

                font.pixelSize: Style.fontNormal
                color: Color.foregroundMuted
            }
        }
    }
}
