import QtQuick
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root
    required property var advice
    readonly property color accent: advice.severity === "danger" ? Color.error
        : advice.severity === "warning" ? Color.warning
        : advice.severity === "info" ? Color.info : Color.foregroundMuted
    implicitHeight: body.implicitHeight + 24
    radius: Style.controlRadius
    color: Qt.alpha(root.accent, 0.07)
    RowLayout {
        id: body
        x: 12; y: 12; width: parent.width - 24
        spacing: 10
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 32; implicitHeight: 32
            radius: 10
            color: Qt.alpha(root.accent, 0.12)
            MaterialIcon { anchors.centerIn: parent; text: root.advice.icon; iconSize: 22; iconColor: root.accent }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.advice.title
                    textFormat: Text.PlainText
                    color: Color.foreground
                    font.pixelSize: Style.fontSmall
                    font.bold: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                Text { text: root.advice.when; textFormat: Text.PlainText; color: root.accent; font.pixelSize: 10; font.bold: true }
            }
            Text {
                text: root.advice.text
                textFormat: Text.PlainText
                color: Color.foregroundMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                text: root.advice.detail
                textFormat: Text.PlainText
                color: root.accent
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
