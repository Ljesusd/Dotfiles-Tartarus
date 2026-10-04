import QtQuick
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    required property string icon
    required property string label
    property string detail: ""
    property color accent: Color.primary
    property bool visualizer: false
    property bool visualizerRunning: false
    property bool compact: false
    property string artworkUrl: ""
    signal activated()

    implicitWidth: root.compact
        ? Style.barInnerHeight
        : Math.min(190, activityText.implicitWidth + 38)
    implicitHeight: Style.barInnerHeight

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusFull
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
        border.width: Style.panelBorderWidth
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.compact ? 0 : Style.paddingSmall
            anchors.rightMargin: root.compact ? 0 : Style.paddingSmall
            spacing: Style.spacingXs

            Item {
                Layout.alignment: root.compact ? Qt.AlignHCenter : Qt.AlignVCenter
                Layout.preferredWidth: root.compact ? Style.barInnerHeight - 4 : Style.barIconSmall
                Layout.preferredHeight: root.compact ? Style.barInnerHeight - 4 : Style.barIconSmall

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusSmall
                    clip: true
                    color: Color.surfaceContainerHigh
                    visible: root.compact && root.artworkUrl !== ""

                    Image {
                        id: bubbleArt
                        anchors.fill: parent
                        source: root.artworkUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    iconSize: Style.barIconSmall
                    iconColor: root.accent
                    visible: !root.visualizer
                        && (!root.compact || bubbleArt.status !== Image.Ready)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: root.visualizer
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            height: 5 + index * 2
                            radius: 2
                            color: root.accent
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: root.visualizerRunning
                                loops: Animation.Infinite
                                NumberAnimation { to: 5 + ((index + 1) % 3) * 4; duration: 220 + index * 70; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 5 + index * 2; duration: 180 + index * 60; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            Text {
                id: activityText
                Layout.fillWidth: true
                visible: !root.compact
                text: root.detail !== "" ? root.detail : root.label
                color: Color.foreground
                font.pixelSize: Style.barFontSmall
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        TapHandler { onTapped: root.activated() }
    }
}
