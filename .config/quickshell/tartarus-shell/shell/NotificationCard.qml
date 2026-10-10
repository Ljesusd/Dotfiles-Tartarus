import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../services/NotificationMedia.js" as Media
import "../theme"

// Shared presentation for live popups and the notification history. Keeping
// the card in one place makes the popup and SwayNC-like center behave alike.
Rectangle {
    id: root

    property var notification: null
    property string appName: notification ? (notification.appName || "") : ""
    property string summary: notification ? (notification.summary || "") : ""
    property string body: notification ? (notification.body || "") : ""
    property string image: notification ? (notification.image || "") : ""
    property var actions: notification && notification.actions
        ? notification.actions
        : []
    property string notificationId: notification ? `${notification.id}` : ""
    property string timestampLabel: ""
    property string screenName: ""
    property int groupCount: 1
    property bool compact: false
    property bool showActions: true
    property bool showRemove: false
    property int historyIndex: -1

    signal dismissRequested()
    signal removeRequested(int index)
    signal actionRequested(string identifier)

    implicitHeight: content.implicitHeight + Style.paddingLarge * 2
    radius: Style.radiusLarge
    color: Color.surfaceContainer
    border.width: Style.panelBorderWidth
    border.color: Color.outlineVariant

    function twoFactorCode() {
        return Services.NotificationService.twoFactorCode(
            `${root.summary} ${root.body}`
        )
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall

        RowLayout {
            width: parent.width

            Text {
                Layout.fillWidth: true
                text: root.appName.length > 0 ? root.appName : "Notification"
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.groupCount > 1
                Layout.preferredWidth: visible ? groupCountLabel.implicitWidth + 12 : 0
                Layout.preferredHeight: visible ? 22 : 0
                radius: Style.radiusFull
                color: Color.primaryContainer

                Text {
                    id: groupCountLabel
                    anchors.centerIn: parent
                    text: `×${root.groupCount}`
                    color: Color.foreground
                    font.pixelSize: Style.fontSmall
                    font.bold: true
                }
            }

            Text {
                visible: root.timestampLabel.length > 0
                text: root.timestampLabel
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
            }

            ToolButton {
                visible: root.compact || root.showRemove
                display: AbstractButton.IconOnly
                padding: 0
                implicitWidth: Style.barIconSmall + Style.paddingSmall
                implicitHeight: Style.barIconSmall + Style.paddingSmall
                contentItem: MaterialIcon {
                    text: "close"
                    color: parent.hovered ? Color.foreground : Color.foregroundMuted
                    font.pixelSize: Style.materialIconSmall
                }
                onClicked: {
                    if (root.showRemove && root.historyIndex >= 0)
                        root.removeRequested(root.historyIndex)
                    else
                        root.dismissRequested()
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: Style.spacingMedium

            Rectangle {
                visible: Media.avatar(root.image, root.appName).length > 0
                Layout.preferredWidth: visible ? (root.compact ? 48 : 52) : 0
                Layout.preferredHeight: visible ? (root.compact ? 48 : 52) : 0
                radius: width / 2
                color: Color.surfaceContainerHigh
                clip: true

                Image {
                    anchors.fill: parent
                    source: Media.avatar(root.image, root.appName)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.spacingXs

                Text {
                    Layout.fillWidth: true
                    text: root.summary
                    color: Color.foreground
                    font.pixelSize: root.compact ? Style.fontSmall : Style.fontNormal
                    font.bold: !root.compact
                    wrapMode: Text.Wrap
                    maximumLineCount: root.compact ? 2 : 3
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: Media.textBody(root.body)
                    color: Color.foregroundMuted
                    font.pixelSize: Style.fontSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: root.compact ? 3 : 6
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        NotificationPreview {
            width: parent.width
            maxHeight: root.compact ? 140 : 180
            imageSource: Media.notificationPreview(
                root.image,
                root.body,
                root.appName
            )
        }

        Flow {
            width: parent.width
            spacing: Style.spacingSmall
            visible: root.showActions && actionRepeater.count > 0

            Repeater {
                id: actionRepeater
                model: root.actions
                delegate: ToolButton {
                    id: actionButton
                    required property var modelData
                    readonly property string actionText: modelData.text || ""
                    visible: actionText.length > 0
                    text: actionText
                    height: 30
                    implicitWidth: actionLabel.implicitWidth + Style.paddingLarge * 2

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

                    onClicked: root.actionRequested(modelData.identifier)
                }
            }

            ToolButton {
                visible: root.twoFactorCode().length > 0
                text: "Copiar código"
                height: 30
                onClicked: Services.NotificationService.copyTwoFactorCode(
                    `${root.summary} ${root.body}`,
                    root.screenName
                )
            }
        }
    }
}
