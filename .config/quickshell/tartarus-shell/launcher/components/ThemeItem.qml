import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var theme
    required property bool selected
    required property bool active

    signal activated()
    signal hovered()

    implicitHeight: 82

    radius: Style.radiusMedium

    color: root.selected
        ? Color.selection
        : hoverHandler.hovered
            ? Color.surfaceHover
            : Color.surface

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: Style.paddingLarge
        anchors.rightMargin: Style.paddingLarge

        spacing: Style.spacingMedium

        ColumnLayout {
            Layout.fillWidth: true

            spacing: Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                spacing: Style.spacingMedium

                Text {
                    Layout.fillWidth: true

                    text: root.theme.name

                    font.pixelSize: Style.fontNormal
                    color: Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    visible: root.active

                    text: "Active"

                    font.pixelSize: Style.fontSmall
                    color: Color.accent
                }
            }

            Text {
                text: root.theme.mode

                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
            }

            Row {
                spacing: Style.spacingSmall

                Repeater {
                    model: root.theme.preview ?? []

                    Rectangle {
                        required property var modelData

                        width: 20
                        height: 8

                        radius: 4

                        color: modelData
                    }
                }
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
