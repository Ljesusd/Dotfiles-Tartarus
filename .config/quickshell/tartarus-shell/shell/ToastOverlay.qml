import Quickshell
import QtQuick
import QtQuick.Layouts

import "../services" as Services
import "../theme"
import "."

Scope {
    id: root

    required property ShellScreen monitorScreen
    readonly property int maxVisibleToasts: 3
    readonly property var screenToasts:
        Services.ToastService.toasts.filter(
            toast => toast.screenName === root.monitorScreen.name
        )
    readonly property var visibleToasts:
        root.screenToasts.slice(
            0,
            root.maxVisibleToasts
        )

    PanelWindow {
        id: window

        screen: root.monitorScreen

        anchors {
            top: true
            right: true
        }

        margins {
            top: Style.barHeight
                + Style.spacingLarge
            right: Style.paddingLarge
        }

        implicitWidth: 320
        implicitHeight: toastStack.childrenRect.height

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.visibleToasts.length > 0

        Item {
            id: toastStack

            width: window.implicitWidth
            implicitHeight: childrenRect.height

            Repeater {
                id: toastRepeater

                model: root.visibleToasts

                ToastCard {
                    required property var modelData
                    required property int index

                    width: toastStack.width
                    toast: modelData

                    y: index === 0
                        ? 0
                        : toastRepeater.itemAt(index - 1).y
                            + toastRepeater.itemAt(index - 1).height
                            + Style.spacingMedium

                    Behavior on y {
                        NumberAnimation {
                            duration: Style.motionNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
