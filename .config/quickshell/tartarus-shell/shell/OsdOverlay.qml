import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "../theme"

PanelWindow {
    required property var monitorScreen
    required property var monitorContext
    screen: monitorScreen
    anchors { bottom: true; left: true }
    margins { bottom: Style.barHeight + Style.spacingLarge; left: Style.spacingLarge }
    implicitWidth: 260; implicitHeight: 58
    color: "transparent"
    visible: monitorContext.osdActive
    exclusionMode: ExclusionMode.Ignore
    Rectangle {
        anchors.fill: parent; radius: Style.radiusLarge
        color: Color.surfaceContainer; border.width: Style.panelBorderWidth; border.color: Color.outlineVariant
        RowLayout { anchors.fill: parent; anchors.margins: Style.paddingMedium; spacing: Style.spacingMedium
            MaterialIcon { text: monitorContext.osdKind === "microphone" ? (monitorContext.osdMuted ? "mic_off" : "mic") : monitorContext.osdKind === "brightness" ? "brightness_6" : (monitorContext.osdMuted ? "volume_off" : "volume_up"); iconSize: Style.materialIconMedium; iconColor: Color.primary }
            Text { Layout.fillWidth: true; text: monitorContext.osdKind === "microphone" ? "Microphone" : monitorContext.osdKind === "brightness" ? "Brightness" : "Volume"; color: Color.foreground; font.pixelSize: Style.fontNormal }
            Text { text: monitorContext.osdMuted ? "Muted" : Math.round(monitorContext.osdValue) + "%"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true }
        }
    }
}
