import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var application
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.paddingLarge
        anchors.rightMargin: Style.paddingLarge
        anchors.topMargin: Style.spacingMedium
        anchors.bottomMargin: Style.spacingMedium

        spacing: Style.spacingMedium

        Image {
            id: appIcon

            Layout.alignment: Qt.AlignTop

            Layout.preferredWidth: Style.iconMedium
            Layout.preferredHeight: Style.iconMedium

            source: Quickshell.iconPath(root.application.icon)
            fillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: Style.spacingXs

            Text {
                Layout.fillWidth: true

                text: root.application.name

                font.pixelSize: Style.fontNormal
                color: Color.foreground

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                Layout.fillWidth: true

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
