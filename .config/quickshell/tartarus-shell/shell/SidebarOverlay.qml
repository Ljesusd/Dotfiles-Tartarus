import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../services" as Services
import "../theme"

PanelWindow {
    id: root
    required property var monitorScreen
    required property var pluginRegistry
    required property var monitorContext
    screen: monitorScreen
    anchors { top: true; right: true; bottom: true; left: true }
    color: "transparent"
    property real offsetScale: monitorContext.sidebarOpened ? 0 : 1
    // Keep the window alive while the drawer animates out.  The drawer is
    // owned by this monitor; changing focus must not reparent or hide it.
    visible: monitorContext.sidebarOpened || offsetScale < 1
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onClicked: monitorContext.sidebarOpened = false
        Rectangle {
            id: drawer
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
            width: Math.min(root.monitorContext.sidebarTab === 0 ? 380 : 470, parent.width - 24)
            anchors.rightMargin: -(width + Style.spacingLarge) * root.offsetScale
            opacity: 1 - root.offsetScale
            scale: 0.97 + (1 - root.offsetScale) * 0.03
            transformOrigin: Item.Right
            Behavior on anchors.rightMargin { Anim { duration: Style.motionSlow } }
            Behavior on opacity { Anim { duration: Style.motionFast } }
            Behavior on scale { Anim { duration: Style.motionPanel; easing.type: Easing.OutCubic } }
            color: Color.surfaceContainer
            border.width: Style.panelBorderWidth
            border.color: Color.outlineVariant
            radius: Style.panelRadius
            clip: true
            MouseArea { anchors.fill: parent; onClicked: event => event.accepted = true }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingLarge
                spacing: Style.spacingLarge
                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Style.radiusFull
                        color: Color.primaryContainer
                        MaterialIcon { anchors.centerIn: parent; text: "monitor_heart"; iconSize: Style.materialIconMedium; iconColor: Color.primary }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.spacingXs
                        Text { text: "Centro de sistema"; Layout.fillWidth: true; color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true }
                        Text { text: "Información, hardware y periféricos"; Layout.fillWidth: true; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; elide: Text.ElideRight }
                    }
                    MaterialIcon {
                        text: "close"
                        iconSize: Style.materialIconMedium
                        iconColor: Color.foregroundMuted
                        TapHandler { onTapped: root.monitorContext.sidebarOpened = false }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacingSmall
                    Repeater {
                        model: [
                            { label: "Sistema", icon: "tune" },
                            { label: "Hardware", icon: "memory" },
                            { label: "Info", icon: "info" },
                            { label: "Periféricos", icon: "devices" },
                            { label: "Dashboard", icon: "dashboard" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Style.radiusFull
                            color: root.monitorContext.sidebarTab === index ? Color.primary : Color.surfaceContainerHigh
                            scale: tabHover.hovered ? 1.02 : 1
                            Behavior on color { ColorAnimation { duration: Style.motionFast } }
                            Behavior on scale { Anim { duration: Style.motionFast; easing.type: Easing.OutCubic } }
                            HoverHandler { id: tabHover }
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Style.spacingSmall
                                MaterialIcon {
                                    text: modelData.icon
                                    iconSize: Style.materialIconSmall
                                    iconColor: root.monitorContext.sidebarTab === index ? Color.onPrimary : Color.foregroundMuted
                                }
                                Text {
                                    text: modelData.label
                                    color: root.monitorContext.sidebarTab === index ? Color.onPrimary : Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                }
                            }
                            TapHandler { onTapped: root.monitorContext.sidebarTab = index }
                        }
                    }
                }
                StackLayout {
                    id: sidebarTabs
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.monitorContext.sidebarTab
                    SystemPanel { Layout.fillWidth: true; Layout.fillHeight: true; monitorScreen: root.monitorScreen; pluginRegistry: root.pluginRegistry }
                    HardwarePanel { Layout.fillWidth: true; Layout.fillHeight: true; monitorContext: root.monitorContext }
                    HardwareInfoPanel { Layout.fillWidth: true; Layout.fillHeight: true }
                    PeripheralPanel { Layout.fillWidth: true; Layout.fillHeight: true }
                    DashboardPanel { Layout.fillWidth: true; Layout.fillHeight: true; monitorScreen: root.monitorScreen }
                }
            }
        }
    }
}
