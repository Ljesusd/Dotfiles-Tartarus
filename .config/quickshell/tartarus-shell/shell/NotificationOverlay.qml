import Quickshell
import QtQuick
import QtQuick.Controls
import "../services" as Services
import "../theme" as Theme

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext

    readonly property var items: Services.NotificationService.notifications
    readonly property int maxVisible: 3

    PanelWindow {
        screen: root.monitorScreen
        anchors { top: true; right: true }
        margins {
            top: Theme.Style.barHeight + Theme.Style.spacingLarge
            right: Theme.Style.paddingLarge
        }
        implicitWidth: Math.min(
            380,
            Math.max(280, (root.monitorScreen?.width ?? 1280) - Theme.Style.paddingLarge * 2)
        )
        implicitHeight: Math.min(
            stack.implicitHeight,
            Math.max(
                1,
                (root.monitorScreen?.height ?? 1080)
                    - Theme.Style.barHeight
                    - Theme.Style.spacingLarge
                    - Theme.Style.paddingLarge
            )
        )
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.monitorContext.notificationPopupCount > 0
            && !Services.NotificationService.dnd
            && !Services.NotificationService.centerOpen

        Flickable {
            anchors.fill: parent
            contentWidth: width
            contentHeight: stack.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: stack
                width: parent.width
                spacing: Theme.Style.spacingMedium

                Repeater {
                    model: root.items

                    delegate: NotificationCard {
                        id: card
                        required property var notification
                        required property var notificationId
                        required property string screenName
                        required property string groupKey

                        width: stack.width
                        compact: true
                        appName: notification ? notification.appName : ""
                        summary: notification ? notification.summary : ""
                        body: notification ? notification.body : ""
                        image: notification ? notification.image : ""
                        actions: notification && notification.actions
                            ? notification.actions
                            : []
                        screenName: card.screenName
                        groupCount: Services.NotificationService.liveGroupCount(
                            card.groupKey
                        )
                        showActions: true
                        visible: root.monitorContext.notificationPopupIds
                            .indexOf(notificationId) !== -1
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.97
                        height: visible ? implicitHeight : 0
                        transformOrigin: Item.Top

                        Behavior on opacity {
                            Theme.Anim { duration: Theme.Style.motionFast }
                        }
                        Behavior on scale {
                            Theme.Anim {
                                duration: Theme.Style.motionPopup
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            Theme.Anim {
                                duration: Theme.Style.motionPopup
                                easing.type: Easing.OutCubic
                            }
                        }

                        onDismissRequested:
                            Services.NotificationService.close(notificationId)
                        onActionRequested: identifier =>
                            Services.NotificationService.invokeAction(
                                notificationId,
                                identifier
                            )
                    }
                }
            }
        }
    }
}
