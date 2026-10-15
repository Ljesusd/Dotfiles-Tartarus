import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme

Rectangle {
    id: root

    required property var theme
    required property bool selected
    required property bool current
    readonly property bool highlighted:
        root.selected || hoverHandler.hovered

    signal activated()
    signal hovered()

    implicitHeight: Math.max(Theme.Style.launcherSchemeItemHeight,
        themeContent.implicitHeight + Theme.Style.paddingSmall * 2)

    radius: Theme.Style.cardRadius

    color: hoverHandler.hovered && !root.selected
            ? Qt.rgba(Theme.Color.foreground.r, Theme.Color.foreground.g, Theme.Color.foreground.b, Theme.Style.hoverOpacity)
            : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: themeContent
        anchors.fill: parent

        anchors.leftMargin: Theme.Style.paddingLarge
        anchors.rightMargin: Theme.Style.paddingLarge
        anchors.topMargin: Theme.Style.paddingSmall
        anchors.bottomMargin: Theme.Style.paddingSmall

        spacing: Theme.Style.spacingMedium

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 36
            Layout.minimumWidth: 36
            Layout.maximumWidth: 36
            Layout.preferredHeight: 36
            Theme.MaterialIcon {
                anchors.centerIn: parent
                text: "palette"
                iconSize: 26
                iconColor: Theme.Color.foregroundMuted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: Theme.Style.spacingSmall

            RowLayout {
                Layout.fillWidth: true

                spacing: Theme.Style.spacingMedium

                Text {
                    Layout.fillWidth: true

                    text: root.theme.name

                    font.pixelSize: Theme.Style.fontNormal
                    color: Theme.Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    radius: Theme.Style.radiusFull
                    color: Qt.alpha(Theme.Color.primary, 0.12)
                    implicitHeight: Theme.Style.launcherSchemeBadgeHeight
                    implicitWidth:
                        currentText.implicitWidth
                        + Theme.Style.paddingSmall * 2
                    visible: root.current
                    opacity: root.current ? 1.0 : 0.0
                    scale: root.current ? 1.0 : 0.96

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.Style.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.Style.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: currentText

                        anchors.centerIn: parent

                        text: "Current"
                        font.pixelSize: Theme.Style.fontSmall
                        color: Theme.Color.primary
                    }
                }
            }

            Text {
                text: root.theme.mode

                font.pixelSize: Theme.Style.fontSmall
                color: Theme.Color.foregroundMuted
            }

            Row {
                spacing: Theme.Style.spacingSmall

                Repeater {
                    model: root.theme.preview ?? []

                    Rectangle {
                        required property var modelData

                        width: Theme.Style.launcherSchemePreviewWidth
                        height: Theme.Style.launcherSchemePreviewHeight

                        radius: Theme.Style.launcherSchemePreviewRadius

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
