import Quickshell
import QtQuick

import "../../theme"
import "../../services" as Services

Rectangle {
    id: root

    signal closeLauncherRequested()

    color: "transparent"
    radius: 0
    border.width: 0

    implicitWidth: clockText.implicitWidth
        + Style.barPaddingNormal * 2

    implicitHeight: Style.barControlHeight

    Text {
        id: clockText

        anchors.centerIn: parent

        font.pixelSize: Style.barFontNormal

        text: Services.LocationService.currentTime

        color: Color.foreground
    }

    TapHandler {
        onTapped: {
            root.closeLauncherRequested()
        }
    }
}
