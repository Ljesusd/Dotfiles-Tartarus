import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "../services" as Services
import "../theme" as Theme

PanelWindow {
    id: root

    required property var monitorScreen

    readonly property bool active:
        Services.RecorderService.regionPickerOpen
        && Services.RecorderService.regionPickerScreen === (root.monitorScreen
            ? root.monitorScreen.name : "")

    property point startPoint: Qt.point(0, 0)
    property rect selection: Qt.rect(0, 0, 0, 0)

    screen: root.monitorScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    visible: root.active
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "tartarus-recording-region"

    function normalizedRect() {
        const x = Math.max(0, Math.min(selection.x, selection.x + selection.width))
        const y = Math.max(0, Math.min(selection.y, selection.y + selection.height))
        const width = Math.abs(selection.width)
        const height = Math.abs(selection.height)
        return Qt.rect(x, y, width, height)
    }

    onVisibleChanged: {
        if (visible) {
            root.selection = Qt.rect(0, 0, 0, 0)
            pickerFocus.forceActiveFocus()
        }
    }

    FocusScope {
        id: pickerFocus
        anchors.fill: parent
        focus: root.active
        Keys.onEscapePressed: Services.RecorderService.cancelRegionSelection()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.42)
        }

        Rectangle {
            id: selectionRect
            x: root.normalizedRect().x
            y: root.normalizedRect().y
            width: root.normalizedRect().width
            height: root.normalizedRect().height
            color: Qt.alpha(Theme.Color.primary, 0.20)
            border.width: 2
            border.color: Theme.Color.primary
            visible: width > 0 && height > 0
        }

        ColumnLayout {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.Style.paddingLarge
            spacing: Theme.Style.spacingSmall
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: pickerHint.implicitWidth + Theme.Style.paddingLarge * 2
                implicitHeight: pickerHint.implicitHeight + Theme.Style.paddingSmall * 2
                radius: Theme.Style.radiusFull
                color: Theme.Color.surfaceContainer
                border.width: 1
                border.color: Theme.Color.outline
                Text {
                    id: pickerHint
                    anchors.centerIn: parent
                    text: "Arrastra para seleccionar una región · Esc para cancelar"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontSmall
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.selection.width > 0
                    ? Math.round(root.selection.width) + " × " + Math.round(root.selection.height)
                    : ""
                color: Theme.Color.foreground
                font.pixelSize: 12
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: mouse => {
                root.startPoint = Qt.point(mouse.x, mouse.y)
                root.selection = Qt.rect(mouse.x, mouse.y, 0, 0)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.selection = Qt.rect(
                        root.startPoint.x,
                        root.startPoint.y,
                        mouse.x - root.startPoint.x,
                        mouse.y - root.startPoint.y
                    )
            }
            onReleased: {
                const selected = root.normalizedRect()
                if (selected.width < 8 || selected.height < 8) {
                    root.selection = Qt.rect(0, 0, 0, 0)
                    return
                }
                Services.RecorderService.completeRegionSelection(
                    root.monitorScreen.name,
                    Number(root.monitorScreen.x || 0) + selected.x,
                    Number(root.monitorScreen.y || 0) + selected.y,
                    selected.width,
                    selected.height
                )
            }
        }
    }
}
