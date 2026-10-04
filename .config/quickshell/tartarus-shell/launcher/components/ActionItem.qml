import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var action
    required property bool selected
    readonly property bool highlighted:
        root.selected || hoverHandler.hovered

    signal activated()
    signal hovered()

    implicitWidth: ListView.view ? ListView.view.width : 0
    implicitHeight: Style.itemHeight

    radius: Style.cardRadius

    color: root.selected
        ? Color.primaryContainer
        : hoverHandler.hovered
            ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, Style.hoverOpacity)
            : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: Style.paddingLarge
        anchors.rightMargin: Style.paddingLarge
        anchors.topMargin: Style.spacingMedium
        anchors.bottomMargin: Style.spacingMedium

        spacing: Style.spacingMedium

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 3
            Layout.preferredHeight: 24
            radius: 2
            visible: root.selected
            color: Color.primary
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: root.action.icon
            iconSize: Style.materialIconMedium
            iconColor: root.selected ? Color.onPrimaryContainer : Color.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: Style.spacingXs

            Text {
                Layout.fillWidth: true

                text: root.action.name

                font.pixelSize: Style.fontNormal
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                color: root.selected ? Color.onPrimaryContainer : Color.foreground

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true

                text: root.action.description

                font.pixelSize: Style.fontSmall
                color: root.selected ? Color.onPrimaryContainer : Color.foregroundMuted

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: "chevron_right"
            iconSize: Style.materialIconMedium
            iconColor: root.selected
                ? Color.onPrimaryContainer
                : Color.foregroundMuted
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
