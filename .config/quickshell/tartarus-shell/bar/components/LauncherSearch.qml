import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var launcherState

    implicitWidth: Style.launcherSearchWidth
    implicitHeight: Style.launcherSearchHeight

    radius: Style.radiusMedium

    color: {
        if (root.launcherState.opened)
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

    Component.onCompleted: {
        root.launcherState.anchorItem = root
    }

    Rectangle {
        id: bottomCornerFill

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        height: root.launcherState.opened
            ? Style.radiusMedium
            : 0

        color: root.color

        visible: height > 0

        Behavior on height {
            NumberAnimation {
                duration: Style.animationFast
            }
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

                    if (!root.launcherState.opened)
                        root.launcherState.open()
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
            root.launcherState.open()

            Qt.callLater(() => {
                input.forceActiveFocus()
            })
        }
    }

    Connections {
        target: root.launcherState

        function onFocusRequested() {
            input.forceActiveFocus()
        }

        function onOpenedChanged() {
            if (!root.launcherState.opened)
                input.focus = false
        }
    }

    function focusSearch() {
        input.forceActiveFocus()
    }
}
