import Quickshell
import QtQuick

import "../../theme"

Rectangle {
    id: root

    signal closeLauncherRequested()

    color: "transparent"

    implicitWidth: clockText.implicitWidth
        + Style.barPaddingNormal * 2

    implicitHeight: Style.barControlHeight

    Text {
        id: clockText

        anchors.centerIn: parent

        font.pixelSize: Style.barFontNormal

        text: Qt.formatDateTime(
            clock.date,
            "HH:mm"
        )

        color: Color.foreground
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    TapHandler {
        onTapped: {
            root.closeLauncherRequested()
        }
    }
}
