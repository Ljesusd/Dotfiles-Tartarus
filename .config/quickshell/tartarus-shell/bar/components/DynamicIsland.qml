import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services" as Services

Item {
    id: root

    required property var monitorContext
    required property var launcherState
    required property var shellState
    required property var workspaceService
    required property var screen

    readonly property string weatherText: Services.WeatherService.current
        ? Services.WeatherService.current.temp + "°" : "—°"
    readonly property string weatherLocation: Services.WeatherService.location || "Clima"
    readonly property string weatherIcon: Services.WeatherService.current
        ? Services.WeatherService.icon(Services.WeatherService.current.code, Services.WeatherService.current.isDay)
        : "cloud"
    readonly property bool weatherLoading: Services.WeatherService.loading
    property string currentTime: Qt.formatTime(new Date(), "HH:mm")
    readonly property bool primaryActivityActive:
        Services.TimerService.active || Services.RecorderService.active
    readonly property bool musicActive: !root.primaryActivityActive
        && Services.DynamicActivityService.mediaActive

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatTime(new Date(), "HH:mm")
    }

    implicitWidth: root.monitorContext.launcherOpened
        ? Style.launcherSearchWidth
        : Math.max(54, centerIsland.implicitWidth + (activityRow.implicitWidth > 0 ? activityRow.implicitWidth + Style.spacingMedium : 0))
    implicitHeight: Style.barInnerHeight

    Behavior on implicitWidth {
        Anim { duration: Style.motionPanel; easing.type: Easing.OutCubic }
    }

    Item {
        id: centerIsland
        anchors.centerIn: parent
        implicitWidth: root.monitorContext.launcherOpened
            ? Style.launcherSearchWidth
            : Math.max(54, (root.primaryActivityActive
                ? primaryRow.implicitWidth
                : root.musicActive ? mediaRow.implicitWidth
                : statusRow.implicitWidth) + Style.barPaddingNormal * 2)
        width: implicitWidth
        height: parent.height

        Rectangle {
        id: islandSurface
        anchors.fill: parent
        radius: Style.radiusFull
        color: root.monitorContext.launcherOpened
            ? "transparent"
            : Qt.rgba(Color.backgroundAlt.r, Color.backgroundAlt.g, Color.backgroundAlt.b, 0.92)
        border.width: root.monitorContext.launcherOpened
            ? Style.panelBorderWidth
            : 0
        border.color: Color.primary

        Behavior on color { ColorAnimation { duration: Style.motionFast } }
        Behavior on border.width { NumberAnimation { duration: Style.motionFast } }
        }

        LauncherSearch {
            id: launcherSearch
            anchors.fill: parent
            visible: root.monitorContext.launcherOpened
            opacity: visible ? 1 : 0
            launcherState: root.launcherState
            monitorContext: root.monitorContext
            shellState: root.shellState
            Behavior on opacity { Anim { duration: Style.motionFast } }
        }
    }

    RowLayout {
        id: activityRow
        anchors.right: centerIsland.left
        anchors.rightMargin: Style.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.barSpacingSmall
        visible: !root.monitorContext.launcherOpened

        Repeater {
            model: [
                { active: (root.primaryActivityActive || root.musicActive), icon: "schedule", label: "Hora", detail: root.currentTime, accent: Color.primary },
                { active: Services.DynamicActivityService.vpnActive, icon: "vpn_lock", label: "VPN", accent: Color.primary },
                { active: root.primaryActivityActive && Services.DynamicActivityService.mediaActive, icon: "music_note", label: "Media", accent: Color.accent, compact: true },
                { active: Services.DynamicActivityService.localSendActive, icon: "upload", label: "LocalSend", accent: Color.primary }
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
                        Services.MediaService.command("play-pause")
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

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        id: primaryRow

        anchors.centerIn: parent
        spacing: Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || !root.primaryActivityActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || !root.primaryActivityActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && root.primaryActivityActive

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutCubic } }

        TimerDial {
            visible: Services.TimerService.active
            progress: Services.TimerService.totalSeconds > 0
                ? Services.TimerService.remainingSeconds / Services.TimerService.totalSeconds
                : 0
            accent: Color.warning
        }

        MaterialIcon {
            visible: !Services.TimerService.active
            text: Services.TimerService.active ? "timer" : "fiber_manual_record"
            iconSize: Style.barIconSmall
            iconColor: Services.TimerService.active ? Color.warning : Color.error
        }

        Text {
            text: Services.TimerService.active
                ? Services.TimerService.label + (Services.TimerService.mode === "pomodoro"
                    ? " " + Services.TimerService.cycleText
                    : "")
                : "Grabando"
            color: Color.foreground
            font.pixelSize: Style.barFontSmall
        }

        Text {
            text: Services.TimerService.active
                ? Services.TimerService.displayTime
                : Services.RecorderService.displayTime
            color: Color.foreground
            font.pixelSize: Style.barFontSmall
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.preferredWidth: Style.barIconSmall + Style.spacingXs
            Layout.preferredHeight: Style.barIconSmall + Style.spacingXs
            radius: Style.radiusFull
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)

            MaterialIcon {
                anchors.centerIn: parent
                text: "stop"
                iconSize: Style.barIconSmall
                iconColor: Color.foregroundMuted
            }

            TapHandler {
                onTapped: {
                    Services.TimerService.stop()
                    Services.RecorderService.stop()
                }
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
        spacing: Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || !root.musicActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || !root.musicActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && root.musicActive

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutCubic } }

        Rectangle {
            Layout.preferredWidth: Style.barInnerHeight - 4
            Layout.preferredHeight: Style.barInnerHeight - 4
            radius: Style.radiusSmall
            clip: true
            color: Color.surfaceContainerHigh

            Image {
                id: albumArt
                anchors.fill: parent
                source: Services.MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: albumArt.status !== Image.Ready
                text: "music_note"
                iconSize: Style.barIconSmall
                iconColor: Color.foreground
            }
        }

        Text {
            text: Services.MediaService.title || Services.MediaService.identity || "Música"
            color: Color.foreground
            font.pixelSize: Style.barFontSmall
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
                    color: Color.foregroundMuted
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on height {
                        running: Services.MediaService.playing
                        loops: Animation.Infinite
                        NumberAnimation { to: 6 + ((index + 2) % 4) * 3; duration: 190 + index * 45; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 5 + (index % 3) * 3; duration: 230 + index * 35; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        TapHandler { onTapped: Services.MediaService.command("play-pause") }
    }

    RowLayout {
        id: statusRow

        anchors.centerIn: parent
        spacing: Style.spacingSmall
        opacity: root.monitorContext.launcherOpened || root.primaryActivityActive || root.musicActive ? 0 : 1
        scale: root.monitorContext.launcherOpened || root.primaryActivityActive || root.musicActive ? 0.82 : 1
        enabled: !root.monitorContext.launcherOpened && !root.primaryActivityActive && !root.musicActive

        Behavior on opacity { Anim { duration: Style.motionFast } }
        Behavior on scale { Anim { duration: Style.motionNormal; easing.type: Easing.OutCubic } }

        Rectangle {
            Layout.preferredWidth: weatherLabel.implicitWidth + 28
            Layout.preferredHeight: Style.barControlHeight
            color: "transparent"

            Row {
                anchors.centerIn: parent
                spacing: Style.spacingSmall

                MaterialIcon {
                    text: root.weatherIcon
                    iconSize: Style.barIconSmall
                    iconColor: Color.foreground
                }

                Text {
                    id: weatherLabel
                    text: root.weatherText
                    color: Color.foreground
                    font.pixelSize: Style.barFontSmall
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: clockLabel.implicitWidth + 28
            Layout.preferredHeight: Style.barControlHeight
            color: "transparent"

            Text {
                id: clockLabel
                anchors.centerIn: parent
                text: Services.LocationService.currentTime
                color: Color.foreground
                font.pixelSize: Style.barFontSmall
            }
        }
    }

}
