import QtQuick

import "." as Theme

Text {
    id: root

    property color iconColor: Theme.Color.foreground
    property int iconSize: Theme.Style.materialIconMedium
    property int fill: 0
    property int weight: 400
    property int grade: 0
    property int opticalSize: iconSize

    color: root.iconColor

    font.family: Theme.Style.materialIconFont
    font.pixelSize: root.iconSize
    font.variableAxes: ({
        "FILL": root.fill,
        "wght": root.weight,
        "GRAD": root.grade,
        "opsz": root.opticalSize
    })

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
