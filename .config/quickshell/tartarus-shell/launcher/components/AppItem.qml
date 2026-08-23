import Quickshell
import QtQuick
import "../../theme"

Rectangle {
    id: root

    required property var application
    required property bool selected

    signal activated()
    signal hovered()

    width: ListView.view ? ListView.view.width : 0
    height: Style.itemHeight
    radius: Style.radiusMedium

    color: root.selected
        ? Color.selection
        : hoverHandler.hovered
            ? Color.surfaceHover
            : "transparent"

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (hovered)
                root.hovered()
        }
    }

    TapHandler {
        onTapped: {
            root.activated()
        }
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter

            leftMargin: Style.paddingLarge
            rightMargin: Style.paddingLarge
        }

        spacing: Style.spacingMedium

        Image {
            id: appIcon

            width: Style.iconLarge
            height: Style.iconLarge

            source: Quickshell.iconPath(root.application.icon)
            fillMode: Image.PreserveAspectFit
        }

        Column {
            width: parent.width - appIcon.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter

            spacing: 2

            Text {
                width: parent.width

                text: root.application.name

                font.pixelSize: Style.fontNormal
                color: Color.foreground

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width

                visible: root.application.comment
                    && root.application.comment.length > 0

                text: root.application.comment ?? ""

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
