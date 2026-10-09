import QtQuick
import Quickshell.Widgets
import "../../theme"

// Caelestia's launcher composition adapted to Tartarus: fixed icon slot,
// vertically centred text block, selection painted by the surrounding list.
Item {
    id: root
    required property bool selected
    property string title: ""
    property string description: ""
    property string iconSource: ""
    property string symbol: "apps"
    property bool showChevron: false
    readonly property bool highlighted: selected || pointer.containsMouse
    readonly property int iconStatus: appIcon.status
    signal activated()
    signal hovered()

    implicitWidth: ListView.view ? ListView.view.width : 0
    implicitHeight: Math.max(64, labels.implicitHeight + Style.paddingSmall * 2)

    Rectangle {
        anchors.fill: parent
        radius: Style.cardRadius
        color: Color.foreground
        opacity: pointer.pressed ? 0.12 : pointer.containsMouse && !root.selected ? 0.04 : 0
        Behavior on opacity { Anim { duration: Style.launcherMotionFast } }
    }
    Item {
        id: iconSlot
        objectName: "launcherIconSlot"
        x: Style.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36
        IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: 32
            source: root.iconSource
            asynchronous: true
            mipmap: true
            visible: status === Image.Ready
        }
        MaterialIcon {
            anchors.centerIn: parent
            visible: appIcon.status !== Image.Ready
            text: root.symbol
            iconSize: 26
            iconColor: Color.foregroundMuted
        }
    }
    Column {
        id: labels
        objectName: "launcherLabels"
        anchors.left: iconSlot.right
        anchors.leftMargin: Style.spacingMedium
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: Style.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: root.title
            textFormat: Text.PlainText
            font.pixelSize: Style.fontNormal
            color: Color.foreground
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.description
            textFormat: Text.PlainText
            font.pixelSize: Style.fontSmall
            color: Color.foregroundMuted
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
    MaterialIcon {
        id: chevron
        visible: root.showChevron
        anchors.right: parent.right
        anchors.rightMargin: Style.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        text: "chevron_right"
        iconSize: 18
        iconColor: Color.foregroundMuted
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: if (containsMouse && !root.selected) root.hovered()
        onClicked: root.activated()
    }
}
