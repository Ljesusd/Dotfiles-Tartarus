import QtQuick
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root
    required property string label
    required property string value
    property string detail: ""
    property string icon: ""
    property color accent: Color.primary
    property real level: -1
    implicitHeight: body.implicitHeight + 24
    radius: Style.controlRadius
    color: Color.surfaceContainerHigh
    ColumnLayout {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: root.icon; iconSize: 17; iconColor: root.accent }
            Text { text: root.label; textFormat: Text.PlainText; color: Color.foregroundMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Text { text: root.value; textFormat: Text.PlainText; color: Color.foreground; font.pixelSize: 23; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: root.detail || "\u00a0"; textFormat: Text.PlainText; color: Color.foregroundMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
        Rectangle {
            opacity: root.level >= 0 ? 1 : 0
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: Qt.alpha(root.accent, 0.15)
            Rectangle { width: parent.width * Math.max(0, Math.min(1, root.level)); height: parent.height; radius: 2; color: root.accent }
        }
    }
}
