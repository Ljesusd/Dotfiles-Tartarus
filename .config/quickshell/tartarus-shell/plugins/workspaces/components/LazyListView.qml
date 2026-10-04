import QtQuick
import "../../../theme"

ListView {
    id: root

    // Small compatibility layer for the subset of Caelestia's LazyListView
    // used by the workspace strip.
    property real preferredHeight: contentHeight
    property real visibleHeight: contentHeight
    property bool trackViewport: false
    readonly property bool ready: true
    readonly property bool adding: false
    readonly property bool removing: false
    property int addDuration: Style.motionNormal
    property int removeDuration: Style.motionNormal

    implicitHeight: root.preferredHeight

    add: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.addDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.82
                to: 1
                duration: root.addDuration
                easing.type: Easing.OutBack
            }
        }
    }

    remove: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: root.removeDuration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                property: "scale"
                to: 0.82
                duration: root.removeDuration
                easing.type: Easing.InCubic
            }
        }
    }

    displaced: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: root.addDuration
            easing.type: Easing.OutCubic
        }
    }
}
