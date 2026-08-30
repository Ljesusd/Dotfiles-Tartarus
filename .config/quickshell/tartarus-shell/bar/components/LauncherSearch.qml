import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var launcherState
    required property var monitorContext
    required property var shellState

    implicitWidth: Style.launcherSearchWidth
    implicitHeight: Style.launcherSearchHeight

    radius: Style.radiusMedium

    color: {
        if (root.monitorContext.launcherOpened)
            return Color.background

        if (input.activeFocus || hoverHandler.hovered)
            return Color.surfaceHover

        return Color.surface
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.animationFast
        }
    }

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: Style.barPaddingNormal
        anchors.rightMargin: Style.barPaddingNormal

        spacing: Style.barSpacingSmall

        Text {
            text: "⌕"

            font.family: Style.iconFont
            font.pixelSize: Style.barIconNormal
            color: Color.foregroundMuted
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

                font.pixelSize: Style.barFontNormal
                color: Color.foregroundMuted
            }

            TextInput {
                id: input

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                text: root.launcherState.query

                font.pixelSize: Style.barFontNormal
                color: Color.foreground

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
