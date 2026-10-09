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

    implicitHeight: Math.max(Style.launcherSchemeItemHeight,
        themeContent.implicitHeight + Style.paddingSmall * 2)

    radius: Style.cardRadius

    color: hoverHandler.hovered && !root.selected
            ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, Style.hoverOpacity)
            : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Style.motionFast
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: themeContent
        anchors.fill: parent

        anchors.leftMargin: Style.paddingLarge
        anchors.rightMargin: Style.paddingLarge
        anchors.topMargin: Style.paddingSmall
        anchors.bottomMargin: Style.paddingSmall

        spacing: Style.spacingMedium

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 36
            Layout.minimumWidth: 36
            Layout.maximumWidth: 36
            Layout.preferredHeight: 36
            MaterialIcon {
                anchors.centerIn: parent
                text: "palette"
                iconSize: 26
                iconColor: Color.foregroundMuted
            }
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
                    color: Color.foreground

                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    radius: Style.radiusFull
                    color: Qt.alpha(Color.primary, 0.12)
                    implicitHeight: Style.launcherSchemeBadgeHeight
                    implicitWidth:
                        currentText.implicitWidth
                        + Style.paddingSmall * 2
                    visible: root.current
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
                        color: Color.primary
                    }
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
