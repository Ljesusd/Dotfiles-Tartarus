import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var monitorScreen
    screen: root.monitorScreen
    anchors { top: true; bottom: true; left: true; right: true }
    margins { top: 0; bottom: 0; left: 0; right: 0 }
    implicitWidth: root.monitorScreen?.width ?? 1
    implicitHeight: root.monitorScreen?.height ?? 1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.aboveWindows: false
    WlrLayershell.namespace: "tartarus-desktop-widgets"

    DesktopMusicWidget {
        monitorScreen: root.monitorScreen
    }

    DesktopWidgetSlot {
        id: clockSlot
        monitorScreen: root.monitorScreen
        widgetId: "clock"
        defaultX: 36
        defaultY: 92
        DesktopClockWidget { }
    }

    DesktopWidgetSlot {
        id: weatherSlot
        monitorScreen: root.monitorScreen
        widgetId: "weather"
        defaultX: 36
        defaultY: 250
        DesktopWeatherWidget { }
    }

    DesktopWidgetSlot {
        id: calendarSlot
        monitorScreen: root.monitorScreen
        widgetId: "calendar"
        defaultX: 36
        defaultY: 460
        DesktopCalendarWidget { }
    }

    DesktopWidgetSlot {
        id: hardwareSlot
        monitorScreen: root.monitorScreen
        widgetId: "hardware"
        defaultX: Math.max(24, (root.monitorScreen?.width ?? 1280) - 365)
        defaultY: 92
        DesktopHardwareWidget { active: hardwareSlot.visible; monitorName: root.monitorScreen?.name ?? "default" }
    }

    DesktopWidgetSlot {
        id: notesSlot
        monitorScreen: root.monitorScreen
        widgetId: "notes"
        defaultX: Math.max(24, (root.monitorScreen?.width ?? 1280) - 355)
        defaultY: 300
        DesktopNotesWidget { }
    }
}
