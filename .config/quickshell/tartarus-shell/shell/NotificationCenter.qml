import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext

    readonly property var history:
        Services.NotificationService.history

    readonly property bool isFocused: root.monitorContext.notificationCenterOpen

    PanelWindow {
        screen: root.monitorScreen
        anchors {
            top: true
            bottom: true
            right: true
        }
        margins {
            top: Style.barHeight + Style.spacingLarge
            right: Style.spacingLarge
            bottom: Style.spacingLarge
        }
        implicitWidth: 380
        implicitHeight: 640
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.isFocused
            && (Services.NotificationService.centerOpen
                || drawer.opacity > 0)

        Rectangle {
            id: drawer

            x: Services.NotificationService.centerOpen
                ? 0
                : width
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            opacity: Services.NotificationService.centerOpen ? 1 : 0
            clip: true
            radius: Style.radiusLarge
            color: Color.backgroundAlt
            border.width: Style.panelBorderWidth
            border.color: Color.outlineVariant

            Behavior on x {
                NumberAnimation {
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Style.motionFast
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingLarge
                spacing: Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Notifications"
                        color: Color.foreground
                        font.pixelSize: Style.fontNormal
                        font.bold: true
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: Services.NotificationService.dnd
                            ? "Disable Do Not Disturb"
                            : "Enable Do Not Disturb"
                        contentItem: MaterialIcon {
                            text: Services.NotificationService.dnd
                                ? "notifications_off"
                                : "notifications"
                            color: Services.NotificationService.dnd
                                ? Color.tertiaryContainer
                                : Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.toggleDnd(
                            root.monitorScreen.name
                        )
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Clear history"
                        contentItem: MaterialIcon {
                            text: "delete_sweep"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.clearHistory()
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Close"
                        contentItem: MaterialIcon {
                            text: "close"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: {
                            root.monitorContext.closeNotificationCenter()
                            Services.NotificationService.closeCenter()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Color.surfaceHover
                }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Style.spacingSmall
                    model: root.history
                    verticalLayoutDirection: ListView.TopToBottom

                    Connections {
                        target: Services.NotificationService
                        function onCenterOpenChanged() {
                            if (Services.NotificationService.centerOpen)
                                Qt.callLater(historyList.positionViewAtBeginning)
                        }
                    }

                    delegate: Rectangle {
                        required property string appName
                        required property string summary
                        required property string body
                        required property double timestamp
                        required property int index

                        width: historyList.width
                        implicitHeight: historyContent.implicitHeight
                            + Style.paddingMedium * 2
                        radius: Style.radiusMedium
                        color: Color.surfaceElevated
                        border.width: 1
                        border.color: Color.outlineVariant

                        Column {
                            id: historyContent
                            anchors.fill: parent
                            anchors.margins: Style.paddingMedium
                            spacing: Style.spacingXs

                            Row {
                                width: parent.width
                                spacing: Style.spacingSmall

                                MaterialIcon {
                                    text: {
                                        const name = appName.toLowerCase()

                                        if (
                                            name.includes("discord")
                                            || name.includes("vesktop")
                                        )
                                            return "chat"

                                        if (name.includes("steam"))
                                            return "sports_esports"

                                        if (
                                            name.includes("firefox")
                                            || name.includes("chrome")
                                            || name.includes("browser")
                                        )
                                            return "language"

                                        if (name.includes("spotify"))
                                            return "music_note"

                                        return "notifications"
                                    }
                                    color: Color.tertiaryContainer
                                    font.pixelSize: Style.materialIconSmall
                                }

                                Text {
                                    width: parent.width - timeLabel.width
                                        - dismissButton.width
                                        - Style.spacingSmall * 3
                                    text: appName.length > 0
                                        ? appName
                                        : "Notification"
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: timeLabel
                                    text: root.relativeTime(timestamp)
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                }

                                ToolButton {
                                    id: dismissButton
                                    display: AbstractButton.IconOnly
                                    width: Style.barIconSmall
                                    height: Style.barIconSmall
                                    padding: 0
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove"
                                    contentItem: MaterialIcon {
                                        text: "close"
                                        color: dismissButton.hovered
                                            ? Color.foreground
                                            : Color.foregroundMuted
                                        font.pixelSize: Style.materialIconSmall
                                    }
                                    onClicked:
                                        Services.NotificationService.removeHistory(
                                            index
                                        )
                                }
                            }

                            Text {
                                width: parent.width
                                text: summary
                                color: Color.foreground
                                font.pixelSize: Style.fontSmall
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Text {
                                width: parent.width
                                text: body
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No notifications"
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                        visible: historyList.count === 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: Services.NotificationService.dnd
                            ? "notifications_off"
                            : "notifications"
                        color: Services.NotificationService.dnd
                            ? Color.tertiaryContainer
                            : Color.foregroundMuted
                        font.pixelSize: Style.materialIconSmall
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Services.NotificationService.dnd
                            ? "Do Not Disturb enabled"
                            : "Notifications enabled"
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                    }

                    Text {
                        text: `${historyList.count}`
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                    }
                }
            }
        }
    }

    function relativeTime(timestamp) {
        const seconds = Math.max(
            0,
            Math.floor((Date.now() - timestamp) / 1000)
        )

        if (seconds < 60)
            return "now"

        const minutes = Math.floor(seconds / 60)

        if (minutes < 60)
            return `${minutes}m`

        const hours = Math.floor(minutes / 60)

        if (hours < 24)
            return `${hours}h`

        return `${Math.floor(hours / 24)}d`
    }
}
