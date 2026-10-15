import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme

PanelWindow {
    required property var monitorScreen
    required property var monitorContext
    screen: monitorScreen
    anchors { bottom: true; left: true }
    margins { bottom: Theme.Style.barHeight + Theme.Style.spacingLarge; left: Theme.Style.spacingLarge }
    implicitWidth: Math.min(
        320,
        Math.max(240, (root.monitorScreen?.width ?? 1280) - Theme.Style.spacingLarge * 2)
    )
    implicitHeight: 58
    color: "transparent"
    visible: monitorContext.osdActive
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
        anchors.fill: parent; radius: Theme.Style.radiusLarge
        color: Theme.Color.surfaceContainer; border.width: Theme.Style.panelBorderWidth; border.color: Theme.Color.outlineVariant
        RowLayout { anchors.fill: parent; anchors.margins: Theme.Style.paddingMedium; spacing: Theme.Style.spacingMedium
            Theme.MaterialIcon { text: monitorContext.osdKind === "microphone" ? (monitorContext.osdMuted ? "mic_off" : "mic") : monitorContext.osdKind === "brightness" ? "brightness_6" : (monitorContext.osdMuted ? "volume_off" : "volume_up"); iconSize: Theme.Style.materialIconMedium; iconColor: Theme.Color.primary }
            Text { Layout.fillWidth: true; text: monitorContext.osdKind === "microphone" ? "Microphone" : monitorContext.osdKind === "brightness" ? "Brightness" : "Volume"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal }
            Text { text: monitorContext.osdMuted ? "Muted" : Math.round(monitorContext.osdValue) + "%"; color: Theme.Color.foreground; font.pixelSize: Theme.Style.fontNormal; font.bold: true }
        }
    }
}
