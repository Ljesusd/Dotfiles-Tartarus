pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../theme" as Theme

// Caelestia's moving surface highlight and result transitions, using
// Tartarus's palette/motion tokens instead of Caelestia dependencies.
ListView {
    id: root
    property bool pageActive: true
    clip: true
    spacing: Theme.Style.spacingXs
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    highlight: Rectangle {
        x: 0
        y: root.currentItem ? root.currentItem.y : 0
        width: root.width
        height: root.currentItem ? root.currentItem.height : 0
        visible: root.currentItem !== null
        radius: Theme.Style.cardRadius
        color: Qt.alpha(Theme.Color.foreground, 0.08)
        Behavior on y { Theme.Anim { duration: Theme.Style.launcherMotionFast } }
        Behavior on height { Theme.Anim { duration: Theme.Style.launcherMotionFast } }
    }
    opacity: pageActive ? 1 : 0
    Behavior on opacity { Theme.Anim { duration: Theme.Style.launcherMotionFast } }
    add: Transition { Theme.Anim { property: "opacity"; from: 0; to: 1; duration: Theme.Style.launcherMotionFast } }
    remove: Transition { Theme.Anim { property: "opacity"; from: 1; to: 0; duration: Theme.Style.launcherMotionFast } }
    displaced: Transition { Theme.Anim { properties: "x,y"; duration: Theme.Style.launcherMotionFast } }
    move: Transition { Theme.Anim { property: "y"; duration: Theme.Style.launcherMotionFast } }
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
}
