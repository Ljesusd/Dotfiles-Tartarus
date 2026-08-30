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

    radius: Style.radiusMedium

    color: root.selected
        ? Color.selection
        : hoverHandler.hovered
            ? Color.surfaceHover
            : Color.surface

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

        MaterialIcon {
            Layout.alignment: Qt.AlignTop

            text: root.action.icon
            iconSize: Style.iconMedium
            iconColor: Color.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: Style.spacingXs

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

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: "chevron_right"
            iconSize: Style.materialIconMedium
            iconColor: Color.foregroundMuted
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
