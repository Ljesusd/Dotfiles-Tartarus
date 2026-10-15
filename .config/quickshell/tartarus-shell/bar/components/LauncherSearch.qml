import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme

Rectangle {
    id: root

    required property var launcherState
    required property var monitorContext
    required property var shellState

    implicitWidth: Theme.Style.launcherSearchWidth
    implicitHeight: Theme.Style.launcherSearchHeight

    radius: Theme.Style.radiusFull

    color: root.monitorContext.launcherOpened || input.activeFocus
        ? Theme.Color.surfaceContainerHigh
        : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.Style.animationFast
        }
    }

    border.width: input.activeFocus || hoverHandler.hovered
        ? Theme.Style.panelBorderWidth
        : 0
    border.color: Theme.Color.primary

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: Theme.Style.barPaddingNormal
        anchors.rightMargin: Theme.Style.barPaddingNormal

        spacing: Theme.Style.barSpacingSmall

        Theme.MaterialIcon {
            text: "search"
            iconSize: Theme.Style.barIconNormal
            iconColor: Theme.Color.foregroundMuted
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }

                visible: input.text === ""

                text: "Search"

                font.pixelSize: Theme.Style.barFontNormal
                color: Theme.Color.foregroundMuted
            }

            TextInput {
                id: input

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                text: root.launcherState.query

                font.pixelSize: Theme.Style.barFontNormal
                color: Theme.Color.foreground

                selectByMouse: true

                onTextEdited: {
                    root.launcherState.query = text

                    if (!root.monitorContext.launcherOpened) {
                        root.shellState.openLauncher(
                            root.monitorContext
                        )
                        root.launcherState.focusSearch()
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        root.launcherState.moveDownRequested()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.launcherState.moveUpRequested()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (
                            input.text.length === 0
                            || input.cursorPosition === 0
                        ) {
                            root.launcherState.moveLeftRequested()
                            event.accepted = true
                        }
                    } else if (event.key === Qt.Key_Right) {
                        if (
                            input.text.length === 0
                            || input.cursorPosition === input.text.length
                        ) {
                            root.launcherState.moveRightRequested()
                            event.accepted = true
                        }
                    } else if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        root.launcherState.acceptRequested()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        root.launcherState.escapeRequested()
                        event.accepted = true
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        onTapped: {
            root.shellState.openLauncher(
                root.monitorContext
            )
            root.launcherState.focusSearch()

            Qt.callLater(() => {
                input.forceActiveFocus()
            })
        }
    }

    Connections {
        target: root.launcherState

        function onFocusRequested() {
            if (!root.monitorContext.launcherOpened)
                return

            input.forceActiveFocus()
        }
    }

    Connections {
        target: root.monitorContext

        function onLauncherOpenedChanged() {
            if (!root.monitorContext.launcherOpened)
                input.focus = false
        }
    }

    function focusSearch() {
        input.forceActiveFocus()
    }
}
