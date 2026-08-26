import QtQuick
import QtQuick.Layouts

import "../../theme"

Item {
    id: root

    required property string entryId
    readonly property bool isBarEntry: true

    default property alias content: contentHost.data

    readonly property Item contentItem:
        contentHost.children.length > 0
            ? contentHost.children[0]
            : null
    readonly property Item entryItem: {
        if (!root.contentItem)
            return null

        if ("item" in root.contentItem)
            return root.contentItem.item

        return root.contentItem
    }
    readonly property bool handlesWheel:
        root.entryItem
        && typeof root.entryItem.handleWheel === "function"
    readonly property bool handlesHover:
        root.entryItem
        && typeof root.entryItem.handleHover === "function"

    implicitWidth:
        root.contentItem
            ? root.contentItem.implicitWidth
            : 0

    implicitHeight: Style.barInnerHeight

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function handleWheel(angleDelta) {
        if (!root.handlesWheel)
            return false

        return root.entryItem.handleWheel(angleDelta)
    }

    function handleHover(hovered) {
        if (!root.handlesHover)
            return false

        return root.entryItem.handleHover(
            hovered,
            root
        )
    }

    Item {
        id: contentHost

        anchors.centerIn: parent

        width:
            root.contentItem
                ? root.contentItem.implicitWidth
                : 0

        height:
            root.contentItem
                ? root.contentItem.implicitHeight
                : 0
    }
}
