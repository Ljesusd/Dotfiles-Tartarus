import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext

    readonly property var groups: Services.NotificationService.groupedHistory

    PanelWindow {
        screen: root.monitorScreen
        anchors {
            top: true
            bottom: true
            right: true
        }
        margins {
            top: Style.barHeight + Style.spacingLarge
            right: Style.spacingLarge
            bottom: Style.spacingLarge
        }
        implicitWidth: Math.min(
            440,
            Math.max(300, (root.monitorScreen?.width ?? 1280) - Style.spacingLarge * 2)
        )
        implicitHeight: Math.min(
            720,
            Math.max(420, (root.monitorScreen?.height ?? 800)
                - Style.barHeight - Style.spacingLarge * 2)
        )
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: Services.NotificationService.centerOpen || drawer.opacity > 0

        Rectangle {
            id: drawer
            x: Services.NotificationService.centerOpen ? 0 : width
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            opacity: Services.NotificationService.centerOpen ? 1 : 0
            clip: true
            radius: Style.panelRadius
            color: Color.surfaceContainer
            border.width: Style.panelBorderWidth
            border.color: Color.outlineVariant

            Behavior on x {
                NumberAnimation {
                    duration: Style.motionNormal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.motionFast
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingLarge
                spacing: Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Notificaciones"
                            color: Color.foreground
                            font.pixelSize: Style.fontNormal
                            font.bold: true
                        }
                        Text {
                            text: `${historyList.count} aplicaciones · ${Services.NotificationService.history.count} avisos`
                            color: Color.foregroundMuted
                            font.pixelSize: Style.fontSmall
                        }
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: Services.NotificationService.dnd
                            ? "Desactivar no molestar"
                            : "Activar no molestar"
                        contentItem: MaterialIcon {
                            text: Services.NotificationService.dnd
                                ? "notifications_off"
                                : "notifications"
                            color: Services.NotificationService.dnd
                                ? Color.tertiaryContainer
                                : Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.toggleDnd(
                            root.monitorScreen.name
                        )
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Limpiar historial"
                        contentItem: MaterialIcon {
                            text: "delete_sweep"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.clearHistory()
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Cerrar"
                        contentItem: MaterialIcon {
                            text: "close"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: {
                            root.monitorContext.closeNotificationCenter()
                            Services.NotificationService.closeCenter()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Color.surfaceHover
                }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Style.spacingSmall
                    model: root.groups
                    verticalLayoutDirection: ListView.TopToBottom

                    Connections {
                        target: Services.NotificationService
                        function onCenterOpenChanged() {
                            if (Services.NotificationService.centerOpen)
                                Qt.callLater(historyList.positionViewAtBeginning)
                        }
                    }

                    delegate: Item {
                        id: groupItem
                        required property string appName
                        required property int count
                        required property string itemsJson
                        required property string latestAppName
                        required property string latestSummary
                        required property string latestBody
                        required property string latestImage
                        required property double latestTimestamp
                        required property int latestHistoryIndex
                        property bool expanded: false

                        function olderItems() {
                            try {
                                return JSON.parse(itemsJson || "[]")
                            } catch (error) {
                                return []
                            }
                        }

                        width: historyList.width
                        implicitHeight: groupContent.implicitHeight

                        Column {
                            id: groupContent
                            width: parent.width
                            spacing: Style.spacingSmall

                            NotificationCard {
                                width: parent.width
                                appName: groupItem.latestAppName || groupItem.appName
                                summary: groupItem.latestSummary
                                body: groupItem.latestBody
                                image: groupItem.latestImage
                                timestampLabel: root.relativeTime(groupItem.latestTimestamp)
                                groupCount: groupItem.count
                                showActions: false
                                showRemove: true
                                historyIndex: groupItem.latestHistoryIndex
                                screenName: root.monitorScreen.name
                                onRemoveRequested: index =>
                                    Services.NotificationService.removeHistory(index)
                            }

                            ToolButton {
                                visible: groupItem.count > 1
                                width: parent.width
                                height: 32
                                text: groupItem.expanded
                                    ? "Ocultar avisos anteriores"
                                    : `Ver ${groupItem.count - 1} avisos anteriores`
                                onClicked: groupItem.expanded = !groupItem.expanded

                                background: Rectangle {
                                    radius: Style.controlRadius
                                    color: parent.hovered
                                        ? Color.surfaceHover
                                        : Color.surfaceElevated
                                    border.width: 1
                                    border.color: Color.outlineVariant
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Style.spacingSmall
                                visible: groupItem.expanded

                                Repeater {
                                    model: groupItem.olderItems()
                                    delegate: NotificationCard {
                                        width: groupContent.width
                                        appName: modelData.appName
                                        summary: modelData.summary
                                        body: modelData.body
                                        image: modelData.image
                                        timestampLabel: root.relativeTime(
                                            modelData.timestamp
                                        )
                                        showActions: false
                                        showRemove: true
                                        historyIndex: modelData.historyIndex
                                        screenName: root.monitorScreen.name
                                        onRemoveRequested: index =>
                                            Services.NotificationService.removeHistory(index)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No hay notificaciones"
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                        visible: historyList.count === 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon {
                        text: Services.NotificationService.dnd
                            ? "notifications_off"
                            : "notifications"
                        color: Services.NotificationService.dnd
                            ? Color.tertiaryContainer
                            : Color.foregroundMuted
                        font.pixelSize: Style.materialIconSmall
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Services.NotificationService.dnd
                            ? "No molestar activo"
                            : "Notificaciones activas"
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                    }
                }
            }
        }
    }

    function relativeTime(timestamp) {
        const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000))
        if (seconds < 60) return "ahora"
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60) return `${minutes} min`
        const hours = Math.floor(minutes / 60)
        if (hours < 24) return `${hours} h`
        return `${Math.floor(hours / 24)} d`
    }
}
