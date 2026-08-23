import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var action
    required property bool selected

    signal activated()
    signal hovered()

    implicitHeight: Style.itemHeight

    radius: Style.radiusMedium

    color: root.selected
        ? Color.selection
        : hoverHandler.hovered
            ? Color.surfaceHover
            : "transparent"

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: Style.paddingLarge
        anchors.rightMargin: Style.paddingLarge

        spacing: Style.spacingMedium

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 2

            Text {
                Layout.fillWidth: true

                text: root.action.name

                font.pixelSize: Style.fontNormal
                color: Color.foreground

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true

                text: root.action.description

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

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
}
