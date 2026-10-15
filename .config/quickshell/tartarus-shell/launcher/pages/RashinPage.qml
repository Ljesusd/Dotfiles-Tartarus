import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../services" as Services
import "../../theme" as Theme

Item {
    id: root

    required property var controller
    required property bool active
    visible: root.active

    readonly property color statusColor:
        !Services.RashinService.enabled ? Theme.Color.foregroundMuted
        : Services.RashinService.backendAvailable ? Theme.Color.success
        : Theme.Color.warning

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.Style.paddingXLarge
        anchors.rightMargin: Theme.Style.paddingXLarge
        anchors.topMargin: Theme.Style.paddingLarge
        anchors.bottomMargin: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingLarge

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.Style.radiusSmall
                color: Qt.alpha(Theme.Color.primary, 0.18)
                border.width: 1
                border.color: Qt.alpha(Theme.Color.primary, 0.5)

                Theme.MaterialIcon {
                    anchors.centerIn: parent
                    text: "psychology"
                    iconSize: Theme.Style.materialIconLarge
                    iconColor: Theme.Color.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.Style.spacingXs

                Text {
                    text: "Rashin local"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontNormal
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "\\ pregunta · contexto privado de Tartarus"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    elide: Text.ElideRight
                }
            }

            Text {
                    text: Services.RashinService.connectionText
                color: root.statusColor
                font.pixelSize: Theme.Style.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: 220
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Theme.Style.cardRadius
            color: Theme.Color.surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(root.statusColor, 0.38)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingMedium
                spacing: Theme.Style.spacingMedium

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: Theme.Style.radiusMedium
                    color: Qt.alpha(root.statusColor, 0.16)
                    Theme.MaterialIcon {
                        anchors.centerIn: parent
                        text: Services.RashinService.enabled ? "lock" : "lock_open"
                        iconSize: Theme.Style.materialIconSmall
                        iconColor: root.statusColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: Services.RashinService.enabled ? "Modo local activo" : "Modo local desactivado"
                        color: Theme.Color.foreground
                        font.pixelSize: Theme.Style.fontSmall
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Services.RashinService.enabled
                            ? Services.RashinService.modelLabel + " · " + Services.RashinService.vaultPath
                            : "Actívalo desde Configuración → Rashin para enviar preguntas al modelo local."
                        color: Theme.Color.foregroundMuted
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.Style.cardRadius
            color: Theme.Color.surfaceContainerHigh
            border.width: 1
            border.color: Theme.Color.outlineVariant

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingLarge
                spacing: Theme.Style.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: Services.RashinService.lastQuestion !== ""
                            ? "Respuesta local"
                            : "Pregúntale a tu sistema"
                        color: Theme.Color.foreground
                        font.pixelSize: Theme.Style.fontNormal
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: Services.RashinService.lastQuestion !== ""
                        text: "LOCAL"
                        color: root.statusColor
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }

                Text {
                    visible: Services.RashinService.lastQuestion !== ""
                    Layout.fillWidth: true
                    text: Services.RashinService.lastQuestion
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Services.RashinService.answer !== ""
                    radius: Theme.Style.controlRadius
                    color: Theme.Color.surfaceContainer

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.Style.paddingMedium
                        clip: true
                        TextEdit {
                            readOnly: true
                            selectByMouse: true
                            persistentSelection: true
                            selectionColor: Qt.alpha(Theme.Color.primary, 0.42)
                            selectedTextColor: Theme.Color.foreground
                            width: parent.width
                            text: Services.RashinService.answer
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontSmall
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                        }
                    }
                }

                Text {
                    visible: Services.RashinService.answer === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: Services.RashinService.errorText !== ""
                        ? Services.RashinService.errorText
                        : Services.RashinService.busy ? "…"
                        : "Escribe una pregunta después de \\ y pulsa Enter.\n\nEjemplos:\n  \\ ¿qué monitor está activo?\n  \\ ¿dónde se guardan las grabaciones?\n  \\ resume la configuración de Tartarus"
                    color: Services.RashinService.errorText !== ""
                        ? Theme.Color.error
                        : Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: Services.RashinService.permissionRequestId !== ""
                    implicitHeight: permissionColumn.implicitHeight + Theme.Style.paddingMedium * 2
                    radius: Theme.Style.controlRadius
                    color: Qt.alpha(Theme.Color.warning, 0.12)
                    border.width: 1
                    border.color: Qt.alpha(Theme.Color.warning, 0.55)

                    ColumnLayout {
                        id: permissionColumn
                        anchors.fill: parent
                        anchors.margins: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingSmall

                        Text {
                            text: "Permiso requerido"
                            color: Theme.Color.warning
                            font.pixelSize: Theme.Style.fontSmall
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: Services.RashinService.permissionTitle
                            color: Theme.Color.foreground
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.Style.spacingSmall

                            RashinButton {
                                iconName: "check"
                                label: "Permitir una vez"
                                onClicked: Services.RashinService.resolvePermission(true)
                            }

                            RashinButton {
                                iconName: "close"
                                label: "Denegar"
                                onClicked: Services.RashinService.resolvePermission(false)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingSmall

            RashinButton {
                iconName: "refresh"
                label: "Actualizar contexto"
                enabled: !Services.RashinService.busy
                onClicked: Services.RashinService.index()
            }

            RashinButton {
                iconName: "settings"
                label: "Configuración"
                onClicked: root.controller.openRashinSettings()
            }

            RashinButton {
                iconName: "open_in_full"
                label: "Dashboard"
                onClicked: Services.RashinService.openDashboard()
            }

            Item { Layout.fillWidth: true }

            RashinButton {
                visible: Services.RashinService.answer !== ""
                iconName: "clear"
                label: "Limpiar"
                onClicked: Services.RashinService.clearAnswer()
            }
        }
    }

    component RashinButton: Rectangle {
        id: button
        property string iconName: "circle"
        property string label: ""
        property bool enabled: true
        signal clicked()

        implicitWidth: buttonLabel.implicitWidth + 48
        implicitHeight: 38
        radius: Theme.Style.radiusFull
        color: !button.enabled ? Theme.Color.surfaceContainer
            : buttonHover.hovered ? Theme.Color.surfaceHover : Theme.Color.surfaceContainerHigh
        border.width: buttonHover.hovered && button.enabled ? 1 : 0
        border.color: Theme.Color.primary
        opacity: button.enabled ? 1 : 0.5

        Behavior on color { ColorAnimation { duration: Theme.Style.motionFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.Style.paddingMedium
            anchors.rightMargin: Theme.Style.paddingMedium
            spacing: Theme.Style.spacingSmall
            Theme.MaterialIcon { text: button.iconName; iconSize: Theme.Style.materialIconSmall; iconColor: Theme.Color.primary }
            Text { id: buttonLabel; text: button.label; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontSmall; font.weight: Font.DemiBold }
        }

        HoverHandler { id: buttonHover; enabled: button.enabled }
        TapHandler { enabled: button.enabled; onTapped: button.clicked() }
    }
}
