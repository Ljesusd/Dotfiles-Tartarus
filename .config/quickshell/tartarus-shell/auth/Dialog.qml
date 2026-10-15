pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: dialog
    required property QtObject auth
    required property var theme
    required property bool preview

    title: "Tartarus — Autenticación"
    visible: auth.active
    color: "transparent"
    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    width: Math.min(480, Screen.desktopAvailableWidth - 32)
    // Keep a stable native-window envelope. Deriving the window height from a
    // child inside its own ScrollView creates a zero-height feedback loop on
    // Wayland, which leaves only the title bar visible.
    height: Math.min(560, Math.max(360, Screen.desktopAvailableHeight - 48))
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height

    onClosing: function(close) {
        close.accepted = false
        auth.cancel()
    }

    component AuthButton: Button {
        id: button
        property bool primary: false
        implicitHeight: 44
        leftPadding: 20
        rightPadding: 20
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        background: Rectangle {
            radius: 14
            color: button.primary ? dialog.theme.primary
                : button.hovered ? dialog.theme.surface_container_high : dialog.theme.surface_container
            opacity: button.enabled ? (button.down ? 0.8 : 1) : 0.45
            border.width: button.activeFocus ? 2 : (button.primary ? 0 : 1)
            border.color: button.activeFocus ? dialog.theme.primary : dialog.theme.outline_variant
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: Text {
            text: button.text
            textFormat: Text.PlainText
            color: button.primary ? dialog.theme.on_primary : dialog.theme.foreground
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: button.enabled ? 1 : 0.5
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: dialog.theme.background
        border.width: 1
        border.color: dialog.theme.outline

        ScrollView {
            anchors.fill: parent
            anchors.margins: 24
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: 16
                        color: dialog.theme.surface_container_high
                        // Code-native lock: no icon theme or shell dependency.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 10; width: 16; height: 17; radius: 8
                            color: "transparent"
                            border.width: 2; border.color: dialog.theme.primary
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 22; width: 24; height: 18; radius: 5
                            color: dialog.theme.primary
                            Rectangle {
                                anchors.centerIn: parent
                                width: 3; height: 7; radius: 1.5
                                color: dialog.theme.background
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Autenticación"
                            color: dialog.theme.foreground
                            font.pixelSize: 23; font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Tartarus · Permisos del sistema"
                            color: dialog.theme.foreground_muted
                            font.pixelSize: 12
                        }
                    }
                    ToolButton {
                        text: "×"
                        Accessible.name: "Cancelar autenticación"
                        onClicked: dialog.auth.cancel()
                        contentItem: Text {
                            text: "×"; color: dialog.theme.foreground_muted
                            font.pixelSize: 23
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 10; color: parent.hovered ? dialog.theme.surface : "transparent"
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: dialog.preview ? "Vista previa. No introduzcas tu contraseña."
                        : dialog.auth.message
                    textFormat: Text.PlainText
                    color: dialog.theme.foreground_muted
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: actionDetails.implicitHeight + 24
                    radius: 14
                    color: dialog.theme.surface
                    ColumnLayout {
                        id: actionDetails
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        Text {
                            text: dialog.auth.command ? "COMANDO SOLICITADO" : "ACCIÓN SOLICITADA"
                            color: dialog.theme.foreground_muted
                            font.pixelSize: 10; font.letterSpacing: 1.1
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dialog.auth.command || dialog.auth.actionId
                            textFormat: Text.PlainText
                            color: dialog.theme.foreground
                            font.family: "monospace"; font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Autenticar como"
                        color: dialog.theme.foreground_muted; font.pixelSize: 12
                    }
                    ComboBox {
                        id: identity
                        Layout.fillWidth: true
                        implicitHeight: 42
                        model: dialog.auth.identities
                        currentIndex: dialog.auth.identityIndex
                        enabled: !dialog.auth.busy && count > 1
                        onActivated: dialog.auth.selectIdentity(currentIndex)
                        leftPadding: 14
                        contentItem: Text {
                            text: identity.displayText
                            textFormat: Text.PlainText
                            color: dialog.theme.foreground
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                        }
                        indicator: Text {
                            visible: identity.count > 1
                            x: identity.width - 26; y: (identity.height - height) / 2
                            text: "⌄"; color: dialog.theme.foreground_muted
                        }
                        background: Rectangle {
                            radius: 12
                            color: dialog.theme.surface_container
                            border.width: 1
                            border.color: identity.activeFocus ? dialog.theme.primary : dialog.theme.outline_variant
                        }
                        palette.window: dialog.theme.surface
                        palette.base: dialog.theme.surface
                        palette.text: dialog.theme.foreground
                        palette.buttonText: dialog.theme.foreground
                        palette.highlight: dialog.theme.primary
                        palette.highlightedText: dialog.theme.on_primary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: dialog.auth.prompt || "Contraseña"
                        textFormat: Text.PlainText
                        color: dialog.theme.foreground_muted; font.pixelSize: 12
                    }
                    TextField {
                        id: response
                        objectName: "responseField"
                        Layout.fillWidth: true
                        implicitHeight: 46
                        enabled: dialog.auth.waiting && !dialog.preview
                        echoMode: dialog.auth.echo ? TextInput.Normal : TextInput.Password
                        passwordMaskDelay: 0
                        selectByMouse: false
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            | (dialog.auth.echo ? Qt.ImhNone : Qt.ImhHiddenText)
                        placeholderText: dialog.preview ? "Vista previa" : "Introduce tu respuesta"
                        placeholderTextColor: dialog.theme.foreground_muted
                        color: dialog.theme.foreground
                        selectionColor: dialog.theme.primary
                        selectedTextColor: dialog.theme.on_primary
                        font.pixelSize: 15
                        leftPadding: 14; rightPadding: 14
                        Accessible.name: dialog.auth.prompt || "Contraseña"
                        onAccepted: dialog.auth.submit(text)
                        background: Rectangle {
                            radius: 14
                            color: dialog.theme.surface_container
                            border.width: response.activeFocus ? 2 : 1
                            border.color: response.activeFocus ? dialog.theme.primary : dialog.theme.outline_variant
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: dialog.auth.errorMessage || dialog.auth.infoMessage
                        textFormat: Text.PlainText
                        color: dialog.auth.errorMessage ? dialog.theme.error : dialog.theme.foreground_muted
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    BusyIndicator {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        running: dialog.auth.busy
                        visible: running
                        palette.dark: dialog.theme.primary
                    }
                    Item { Layout.fillWidth: true }
                    AuthButton {
                        text: "Cancelar"
                        onClicked: dialog.auth.cancel()
                    }
                    AuthButton {
                        primary: true
                        text: dialog.auth.busy ? "Autenticando…"
                            : dialog.auth.canRetry ? "Reintentar" : "Autenticar"
                        enabled: !dialog.preview && (dialog.auth.waiting || dialog.auth.canRetry)
                        onClicked: {
                            if (dialog.auth.canRetry) dialog.auth.retry()
                            else dialog.auth.submit(response.text)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Validado por Polkit · La contraseña no se guarda"
                    color: dialog.theme.foreground_muted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: dialog.auth.cancel()
    }
    Connections {
        target: dialog.auth
        function onClearResponse() { response.clear() }
        function onPromptReady() {
            Qt.callLater(function() {
                if (dialog.auth.waiting && !dialog.preview)
                    response.forceActiveFocus()
            })
        }
    }
}
