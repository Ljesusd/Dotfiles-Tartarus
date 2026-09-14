import QtQuick
import "../../theme"

Rectangle {
    id: root

    property alias query: input.text

    signal escapePressed()
    signal moveUp()
    signal moveDown()
    signal moveLeft()
    signal moveRight()
    signal acceptPressed()

    height: Style.controlHeight
    radius: Style.radiusMedium

    color: Color.surface

    Text {
        id: searchIcon

        anchors {
            left: parent.left
            leftMargin: Style.paddingLarge
            verticalCenter: parent.verticalCenter
        }

        text: "⌕"
        font.pixelSize: Style.iconMedium
        color: Color.foregroundMuted
    }

    TextInput {
        id: input

        anchors {
            left: searchIcon.right
            right: parent.right
            verticalCenter: parent.verticalCenter

            leftMargin: Style.spacingMedium
            rightMargin: Style.paddingLarge
        }

        height: parent.height

        verticalAlignment: TextInput.AlignVCenter

        focus: true

        font.pixelSize: Style.fontLarge
        color: Color.foreground

        Keys.onEscapePressed: {
            root.escapePressed()
        }

        Keys.onDownPressed: {
            root.moveDown()
        }

        Keys.onUpPressed: {
            root.moveUp()
        }

        Keys.onLeftPressed: (event) => {
            if (input.text.length === 0 || input.cursorPosition === 0) {
                event.accepted = true
                root.moveLeft()
            }
        }

        Keys.onRightPressed: (event) => {
            if (input.text.length === 0 || input.cursorPosition === input.text.length) {
                event.accepted = true
                root.moveRight()
            }
        }

        Keys.onReturnPressed: {
            root.acceptPressed()
        }
    }

    Text {
        anchors {
            left: input.left
            verticalCenter: input.verticalCenter
        }

        visible: input.text.length === 0

        text: "Search applications..."
        font.pixelSize: Style.fontLarge
        color: Color.foregroundMuted
    }

    function forceActiveFocus() {
        input.forceActiveFocus()
    }
}
