import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../services" as Services
import "../theme" as Theme

Rectangle {
    id: root
    implicitWidth: 320
    implicitHeight: 220
    radius: Theme.Style.panelRadius
    color: Qt.alpha(Theme.Color.surfaceContainer, 0.94)
    border.width: 1
    border.color: Qt.alpha(Theme.Color.outlineVariant, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            Theme.MaterialIcon { text: "sticky_note_2"; iconSize: 20; iconColor: Theme.Color.primary }
            Text { text: "Notas"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true; Layout.fillWidth: true }
            Text { text: "Guardado local"; color: Theme.Color.foregroundMuted; font.pixelSize: 11 }
        }
        Controls.TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Services.DesktopNotesService.text
            placeholderText: "Escribe una nota…"
            color: Theme.Color.foreground
            placeholderTextColor: Theme.Color.foregroundMuted
            font.pixelSize: 13
            wrapMode: TextEdit.Wrap
            background: Rectangle { radius: Theme.Style.controlRadius; color: Theme.Color.surfaceContainerHigh; border.width: editor.activeFocus ? 1 : 0; border.color: Theme.Color.primary }
            onTextChanged: if (activeFocus) Services.DesktopNotesService.save(text)
        }
    }
}
