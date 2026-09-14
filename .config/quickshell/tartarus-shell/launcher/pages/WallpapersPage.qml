import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../theme"
import "../components"

Item {
    id: root

    required property var wallpapers
    required property var controller
    required property bool active
    required property string monitorName
    visible: root.active
    property int visibleSlots: 3

    readonly property string defaultWallpaperFolder: "~/Pictures/Wallpaper"
    readonly property int wallpaperCardWidth: Math.max(1, Math.min(280,
        Math.floor((wallpaperList.width / root.carouselItemCount - 20) / 0.9)))
    readonly property int wallpaperCardHeight: Math.round(root.wallpaperCardWidth * 9 / 16)
    readonly property int carouselDuration: Style.motionSlow
    readonly property int carouselItemCount: root.visibleSlots
    readonly property string monitorWallpaperPath:
        root.wallpapers.currentPathForMonitor(root.monitorName)

    function revealSelection() {
        if (!root.active)
            return

        if (root.controller.selectedIndex < 0) {
            return
        }

        if (wallpaperList.currentIndex >= 0)
            wallpaperList.currentIndex = root.controller.selectedIndex
    }

    onActiveChanged: {
        if (root.active) {
            root.revealSelection()
            root.wallpapers.refresh()
        }
    }

    Connections {
        target: root.controller

        function onSelectedIndexChanged() {
            root.revealSelection()
        }
    }

    readonly property Process openFolderProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text.length > 0)
                    console.log("Open wallpaper folder output:", text)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()

                if (text.length > 0)
                    console.warn("Open wallpaper folder error:", text)
            }
        }
    }

    function openWallpapersFolder() {
        if (!root.active)
            return

        root.openFolderProcess.command = [
            "/bin/bash",
            Quickshell.shellPath("scripts/open-wallpapers-folder.sh"),
            root.defaultWallpaperFolder
        ]

        root.openFolderProcess.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.paddingXLarge
        anchors.rightMargin: Style.paddingXLarge
        anchors.topMargin: Style.paddingLarge
        anchors.bottomMargin: Style.paddingLarge

        spacing: Style.spacingLarge

        RowLayout {
            visible: false
            Layout.fillWidth: true

            spacing: Style.spacingMedium

            MaterialIcon {
                text: "photo"
                iconSize: Style.materialIconMedium
                iconColor: Color.primary
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: Style.spacingXs

                Text {
                    text: "Wallpaper"

                    font.pixelSize: Style.fontNormal
                    font.weight: Font.DemiBold
                    color: Color.foreground
                }

                Text {
                    text: "Pick a wallpaper image"

                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                }
            }

            Text {
                text: root.monitorWallpaperPath
                    ? "Current"
                    : ""

                font.pixelSize: Style.fontSmall
                color: Color.tertiary
                opacity: root.monitorWallpaperPath ? 1 : 0
            }
        }

            Item {
                id: wallpaperViewport
                Layout.fillWidth: true
                Layout.preferredHeight: root.wallpaperCardHeight + Style.paddingLarge * 2
                Layout.minimumHeight: root.wallpaperCardHeight + Style.paddingLarge * 2
                Layout.leftMargin: Style.spacingLarge
                Layout.rightMargin: Style.spacingLarge

            MouseArea {
                id: wallpaperWheelArea

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                z: 1

                onWheel: event => {
                    if (!root.active || !root.wallpapers)
                        return

                    const horizDelta = event.angleDelta.x !== 0
                        ? event.angleDelta.x
                        : event.pixelDelta.x
                    const vertDelta = event.angleDelta.y !== 0
                        ? event.angleDelta.y
                        : event.pixelDelta.y
                    const absHoriz = Math.abs(horizDelta)
                    const absVert = Math.abs(vertDelta)

                    if (absHoriz < 2 && absVert < 2)
                        return

                    const delta = absHoriz > absVert
                        ? horizDelta
                        : vertDelta

                    if (delta > 0) {
                        root.controller.moveLeft()
                    } else if (delta < 0) {
                        root.controller.moveRight()
                    }

                    event.accepted = true
                }
            }

            PathView {
                id: wallpaperList

                anchors.fill: parent
                anchors.leftMargin: 42
                anchors.rightMargin: 42
                clip: true
                pathItemCount: root.carouselItemCount
                cacheItemCount: 4
                snapMode: PathView.SnapToItem
                highlightRangeMode: PathView.StrictlyEnforceRange
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightMoveDuration: root.carouselDuration
                interactive: false

                model: root.wallpapers.filtered(
                    root.controller.wallpaperQuery
                )
                currentIndex: root.active
                    ? root.controller.selectedIndex
                    : -1

                onCountChanged: {
                    if (root.active)
                        root.controller.resetSelection()
                }

                onCurrentIndexChanged: {
                    if (!root.active)
                        return

                    if (wallpaperList.currentIndex === -1)
                        return

                    root.controller.select(wallpaperList.currentIndex)
                }

                delegate: WallpaperItem {
                    required property var modelData
                    required property int index

                    wallpaper: modelData
                    cardWidth: root.wallpaperCardWidth
                    cardHeight: root.wallpaperCardHeight
                    selected: PathView.isCurrentItem
                    current:
                        modelData.path === root.monitorWallpaperPath

                    onActivated: {
                        root.controller.select(index)
                        root.controller.accept()
                    }
                }

                path: Path {
                    startX: 0
                    startY: wallpaperList.height / 2

                    PathAttribute {
                        name: "carouselScale"
                        value: 1
                    }

                    PathAttribute {
                        name: "carouselOpacity"
                        value: 1
                    }

                    PathAttribute {
                        name: "z"
                        value: 1
                    }

                    PathLine {
                        x: wallpaperList.width / 2
                        y: wallpaperList.height / 2
                    }

                    PathAttribute {
                        name: "carouselScale"
                        value: 1.0
                    }

                    PathAttribute {
                        name: "carouselOpacity"
                        value: 1.0
                    }

                    PathAttribute {
                        name: "z"
                        value: 3
                    }

                    PathLine {
                        x: wallpaperList.width
                        y: wallpaperList.height / 2
                    }

                    PathAttribute {
                        name: "carouselScale"
                        value: 1
                    }

                    PathAttribute {
                        name: "carouselOpacity"
                        value: 1
                    }

                    PathAttribute {
                        name: "z"
                        value: 1
                    }
                }
            }

            Rectangle {
                id: prevButton
                property bool hovered: false
                anchors {
                    left: parent.left
                    leftMargin: Style.spacingSmall
                    verticalCenter: parent.verticalCenter
                }
                width: 34
                height: 34
                radius: Style.radiusFull
                color: prevButton.hovered
                    ? Color.surfaceHover
                    : Color.surface
                border.width: Style.panelBorderWidth
                border.color: prevButton.hovered
                    ? Color.outline
                    : Color.outlineVariant
                z: 2

                Behavior on color {
                    ColorAnimation {
                        duration: Style.motionFast
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.motionFast
                        easing.type: Easing.OutCubic
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    iconSize: Style.materialIconSmall
                    iconColor: Color.foreground
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.controller.moveLeft()
                    onEntered: prevButton.hovered = true
                    onExited: prevButton.hovered = false
                    onCanceled: prevButton.hovered = false
                }
            }

            Rectangle {
                id: nextButton
                property bool hovered: false
                anchors {
                    right: parent.right
                    rightMargin: Style.spacingSmall
                    verticalCenter: parent.verticalCenter
                }
                width: 34
                height: 34
                radius: Style.radiusFull
                color: nextButton.hovered
                    ? Color.surfaceHover
                    : Color.surface
                border.width: Style.panelBorderWidth
                border.color: nextButton.hovered
                    ? Color.outline
                    : Color.outlineVariant
                z: 2

                Behavior on color {
                    ColorAnimation {
                        duration: Style.motionFast
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Style.motionFast
                        easing.type: Easing.OutCubic
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    iconSize: Style.materialIconSmall
                    iconColor: Color.foreground
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.controller.moveRight()
                    onEntered: nextButton.hovered = true
                    onExited: nextButton.hovered = false
                    onCanceled: nextButton.hovered = false
                }
            }

            Column {
                anchors.centerIn: wallpaperList
                spacing: Style.spacingMedium
                visible: root.active && wallpaperList.count === 0
                width: Math.min(parent.width * 0.8, 320)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: "No wallpapers found\n\nPut images in:\n  ~/Pictures/Wallpaper\n(or ~/Pictures/Wallpapers)"
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.35
                    lineHeightMode: Text.ProportionalHeight
                    font.pixelSize: Style.fontSmall
                    color: Color.foregroundMuted
                    font.weight: Font.Medium
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: Math.min(parent.width, 240)
                    height: Style.itemHeight
                    radius: Style.radiusMedium
                    color: Color.primary
                    border.color: Color.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Style.spacingSmall

                        MaterialIcon {
                            text: "folder_open"
                            iconSize: Style.materialIconSmall
                            iconColor: Color.onPrimary
                        }

                        Text {
                            text: "Open wallpapers folder"
                            color: Color.onPrimary
                            font.pixelSize: Style.fontSmall
                            font.weight: Font.Medium
                        }
                    }

                    TapHandler {
                        id: openFolderTap
                        onTapped: root.openWallpapersFolder()
                    }
                }
            }
        }
    }
}
