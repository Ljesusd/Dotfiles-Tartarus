import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import Quickshell
import "../../services" as Services
import "../../theme"

Item {
    id: root
    required property var controller
    required property bool active
    readonly property var service: Services.InstallerService
    visible: root.active

    function handleUrl(url) {
        root.service.inspect(root.service.localPath(url))
    }

    onActiveChanged: {
        if (root.active)
            root.service.clear()
    }

    FileDialog {
        id: fileDialog
        title: "Seleccionar aplicación o paquete"
        fileMode: FileDialog.OpenFile
        nameFilters: [
            "Aplicaciones y paquetes (*.AppImage *.appimage *.flatpak *.pkg.tar.* *.deb *.rpm *.tar *.tar.gz *.tgz *.tar.xz *.tar.zst)",
            "Todos los archivos (*)"
        ]
        onAccepted: root.handleUrl(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "download"; iconSize: Style.materialIconLarge; iconColor: Color.primary }
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: "Instalar aplicación"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true }
                Text { text: ">install · arrastra un archivo aquí"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall }
            }
        }

        Rectangle {
            id: dropSurface
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 190
            radius: Style.panelRadius
            color: dropArea.containsDrag ? Color.primaryContainer : Color.surfaceContainerHigh
            border.width: dropArea.containsDrag ? 2 : 1
            border.color: dropArea.containsDrag ? Color.primary : Color.outlineVariant
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            DropArea {
                id: dropArea
                anchors.fill: parent
                onDropped: drop => {
                    if (drop.urls && drop.urls.length > 0)
                        root.handleUrl(drop.urls[0])
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Style.paddingLarge * 2
                spacing: Style.spacingSmall
                MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: dropArea.containsDrag ? "file_download" : "upload_file"; iconSize: 44; iconColor: Color.primary }
                Text { Layout.fillWidth: true; text: dropArea.containsDrag ? "Suelta el archivo para analizarlo" : "Suelta una aplicación o paquete"; color: Color.foreground; font.pixelSize: Style.fontNormal; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; text: "AppImage · Flatpak · Arch · DEB · RPM · tar"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.service.phase !== "idle" && root.service.phase !== "inspecting"
            implicitHeight: details.implicitHeight + Style.paddingMedium * 2
            radius: Style.cardRadius
            color: Color.surfaceContainerHigh
            border.width: 1
            border.color: root.service.phase === "error" ? Color.error : Color.outlineVariant

            ColumnLayout {
                id: details
                anchors.fill: parent
                anchors.margins: Style.paddingMedium
                spacing: Style.spacingXs
                Text { Layout.fillWidth: true; text: root.service.name; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; elide: Text.ElideMiddle }
                Text { Layout.fillWidth: true; text: root.service.kindLabel + (root.service.detail ? " · " + root.service.detail : ""); color: root.service.phase === "error" ? Color.error : Color.foregroundMuted; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; visible: root.service.phase === "installed"; text: "Instalación terminada. El launcher se actualizará al detectar la nueva aplicación."; color: Color.primary; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; visible: root.service.phase === "error"; text: root.service.error; color: Color.error; wrapMode: Text.WordWrap }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.service.phase === "installing"
                    ? "Instalando…"
                    : root.service.phase === "installed"
                        ? "Aplicación instalada"
                        : "La instalación requiere confirmación"
                color: Color.foregroundMuted
                wrapMode: Text.WordWrap
            }
            Rectangle {
                visible: root.service.ready
                implicitWidth: 128; implicitHeight: 38; radius: Style.controlRadius; color: Color.primary
                Text { anchors.centerIn: parent; text: "Instalar"; color: Color.background; font.bold: true }
                TapHandler { onTapped: root.service.install() }
            }
            Rectangle {
                implicitWidth: 120; implicitHeight: 38; radius: Style.controlRadius; color: Color.surfaceElevated
                Text { anchors.centerIn: parent; text: "Elegir archivo"; color: Color.foreground; font.bold: true }
                TapHandler { onTapped: fileDialog.open() }
            }
            Rectangle {
                visible: root.service.phase !== "idle"
                implicitWidth: 80; implicitHeight: 38; radius: Style.controlRadius; color: Color.surfaceElevated
                Text { anchors.centerIn: parent; text: "Limpiar"; color: Color.foreground; font.bold: true }
                TapHandler { onTapped: root.service.clear() }
            }
        }
    }
}
