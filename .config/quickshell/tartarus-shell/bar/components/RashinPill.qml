import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../services" as Services
import "../../theme" as Theme
import "../../launcher/components" as LauncherComponents

Item {
    id: root

    required property Item anchorItem
    required property var barWindow
    required property var monitorContext

    property bool popupOpen: false

    implicitWidth: 174
    implicitHeight: Theme.Style.barControlHeight
    visible: !root.monitorContext.launcherOpened

    function close() {
        root.popupOpen = false
    }

    function submit() {
        const value = String(chatInput.text || "").trim()
        if (value === "" || Services.RashinService.busy)
            return

        if (Services.RashinService.ask(value)) {
            chatInput.clear()
            transcript.followLatest = true
            transcript.scrollToLatest()
        }
        Qt.callLater(() => chatInput.forceActiveFocus())
    }

    onPopupOpenChanged: {
        if (root.popupOpen) {
            Services.RashinService.refresh()
            transcript.followLatest = true
            Qt.callLater(() => {
                chatInput.forceActiveFocus()
                transcript.scrollToLatest()
            })
        }
    }

    // Probe only while the chat is visible, never poll the model in the background.
    Timer {
        interval: 10000
        repeat: true
        running: root.popupOpen && !Services.RashinService.busy
        onTriggered: Services.RashinService.probe()
    }

    Rectangle {
        id: pillSurface
        anchors.fill: parent
        radius: Theme.Style.radiusFull
        color: pillHover.hovered
            ? Theme.Color.surfaceHover
            : Theme.Color.surfaceContainerHigh
        border.width: 1
        border.color: root.popupOpen
            ? Theme.Color.primary
            : Qt.alpha(Theme.Color.primary, 0.34)

        Behavior on color { ColorAnimation { duration: Theme.Style.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.Style.motionFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.Style.paddingSmall
            anchors.rightMargin: Theme.Style.paddingSmall
            spacing: Theme.Style.spacingSmall

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Theme.Style.radiusFull
                color: Qt.alpha(Theme.Color.primary, 0.18)

                Theme.MaterialIcon {
                    anchors.centerIn: parent
                    text: "psychology"
                    iconSize: Theme.Style.materialIconSmall
                    iconColor: Theme.Color.primary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Rashin"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: Services.RashinService.modelLabel
                    color: Services.RashinService.backendAvailable
                        ? Theme.Color.primary
                        : Theme.Color.foregroundMuted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Theme.MaterialIcon {
                text: root.popupOpen ? "expand_more" : "chat_bubble_outline"
                iconSize: Theme.Style.materialIconSmall
                iconColor: Theme.Color.foregroundMuted
            }
        }

        TapHandler {
            onTapped: {
                root.barWindow.closeLauncherIfOpen()
                root.popupOpen = !root.popupOpen
            }
        }

        HoverHandler { id: pillHover }
    }

    PopupWindow {
        id: chatWindow

        anchor.item: root.anchorItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide

        implicitWidth: Math.min(
            460 + chatSurface.horizontalInset * 2,
            Math.max(1, (root.barWindow.screen?.width ?? 1280) - 32)
        )
        implicitHeight: Math.min(
            540,
            Math.max(
                390,
                (root.barWindow.screen?.height ?? 800)
                    - Theme.Style.barHeight - Theme.Style.paddingLarge
            )
        )
        visible: root.popupOpen || chatSurface.reveal > 0
        color: "transparent"
        mask: Region { item: chatSurface.maskItem }

        HyprlandFocusGrab {
            windows: [root.barWindow, chatWindow]
            active: root.popupOpen
            onCleared: root.close()
        }

        Connections {
            target: root.monitorContext
            function onLauncherOpenedChanged() {
                if (root.monitorContext.launcherOpened)
                    root.close()
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: root.popupOpen
            onActivated: root.close()
        }

        LauncherComponents.LauncherSurface {
            id: chatSurface
            anchors.fill: parent
            opened: root.popupOpen
            contentWidth: Math.max(1, chatWindow.width - horizontalInset * 2)
            contentHeight: Math.max(1, chatWindow.height - shadowPadding - 8)
        }

        Item {
            id: chatContent
            parent: chatSurface.contentItem
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingLarge
                anchors.bottomMargin: Theme.Style.paddingLarge + Theme.Style.barPopupGap
                spacing: Theme.Style.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Rashin"
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontNormal
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Services.RashinService.modelLabel
                            color: Services.RashinService.backendAvailable
                                ? Theme.Color.primary
                                : Theme.Color.warning
                            font.pixelSize: Theme.Style.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Services.RashinService.backendAvailable ? Theme.Color.success
                                : Services.RashinService.connectionText === "Conectando" ? Theme.Color.warning
                                : Theme.Color.foregroundMuted
                        }

                        Text {
                            text: Services.RashinService.connectionText
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: 11
                        }
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        implicitWidth: 30
                        implicitHeight: 30
                        onClicked: {
                            Services.RashinService.openDashboard()
                            root.close()
                        }
                        contentItem: Theme.MaterialIcon {
                            text: "open_in_full"
                            iconSize: Theme.Style.materialIconSmall
                            iconColor: Theme.Color.foregroundMuted
                        }
                        background: Rectangle {
                            radius: Theme.Style.radiusFull
                            color: parent.hovered ? Theme.Color.surfaceHover : "transparent"
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "Abrir dashboard local"
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        implicitWidth: 30
                        implicitHeight: 30
                        onClicked: root.close()
                        contentItem: Theme.MaterialIcon {
                            text: "close"
                            iconSize: Theme.Style.materialIconSmall
                            iconColor: Theme.Color.foregroundMuted
                        }
                        background: Rectangle {
                            radius: Theme.Style.radiusFull
                            color: parent.hovered ? Theme.Color.surfaceHover : "transparent"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.Color.surfaceHover
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: transcript
                        property bool followLatest: true
                        anchors.fill: parent
                        clip: true
                        spacing: Theme.Style.spacingMedium
                        model: Services.RashinService.historyItems
                        verticalLayoutDirection: ListView.TopToBottom
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        function scrollToLatest() {
                            if (root.popupOpen && followLatest && !moving)
                                Qt.callLater(() => {
                                    if (root.popupOpen && followLatest && !moving)
                                        transcript.positionViewAtEnd()
                                })
                        }

                        onCountChanged: scrollToLatest()
                        onContentHeightChanged: scrollToLatest()
                        onHeightChanged: scrollToLatest()
                        onContentYChanged: if (moving) followLatest = atYEnd
                        onMovementEnded: followLatest = atYEnd

                        delegate: ColumnLayout {
                            required property var modelData
                            width: transcript.width
                            spacing: 3

                            Text {
                                text: "Tú"
                                color: Theme.Color.primary
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            TextEdit {
                                readOnly: true
                                selectByMouse: true
                                persistentSelection: true
                                selectionColor: Qt.alpha(Theme.Color.primary, 0.42)
                                selectedTextColor: Theme.Color.foreground
                                Layout.fillWidth: true
                                text: String(modelData.question || "")
                                textFormat: TextEdit.PlainText
                                color: Theme.Color.foreground
                                font.pixelSize: Theme.Style.fontSmall
                                wrapMode: TextEdit.Wrap
                            }

                            Text {
                                text: "Rashin"
                                color: Theme.Color.secondary
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            TextEdit {
                                readOnly: true
                                selectByMouse: true
                                persistentSelection: true
                                selectionColor: Qt.alpha(Theme.Color.primary, 0.42)
                                selectedTextColor: Theme.Color.foreground
                                Layout.fillWidth: true
                                text: String(modelData.answer || "")
                                textFormat: TextEdit.PlainText
                                color: Theme.Color.foregroundMuted
                                font.pixelSize: Theme.Style.fontSmall
                                wrapMode: TextEdit.Wrap
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.Style.spacingSmall
                                height: 1
                                color: Theme.Color.surfaceHover
                            }
                        }

                        // The active reply is part of the transcript, not an
                        // overlay on older messages. Closing the popup keeps it running.
                        footer: Item {
                            width: transcript.width
                            height: Services.RashinService.turnVisible ? liveTurn.implicitHeight : 0
                            visible: Services.RashinService.turnVisible

                            ColumnLayout {
                                id: liveTurn
                                width: parent.width
                                spacing: 3

                                Text {
                                    text: "Tú"
                                    color: Theme.Color.primary
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                TextEdit {
                                    readOnly: true
                                    selectByMouse: true
                                    persistentSelection: true
                                    selectionColor: Qt.alpha(Theme.Color.primary, 0.42)
                                    selectedTextColor: Theme.Color.foreground
                                    Layout.fillWidth: true
                                    text: Services.RashinService.lastQuestion
                                    textFormat: TextEdit.PlainText
                                    color: Theme.Color.foreground
                                    font.pixelSize: Theme.Style.fontSmall
                                    wrapMode: TextEdit.Wrap
                                }

                                Text {
                                    text: "Rashin"
                                    color: Theme.Color.secondary
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                TextEdit {
                                    readOnly: true
                                    selectByMouse: true
                                    persistentSelection: true
                                    selectionColor: Qt.alpha(Theme.Color.primary, 0.42)
                                    selectedTextColor: Theme.Color.foreground
                                    Layout.fillWidth: true
                                    visible: Services.RashinService.answer !== ""
                                    text: Services.RashinService.answer
                                    textFormat: TextEdit.PlainText
                                    color: Theme.Color.foregroundMuted
                                    font.pixelSize: Theme.Style.fontSmall
                                    wrapMode: TextEdit.Wrap
                                }

                                Text {
                                    id: pendingReply
                                    visible: Services.RashinService.busy && Services.RashinService.answer === ""
                                    text: "…"
                                    color: Theme.Color.primary
                                    font.pixelSize: Theme.Style.fontNormal
                                    SequentialAnimation on opacity {
                                        running: root.popupOpen && pendingReply.visible && Theme.Style.motionNormal > 0
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.35; duration: 500 }
                                        NumberAnimation { to: 1; duration: 500 }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: transcript.count === 0 && !Services.RashinService.turnVisible
                            text: "Escribe una pregunta para empezar"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: Services.RashinService.errorText !== ""
                    text: Services.RashinService.errorText
                    color: Theme.Color.error
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
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

                            Button {
                                text: "Permitir una vez"
                                implicitHeight: 32
                                onClicked: Services.RashinService.resolvePermission(true)
                                contentItem: Text {
                                    text: parent.text
                                    color: Theme.Color.foreground
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    radius: Theme.Style.controlRadius
                                    color: parent.hovered ? Theme.Color.primary : Theme.Color.surfaceHover
                                    border.width: 1
                                    border.color: Theme.Color.primary
                                }
                            }

                            Button {
                                text: "Denegar"
                                implicitHeight: 32
                                onClicked: Services.RashinService.resolvePermission(false)
                                contentItem: Text {
                                    text: parent.text
                                    color: Theme.Color.foregroundMuted
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    radius: Theme.Style.controlRadius
                                    color: parent.hovered ? Theme.Color.surfaceHover : "transparent"
                                    border.width: 1
                                    border.color: Theme.Color.outlineVariant
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall

                    TextField {
                        id: chatInput
                        Layout.fillWidth: true
                        enabled: Services.RashinService.enabled && !Services.RashinService.busy
                        placeholderText: "Pregunta a Rashin…"
                        color: Theme.Color.foreground
                        placeholderTextColor: Theme.Color.foregroundMuted
                        selectByMouse: true
                        leftPadding: Theme.Style.paddingMedium
                        rightPadding: Theme.Style.paddingMedium
                        onAccepted: root.submit()
                        background: Rectangle {
                            radius: Theme.Style.controlRadius
                            color: Theme.Color.surfaceContainerHigh
                            border.width: chatInput.activeFocus ? 1 : 0
                            border.color: Theme.Color.primary
                        }
                    }

                    Button {
                        text: "Enviar"
                        enabled: chatInput.text.trim() !== "" && !Services.RashinService.busy
                            && Services.RashinService.enabled
                        implicitHeight: 38
                        implicitWidth: 82
                        onClicked: root.submit()
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? Theme.Color.foreground : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: Theme.Style.controlRadius
                            color: parent.enabled
                                ? (parent.hovered ? Theme.Color.primary : Theme.Color.surfaceHover)
                                : Theme.Color.surfaceContainerHigh
                            border.width: 1
                            border.color: parent.enabled
                                ? Theme.Color.primary
                                : Theme.Color.outlineVariant
                        }
                    }
                }
            }
        }
    }
}
