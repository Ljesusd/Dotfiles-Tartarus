import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import Quickshell
import "../../services" as Services
import "../../theme" as Theme

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
            "Aplicaciones y paquetes (*.AppImage *.appimage *.flatpak *.flatpakref *.pkg.tar.* *.deb *.rpm *.tar *.tar.gz *.tgz *.tar.xz *.tar.zst)",
            "Todos los archivos (*)"
        ]
        onAccepted: root.handleUrl(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            Theme.MaterialIcon { text: "download"; iconSize: Theme.Style.materialIconLarge; iconColor: Theme.Color.primary }
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: "Instalar aplicación"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true }
                Text { text: ">install · arrastra un archivo aquí"; color: Theme.Color.foregroundMuted; font.pixelSize: Theme.Style.fontSmall }
            }
        }

        Rectangle {
            id: dropSurface
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 190
            radius: Theme.Style.panelRadius
            color: dropArea.containsDrag ? Theme.Color.primaryContainer : Theme.Color.surfaceContainerHigh
            border.width: dropArea.containsDrag ? 2 : 1
            border.color: dropArea.containsDrag ? Theme.Color.primary : Theme.Color.outlineVariant
            Behavior on color { ColorAnimation { duration: Theme.Motion.fast } }

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
                width: parent.width - Theme.Style.paddingLarge * 2
                spacing: Theme.Style.spacingSmall
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: root.service.phase === "installing" ? 52 : 44
                    height: root.service.phase === "installing" ? 52 : 44

                    Theme.MaterialIcon {
                        anchors.centerIn: parent
                        text: root.service.phase === "installing"
                            ? "download"
                            : dropArea.containsDrag ? "file_download" : "upload_file"
                        iconSize: root.service.phase === "installing" ? 26 : 44
                        iconColor: Theme.Color.primary
                    }

                    Rectangle {
                        visible: root.service.phase === "installing"
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.Color.primary
                        opacity: 0.8
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: root.service.phase === "installing"
                        }
                    }
                }
                Text { Layout.fillWidth: true; text: root.service.phase === "installing" ? (root.service.nativePackage ? "Instalando paquete nativo…" : "Instalando aplicación…") : dropArea.containsDrag ? "Suelta el archivo para analizarlo" : "Suelta una aplicación o paquete"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; text: root.service.phase === "installing" ? root.service.progressLabel : "AppImage · Flatpak/FlatpakRef · Arch · DEB · RPM · tar"; color: Theme.Color.foregroundMuted; font.pixelSize: Theme.Style.fontSmall; horizontalAlignment: Text.AlignHCenter }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.service.phase !== "idle" && root.service.phase !== "inspecting"
            implicitHeight: details.implicitHeight + Theme.Style.paddingMedium * 2
            radius: Theme.Style.cardRadius
            color: Theme.Color.surfaceContainerHigh
            border.width: 1
            border.color: root.service.phase === "error" ? Theme.Color.error : Theme.Color.outlineVariant

            ColumnLayout {
                id: details
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingMedium
                spacing: Theme.Style.spacingXs
                Text { Layout.fillWidth: true; text: root.service.name; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true; elide: Text.ElideMiddle }
                Text { Layout.fillWidth: true; text: root.service.kindLabel + (root.service.detail ? " · " + root.service.detail : ""); color: root.service.phase === "error" ? Theme.Color.error : Theme.Color.foregroundMuted; wrapMode: Text.WordWrap }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.service.phase === "installing"
                    spacing: Theme.Style.spacingSmall
                    Text {
                        text: root.service.progress + "%"
                        color: Theme.Color.primary
                        font.pixelSize: Theme.Style.fontNormal
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.service.nativePackage
                            ? "progreso estimado · la contraseña la gestiona Polkit"
                            : "progreso estimado · el shell mantiene el estado"
                        color: Theme.Color.foregroundMuted
                        font.pixelSize: Theme.Style.fontSmall
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.service.phase === "installing"
                    implicitHeight: 8
                    radius: height / 2
                    color: Theme.Color.surfaceContainerHigh
                    clip: true
                    Rectangle {
                        height: parent.height
                        width: parent.width * root.service.progress / 100.0
                        radius: height / 2
                        color: Theme.Color.primary
                        Behavior on width { NumberAnimation { duration: Theme.Motion.fast } }
                    }
                }
                Text { Layout.fillWidth: true; visible: root.service.phase === "installed"; text: root.service.nativePackage ? "Steam quedó instalado con el paquete nativo de Arch." : "Instalación terminada. El launcher se actualizará al detectar la nueva aplicación."; color: Theme.Color.primary; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; visible: root.service.phase === "cancelled"; text: root.service.error; color: Theme.Color.foregroundMuted; wrapMode: Text.WordWrap }
                Text { Layout.fillWidth: true; visible: root.service.phase === "error"; text: root.service.error; color: Theme.Color.error; wrapMode: Text.WordWrap }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.service.phase === "installing"
                    ? (root.service.nativePackage ? "Instalando paquete nativo…" : "Instalando…")
                    : root.service.phase === "installed"
                        ? "Aplicación instalada"
                        : root.service.phase === "cancelled"
                            ? "Instalación cancelada"
                            : root.service.phase === "error"
                                ? "La instalación falló"
                        : "La instalación requiere confirmación"
                color: Theme.Color.foregroundMuted
                wrapMode: Text.WordWrap
            }
            Rectangle {
                visible: root.service.ready
                implicitWidth: 128; implicitHeight: 38; radius: Theme.Style.controlRadius; color: Theme.Color.primary
                Text { anchors.centerIn: parent; text: "Instalar"; color: Theme.Color.background; font.bold: true }
                TapHandler { onTapped: root.service.install() }
            }
            Rectangle {
                visible: !root.service.busy
                implicitWidth: 120; implicitHeight: 38; radius: Theme.Style.controlRadius; color: Theme.Color.surfaceElevated
                Text { anchors.centerIn: parent; text: "Elegir archivo"; color: Theme.Color.foreground; font.bold: true }
                TapHandler { onTapped: fileDialog.open() }
            }
            Rectangle {
                visible: root.service.phase !== "idle" && !root.service.busy
                implicitWidth: 80; implicitHeight: 38; radius: Theme.Style.controlRadius; color: Theme.Color.surfaceElevated
                Text { anchors.centerIn: parent; text: "Limpiar"; color: Theme.Color.foreground; font.bold: true }
                TapHandler { onTapped: root.service.clear() }
            }
            Rectangle {
                visible: root.service.busy
                implicitWidth: 100; implicitHeight: 38; radius: Theme.Style.controlRadius; color: Theme.Color.surfaceElevated
                Text { anchors.centerIn: parent; text: "Cancelar"; color: Theme.Color.foreground; font.bold: true }
                TapHandler { onTapped: root.service.cancel() }
            }
        }
    }
}
