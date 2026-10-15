import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme
import "../../services" as Services

Item {
    id: root

    required property var monitorContext
    required property var launcherState
    required property var shellState
    required property var workspaceService
    required property var screen
    signal musicRequested()

    readonly property string weatherText: Services.WeatherService.current
        ? Services.WeatherService.current.temp + "°" : "—°"
    readonly property string weatherLocation: Services.WeatherService.location || "Clima"
    readonly property string weatherIcon: Services.WeatherService.current
        ? Services.WeatherService.icon(Services.WeatherService.current.code, Services.WeatherService.current.isDay)
        : "cloud"
    readonly property bool weatherLoading: Services.WeatherService.loading
    property string currentTime: Qt.formatTime(new Date(), "HH:mm")
    // Screen recording has its own floating HUD. Keep the island available
    // for music and running apps while a capture is in progress.
    readonly property bool primaryActivityActive:
        Services.TimerService.active
    readonly property bool musicActive: !root.primaryActivityActive
        && Services.MediaService.available
        && (Services.DynamicActivityService.mediaActive || Services.MediaService.title !== "")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "HH:mm")
    }

    implicitWidth: root.monitorContext.launcherOpened
        ? Theme.Style.launcherSearchWidth
        : Math.max(54, centerIsland.implicitWidth + (activityRow.implicitWidth > 0 ? activityRow.implicitWidth + Theme.Style.spacingMedium : 0))
    implicitHeight: Theme.Style.barInnerHeight

    Behavior on implicitWidth {
        Theme.Anim { duration: Theme.Style.motionPanel; easing.type: Easing.OutCubic }
    }

    Item {
        id: centerIsland
        anchors.centerIn: parent
        implicitWidth: root.monitorContext.launcherOpened
            ? Theme.Style.launcherSearchWidth
            : Math.max(54, (root.primaryActivityActive
                ? primaryRow.implicitWidth
                : root.musicActive ? mediaRow.implicitWidth
                : statusRow.implicitWidth) + Theme.Style.barPaddingNormal * 2)
        width: implicitWidth
        height: parent.height

        Rectangle {
        id: islandSurface
        anchors.fill: parent
        radius: Theme.Style.radiusFull
        color: root.monitorContext.launcherOpened
            ? "transparent"
            : Qt.rgba(Theme.Color.backgroundAlt.r, Theme.Color.backgroundAlt.g, Theme.Color.backgroundAlt.b, 0.92)
        border.width: root.monitorContext.launcherOpened
            ? Theme.Style.panelBorderWidth
            : 0
        border.color: Theme.Color.primary

        Behavior on color { ColorAnimation { duration: Theme.Style.motionFast } }
        Behavior on border.width { NumberAnimation { duration: Theme.Style.motionFast } }
        }

        LauncherSearch {
            id: launcherSearch
            anchors.fill: parent
            visible: root.monitorContext.launcherOpened
            opacity: visible ? 1 : 0
            launcherState: root.launcherState
            monitorContext: root.monitorContext
            shellState: root.shellState
            Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        }
    }

    RowLayout {
        id: activityRow
        anchors.right: centerIsland.left
        anchors.rightMargin: Theme.Style.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.Style.barSpacingSmall
        visible: !root.monitorContext.launcherOpened

        Repeater {
            model: [
                { active: (root.primaryActivityActive || root.musicActive), icon: "schedule", label: "Hora", detail: root.currentTime, accent: Theme.Color.primary },
                { active: Services.DynamicActivityService.vpnActive, icon: "vpn_lock", label: "VPN", accent: Theme.Color.primary },
                { active: root.primaryActivityActive && Services.DynamicActivityService.mediaActive, icon: "music_note", label: "Media", accent: Theme.Color.accent, compact: true },
                { active: Services.DynamicActivityService.localSendActive, icon: "upload", label: "LocalSend", accent: Theme.Color.primary }
            ].filter(activity => activity.active)

            delegate: ActivityBubble {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                detail: modelData.detail || ""
                accent: modelData.accent
                compact: modelData.compact || false
                artworkUrl: modelData.label === "Media" ? Services.MediaService.artUrl : ""
                visualizer: false
                onActivated: {
                    if (modelData.label === "Media")
                        root.musicRequested()
                }
            }
        }
    }

    RunningApps {
        id: apps
        anchors.centerIn: parent
        visible: false
        opacity: root.monitorContext.launcherOpened || root.primaryActivityActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || root.primaryActivityActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && !root.primaryActivityActive
        workspaceService: root.workspaceService
        screen: root.screen

        Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        Behavior on scale { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: primaryRow

        anchors.centerIn: parent
        spacing: Theme.Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || !root.primaryActivityActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || !root.primaryActivityActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && root.primaryActivityActive

        Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        Behavior on scale { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }

        TimerDial {
            visible: Services.TimerService.active
            progress: Services.TimerService.totalSeconds > 0
                ? Services.TimerService.remainingSeconds / Services.TimerService.totalSeconds
                : 0
            accent: Theme.Color.warning
        }

        Theme.MaterialIcon {
            visible: !Services.TimerService.active
            text: "timer"
            iconSize: Theme.Style.barIconSmall
            iconColor: Theme.Color.warning
        }

        Text {
            text: Services.TimerService.label + (Services.TimerService.mode === "pomodoro"
                ? " " + Services.TimerService.cycleText
                : "")
            color: Theme.Color.foreground
            font.pixelSize: Theme.Style.barFontSmall
        }

        Text {
            text: Services.TimerService.displayTime
            color: Theme.Color.foreground
            font.pixelSize: Theme.Style.barFontSmall
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.preferredWidth: Theme.Style.barIconSmall + Theme.Style.spacingXs
            Layout.preferredHeight: Theme.Style.barIconSmall + Theme.Style.spacingXs
            radius: Theme.Style.radiusFull
            color: Qt.rgba(Theme.Color.foreground.r, Theme.Color.foreground.g, Theme.Color.foreground.b, 0.12)

            Theme.MaterialIcon {
                anchors.centerIn: parent
                text: "stop"
                iconSize: Theme.Style.barIconSmall
                iconColor: Theme.Color.foregroundMuted
            }

            TapHandler {
                onTapped: Services.TimerService.stop()
            }
        }

        TapHandler {
            onTapped: {
                if (Services.TimerService.active)
                    Services.TimerService.togglePause()
            }
        }
    }

    RowLayout {
        id: mediaRow
        anchors.centerIn: parent
        spacing: Theme.Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || !root.musicActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || !root.musicActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && root.musicActive

        Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        Behavior on scale { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }

        Rectangle {
            Layout.preferredWidth: Theme.Style.barInnerHeight - 4
            Layout.preferredHeight: Theme.Style.barInnerHeight - 4
            radius: Theme.Style.radiusSmall
            clip: true
            color: Theme.Color.surfaceContainerHigh

            Image {
                id: albumArt
                anchors.fill: parent
                source: Services.MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Theme.MaterialIcon {
                anchors.centerIn: parent
                visible: albumArt.status !== Image.Ready
                text: "music_note"
                iconSize: Theme.Style.barIconSmall
                iconColor: Theme.Color.foreground
            }
        }

        Text {
            text: Services.MediaService.title || Services.MediaService.identity || "Música"
            color: Theme.Color.foreground
            font.pixelSize: Theme.Style.barFontSmall
            Layout.preferredWidth: Math.min(110, implicitWidth)
            Layout.minimumWidth: 0
            Layout.maximumWidth: 110
            elide: Text.ElideRight
        }

        Row {
            spacing: 2
            Repeater {
                model: 5
                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 5 + (index % 3) * 3
                    radius: 2
                    color: Theme.Color.foregroundMuted
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on height {
                        running: root.musicActive && !root.monitorContext.launcherOpened && Services.MediaService.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: 6 + ((index + 2) % 4) * 3; duration: 190 + index * 45; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 5 + (index % 3) * 3; duration: 230 + index * 35; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        TapHandler { onTapped: root.musicRequested() }
    }

    RowLayout {
        id: statusRow

        anchors.centerIn: parent
        spacing: Theme.Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || root.primaryActivityActive || root.musicActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || root.primaryActivityActive || root.musicActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && !root.primaryActivityActive && !root.musicActive

        Behavior on opacity { Theme.Anim { duration: Theme.Style.motionFast } }
        Behavior on scale { Theme.Anim { duration: Theme.Style.motionNormal; easing.type: Easing.OutCubic } }

        Rectangle {
            Layout.preferredWidth: weatherLabel.implicitWidth + 28
            Layout.preferredHeight: Theme.Style.barControlHeight
            color: "transparent"

            Row {
                anchors.centerIn: parent
                spacing: Theme.Style.spacingSmall

                Theme.MaterialIcon {
                    text: root.weatherIcon
                    iconSize: Theme.Style.barIconSmall
                    iconColor: Theme.Color.foreground
                }

                Text {
                    id: weatherLabel
                    text: root.weatherText
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.barFontSmall
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: clockLabel.implicitWidth + 28
            Layout.preferredHeight: Theme.Style.barControlHeight
            color: "transparent"

            Text {
                id: clockLabel
                anchors.centerIn: parent
                text: Services.LocationService.currentTime
                color: Theme.Color.foreground
                font.pixelSize: Theme.Style.barFontSmall
            }
        }
    }

}
