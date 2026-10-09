pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../theme"

// Caelestia's moving surface highlight and result transitions, using
// Tartarus's palette/motion tokens instead of Caelestia dependencies.
ListView {
    id: root
    property bool pageActive: true
    clip: true
    spacing: Style.spacingXs
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    highlight: Rectangle {
        x: 0
        y: root.currentItem ? root.currentItem.y : 0
        width: root.width
        height: root.currentItem ? root.currentItem.height : 0
        visible: root.currentItem !== null
        radius: Style.cardRadius
        color: Qt.alpha(Color.foreground, 0.08)
        Behavior on y { Anim { duration: Style.launcherMotionFast } }
        Behavior on height { Anim { duration: Style.launcherMotionFast } }
    }
    opacity: pageActive ? 1 : 0
    Behavior on opacity { Anim { duration: Style.launcherMotionFast } }
    add: Transition { Anim { property: "opacity"; from: 0; to: 1; duration: Style.launcherMotionFast } }
    remove: Transition { Anim { property: "opacity"; from: 1; to: 0; duration: Style.launcherMotionFast } }
    displaced: Transition { Anim { properties: "x,y"; duration: Style.launcherMotionFast } }
    move: Transition { Anim { property: "y"; duration: Style.launcherMotionFast } }
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
}
