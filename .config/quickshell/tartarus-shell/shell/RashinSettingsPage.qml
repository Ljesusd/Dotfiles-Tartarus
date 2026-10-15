import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../services" as Services
import "../theme" as Theme

Flickable {
    id: root

    property bool active: false
    property color backgroundColor: Theme.Color.background
    property color surfaceColor: Theme.Color.surfaceContainer
    property color surfaceHighColor: Theme.Color.surfaceContainerHigh
    property color hoverColor: Theme.Color.surfaceHover
    property color accentColor: Theme.Color.primary
    property color textColor: Theme.Color.foreground
    property color mutedColor: Theme.Color.foregroundMuted

    property string draftEndpoint: Services.RashinService.endpoint
    property string draftModel: Services.RashinService.model
    property string draftVault: Services.RashinService.vaultPath

    contentWidth: width
    contentHeight: body.implicitHeight + Theme.Style.paddingLarge * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    function syncDraft() {
        root.draftEndpoint = Services.RashinService.endpoint
        root.draftModel = Services.RashinService.model
        root.draftVault = Services.RashinService.vaultPath
    }

    function saveDraft() {
        Services.RashinService.endpoint = root.draftEndpoint.trim()
        Services.RashinService.model = root.draftModel.trim()
        Services.RashinService.vaultPath = root.draftVault.trim()
        Services.RashinService.saveAndProbe()
    }

    onActiveChanged: if (active) root.syncDraft()
    Component.onCompleted: root.syncDraft()

    ColumnLayout {
        id: body
        x: Theme.Style.paddingLarge
        y: Theme.Style.paddingLarge
        width: root.width - Theme.Style.paddingLarge * 2
        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            spacing: Theme.Style.spacingMedium

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Theme.Style.radiusSmall
                color: Qt.alpha(root.accentColor, 0.18)
                border.width: 1
                border.color: Qt.alpha(root.accentColor, 0.55)
                Theme.MaterialIcon {
                    anchors.centerIn: parent
                    text: "psychology"
                    iconSize: Theme.Style.materialIconLarge
                    iconColor: root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Rashin"; color: root.textColor; font.pixelSize: 27; font.bold: true }
                Text {
                    text: "Contexto local y consultas privadas para Tartarus"
                    color: root.mutedColor
                    font.pixelSize: Theme.Style.fontSmall
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        RashinCard {
            title: "Estado local"
            iconName: "lock"
            subtitle: "Controla Rashin y el modelo local"

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Services.RashinService.enabled ? "Rashin activado" : "Rashin desactivado"
                    color: root.textColor
                    font.pixelSize: Theme.Style.fontSmall
                    font.bold: true
                }
                Text {
                    text: Services.RashinService.connectionText
                    color: Services.RashinService.backendAvailable
                        ? Theme.Color.success : root.mutedColor
                    font.pixelSize: Theme.Style.fontSmall
                }
                RashinSwitch {
                    checked: Services.RashinService.enabled
                    enabled: !Services.RashinService.serviceTransition
                    opacity: enabled ? 1 : 0.5
                    onToggled: value => Services.RashinService.setEnabled(value)
                }
            }

            Text {
                text: "Al apagar, se detienen Rashin y llama.cpp, se libera la memoria GPU del modelo y se desactiva su arranque automático. Al encender, vuelven a iniciarse y arrancarán con la sesión."
                color: root.mutedColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                visible: Services.RashinService.errorText !== ""
                text: Services.RashinService.errorText
                color: Theme.Color.error
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        RashinCard {
            title: "Modelo local"
            iconName: "memory"
            subtitle: "Endpoint compatible con Ollama o una API local"

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Endpoint"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.preferredWidth: 100 }
                TextField {
                    id: endpointField
                    Layout.fillWidth: true
                    text: root.draftEndpoint
                    color: root.textColor
                    placeholderText: "http://127.0.0.1:11434/api/chat"
                    placeholderTextColor: root.mutedColor
                    selectByMouse: true
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        radius: Theme.Style.controlRadius
                        color: root.surfaceHighColor
                        border.width: endpointField.activeFocus ? 1 : 0
                        border.color: root.accentColor
                    }
                    onTextEdited: root.draftEndpoint = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Modelo"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.preferredWidth: 100 }
                TextField {
                    id: modelField
                    Layout.fillWidth: true
                    text: root.draftModel
                    color: root.textColor
                    placeholderText: "llama3.2"
                    placeholderTextColor: root.mutedColor
                    selectByMouse: true
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        radius: Theme.Style.controlRadius
                        color: root.surfaceHighColor
                        border.width: modelField.activeFocus ? 1 : 0
                        border.color: root.accentColor
                    }
                    onTextEdited: root.draftModel = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Contexto"; color: root.textColor; font.pixelSize: Theme.Style.fontSmall; Layout.preferredWidth: 100 }
                TextField {
                    id: vaultField
                    Layout.fillWidth: true
                    text: root.draftVault
                    color: root.textColor
                    placeholderTextColor: root.mutedColor
                    selectByMouse: true
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        radius: Theme.Style.controlRadius
                        color: root.surfaceHighColor
                        border.width: vaultField.activeFocus ? 1 : 0
                        border.color: root.accentColor
                    }
                    onTextEdited: root.draftVault = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                RashinButton { iconName: "folder_open"; text: "Abrir bóveda"; onClicked: Services.RashinService.openVault() }
                RashinButton { iconName: "save"; text: "Guardar y comprobar"; onClicked: root.saveDraft() }
            }
        }

        RashinCard {
            title: "Bóveda local"
            iconName: "inventory_2"
            subtitle: "Mapas generados para que el asistente conozca tu entorno"

            Text {
                Layout.fillWidth: true
                text: Services.RashinService.vaultPath
                color: root.textColor
                font.pixelSize: Theme.Style.fontSmall
                elide: Text.ElideMiddle
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Services.RashinService.indexed
                        ? "Contexto indexado localmente"
                        : "Todavía no hay un índice generado"
                    color: Services.RashinService.indexed ? Theme.Color.success : root.mutedColor
                    font.pixelSize: 12
                }
                RashinButton {
                    iconName: "refresh"
                    text: Services.RashinService.busy ? "Indexando…" : "Reindexar"
                    enabled: !Services.RashinService.busy
                    onClicked: Services.RashinService.index()
                }
            }
        }

        RashinCard {
            title: "Hermes ACP"
            iconName: "hub"
            subtitle: "Agente local para herramientas, memoria, skills y permisos"

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "El setup se ejecuta en una ventana Kitty y no se inicia automáticamente."
                    color: root.mutedColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                RashinButton {
                    iconName: "settings_suggest"
                    text: "Configurar Hermes"
                    enabled: !Services.RashinService.busy
                    onClicked: Services.RashinService.setupHermes()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 58
            radius: Theme.Style.cardRadius
            color: Qt.alpha(root.accentColor, 0.08)
            border.width: 1
            border.color: Qt.alpha(root.accentColor, 0.25)
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingMedium
                spacing: Theme.Style.spacingSmall
                Theme.MaterialIcon { text: "security"; iconSize: Theme.Style.materialIconSmall; iconColor: root.accentColor }
                Text {
                    Layout.fillWidth: true
                    text: "Rashin solo consulta localhost. Las respuestas pueden proponer comandos, pero el shell nunca los ejecuta automáticamente."
                    color: root.mutedColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component RashinCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property string iconName: "settings"
        default property alias content: cardBody.data
        Layout.fillWidth: true
        implicitHeight: cardBody.implicitHeight + Theme.Style.paddingMedium * 2
        radius: Theme.Style.radiusMedium
        color: root.surfaceColor
        border.width: 1
        border.color: Qt.alpha(root.accentColor, 0.18)

        ColumnLayout {
            id: cardBody
            anchors.fill: parent
            anchors.margins: Theme.Style.paddingLarge
            spacing: Theme.Style.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.Style.radiusSmall
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(root.accentColor, 0.42)
                    Theme.MaterialIcon { anchors.centerIn: parent; text: card.iconName; iconSize: Theme.Style.sectionIconSize - 2; iconColor: root.accentColor }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: card.title; color: root.textColor; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { visible: card.subtitle !== ""; text: card.subtitle; color: root.mutedColor; font.pixelSize: Theme.Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }

    component RashinSwitch: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled(bool value)
        implicitWidth: 48
        implicitHeight: 28
        radius: height / 2
        color: toggle.checked ? root.accentColor : root.surfaceHighColor
        border.width: 1
        border.color: toggle.checked ? root.accentColor : Qt.alpha(root.mutedColor, 0.5)
        Rectangle {
            width: 20
            height: 20
            y: 3
            x: toggle.checked ? parent.width - width - 3 : 3
            radius: width / 2
            color: toggle.checked ? root.backgroundColor : root.textColor
            Behavior on x { NumberAnimation { duration: Theme.Style.motionFast; easing.type: Easing.OutCubic } }
        }
        TapHandler { onTapped: toggle.toggled(!toggle.checked) }
    }

    component RashinButton: Button {
        id: button
        property string iconName: "circle"
        implicitHeight: 34
        implicitWidth: Math.max(120, contentItem.implicitWidth + 30)
        contentItem: RowLayout {
            spacing: Theme.Style.spacingSmall
            Theme.MaterialIcon { text: button.iconName; iconSize: Theme.Style.materialIconSmall; iconColor: button.enabled ? root.accentColor : root.mutedColor }
            Text { text: button.text; color: button.enabled ? root.textColor : root.mutedColor; font.pixelSize: Theme.Style.fontSmall; font.bold: true; elide: Text.ElideRight }
        }
        background: Rectangle {
            radius: Theme.Style.radiusSmall
            color: button.down ? root.accentColor : button.hovered ? root.hoverColor : "transparent"
            border.width: 1
            border.color: button.down || button.hovered ? root.accentColor : Qt.alpha(root.accentColor, 0.42)
            opacity: button.enabled ? 1 : 0.5
        }
    }
}
