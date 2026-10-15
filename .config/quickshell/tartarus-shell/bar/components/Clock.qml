import Quickshell
import QtQuick

import "../../theme" as Theme
import "../../services" as Services

Rectangle {
    id: root

    signal closeLauncherRequested()

    color: "transparent"
    radius: 0
    border.width: 0

    implicitWidth: clockText.implicitWidth
        + Theme.Style.barPaddingNormal * 2

    implicitHeight: Theme.Style.barControlHeight

    Text {
        id: clockText

        anchors.centerIn: parent

        font.pixelSize: Theme.Style.barFontNormal

        text: Services.LocationService.currentTime

        color: Theme.Color.foreground
    }

    TapHandler {
        onTapped: {
            root.closeLauncherRequested()
        }
    }
}
