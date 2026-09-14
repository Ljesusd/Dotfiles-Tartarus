import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../services" as Services
import "../theme"

Scope {
    id: root
    required property ShellScreen monitorScreen
    required property var monitorContext

    function mediaLabel(notification) {
        if (!notification)
            return ""
        const summary = String(notification.summary || "")
        const body = String(notification.body || "")
        if (/^:emoji[_-]\d+:$/i.test(summary)
                || /^:.*emoji.*:$/i.test(summary))
            return "[Emoji personalizado]"
        if (/\b(gif|animad[oa])\b/i.test(summary + " " + body))
            return "[GIF]"
        return ""
    }

    readonly property var items: Services.NotificationService.notifications
    readonly property int maxVisible: 3

    PanelWindow {
        screen: root.monitorScreen
        anchors { top: true; right: true }
        margins { top: Style.barHeight + Style.spacingLarge; right: Style.paddingLarge }
        implicitWidth: 360
        implicitHeight: stack.childrenRect.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.monitorContext.notificationPopupCount > 0
            && !Services.NotificationService.dnd
            && !Services.NotificationService.centerOpen


        Column {
            id: stack
            width: 360
            spacing: Style.spacingMedium

            Repeater {
                model: root.items
                delegate: Rectangle {
                    required property var notification
                    required property int index
                    required property string screenName
                    required property int notificationId
                    visible: root.monitorContext.notificationPopupIds
                        .indexOf(notificationId) !== -1
                    width: stack.width
                    height: content.implicitHeight + Style.paddingLarge * 2
                    radius: Style.radiusLarge
                    color: Color.backgroundAlt
                    border.width: Style.panelBorderWidth
                    border.color: Color.outlineVariant

                    function closeNotification() {
                        Services.NotificationService.close(notificationId)
                    }

                    Column {
                        id: content
                        anchors.fill: parent
                        anchors.margins: Style.paddingLarge
                        spacing: Style.spacingXs
                        RowLayout {
                            width: parent.width
                            Text {
                                Layout.fillWidth: true
                                text: notification && notification.appName
                                    ? notification.appName
                                    : "Notification"
                                color: Color.foregroundMuted
                                font.pixelSize: Style.fontSmall
                            }
                            ToolButton {
                                display: AbstractButton.IconOnly
                                contentItem: MaterialIcon {
                                    text: "close"
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.materialIconSmall
                                }
                                onClicked: closeNotification()
                            }
                        }
                        RowLayout {
                            width: parent.width
                            spacing: Style.spacingMedium
                            Image {
                                id: notificationImage
                                Layout.minimumWidth: visible ? 48 : 0
                                Layout.preferredWidth: visible ? 48 : 0
                                Layout.maximumWidth: visible ? 48 : 0
                                Layout.minimumHeight: visible ? 48 : 0
                                Layout.preferredHeight: visible ? 48 : 0
                                Layout.maximumHeight: visible ? 48 : 0
                            readonly property string imageSource:
                                notification && typeof notification.image === "string"
                                    ? notification.image
                                    : ""
                            visible: imageSource.length > 0
                            source: visible
                                ? (imageSource.startsWith("file://")
                                    || imageSource.startsWith("image://")
                                    || imageSource.startsWith("data:")
                                    ? imageSource
                                    : "file://" + imageSource)
                                : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 96
                            sourceSize.height: 96
                                clip: true
                                asynchronous: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Style.spacingXs
                                Text {
                                    text: notification ? notification.summary : ""
                                    color: Color.foreground
                                    font.pixelSize: notification && String(notification.appName || "").toLowerCase().includes("kitty")
                                        ? Style.fontSmall : Style.fontNormal
                                    font.bold: !(notification && String(notification.appName || "").toLowerCase().includes("kitty"))
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    id: bodyLabel
                                    text: notification ? notification.body : ""
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: root.mediaLabel(notification).length > 0
                                    text: root.mediaLabel(notification)
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        Row {
                            id: actionRow
                            spacing: Style.spacingSmall
                            visible: actionRepeater.count > 0
                            Repeater {
                                id: actionRepeater
                                model: notification && notification.actions
                                    ? notification.actions.filter(action =>
                                        action
                                        && String(action.text || "").trim().length > 0
                                        && !(String(action.identifier || "") === "default"
                                            && String(action.text || "").trim() === ""))
                                    : []
                                delegate: ToolButton {
                                    id: actionButton
                                    required property var modelData
                                    readonly property string actionText: modelData.text
                                    visible: actionText.length > 0

                                    text: actionText
                                    height: 30
                                    implicitWidth: actionLabel.implicitWidth
                                        + Style.paddingLarge * 2

                                    contentItem: Text {
                                        id: actionLabel
                                        text: actionButton.actionText
                                        color: actionButton.pressed
                                            ? Color.foreground
                                            : Color.onPrimaryContainer
                                        font.pixelSize: Style.fontSmall
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    background: Rectangle {
                                        radius: Style.radiusSmall
                                        color: actionButton.pressed
                                            ? Color.selection
                                            : actionButton.hovered
                                                ? Color.surfaceHover
                                                : Color.primaryContainer
                                    }

                                    onClicked: Services.NotificationService.invokeAction(
                                        notificationId,
                                        modelData.identifier
                                    )
                                }
                            }
                        }
                    }
                    HoverHandler { }


                }
            }
        }
    }
}
