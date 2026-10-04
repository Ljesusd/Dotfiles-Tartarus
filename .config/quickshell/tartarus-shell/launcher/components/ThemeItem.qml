import QtQuick
import QtQuick.Layouts

import "../../theme"

Rectangle {
    id: root

    required property var theme
    required property bool selected
    required property bool current
    readonly property bool highlighted:
        root.selected || hoverHandler.hovered

    signal activated()
    signal hovered()

    implicitHeight: Style.launcherSchemeItemHeight

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
            Layout.preferredHeight: 28
            radius: 2
            visible: root.selected
            color: Color.primary
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: "palette"
            iconSize: Style.materialIconMedium
            iconColor: root.selected
                ? Color.onPrimaryContainer
                : Color.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                spacing: Style.spacingMedium

                Text {
                    Layout.fillWidth: true

                    text: root.theme.name

                    font.pixelSize: Style.fontNormal
                    color: root.selected ? Color.onPrimaryContainer : Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    radius: Style.radiusFull
                    color: root.selected
                        ? Color.secondaryContainer
                        : Color.secondary
                    implicitHeight: Style.launcherSchemeBadgeHeight
                    implicitWidth:
                        currentText.implicitWidth
                        + Style.spacingMedium * 2
                    opacity: root.current ? 1.0 : 0.0
                    scale: root.current ? 1.0 : 0.96

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Style.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Style.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: currentText

                        anchors.centerIn: parent

                        text: "Current"
                        font.pixelSize: Style.fontSmall
                        color: root.selected
                            ? Color.onSurface
                            : Color.onSecondary
                    }
                }
            }

            Text {
                text: root.theme.mode

                font.pixelSize: Style.fontSmall
                color: root.selected ? Color.onPrimaryContainer : Color.foregroundMuted
            }

            Row {
                spacing: Style.spacingSmall

                Repeater {
                    model: root.theme.preview ?? []

                    Rectangle {
                        required property var modelData

                        width: Style.launcherSchemePreviewWidth
                        height: Style.launcherSchemePreviewHeight

                        radius: Style.launcherSchemePreviewRadius

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
