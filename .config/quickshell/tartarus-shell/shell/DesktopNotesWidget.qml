import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../services" as Services
import "../theme"

Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: 220
    radius: Style.panelRadius
    color: Qt.alpha(Color.surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Color.outlineVariant, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "sticky_note_2"; iconSize: 20; iconColor: Color.primary }
            Text { text: "Notas"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: "Guardado local"; color: Color.foregroundMuted; font.pixelSize: 11 }
        }
        Controls.TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Services.DesktopNotesService.text
            placeholderText: "Escribe una nota…"
            color: Color.foreground
            placeholderTextColor: Color.foregroundMuted
            font.pixelSize: 13
            wrapMode: TextEdit.Wrap
            background: Rectangle { radius: Style.controlRadius; color: Color.surfaceContainerHigh; border.width: editor.activeFocus ? 1 : 0; border.color: Color.primary }
            onTextChanged: if (activeFocus) Services.DesktopNotesService.save(text)
        }
    }
}
