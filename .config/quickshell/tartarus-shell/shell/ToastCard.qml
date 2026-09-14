import QtQuick
import QtQuick.Layouts

import "../services" as Services
import "../theme"

Item {
    id: root

    required property var toast

    property bool entered: false

    implicitWidth: 320
    implicitHeight:
        content.implicitHeight
        + Style.paddingMedium * 2

    opacity: 0
    scale: 0.96

    states: [
        State {
            name: "entered"
            when: root.entered && !root.toast.closing

            PropertyChanges {
                root.opacity: 1
                root.scale: 1
            }
        },

        State {
            name: "closing"
            when: root.toast.closing

            PropertyChanges {
                root.opacity: 0
                root.scale: 0.94
            }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "entered"

            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    duration: Style.motionFast
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    property: "scale"
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }
        },

        Transition {
            from: "entered"
            to: "closing"

            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    duration: Style.motionSlow
                    easing.type: Easing.InCubic
                }

                NumberAnimation {
                    property: "scale"
                    duration: Style.motionSlow
                    easing.type: Easing.InCubic
                }
            }
        }
    ]

    Component.onCompleted: {
        root.entered = true
    }

    Rectangle {
        anchors.fill: parent

        radius: Style.radiusLarge
        color: Color.backgroundAlt
        border.width: Style.panelBorderWidth
        border.color: Color.outline
    }

    RowLayout {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Style.paddingMedium
            rightMargin: Style.paddingMedium
        }

        spacing: Style.spacingMedium

        Image {
            id: thumbnail
            Layout.preferredWidth: 96
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter

            visible: (root.toast.imagePath ?? "").length > 0
            source: visible
                ? "file://" + root.toast.imagePath
                : ""
            fillMode: Image.PreserveAspectCrop
            clip: true

            layer.enabled: true

            TapHandler {
                enabled: thumbnail.visible

                onTapped: {
                    Services.ImageViewerService.open(
                        root.toast.imagePath,
                        root.toast.screenName
                    )
                    Services.ToastService.dismiss(root.toast.toastId)
                }
            }
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignTop
            visible: (root.toast.icon ?? "").length > 0
            text: root.toast.icon ?? ""
            iconColor: Color.accent
            iconSize: Style.materialIconLarge
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                visible: (root.toast.title ?? "").length > 0

                text: root.toast.title ?? ""
                font.pixelSize: Style.fontSmall
                font.bold: true
                color: Color.foreground
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: (root.toast.body ?? "").length > 0

                text: root.toast.body ?? ""
                font.pixelSize: Style.fontSmall
                color: Color.foregroundMuted
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.spacingSmall

                spacing: Style.spacingSmall
                visible: (root.toast.actions ?? []).length > 0

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: root.toast.actions ?? []

                    Rectangle {
                        id: actionButton

                        required property var modelData

                        implicitWidth:
                            actionContent.implicitWidth
                            + Style.paddingSmall * 2
                        implicitHeight: 28

                        radius: Style.radiusSmall
                        color: actionHover.hovered
                            ? Color.surfaceHover
                            : Color.surface

                        RowLayout {
                            id: actionContent

                            anchors.centerIn: parent
                            spacing: Style.spacingSmall

                            MaterialIcon {
                                visible:
                                    (actionButton.modelData.icon ?? "")
                                        .length > 0
                                text:
                                    actionButton.modelData.icon ?? ""
                                iconSize: Style.materialIconSmall
                                iconColor: Color.accent
                            }

                            Text {
                                text: actionButton.modelData.label ?? ""
                                font.pixelSize: Style.fontSmall
                                font.weight: Font.DemiBold
                                color: Color.foreground
                            }
                        }

                        HoverHandler {
                            id: actionHover
                        }

                        TapHandler {
                            onTapped: {
                                Services.ToastService.triggerAction(
                                    root.toast.toastId,
                                    actionButton.modelData.actionId
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    TapHandler {
        onTapped: {
            Services.ToastService.dismiss(root.toast.toastId)
        }
    }

    HoverHandler {
        onHoveredChanged: {
            Services.ToastService.setHovered(
                root.toast.toastId,
                hovered
            )
        }
    }
}
