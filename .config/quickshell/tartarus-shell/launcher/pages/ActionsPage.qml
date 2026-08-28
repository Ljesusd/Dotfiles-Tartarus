import QtQuick

import "../../theme"
import "../components"

Item {
    id: root

    required property var actions
    required property var controller
    required property bool active
    visible: root.active

    function revealSelection() {
        if (!root.active)
            return

        if (root.controller.selectedIndex < 0)
            return

        if (actionList.currentIndex >= 0)
            actionList.positionViewAtIndex(
                actionList.currentIndex,
                ListView.Contain
            )
    }

    onActiveChanged: {
        if (root.active)
            root.revealSelection()
    }

    Connections {
        target: root.controller

        function onSelectedIndexChanged() {
            root.revealSelection()
        }
    }

    ListView {
        id: actionList

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom

            topMargin: Style.paddingLarge
            leftMargin: Style.paddingXLarge
            rightMargin: Style.paddingXLarge
            bottomMargin: Style.paddingXLarge
        }

        clip: true

        model: root.actions.filtered(
            root.controller.actionQuery
        )

        currentIndex: root.active
            ? root.controller.selectedIndex
            : -1

        onCountChanged: {
            if (root.active)
                root.controller.resetSelection()
        }

        delegate: ActionItem {
            required property var modelData
            required property int index

            action: modelData
            selected: ListView.isCurrentItem

            onHovered: {
                root.controller.select(index)
            }

            onActivated: {
                root.controller.select(index)
                root.controller.accept()
            }
        }
    }
}
